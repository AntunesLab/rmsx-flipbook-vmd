################################################################################
# RMSX Flipbook Timeline package smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline package smoke failed: $message"
    exit 1
}

set plugin_parent $::env(RMSX_TEST_REPO)
if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.3]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

if {[info commands ::RMSXFlipbookTimeline::load_folder] eq ""} {
    smoke_fail "backend load command missing"
}

if {[info commands ::RMSXFlipbookTimeline::load_manifest] eq ""} {
    smoke_fail "manifest load command missing"
}

if {[info commands ::RMSXFlipbookTimeline::write_multimodel_pdb] eq ""} {
    smoke_fail "multi-model export command missing"
}

if {[info commands ::RMSXFlipbookTimeline::render_flipbook_image] eq ""} {
    smoke_fail "render image command missing"
}

if {[info commands ::RMSXFlipbookTimeline::apply_view_preset] eq ""} {
    smoke_fail "view preset command missing"
}

foreach command {
    package_root
    citation
    about
    help_url
    open_help
} {
    if {[info commands ::RMSXFlipbookTimeline::$command] eq ""} {
        smoke_fail "release metadata command missing: $command"
    }
}

if {[string first "10.1038/s41598-026-39869-7" [::RMSXFlipbookTimeline::citation]] < 0} {
    smoke_fail "citation command is missing DOI"
}

if {[::RMSXFlipbookTimeline::apply_view_preset current] ne "current"} {
    smoke_fail "view preset command returned unexpected value"
}

if {[info commands ::RMSXFlipbookTimeline::install_hotkeys] eq ""} {
    smoke_fail "hotkey install command missing"
}

if {[info commands ::RMSXFlipbookTimeline::install_mouse_rotation] eq ""} {
    smoke_fail "mouse rotation install command missing"
}

if {[info commands ::RMSXFlipbookTimeline::mouse_rotation_reset_stats] eq ""} {
    smoke_fail "mouse rotation reset stats command missing"
}

if {[info commands ::RMSXFlipbookTimeline::mouse_rotation_set_sensitivity] eq ""} {
    smoke_fail "mouse rotation sensitivity command missing"
}

if {[info commands ::RMSXFlipbookTimeline::mouse_rotation_burst] eq ""} {
    smoke_fail "mouse rotation burst command missing"
}

if {[info commands ::RMSXFlipbookTimeline::mouse_rotation_format_status] eq ""} {
    smoke_fail "mouse rotation status formatter command missing"
}

if {[info commands ::RMSXFlipbookTimeline::select_viewer_plot_slice] eq ""} {
    smoke_fail "viewer plot slice selection command missing"
}

if {[info commands ::RMSXFlipbookTimeline::show_plot_window] eq ""} {
    smoke_fail "2D plot window command missing"
}

if {[info commands ::RMSXFlipbookTimeline::select_plot_window_slice] eq ""} {
    smoke_fail "2D plot window slice selection command missing"
}

foreach command {
    calculate_timeline
    aggregate_timeline_to_slices
    build_ramachandran_dataset_from_angles
    build_ramachandran_dataset
    apply_ramachandran_overlay
    clear_angle_overlay
    show_timeline_dataset
    show_live_timeline
    show_timeline_tml
    show_timeline_rmsx_csv
    show_timeline_rmsx_folder
    clear_timeline_plot
    select_timeline_cell
    select_timeline_slice
    flipbook_view_diagnostics
    nudge_flipbook_row
    filter_timeline_current
    copy_timeline_to_user
    read_timeline_tml
    read_timeline_rmsx_csv
    read_timeline_rmsx_folder
    write_timeline_tml
    load_timeline_collection
    write_timeline_svg
    write_timeline_png
    write_current_timeline_tml
    write_current_timeline_svg
    write_current_timeline_png
} {
    if {[info commands ::RMSXFlipbookTimeline::$command] eq ""} {
        smoke_fail "Timeline command missing: $command"
    }
}

if {[info commands rmsxflipbooktimeline] eq ""} {
    smoke_fail "VMD callback command missing"
}

if {[info commands rmsxflipbooktimeline_dashboard] eq ""} {
    smoke_fail "dashboard VMD callback command missing"
}

if {[info commands rmsxflipbooktimeline_about] eq ""} {
    smoke_fail "about VMD callback command missing"
}

if {[info commands rmsxflipbooktimeline_citation] eq ""} {
    smoke_fail "citation VMD callback command missing"
}

if {[info commands ::RMSXFlipbookTimeline::show_dashboard] eq ""} {
    smoke_fail "dashboard show command missing"
}

set gui_file [file join $plugin_parent rmsxflipbooktimeline0.3 gui main_window.tcl]
if {[catch {source $gui_file} err]} {
    smoke_fail "GUI source failed: $err"
}

if {[info commands ::RMSXFlipbookTimeline::GUI::show] eq ""} {
    smoke_fail "GUI show command missing after source"
}

puts "RMSX Flipbook Timeline package smoke passed"
if {[info commands quit] ne ""} {
    quit
}
exit 0
