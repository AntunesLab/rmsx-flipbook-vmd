################################################################################
# RMSX Flipbook Timeline in-viewer plot smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline viewer plot smoke failed: $message"
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
    ::RMSXFlipbookTimeline::show_viewer_plot \
        folder $folder \
        palette turbo \
        radius 0.25 \
        width 36 \
        summary 1 \
        pick 1
} plot_result]} {
    smoke_fail "show_viewer_plot failed: $plot_result"
}

if {[dict get $plot_result atoms] != 693} {
    smoke_fail "Expected 693 plot pseudoatoms, got [dict get $plot_result atoms]"
}
if {[dict get $plot_result rows] != 76 || [dict get $plot_result columns] != 9} {
    smoke_fail "Unexpected viewer plot dimensions: $plot_result"
}
if {![dict get $plot_result summary] || [dict get $plot_result summary_points] != 9} {
    smoke_fail "Expected 9 summary points in viewer plot, got $plot_result"
}

set plot_molid [dict get $plot_result molid]
if {[lsearch -exact [molinfo list] $plot_molid] == -1} {
    smoke_fail "Viewer plot molecule is not loaded: $plot_molid"
}

set sel [atomselect $plot_molid all]
set user2_values [$sel get user2]
$sel delete
set user2_range [list [lindex [lsort -real $user2_values] 0] [lindex [lsort -real $user2_values] end]]
if {[lindex $user2_range 0] == [lindex $user2_range 1]} {
    smoke_fail "Viewer plot user2 values are flat"
}

if {[catch {
    ::RMSXFlipbookTimeline::select_viewer_plot_cell 0 1
} selected]} {
    smoke_fail "select_viewer_plot_cell failed: $selected"
}
if {[dict get $selected slice_index] != 2} {
    smoke_fail "Expected selected slice 2, got [dict get $selected slice_index]"
}
if {[dict get $selected resid] ne "1"} {
    smoke_fail "Expected selected residue 1, got [dict get $selected resid]"
}

if {[catch {
    ::RMSXFlipbookTimeline::select_viewer_plot_slice 2
} selected_slice]} {
    smoke_fail "select_viewer_plot_slice failed: $selected_slice"
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
    ::RMSXFlipbookTimeline::select_viewer_plot_structure_atom $slice2_molid $structure_atom
} selected_from_structure]} {
    smoke_fail "select_viewer_plot_structure_atom failed: $selected_from_structure"
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
set selected_from_structure_callback [::RMSXFlipbookTimeline::ViewerPlot::pick_callback ::vmd_pick_atom "" write]
if {[dict get $selected_from_structure_callback slice_index] != 2} {
    smoke_fail "Expected structure pick callback to select slice 2"
}

set vmd_pick_mol $plot_molid
set vmd_pick_atom 77
set selected_after_pick [::RMSXFlipbookTimeline::ViewerPlot::pick_callback ::vmd_pick_atom "" write]
if {[dict get $selected_after_pick slice_index] != 2} {
    smoke_fail "Expected simulated pick atom 77 to map to slice 2"
}

set vmd_pick_mol $plot_molid
set vmd_pick_atom 685
set selected_summary_after_pick [::RMSXFlipbookTimeline::ViewerPlot::pick_callback ::vmd_pick_atom "" write]
if {[dict get $selected_summary_after_pick kind] ne "slice_summary"} {
    smoke_fail "Expected simulated summary pick to return a slice summary record"
}
if {[dict get $selected_summary_after_pick slice_index] != 2} {
    smoke_fail "Expected simulated summary pick atom 685 to map to slice 2"
}

if {[catch {::RMSXFlipbookTimeline::clear_viewer_plot} clear_result]} {
    smoke_fail "clear_viewer_plot failed: $clear_result"
}
if {[lsearch -exact [molinfo list] $plot_molid] != -1} {
    smoke_fail "Viewer plot molecule was not deleted"
}
}

run_smoke
puts "RMSX Flipbook Timeline viewer plot smoke passed"
quit
