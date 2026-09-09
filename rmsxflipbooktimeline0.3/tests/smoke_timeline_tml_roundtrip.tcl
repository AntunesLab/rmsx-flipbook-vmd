################################################################################
# RMSX Flipbook Timeline .tml round-trip smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline TML round-trip smoke failed: $message"
    exit 1
}

proc assert_equal {actual expected message} {
    if {$actual ne $expected} {
        smoke_fail "$message: expected '$expected', got '$actual'"
    }
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir $::env(RMSX_TEST_PACKAGE)
    set plugin_parent $::env(RMSX_TEST_REPO)
} else {
    set plugin_parent $::env(RMSX_TEST_REPO)
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

set tmp_dir [file normalize [file join $::env(TMPDIR) rmsxflipbooktimeline-tml-smoke-[pid]]]
file delete -force $tmp_dir
file mkdir $tmp_dir

set rows [list \
    [dict create index 0 resid 1 resname GLY chain A segid PROA label "A:1 GLY" selection "resid 1 and chain A" row_mode residue] \
    [dict create index 1 resid 2 resname SER chain A segid PROA label "A:2 SER" selection "resid 2 and chain A" row_mode residue]]
set columns [list \
    [dict create index 0 frame 0 label 0 target_type frame] \
    [dict create index 1 frame 1 label 1 target_type frame] \
    [dict create index 2 frame 2 label 2 target_type frame]]
set values [list {0.1 0.2} {1.1 1.2} {2.1 2.2}]

set residue_dataset [::RMSXFlipbookTimeline::Matrix::create \
    title "Residue Smoke" \
    value_label displacement \
    unit A \
    source_type test \
    row_mode residue \
    column_mode frame \
    rows $rows \
    columns $columns \
    values $values]

set residue_tml [file join $tmp_dir residue.tml]
::RMSXFlipbookTimeline::write_timeline_tml $residue_dataset $residue_tml
set residue_read [::RMSXFlipbookTimeline::read_timeline_tml $residue_tml]

assert_equal [dict get $residue_read row_count] 2 "residue row count"
assert_equal [dict get $residue_read column_count] 3 "residue column count"
assert_equal [dict get $residue_read title] "Residue Smoke" "residue dataset title"
assert_equal [dict get $residue_read unit] "A" "residue unit"
assert_equal [dict get $residue_read value_label] displacement "residue value label"
assert_equal [::RMSXFlipbookTimeline::Matrix::cell_value $residue_read 0 0] 0.1 "residue first value"
assert_equal [::RMSXFlipbookTimeline::Matrix::cell_value $residue_read 1 2] 2.2 "residue last value"
assert_equal [::RMSXFlipbookTimeline::Matrix::row_label [lindex [dict get $residue_read rows] 0]] "A:1 GLY" "residue label"
assert_equal [::RMSXFlipbookTimeline::Matrix::column_label [lindex [dict get $residue_read columns] 2]] 2 "residue column label"
assert_equal [dict get [lindex [dict get $residue_read rows] 0] selection] "resid 1 and chain A" "residue selection"
assert_equal [dict get [dict get $residue_read provenance] file_version] "1.4" "residue file version provenance"

set free_rows [list \
    [dict create index 0 label "Loop A" selection "resid 1 to 4" row_mode free_selection] \
    [dict create index 1 label "Loop B" selection "resid 5 to 8" row_mode free_selection]]
set free_values [list {1 0} {0 1} {1 1}]
set free_dataset [::RMSXFlipbookTimeline::Matrix::create \
    title "Free Selection Smoke" \
    value_label contact \
    source_type test \
    row_mode free_selection \
    column_mode frame \
    rows $free_rows \
    columns $columns \
    values $free_values]

set free_tml [file join $tmp_dir free.TmL]
::RMSXFlipbookTimeline::write_timeline_tml $free_dataset $free_tml
set free_read [::RMSXFlipbookTimeline::read_timeline_tml $free_tml]

assert_equal [dict get $free_read row_mode] free_selection "free-selection row mode"
assert_equal [dict get $free_read row_count] 2 "free-selection row count"
assert_equal [dict get $free_read title] "Free Selection Smoke" "free-selection dataset title"
assert_equal [dict get [lindex [dict get $free_read rows] 1] selection] "resid 5 to 8" "free-selection selection"
assert_equal [::RMSXFlipbookTimeline::Matrix::cell_value $free_read 0 2] 1 "free-selection value"

set collection [::RMSXFlipbookTimeline::load_timeline_collection $tmp_dir]
assert_equal [llength $collection] 2 "collection dataset count"
assert_equal [llength [lsort -unique [lmap dataset $collection {dict get $dataset provenance file}]]] 2 "collection distinct files"

set legacy_tml [file join $tmp_dir legacy_free_selection.tml]
set fp [open $legacy_tml w]
puts $fp "# VMD Timeline data file"
puts $fp "# FILE_VERSION= 1.3"
puts $fp "# CREATOR= legacy"
puts $fp "# MOL_NAME= legacy_mol"
puts $fp "# DATA_TITLE= legacy contacts"
puts $fp "# NUM_FRAMES= 2"
puts $fp "# NUM_ITEMS= 2"
puts $fp "# FREE_SELECTION= 1"
puts $fp "#"
puts $fp "freeSelLabel 0 Alpha loop"
puts $fp "freeSelString 0 resid 1 to 4"
puts $fp "0 0 4.5"
puts $fp "1 0 5.5"
puts $fp "freeSelLabel 1 Beta loop"
puts $fp "freeSelString 1 resid 5 to 8"
puts $fp "0 1 0"
puts $fp "1 1 1"
close $fp

set legacy_read [::RMSXFlipbookTimeline::read_timeline_tml $legacy_tml]
assert_equal [dict get $legacy_read row_mode] free_selection "legacy row mode"
assert_equal [::RMSXFlipbookTimeline::Matrix::row_label [lindex [dict get $legacy_read rows] 0]] "Alpha loop" "legacy label"
assert_equal [dict get [lindex [dict get $legacy_read rows] 1] selection] "resid 5 to 8" "legacy selection"
assert_equal [::RMSXFlipbookTimeline::Matrix::cell_value $legacy_read 0 1] 5.5 "legacy first row frame 1 value"
assert_equal [::RMSXFlipbookTimeline::Matrix::cell_value $legacy_read 1 1] 1 "legacy second row frame 1 value"
assert_equal [dict get [dict get $legacy_read provenance] mol_name] legacy_mol "legacy mol name provenance"
assert_equal [dict get [dict get $legacy_read provenance] file_version] "1.3" "legacy file version provenance"

file delete -force $tmp_dir
puts "RMSX Flipbook Timeline TML round-trip smoke passed"
exit 0
