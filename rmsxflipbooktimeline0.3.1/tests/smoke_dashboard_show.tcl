# Full GUI acceptance runs in a clean installed package and disposable VMD.
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc assert_per_protein_rotation {molids} {
    # The displayed centers and viewing matrices must stay fixed while each protein
    # turns. A whole-row rotation can preserve distances and still fail this check.
    set centers {}
    set atoms {}
    set views [::RMSXFlipbookTimeline::Style::capture_view_matrices $molids]
    foreach id $molids {
        dict set centers $id [::RMSXFlipbookTimeline::Hotkeys::molecule_center $id]
        set sel [atomselect $id all]
        dict set atoms $id [$sel get {x y z}]
        $sel delete
    }
    foreach axis {x y z} {rotate $axis by 7}
    foreach id $molids {
        assert {[vecdist [dict get $centers $id] [::RMSXFlipbookTimeline::Hotkeys::molecule_center $id]] < 0.001} "Rotation translated protein $id"
        set sel [atomselect $id all]
        assert {[$sel get {x y z}] ne [dict get $atoms $id]} "Rotation left protein $id stationary"
        $sel delete
    }
    set after_views [::RMSXFlipbookTimeline::Style::capture_view_matrices $molids]
    foreach before $views after $after_views {
        foreach key {center_matrix global_matrix scale_matrix rotate_matrix} {
            foreach row [::RMSXFlipbookTimeline::MouseRotate::normalize_matrix [dict get $before $key]] next [::RMSXFlipbookTimeline::MouseRotate::normalize_matrix [dict get $after $key]] {
                foreach value $row actual $next {assert {abs($value-$actual) < 0.0001} "Rotation moved the flipbook view: $key"}
            }
        }
    }
}
set repo $::env(RMSX_TEST_REPO)
set install_prefix [file join [pwd] installed]
set startup [file join [pwd] qa-vmdrc]
set original_config "set ::qa_preserved_config yes\n"
set fp [open $startup w]; puts -nonewline $fp $original_config; close $fp
exec $::env(RMSX_TEST_PYTHON) [file join $repo scripts install.py] install --prefix $install_prefix --startup-file $startup
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
update
foreach tab {easy matrix export advanced help} {
    $w.tabs select $w.tabs.$tab
    update
    foreach suffix {scroll_canvas scrollbar content} {assert {[winfo exists $w.tabs.$tab.$suffix]} "Missing scrolling widget: $tab.$suffix"}
    set body $w.tabs.$tab.content
    assert {[winfo reqwidth $body] <= [winfo width $body]+2} "Tab $tab content is clipped at minimum width: [winfo reqwidth $body]/[winfo width $body]"
}
# Grouping frames must not cover their sibling controls. Check actual hit targets,
# since mapped widgets and requested-width checks alone miss this Tk failure.
$w.tabs select $w.tabs.easy
wm geometry $w 600x800
update
set easy $w.tabs.easy.content
foreach relative {
    source.source_new_analysis source.source_existing_folder
    settings.native_chain_entry settings.chains settings.mode_slices settings.mode_size
    settings.native_start_entry settings.native_end_entry
    actions.run actions.popout actions.save actions.figure
    actions.spacing_minus actions.spacing_plus actions.reset_view actions.clear
} {
    set widget $easy.$relative
    set x [expr {[winfo rootx $widget] + [winfo width $widget]/2}]
    set y [expr {[winfo rooty $widget] + [winfo height $widget]/2}]
    set hit [winfo containing $x $y]
    assert {$hit eq $widget || [string match "$widget.*" $hit]} "A grouping frame covers $relative: $hit"
}
assert {[winfo manager $easy.actions.retry] eq ""} "Retry takes space without a saved display failure"
assert {[winfo manager $w.footer.progress] eq ""} "Idle progress takes space"
set native_combo $w.tabs.easy.content.metric.metric_combo
assert {[$native_combo cget -values] eq {RMSX Shift-Map 1-lDDT}} "Compact native labels changed"
set matrix_combo $w.tabs.matrix.content.metric.metric_combo
set ::RMSXFlipbookTimeline::Dashboard::show_advanced 1
foreach metric [$matrix_combo cget -values] {
    set ::RMSXFlipbookTimeline::Dashboard::timeline_metric $metric
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    $w.tabs select $w.tabs.matrix
    update
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
    update
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
# Direct staged loading is also used by the review launcher. There is no new
# window Map event here, so activation itself must enable per-protein rotation.
assert {![dict get [::RMSXFlipbookTimeline::mouse_rotation_status] enabled]} "Empty dashboard unexpectedly enabled rotation"
::RMSXFlipbookTimeline::Dashboard::load_folder_with_view $folder {}
assert {[dict get [::RMSXFlipbookTimeline::mouse_rotation_status] enabled]} "Staged result activation left in-place rotation disabled"
set result [::RMSXFlipbookTimeline::Results::get]
set result_id [dict get $result id]
set molids [::RMSXFlipbookTimeline::state_get molids]
# Repaint an idle result after resizing without a rotation or spacing nudge.
set view_before [::RMSXFlipbookTimeline::Style::capture_view_matrices $molids]
set refresh_before $::RMSXFlipbookTimeline::Dashboard::scene_refresh_count
wm geometry $w 620x700
::RMSXFlipbookTimeline::Dashboard::request_scene_refresh
set ::qa_redraw_wait 0
after 1200 {set ::qa_redraw_wait 1}
vwait ::qa_redraw_wait
assert {$::RMSXFlipbookTimeline::Dashboard::scene_refresh_count >= $refresh_before+2} "Resize/periodic scene redraw did not run"
assert {$::RMSXFlipbookTimeline::Dashboard::scene_refresh_error eq ""} "Scene redraw failed"
assert {[::RMSXFlipbookTimeline::Style::capture_view_matrices $molids] eq $view_before} "Refresh moved the viewing matrices"
# Temporary export views and busy analyses must never be repainted by the pulse.
foreach guard {export operation} {
    if {$guard eq "export"} {set ::RMSXFlipbookTimeline::Render::active 1} else {::RMSXFlipbookTimeline::Operation::begin redraw_guard}
    set refresh_before $::RMSXFlipbookTimeline::Dashboard::scene_refresh_count
    ::RMSXFlipbookTimeline::Dashboard::request_scene_refresh
    set ::qa_redraw_wait 0
    after 220 {set ::qa_redraw_wait 1}
    vwait ::qa_redraw_wait
    assert {$::RMSXFlipbookTimeline::Dashboard::scene_refresh_count == $refresh_before} "Refresh entered $guard"
    if {$guard eq "export"} {set ::RMSXFlipbookTimeline::Render::active 0} else {::RMSXFlipbookTimeline::Operation::finish complete Complete}
}
wm geometry $w 660x800
assert_per_protein_rotation $molids
::RMSXFlipbookTimeline::Dashboard::nudge_spacing -2.0
assert_per_protein_rotation $molids
::RMSXFlipbookTimeline::Dashboard::reset_view
assert_per_protein_rotation $molids
set canvas $::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_canvas
assert {[dict exists $::RMSXFlipbookTimeline::Navigation::views $canvas cells]} "Native heatmap not connected to keyboard navigation"
::RMSXFlipbookTimeline::Navigation::key $canvas Return
::RMSXFlipbookTimeline::Navigation::key $canvas Right
assert {[lindex [dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] 1] == 1} "Right did not select the next heatmap cell"
assert {[llength [$canvas find withtag keyboard_selection]] == 1} "Keyboard cell focus is not visible"
set ::RMSXFlipbookTimeline::Dashboard::folder [file join [pwd] different-input]
assert {[::RMSXFlipbookTimeline::Dashboard::current_native_folder] eq $folder} "Editable source redirected committed result"
set stale_refresh_generation $::RMSXFlipbookTimeline::Dashboard::scene_refresh_generation
::RMSXFlipbookTimeline::Dashboard::close_window
set refresh_before $::RMSXFlipbookTimeline::Dashboard::scene_refresh_count
::RMSXFlipbookTimeline::Dashboard::refresh_scene_tick $stale_refresh_generation
assert {$::RMSXFlipbookTimeline::Dashboard::scene_refresh_after eq ""} "Close retained the redraw timer"
assert {$::RMSXFlipbookTimeline::Dashboard::scene_refresh_count == $refresh_before} "Stale refresh ran after close"
assert {[wm state $w] eq "withdrawn"} "Close did not hide the window"
assert {[::RMSXFlipbookTimeline::state_get molids] eq $molids} "Close removed loaded scene"
assert {![dict get [::RMSXFlipbookTimeline::mouse_rotation_status] enabled]} "Close retained the rotation input hook"
menu rmsxflipbooktimeline on
update
assert {[dict get [::RMSXFlipbookTimeline::Results::get] id] == $result_id} "Reopen changed current result identity"
assert {[dict get [::RMSXFlipbookTimeline::mouse_rotation_status] enabled]} "Reopen lost per-protein rotation"
assert {$::RMSXFlipbookTimeline::Dashboard::scene_refresh_after ne ""} "Reopen did not resume redraws"
assert_per_protein_rotation $molids
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
::RMSXFlipbookTimeline::uninstall_mouse_rotation
$w.tabs.easy.content.actions.retry invoke
assert {[dict get [::RMSXFlipbookTimeline::mouse_rotation_status] enabled]} "Retry did not restore in-place rotation"
assert_per_protein_rotation [::RMSXFlipbookTimeline::state_get molids]
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
assert {[string first "Selection:" $::RMSXFlipbookTimeline::Dashboard::result_title] < 0} "Compact header contains verbose metadata"
assert {![winfo exists $w.header.summary]} "Verbose second header row remains"
set details [::RMSXFlipbookTimeline::Dashboard::result_details_text]
assert {[string first "Units: [dict get $live units]" $details] >= 0} "Result Details omits scientific units"
assert {[string first "Selection: protein" $details] >= 0} "Result Details omits selection"
set prior_status $::RMSXFlipbookTimeline::Dashboard::status_text
set prior_log $::RMSXFlipbookTimeline::Dashboard::detail_log
$w.header.details invoke
update
assert {[$w.details.tabs select] eq "$w.details.tabs.result"} "Details did not open Result panel"
assert {$::RMSXFlipbookTimeline::Dashboard::status_text eq $prior_status && $::RMSXFlipbookTimeline::Dashboard::detail_log eq $prior_log} "Opening Details overwrote status or duplicated metadata into log"
set log_path [file join [pwd] details-log.txt]
::RMSXFlipbookTimeline::Dashboard::save_detail_log $log_path
set fp [open $log_path];fconfigure $fp -encoding utf-8;set saved_log [read $fp];close $fp
assert {[string first "Selection: protein" $saved_log] >= 0 && [string first "Diagnostic log" $saved_log] >= 0} "Saved log lost current metadata or diagnostics"
$w.footer.details invoke
assert {[$w.details.tabs select] eq "$w.details.tabs.log"} "Log button did not select diagnostics"
$w.details.actions.hide invoke
update
assert {![winfo ismapped $w.details]} "Hide left Details visible"
assert {[winfo height $w.header] < 60} "Compact header grew beyond one row"
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
exec $::env(RMSX_TEST_PYTHON) [file join $repo scripts install.py] uninstall --prefix $install_prefix --startup-file $startup
set fp [open $startup r]; set restored [read $fp]; close $fp
assert {$restored eq $original_config} "Uninstall did not preserve unrelated startup content"
puts "Dashboard GUI installation, geometry, navigation, lifecycle and Stop checks passed"
after 100 quit
