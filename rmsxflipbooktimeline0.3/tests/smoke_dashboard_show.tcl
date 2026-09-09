# Full GUI acceptance runs in a clean installed package and disposable VMD.
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set repo $::env(RMSX_TEST_REPO)
set install_prefix [file join [pwd] installed]
set startup [file join [pwd] qa-vmdrc]
set original_config "set ::qa_preserved_config yes\n"
set fp [open $startup w]; puts -nonewline $fp $original_config; close $fp
exec python3 [file join $repo scripts install.py] install --prefix $install_prefix --startup-file $startup
source -encoding utf-8 $startup
assert {$::qa_preserved_config eq "yes"} "Installer discarded existing startup content"
menu rmsxflipbooktimeline on
set w .rmsxflipbooktimeline_dashboard
assert {[winfo exists $w]} "Registered VMD menu did not open dashboard"
assert {[string first $install_prefix [::RMSXFlipbookTimeline::state_get basedir]] == 0} "GUI did not use clean installed package"
set children [winfo children .]
menu rmsxflipbooktimeline on
assert {[winfo children .] eq $children} "Repeated menu opening duplicated windows"
assert {![winfo exists .rmsxflipbooktimeline]} "Menu unexpectedly opened classic window"
assert {[llength [$w.tabs tabs]] == 5} "Dashboard must have five tabs"
assert {[wm minsize $w] eq {600 540}} "Unexpected compact minimum size"
wm geometry $w 600x540
update idletasks
foreach tab {easy matrix export advanced help} {
    $w.tabs select $w.tabs.$tab
    update idletasks
    foreach suffix {scroll_canvas scrollbar content} {assert {[winfo exists $w.tabs.$tab.$suffix]} "Missing scrolling widget: $tab.$suffix"}
    set body $w.tabs.$tab.content
    assert {[winfo reqwidth $body] <= [winfo width $body]+2} "Tab $tab content is clipped at minimum width: [winfo reqwidth $body]/[winfo width $body]"
}
set native_combo $w.tabs.easy.content.metric.metric_combo
assert {[$native_combo cget -values] eq {RMSX Shift-Map 1-lDDT}} "Compact native labels changed"
set matrix_combo $w.tabs.matrix.content.metric.metric_combo
set ::RMSXFlipbookTimeline::Dashboard::show_advanced 1
foreach metric [$matrix_combo cget -values] {
    set ::RMSXFlipbookTimeline::Dashboard::timeline_metric $metric
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    $w.tabs select $w.tabs.matrix
    update idletasks
    set body $w.tabs.matrix.content
    assert {[winfo reqwidth $body] <= [winfo width $body]+2} "Timeline options clipped for $metric"
}
# Geometry also grows cleanly with named fonts at the default 660 width.
set font_sizes {}
foreach font {TkDefaultFont TkTextFont TkHeadingFont TkMenuFont TkSmallCaptionFont} {
    if {[lsearch -exact [font names] $font] >= 0} {
        set size [font actual $font -size]
        dict set font_sizes $font $size
        font configure $font -size [expr {$size > 0 ? $size+2 : $size-2}]
    }
}
wm geometry $w 720x800
foreach tab {easy matrix export advanced help} {
    $w.tabs select $w.tabs.$tab
    update idletasks
    set body $w.tabs.$tab.content
    assert {[winfo reqwidth $body] <= [winfo width $body]+2} "Enlarged font clipped $tab"
}
dict for {font size} $font_sizes {font configure $font -size $size}
wm geometry $w 660x800
set ::RMSXFlipbookTimeline::Dashboard::show_advanced 0
set ::RMSXFlipbookTimeline::Dashboard::source_type new_analysis
set ::RMSXFlipbookTimeline::Dashboard::native_topology ""
set ::RMSXFlipbookTimeline::Dashboard::native_trajectory ""
::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
assert {[$w.tabs.easy.content.actions.run cget -state] eq "disabled"} "Run is active without source files"
# Real folder, keyed matrix navigation, committed source identity, close/reopen.
set folder [file join $repo fixtures seed_outputs native-rmsx-1ubq-9 chain_7_rmsx]
set ::RMSXFlipbookTimeline::Dashboard::folder $folder
::RMSXFlipbookTimeline::Dashboard::load_existing_folder
set result [::RMSXFlipbookTimeline::Results::get]
set result_id [dict get $result id]
set molids [::RMSXFlipbookTimeline::state_get molids]
set canvas $::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_canvas
assert {[dict exists $::RMSXFlipbookTimeline::Navigation::views $canvas cells]} "Native heatmap not connected to keyboard navigation"
::RMSXFlipbookTimeline::Navigation::key $canvas Return
::RMSXFlipbookTimeline::Navigation::key $canvas Right
assert {[lindex [dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] 1] == 1} "Right did not select the next heatmap cell"
assert {[llength [$canvas find withtag keyboard_selection]] == 1} "Keyboard cell focus is not visible"
set ::RMSXFlipbookTimeline::Dashboard::folder [file join [pwd] different-input]
assert {[::RMSXFlipbookTimeline::Dashboard::current_native_folder] eq $folder} "Editable source redirected committed result"
::RMSXFlipbookTimeline::Dashboard::close_window
assert {[wm state $w] eq "withdrawn"} "Close did not hide the window"
assert {[::RMSXFlipbookTimeline::state_get molids] eq $molids} "Close removed loaded scene"
menu rmsxflipbooktimeline on
assert {[dict get [::RMSXFlipbookTimeline::Results::get] id] == $result_id} "Reopen changed current result identity"
# Queue a cooperative operation and use the actual Stop control at a checkpoint.
proc gui_test_work {} {
    assert {[.rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.run cget -state] eq "disabled"} "Busy run button was not disabled"
    set ::qa_duplicate_entered 0
    ::RMSXFlipbookTimeline::Dashboard::invoke_action {set ::qa_duplicate_entered 1}
    after 0 {.rmsxflipbooktimeline_dashboard.footer.stop invoke}
    set ::RMSXFlipbookTimeline::Operation::last_service 0
    ::RMSXFlipbookTimeline::Operation::checkpoint [dict create stage calculating message "GUI cancellation test" completed 1 total 2]
}
::RMSXFlipbookTimeline::Dashboard::invoke_action gui_test_work
update
assert {[dict get [::RMSXFlipbookTimeline::Operation::get] state] eq "cancelled"} "Stop did not finish as cancelled"
assert {!$::qa_duplicate_entered} "Run accepted a reentrant operation"
assert {[dict get [::RMSXFlipbookTimeline::Results::get] id] == $result_id} "Cancellation replaced prior result"
assert {[$w.footer.stop cget -state] eq "disabled"} "Stop remained enabled after cancellation"
# Native calculation succeeds on disk, then actual hidden canvas drawing fails.
set before_native [::RMSXFlipbookTimeline::Results::get]
set old_canvas $::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_canvas
set old_cells [llength [$old_canvas find withtag heat_cell]]
set old_ids [::RMSXFlipbookTimeline::state_get molids]
rename ::RMSXFlipbookTimeline::PlotWindow::draw_prepared ::RMSXFlipbookTimeline::PlotWindow::qa_real_draw
proc ::RMSXFlipbookTimeline::PlotWindow::draw_prepared {target prepared} {
    set answer [qa_real_draw $target $prepared]
    if {[winfo manager $target] eq ""} {error "Injected hidden linked-view failure"}
    return $answer
}
set ::RMSXFlipbookTimeline::Dashboard::native_topology [file join $repo fixtures upstream test_files 1UBQ.pdb]
set ::RMSXFlipbookTimeline::Dashboard::native_trajectory [file join $repo fixtures upstream test_files mon_sys.dcd]
set ::RMSXFlipbookTimeline::Dashboard::native_output [file join [pwd] native-output]
file mkdir $::RMSXFlipbookTimeline::Dashboard::native_output
set ::RMSXFlipbookTimeline::Dashboard::native_chain 7
set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end 3
set ::RMSXFlipbookTimeline::Dashboard::native_slices 2
set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slices
set ::RMSXFlipbookTimeline::Dashboard::native_time_step ""
set ::RMSXFlipbookTimeline::Dashboard::native_total_time_ns auto
assert {[catch {::RMSXFlipbookTimeline::Dashboard::run_native_metric} saved_error saved_options]} "Hidden native drawing failure was swallowed"
assert {[dict get $saved_options -errorcode] eq {RMSXFLIPBOOK PARTIAL}} "Saved calculation did not report partial display failure"
assert {[dict get [::RMSXFlipbookTimeline::Results::get] id] == [dict get $before_native id]} "Linked-view failure replaced prior result"
assert {[::RMSXFlipbookTimeline::state_get molids] eq $old_ids} "Linked-view failure discarded prior structures"
assert {[winfo exists $old_canvas] && [llength [$old_canvas find all]] > 0} "Linked-view failure discarded visible heatmap"
assert {[$w.tabs.easy.content.actions.retry cget -state] eq "normal"} "Saved result retry was not enabled"
set saved_folder [dict get $::RMSXFlipbookTimeline::Dashboard::saved_result folder]
assert {[file isdirectory $saved_folder]} "Saved output was lost after display failure"
rename ::RMSXFlipbookTimeline::PlotWindow::draw_prepared {}
rename ::RMSXFlipbookTimeline::PlotWindow::qa_real_draw ::RMSXFlipbookTimeline::PlotWindow::draw_prepared
rename ::RMSXFlipbookTimeline::run_native_analysis ::RMSXFlipbookTimeline::qa_real_run
proc ::RMSXFlipbookTimeline::run_native_analysis {args} {error "Retry must not recalculate"}
$w.tabs.easy.content.actions.retry invoke
assert {[dict get [::RMSXFlipbookTimeline::Results::get] folder] eq $saved_folder} "Retry did not display exact saved folder"
assert {$::RMSXFlipbookTimeline::Dashboard::saved_result eq {}} "Successful retry retained stale saved target"
assert {[$w.tabs.easy.content.actions.retry cget -state] eq "disabled"} "Successful retry remained enabled"
rename ::RMSXFlipbookTimeline::run_native_analysis {}
rename ::RMSXFlipbookTimeline::qa_real_run ::RMSXFlipbookTimeline::run_native_analysis
# Live result metadata survives publication and a dead source does not prevent export.
set source [mol new [file join $repo fixtures upstream test_files 1UBQ.pdb] waitfor all]
mol addfile [file join $repo fixtures upstream test_files mon_sys.dcd] first 0 last 2 waitfor all molid $source
set ::RMSXFlipbookTimeline::Dashboard::timeline_molid $source
set ::RMSXFlipbookTimeline::Dashboard::timeline_metric Displacement
set ::RMSXFlipbookTimeline::Dashboard::timeline_selection protein
set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end 2
set ::RMSXFlipbookTimeline::Dashboard::timeline_column_mode frames
::RMSXFlipbookTimeline::Dashboard::run_live_metric
set live [::RMSXFlipbookTimeline::Results::get]
assert {[dict exists $live units] && [dict get $live units] ne ""} "Live publication lost scientific units"
assert {[dict get $live selection] eq "protein" && [dict get $live frame_first] == 0 && [dict get $live frame_last] == 2} "Live result lost selection or resolved frames"
assert {[string first [dict get $live units] $::RMSXFlipbookTimeline::Dashboard::result_title] >= 0} "Persistent result title omits units"
assert {[string first "Selection: protein" $::RMSXFlipbookTimeline::Dashboard::result_summary] >= 0} "Persistent result summary omits selection"
# A filtered result must retain the source selection, units, and resolved frames.
::RMSXFlipbookTimeline::TimelinePlot::filter_current 0 1000 0 -1 1
set live [::RMSXFlipbookTimeline::Results::get]
assert {[dict get $live selection] eq "protein" && [dict get $live frame_first] == 0 && [dict get $live frame_last] == 2} "Filtering lost live source metadata"
assert {[dict get $live provenance molid] == $source} "Filtering lost the resolved source molecule identity"
set timeline_window $::RMSXFlipbookTimeline::TimelinePlot::window
set timeline_canvas $::RMSXFlipbookTimeline::TimelinePlot::canvas
set live_dataset [dict get $live dataset]
set different [dict replace $live_dataset title Candidate]
assert {[catch {::RMSXFlipbookTimeline::TimelinePlot::show $different width invalid}]} "Bad Timeline layout accepted"
assert {[::RMSXFlipbookTimeline::TimelinePlot::current_dataset] eq $live_dataset} "Failed layout changed active Timeline data"
rename ::RMSXFlipbookTimeline::TimelinePlot::draw ::RMSXFlipbookTimeline::TimelinePlot::qa_real_draw
proc ::RMSXFlipbookTimeline::TimelinePlot::draw {dataset layout palette} {qa_real_draw $dataset $layout $palette; error "Injected Timeline draw failure"}
assert {[catch {::RMSXFlipbookTimeline::TimelinePlot::show $different}]} "Timeline draw failure swallowed"
assert {[winfo exists $timeline_window] && [winfo exists $timeline_canvas]} "Failed Timeline drawing destroyed prior popup"
assert {[::RMSXFlipbookTimeline::TimelinePlot::current_dataset] eq $live_dataset} "Failed drawing changed active Timeline data"
assert {[dict get [::RMSXFlipbookTimeline::Results::get] id] == [dict get $live id]} "Failed drawing replaced committed matrix"
rename ::RMSXFlipbookTimeline::TimelinePlot::draw {}
rename ::RMSXFlipbookTimeline::TimelinePlot::qa_real_draw ::RMSXFlipbookTimeline::TimelinePlot::draw
mol delete $source
rename ::RMSXFlipbookTimeline::Dashboard::choose_save_file ::RMSXFlipbookTimeline::Dashboard::qa_save_dialog
proc ::RMSXFlipbookTimeline::Dashboard::choose_save_file {kind} {return [file join [pwd] "detached.$kind"]}
foreach kind {tml svg png} {
    ::RMSXFlipbookTimeline::Dashboard::export_current $kind
    assert {[file isfile [file join [pwd] "detached.$kind"]]} "Detached matrix $kind export failed"
}
rename ::RMSXFlipbookTimeline::Dashboard::choose_save_file {}
rename ::RMSXFlipbookTimeline::Dashboard::qa_save_dialog ::RMSXFlipbookTimeline::Dashboard::choose_save_file
# Result publication remains successful even if the UI summary has a defect.
rename ::RMSXFlipbookTimeline::Dashboard::refresh_result_header ::RMSXFlipbookTimeline::Dashboard::qa_header
proc ::RMSXFlipbookTimeline::Dashboard::refresh_result_header {} {error "Injected notification failure"}
assert {![catch {::RMSXFlipbookTimeline::Results::update [dict create label Verified]}]} "Notification error invalidated committed result"
assert {[dict exists [::RMSXFlipbookTimeline::Results::get] notification_error]} "Notification failure was not retained for diagnosis"
rename ::RMSXFlipbookTimeline::Dashboard::refresh_result_header {}
rename ::RMSXFlipbookTimeline::Dashboard::qa_header ::RMSXFlipbookTimeline::Dashboard::refresh_result_header

::RMSXFlipbookTimeline::reset 1
assert {[file isdirectory $folder]} "Remove deleted source files"
exec python3 [file join $repo scripts install.py] uninstall --prefix $install_prefix --startup-file $startup
set fp [open $startup r]; set restored [read $fp]; close $fp
assert {$restored eq $original_config} "Uninstall did not preserve unrelated startup content"
puts "Dashboard GUI installation, geometry, navigation, lifecycle and Stop checks passed"
after 100 quit
