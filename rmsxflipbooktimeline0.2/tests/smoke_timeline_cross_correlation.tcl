################################################################################
# RMSX Flipbook Timeline cross-correlation calculator smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline cross-correlation smoke failed: $message"
    exit 1
}

proc assert_dataset_shape {dataset label min_rows expected_columns} {
    if {[dict get $dataset column_count] != $expected_columns} {
        smoke_fail "$label column count: expected $expected_columns, got [dict get $dataset column_count]"
    }
    if {[dict get $dataset row_count] < $min_rows} {
        smoke_fail "$label row count: expected at least $min_rows, got [dict get $dataset row_count]"
    }
    foreach column_values [dict get $dataset values] {
        if {[llength $column_values] != [dict get $dataset row_count]} {
            smoke_fail "$label value column length mismatch"
        }
    }
}

proc assert_numeric_values {dataset label} {
    set numeric_count 0
    foreach column_values [dict get $dataset values] {
        foreach value $column_values {
            if {[string is double -strict $value]} {
                incr numeric_count
            }
        }
    }
    if {$numeric_count == 0} {
        smoke_fail "$label did not produce numeric cross-correlation values"
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

proc main {} {
global auto_path
set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
    set workspace_root [file dirname [file dirname $plugin_parent]]
} else {
    set workspace_root [file normalize [pwd]]
    set plugin_parent [file join $workspace_root workspace_plugins]
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

if {[catch {package require mdff} err]} {
    puts "RMSX Flipbook Timeline cross-correlation smoke skipped: mdff package unavailable: $err"
    exit 0
}
if {[llength [info commands mdff]] == 0} {
    puts "RMSX Flipbook Timeline cross-correlation smoke skipped: mdff command unavailable"
    exit 0
}

set topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ.pdb]
set trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files mon_sys.dcd]
if {![file exists $topology] || ![file exists $trajectory]} {
    smoke_fail "Required 1UBQ test files are missing"
}

set molid [mol new $topology type pdb waitfor all]
mol addfile $trajectory type dcd first 0 last 1 step 1 waitfor all molid $molid
set guard_molid [mol new $topology type pdb waitfor all]

set tmpdir [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : "/tmp"}]
set map_file [file normalize [file join $tmpdir "rmsxflipbooktimeline-crosscorr-[pid].dx"]]
file delete -force $map_file

set sim_sel [atomselect $molid "protein" frame 0]
try {
    if {[catch {mdff sim $sim_sel -o $map_file -res 10.0 -spacing 4.0} err]} {
        puts "RMSX Flipbook Timeline cross-correlation smoke skipped: mdff sim failed: $err"
        exit 0
    }
} finally {
    catch {$sim_sel delete}
}
if {![file exists $map_file]} {
    puts "RMSX Flipbook Timeline cross-correlation smoke skipped: mdff sim did not write $map_file"
    exit 0
}

molinfo $molid set frame 1
molinfo $guard_molid set frame 0
mol top $guard_molid
set expected_top $guard_molid
set expected_molid_frame 1
set expected_guard_frame 0

set common_opts [list \
    selection protein \
    first_frame 0 \
    last_frame 1 \
    cc_map_file $map_file \
    cc_map_res 10.0 \
    cc_spacing 4.0 \
    cc_use_spacing 1]

if {[catch {
    set selection_dataset [::RMSXFlipbookTimeline::calculate_timeline \
        $molid \
        cross_correlation \
        {*}$common_opts \
        cc_method selections \
        cc_selection_list {{resid 1 to 10} {resid 11 to 20}}]
} err]} {
    smoke_fail "selection cross-correlation failed: $err"
}
assert_dataset_shape $selection_dataset "selection cross-correlation" 2 2
if {[dict get $selection_dataset row_mode] ne "free_selection"} {
    smoke_fail "selection cross-correlation should use free_selection rows"
}
assert_numeric_values $selection_dataset "selection cross-correlation"
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "selection cross-correlation"

if {[catch {
    set segment_dataset [::RMSXFlipbookTimeline::calculate_timeline \
        $molid \
        cross_corr \
        {*}$common_opts \
        cc_method segments]
} err]} {
    smoke_fail "segment cross-correlation failed: $err"
}
assert_dataset_shape $segment_dataset "segment cross-correlation" 1 2
if {[dict get $segment_dataset row_mode] ne "residue"} {
    smoke_fail "segment cross-correlation should use residue rows"
}
assert_numeric_values $segment_dataset "segment cross-correlation"
assert_vmd_state $molid $guard_molid $expected_top $expected_molid_frame $expected_guard_frame "segment cross-correlation"

file delete -force $map_file
puts "RMSX Flipbook Timeline cross-correlation smoke passed"
exit 0
}

main
