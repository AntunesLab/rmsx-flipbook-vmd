################################################################################
# RMSX Flipbook Timeline 2D plot window smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline plot window smoke failed: $message"
    exit 1
}

proc run_smoke {} {
global auto_path
set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir $::env(RMSX_TEST_PACKAGE)
    set plugin_parent $::env(RMSX_TEST_REPO)
    set workspace_root $::env(RMSX_TEST_WORKDIR)
} else {
    set workspace_root $::env(RMSX_TEST_WORKDIR)
    set plugin_parent $::env(RMSX_TEST_REPO)
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

set folder [file join $workspace_root outputs native-rmsx-1ubq-9 chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "Expected 9-slice native smoke folder is missing: $folder"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $folder \
        palette viridis \
        rep Lines \
        write_manifest 0 \
        apply_mask 0
} load_result]} {
    smoke_fail "load_folder failed: $load_result"
}

if {[dict get $load_result files] != 9} {
    smoke_fail "Expected 9 loaded slice molecules, got [dict get $load_result files]"
}

if {[catch {
    ::RMSXFlipbookTimeline::show_plot_window \
        folder $folder \
        palette turbo \
        draw 0 \
        pick 1
} plot_result]} {
    smoke_fail "show_plot_window failed: $plot_result"
}

if {[dict get $plot_result drawn] != 0} {
    smoke_fail "Expected headless plot smoke to skip drawing, got $plot_result"
}
if {[dict get $plot_result cells] != 684} {
    smoke_fail "Expected 684 heatmap cells, got [dict get $plot_result cells]"
}
if {[dict get $plot_result summary_points] != 9} {
    smoke_fail "Expected 9 slice summary points, got [dict get $plot_result summary_points]"
}
if {[dict get $plot_result rmsd_points] <= 0} {
    smoke_fail "Expected RMSD points in plot result, got $plot_result"
}
if {[dict get $plot_result rmsd_slice_points] != 9} {
    smoke_fail "Expected 9 binned RMSD slice points, got [dict get $plot_result rmsd_slice_points]"
}
if {[dict get $plot_result rmsf_points] != 76} {
    smoke_fail "Expected 76 RMSF points, got [dict get $plot_result rmsf_points]"
}
if {![dict get $plot_result flanking_plots]} {
    smoke_fail "Expected flanking plots to be enabled, got $plot_result"
}
if {[dict get $plot_result rows] != 76 || [dict get $plot_result columns] != 9} {
    smoke_fail "Unexpected plot dimensions: $plot_result"
}

if {[catch {
    ::RMSXFlipbookTimeline::select_plot_window_cell 0 1
} selected]} {
    smoke_fail "select_plot_window_cell failed: $selected"
}
if {[dict get $selected kind] ne "cell"} {
    smoke_fail "Expected selected cell record, got $selected"
}
if {[dict get $selected slice_index] != 2} {
    smoke_fail "Expected selected slice 2, got [dict get $selected slice_index]"
}
if {[dict get $selected resid] ne "1"} {
    smoke_fail "Expected selected residue 1, got [dict get $selected resid]"
}

if {[catch {
    ::RMSXFlipbookTimeline::select_plot_window_slice 2
} selected_slice]} {
    smoke_fail "select_plot_window_slice failed: $selected_slice"
}
if {[dict get $selected_slice kind] ne "slice_summary"} {
    smoke_fail "Expected selected slice summary record, got $selected_slice"
}
if {[dict get $selected_slice slice_index] != 2} {
    smoke_fail "Expected selected summary slice 2, got [dict get $selected_slice slice_index]"
}

set loaded_molids [dict get $load_result molids]
set slice2_molid [lindex $loaded_molids 1]
set slice2_sel [atomselect $slice2_molid "resid 1"]
set structure_atom [lindex [$slice2_sel get index] 0]
$slice2_sel delete

if {[catch {
    ::RMSXFlipbookTimeline::select_plot_window_structure_atom $slice2_molid $structure_atom
} selected_from_structure]} {
    smoke_fail "select_plot_window_structure_atom failed: $selected_from_structure"
}
if {[dict get $selected_from_structure slice_index] != 2} {
    smoke_fail "Expected structure pick to select slice 2, got [dict get $selected_from_structure slice_index]"
}
if {[dict get $selected_from_structure resid] ne "1"} {
    smoke_fail "Expected structure pick to select residue 1, got [dict get $selected_from_structure resid]"
}

global vmd_pick_mol vmd_pick_atom
set vmd_pick_mol $slice2_molid
set vmd_pick_atom $structure_atom
set selected_from_callback [::RMSXFlipbookTimeline::PlotWindow::pick_callback ::vmd_pick_atom "" write]
if {[dict get $selected_from_callback slice_index] != 2} {
    smoke_fail "Expected pick callback to select slice 2"
}

if {[catch {::RMSXFlipbookTimeline::clear_plot_window} clear_result]} {
    smoke_fail "clear_plot_window failed: $clear_result"
}
}

run_smoke
puts "RMSX Flipbook Timeline plot window smoke passed"
quit
