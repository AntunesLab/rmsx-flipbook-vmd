################################################################################
# RMSX Flipbook Timeline live calculator smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline live calculator smoke failed: $message"
    flush stdout
    catch {mol delete all}
    exit 1
}

proc assert_dataset_shape {dataset metric min_rows expected_columns} {
    if {[dict get $dataset column_count] != $expected_columns} {
        smoke_fail "$metric column count: expected $expected_columns, got [dict get $dataset column_count]"
    }
    if {[dict get $dataset row_count] < $min_rows} {
        smoke_fail "$metric row count: expected at least $min_rows, got [dict get $dataset row_count]"
    }
    foreach column_values [dict get $dataset values] {
        if {[llength $column_values] != [dict get $dataset row_count]} {
            smoke_fail "$metric value column length mismatch"
        }
    }
}

proc assert_vmd_state {molid guard_molid expected_top expected_molid_frame expected_guard_frame label} {
    if {[molinfo top] != $expected_top} {
        smoke_fail "$label changed top molecule: expected $expected_top, got [molinfo top]"
    }
    if {[molinfo $molid get frame] != $expected_molid_frame} {
        smoke_fail "$label changed analysis molecule frame: expected $expected_molid_frame, got [molinfo $molid get frame]"
    }
    if {[molinfo $guard_molid get frame] != $expected_guard_frame} {
        smoke_fail "$label changed guard molecule frame: expected $expected_guard_frame, got [molinfo $guard_molid get frame]"
    }
}

proc ::rmsxflipbooktimeline_smoke_residue_size {key_sel residue_sel context_sel} {
    if {[$key_sel num] <= 0 || [$context_sel num] <= 0} {
        return 0
    }
    return [$residue_sel num]
}

proc run_smoke {} {
global auto_path

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
    set workspace_root [file dirname $plugin_parent]
} else {
    set workspace_root [pwd]
    set plugin_parent [file normalize [file join $workspace_root workspace_plugins]]
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

set topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ.pdb]
set trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files mon_sys.dcd]
if {![file exists $topology]} {
    smoke_fail "topology missing: $topology"
}
if {![file exists $trajectory]} {
    smoke_fail "trajectory missing: $trajectory"
}

if {[catch {
    set molid [mol new $topology type pdb waitfor all]
    mol addfile $trajectory type dcd first 0 last 2 step 1 waitfor all molid $molid
    set guard_molid [mol new $topology type pdb waitfor all]
} err]} {
    smoke_fail "could not load test trajectory: $err"
}

for {set frame 0} {$frame <= 2} {incr frame} {
    set sel [atomselect $molid all frame $frame]
    try {
        $sel set user2 [lrepeat [$sel num] [expr {$frame + 0.25}]]
    } finally {
        catch {$sel delete}
    }
}

molinfo $molid set frame 2
molinfo $guard_molid set frame 0
mol top $guard_molid
set expected_top $guard_molid
set expected_molid_frame 2
set expected_guard_frame 0

set common_opts [list \
    selection protein \
    first_frame 0 \
    last_frame 2 \
    rmsf_window 3 \
    rmsf_step 1 \
    hbond_sel1 protein \
    salt_dist 3.2 \
    inter_method pairs \
    inter_selection_list [list "resid 1 to 5" "resid 6 to 10"] \
    native_from_selection_list [list "resid 1 to 5"] \
    native_to_selection "protein and not resid 1 to 5" \
    native_ref_frame 0 \
    residue_function ::rmsxflipbooktimeline_smoke_residue_size \
    residue_function_label residue_atom_count \
    residue_function_unit atoms]

set metric_specs {
    {x 1}
    {y 1}
    {z 1}
    {user 1}
    {user2 1}
    {user3 1}
    {user4 1}
    {residue_function 1}
    {displacement 1}
    {displacement_velocity 1}
    {rmsd 1}
    {rmsf 1}
    {sasa 1}
    {secondary_structure 1}
    {phi 1}
    {delta_phi 1}
    {psi 1}
    {delta_psi 1}
    {hbonds 0}
    {salt_bridges 0}
    {inter_selection_contacts 1}
    {native_contacts 1}
    {selection_empty 1}
    {test_free_selection 7}
}

