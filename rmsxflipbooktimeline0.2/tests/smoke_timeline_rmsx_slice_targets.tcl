################################################################################
# RMSX Flipbook Timeline RMSX slice-target smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline RMSX slice-target smoke failed: $message"
    flush stdout
    catch {::RMSXFlipbookTimeline::clear_timeline_plot}
    catch {mol delete all}
    exit 1
}

proc assert_equal {actual expected message} {
    if {$actual ne $expected} {
        smoke_fail "$message: expected '$expected', got '$actual'"
    }
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

set folder [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files example1 chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "reference RMSX folder missing: $folder"
}

if {[catch {
    set load_result [::RMSXFlipbookTimeline::load_folder $folder write_manifest 0]
} err]} {
    smoke_fail "load_folder failed: $err"
}
set molids [dict get $load_result molids]
assert_equal [llength $molids] 9 "loaded slice molecule count"

if {[catch {
    set shown [::RMSXFlipbookTimeline::show_timeline_rmsx_folder $folder draw 0 pick 1]
} err]} {
    smoke_fail "show_timeline_rmsx_folder failed: $err"
}
set dataset [dict get $shown dataset]
assert_equal [dict get $dataset column_mode] slice "RMSX Timeline column mode"
assert_equal [dict get $dataset column_count] 9 "RMSX Timeline column count"

set columns [dict get $dataset columns]
for {set i 0} {$i < [llength $columns]} {incr i} {
    set column [lindex $columns $i]
    assert_equal [dict get $column target_type] slice "column $i target type"
    assert_equal [dict get $column slice_molid] [lindex $molids $i] "column $i slice molid"
    if {![file exists [dict get $column slice_file]]} {
        smoke_fail "column $i slice file missing: [dict get $column slice_file]"
    }
}

::RMSXFlipbookTimeline::state_set timeline_neighborhood_enabled 0
set selected_column [::RMSXFlipbookTimeline::select_timeline_slice 2]
assert_equal [dict get $selected_column target_type] slice "selected column target type"
assert_equal [dict get $selected_column molid] [lindex $molids 2] "selected column molid"
assert_equal [molinfo top] [lindex $molids 2] "top molecule after slice selection"

set selected_cell [::RMSXFlipbookTimeline::select_timeline_cell 0 1]
assert_equal [dict get $selected_cell row] 0 "selected cell row"
assert_equal [dict get $selected_cell column] 1 "selected cell column"
assert_equal [molinfo top] [lindex $molids 1] "top molecule after cell selection"

set pick_molid [lindex $molids 3]
set pick_sel [atomselect $pick_molid "resid 1"]
try {
    if {[$pick_sel num] == 0} {
        smoke_fail "could not find pick atom in slice molecule $pick_molid"
    }
    set pick_atom [lindex [$pick_sel get index] 0]
} finally {
    catch {$pick_sel delete}
}

global vmd_pick_mol vmd_pick_atom
set vmd_pick_mol $pick_molid
set vmd_pick_atom $pick_atom
set picked $::RMSXFlipbookTimeline::TimelinePlot::selected_record
assert_equal [dict get $picked row] 0 "picked row"
assert_equal [dict get $picked column] 3 "picked slice column"

if {[catch {
    set copied [::RMSXFlipbookTimeline::copy_timeline_to_user user3]
} err]} {
    smoke_fail "copy_timeline_to_user for RMSX slice dataset failed: $err"
}
assert_equal [dict get $copied field] user3 "copy-to-user field"
assert_equal [llength [dict get $copied molids]] 9 "copy-to-user touched molids"
assert_equal [dict get $copied columns] 9 "copy-to-user copied columns"

set copied_sel [atomselect [lindex $molids 1] "resid 1" frame 0]
try {
    if {[$copied_sel num] == 0} {
        smoke_fail "could not inspect copied user field on slice molecule"
    }
    set copied_value [lindex [$copied_sel get user3] 0]
} finally {
    catch {$copied_sel delete}
}
set expected_value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset 0 1]
if {abs($copied_value - $expected_value) > 0.000001} {
    smoke_fail "copied user3 value mismatch: expected $expected_value, got $copied_value"
}

catch {::RMSXFlipbookTimeline::clear_timeline_plot}
catch {mol delete all}
puts "RMSX Flipbook Timeline RMSX slice-target smoke passed"
flush stdout
}

if {[catch {run_smoke} err]} {
    smoke_fail $err
}
exit 0
