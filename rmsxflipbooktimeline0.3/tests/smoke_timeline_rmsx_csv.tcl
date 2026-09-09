################################################################################
# RMSX Flipbook Timeline RMSX CSV/folder matrix smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline RMSX CSV smoke failed: $message"
    exit 1
}

proc assert_equal {actual expected message} {
    if {$actual ne $expected} {
        smoke_fail "$message: expected '$expected', got '$actual'"
    }
}

proc read_file {path} {
    set fp [open $path r]
    try {
        return [read $fp]
    } finally {
        catch {close $fp}
    }
}

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

set folder [file join $workspace_root fixtures upstream test_files example1 chain_7_rmsx]
set csv_path [file join $folder rmsx_mon_sys_0.015_ns.csv]
if {![file exists $csv_path]} {
    smoke_fail "Reference RMSX CSV missing: $csv_path"
}

set csv_dataset [::RMSXFlipbookTimeline::read_timeline_rmsx_csv $csv_path]
assert_equal [dict get $csv_dataset source_type] rmsx_csv "CSV source type"
assert_equal [dict get $csv_dataset row_mode] residue "CSV row mode"
assert_equal [dict get $csv_dataset column_mode] slice "CSV column mode"
assert_equal [dict get $csv_dataset row_count] 76 "CSV row count"
assert_equal [dict get $csv_dataset column_count] 9 "CSV column count"
assert_equal [dict get $csv_dataset value_label] RMSX "CSV value label"
assert_equal [::RMSXFlipbookTimeline::Matrix::row_label [lindex [dict get $csv_dataset rows] 0]] "7:1" "CSV first row label"
assert_equal [::RMSXFlipbookTimeline::Matrix::column_label [lindex [dict get $csv_dataset columns] 0]] "slice_1.dcd" "CSV first column label"

set first_value [::RMSXFlipbookTimeline::Matrix::cell_value $csv_dataset 0 0]
if {abs($first_value - 4.8094872239894455) > 0.0000001} {
    smoke_fail "unexpected first RMSX value: $first_value"
}
if {[dict get $csv_dataset max] <= [dict get $csv_dataset min]} {
    smoke_fail "expected informative CSV range"
}

set folder_dataset [::RMSXFlipbookTimeline::read_timeline_rmsx_folder $folder]
assert_equal [dict get $folder_dataset row_count] 76 "folder row count"
assert_equal [dict get $folder_dataset column_count] 9 "folder column count"
assert_equal [dict get [dict get $folder_dataset provenance] folder] [file normalize $folder] "folder provenance"

set shown [::RMSXFlipbookTimeline::show_timeline_rmsx_folder \
    $folder \
    draw 0 \
    pick 0 \
    threshold_min 4 \
    threshold_max 8]
if {[dict get $shown rows] != 76 || [dict get $shown columns] != 9 || [dict get $shown drawn] != 0} {
    smoke_fail "unexpected headless RMSX folder show result: $shown"
}

set scrubbed [::RMSXFlipbookTimeline::select_timeline_slice 8]
if {[dict get $scrubbed kind] ne "column" || [dict get $scrubbed column] != 8 || [dict get $scrubbed frame] != 8} {
    smoke_fail "unexpected RMSX slice scrub result: $scrubbed"
}

set tmp_dir [file normalize [file join $::env(TMPDIR) rmsxflipbooktimeline-rmsx-csv-smoke-[pid]]]
file delete -force $tmp_dir
file mkdir $tmp_dir
set svg_path [file join $tmp_dir rmsx_timeline.svg]
::RMSXFlipbookTimeline::write_timeline_svg \
    $folder_dataset \
    $svg_path \
    palette viridis \
    width 720 \
    threshold_min 4 \
    threshold_max 8
if {![file exists $svg_path]} {
    smoke_fail "RMSX Timeline SVG was not written: $svg_path"
}
set svg [read_file $svg_path]
foreach needle {"rmsx_mon_sys_0.015_ns.csv" "7:1" "slice_1.dcd" "RMSX" "Threshold count (4 to 8)"} {
    if {[string first $needle $svg] < 0} {
        smoke_fail "RMSX Timeline SVG missing expected text: $needle"
    }
}
file delete -force $tmp_dir

puts "RMSX Flipbook Timeline RMSX CSV smoke passed"
exit 0