foreach spec $metric_specs {
    lassign $spec metric min_rows
    if {[catch {
        set dataset [::RMSXFlipbookTimeline::calculate_timeline $molid $metric {*}$common_opts]
    } err]} {
        smoke_fail "$metric calculation failed: $err"
    }
    assert_dataset_shape $dataset $metric $min_rows 3
    if {$metric eq "secondary_structure"} {
        if {![dict exists $dataset value_kind] || [dict get $dataset value_kind] ne "categorical"} {
            smoke_fail "secondary_structure should be marked categorical: $dataset"
        }
        if {[string first "alpha helix" [dict get $dataset categories]] < 0} {
            smoke_fail "secondary_structure categories should describe helix/strand/coil states"
        }
    }
    if {$metric in {hbonds salt_bridges}} {
        if {![dict exists $dataset value_kind] || [dict get $dataset value_kind] ne "binary"} {
            smoke_fail "$metric should be marked binary: $dataset"
        }
        if {[string first "active" [dict get $dataset categories]] < 0} {
            smoke_fail "$metric binary categories should include active/inactive labels"
        }
    }
    assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "$metric calculation"
}

if {[catch {
    set inter_residue_dataset [::RMSXFlipbookTimeline::calculate_timeline \
        $molid \
        inter_selection_contacts \
        selection protein \
        first_frame 0 \
        last_frame 2 \
        inter_method residues_to_selection \
        inter_from_selection "resid 1 to 5" \
        inter_to_selection "resid 6 to 10" \
        inter_dist 4.0]
} err]} {
    smoke_fail "inter-selection residue matrix failed: $err"
}
if {[dict get $inter_residue_dataset row_mode] ne "residue_contact" || [dict get $inter_residue_dataset row_count] != 5} {
    smoke_fail "inter-selection residue matrix should have five residue rows, got row_mode=[dict get $inter_residue_dataset row_mode] rows=[dict get $inter_residue_dataset row_count]"
}
set inter_first_row [lindex [dict get $inter_residue_dataset rows] 0]
if {[dict get $inter_first_row selection] ne "same residue as index [dict get $inter_first_row atom_index]"} {
    smoke_fail "inter-selection residue row should highlight only the source residue: $inter_first_row"
}
foreach column_values [dict get $inter_residue_dataset values] {
    if {[llength $column_values] != 5} {
        smoke_fail "inter-selection residue matrix value length mismatch"
    }
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "inter-selection residue matrix"

if {[catch {
    set user2_dataset [::RMSXFlipbookTimeline::calculate_timeline $molid user2 {*}$common_opts]
    set user2_value [::RMSXFlipbookTimeline::Matrix::cell_value $user2_dataset 0 1]
} err]} {
    smoke_fail "user2 value check failed: $err"
}
if {abs(double($user2_value) - 1.25) > 0.000001} {
    smoke_fail "user2 value check expected 1.25, got $user2_value"
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "user2 value check"

if {[catch {
    set user_field_dataset [::RMSXFlipbookTimeline::calculate_timeline $molid user_field {*}$common_opts user_field user2]
    set user_field_value [::RMSXFlipbookTimeline::Matrix::cell_value $user_field_dataset 0 2]
} err]} {
    smoke_fail "generic user_field calculation failed: $err"
}
if {abs(double($user_field_value) - 2.25) > 0.000001} {
    smoke_fail "generic user_field expected 2.25, got $user_field_value"
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "generic user_field check"

if {[catch {
    set function_dataset [::RMSXFlipbookTimeline::calculate_timeline $molid residue_function {*}$common_opts]
    set function_value [::RMSXFlipbookTimeline::Matrix::cell_value $function_dataset 0 0]
} err]} {
    smoke_fail "residue_function value check failed: $err"
}
if {[dict get $function_dataset value_label] ne "residue_atom_count" || $function_value <= 0} {
    smoke_fail "residue_function returned unexpected dataset/value: [dict get $function_dataset value_label] / $function_value"
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "residue_function value check"

if {[catch {
    set empty_dataset [::RMSXFlipbookTimeline::calculate_timeline $molid selection_empty {*}$common_opts]
    set empty_value [::RMSXFlipbookTimeline::Matrix::cell_value $empty_dataset 0 0]
} err]} {
    smoke_fail "selection_empty value check failed: $err"
}
if {[dict get $empty_dataset row_mode] ne "free_selection" || [dict get $empty_dataset value_label] ne "--" || $empty_value != 0} {
    smoke_fail "selection_empty returned unexpected dataset/value: [dict get $empty_dataset row_mode] / [dict get $empty_dataset value_label] / $empty_value"
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "selection_empty value check"

if {[catch {
    set free_test_dataset [::RMSXFlipbookTimeline::calculate_timeline $molid test_free_selection {*}$common_opts]
    set free_test_value [::RMSXFlipbookTimeline::Matrix::cell_value $free_test_dataset 1 2]
} err]} {
    smoke_fail "test_free_selection value check failed: $err"
}
if {[dict get $free_test_dataset row_mode] ne "free_selection" || [dict get $free_test_dataset value_label] ne "free-sel. test" || $free_test_value != -100} {
    smoke_fail "test_free_selection returned unexpected dataset/value: [dict get $free_test_dataset row_mode] / [dict get $free_test_dataset value_label] / $free_test_value"
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "test_free_selection value check"

set rmsdtool_existing [info commands ::rmsdtool]
if {$rmsdtool_existing ne ""} {
    rename ::rmsdtool ::rmsdtool_real_for_timeline_smoke
}
set ::rmsxflipbooktimeline_rmsdtool_called 0
proc ::rmsdtool {} {
    set ::rmsxflipbooktimeline_rmsdtool_called 1
    return .rmsdtool
}
if {[catch {
    set rmsd_tool_dataset [::RMSXFlipbookTimeline::calculate_timeline $molid rmsd_tool {*}$common_opts]
} err]} {
    catch {rename ::rmsdtool {}}
    if {$rmsdtool_existing ne ""} {
        catch {rename ::rmsdtool_real_for_timeline_smoke ::rmsdtool}
    }
    smoke_fail "rmsd_tool compatibility launch failed: $err"
}
catch {rename ::rmsdtool {}}
if {$rmsdtool_existing ne ""} {
    catch {rename ::rmsdtool_real_for_timeline_smoke ::rmsdtool}
}
if {!$::rmsxflipbooktimeline_rmsdtool_called || [dict get $rmsd_tool_dataset row_count] != 0 || [dict get $rmsd_tool_dataset column_count] != 3} {
    smoke_fail "rmsd_tool compatibility result unexpected: called=$::rmsxflipbooktimeline_rmsdtool_called dataset=$rmsd_tool_dataset"
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "rmsd_tool compatibility"
puts "Timeline live smoke: calculators passed"
flush stdout

if {[catch {
    ::RMSXFlipbookTimeline::state_set timeline_neighborhood_enabled 0
    set shown [::RMSXFlipbookTimeline::show_live_timeline \
        $molid \
        displacement \
        {*}$common_opts \
        draw 0 \
        pick 0]
} err]} {
    smoke_fail "show_live_timeline failed: $err"
}
if {[dict get $shown drawn] != 0 || [dict get $shown rows] < 1 || [dict get $shown columns] != 3} {
    smoke_fail "unexpected live show result: $shown"
}
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "headless show"
puts "Timeline live smoke: headless show passed"
flush stdout

if {[catch {
    set selected [::RMSXFlipbookTimeline::select_timeline_cell 0 1]
} err]} {
    smoke_fail "select_timeline_cell failed: $err"
}
if {[catch {
    set selected_row [dict get $selected row]
    set selected_column [dict get $selected column]
} err]} {
    smoke_fail "selected cell result was not a dict: $err / $selected"
}
if {[catch {expr {$selected_row != 0 || $selected_column != 1}} mismatch]} {
    smoke_fail "selected cell row/column were not numeric: $selected"
}
if {$mismatch} {
    smoke_fail "unexpected selected cell: $selected"
}
puts "Timeline live smoke: scrubbing passed"
flush stdout

if {[catch {
    set scrubbed [::RMSXFlipbookTimeline::select_timeline_slice 2]
} err]} {
    smoke_fail "select_timeline_slice failed: $err"
}
if {[dict get $scrubbed kind] ne "column" || [dict get $scrubbed column] != 2 || [molinfo $molid get frame] != 2} {
    smoke_fail "unexpected timeline slice scrub result: $scrubbed / frame [molinfo $molid get frame]"
}
puts "Timeline live smoke: frame scrubber passed"
flush stdout

if {[catch {
    set copied [::RMSXFlipbookTimeline::copy_timeline_to_user user4]
} err]} {
    smoke_fail "copy_timeline_to_user failed: $err"
}
if {[dict get $copied field] ne "user4"} {
    smoke_fail "copy_timeline_to_user returned wrong field: $copied"
}
puts "Timeline live smoke: copy-to-user passed"
flush stdout

set copied_dataset [dict get $shown dataset]
set first_row [lindex [dict get $copied_dataset rows] 0]
set copied_sel [atomselect $molid [::RMSXFlipbookTimeline::Matrix::row_selection $first_row] frame 1]
try {
    set copied_values [$copied_sel get user4]
    if {[llength $copied_values] == 0 || ![::RMSXFlipbookTimeline::Matrix::is_numeric [lindex $copied_values 0]]} {
        smoke_fail "user4 field was not populated"
    }
} finally {
    catch {$copied_sel delete}
}
puts "Timeline live smoke: user field inspection passed"
flush stdout

catch {::RMSXFlipbookTimeline::clear_timeline_plot}
catch {mol delete all}
puts "RMSX Flipbook Timeline live calculator smoke passed"
flush stdout
return ""
}

run_smoke
exit 0
