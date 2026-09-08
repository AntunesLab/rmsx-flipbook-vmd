################################################################################
# RMSX Flipbook Timeline native SVG heatmap smoke for an existing folder
#
# Usage:
#   vmd -dispdev text -e tests/smoke_heatmap_folder.tcl -args <folder> <svg-output>
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline existing-folder heatmap smoke failed: $message"
    exit 1
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
} else {
    set plugin_parent [file normalize [file join [pwd] workspace_plugins]]
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

if {$argc < 2} {
    smoke_fail "Usage: smoke_heatmap_folder.tcl <folder> <svg-output>"
}

set folder [file normalize [lindex $argv 0]]
set svg_output [file normalize [lindex $argv 1]]

if {[catch {
    ::RMSXFlipbookTimeline::write_heatmap_svg \
        $folder \
        -title "RMSX Heatmap Existing Folder Smoke" \
        -output_name $svg_output
} result]} {
    smoke_fail "write_heatmap_svg failed: $result"
}

if {![file exists [dict get $result svg]]} {
    smoke_fail "SVG heatmap was not written: [dict get $result svg]"
}
if {[file tail [dict get $result csv]] eq "rmsx_summary.csv"} {
    smoke_fail "Heatmap used rmsx_summary.csv instead of an RMSX matrix"
}
if {[dict get $result residue_count] < 1 || [dict get $result slice_count] < 1} {
    smoke_fail "Heatmap did not detect residue/slice data: $result"
}

puts "RMSX Flipbook Timeline existing-folder heatmap smoke passed"
puts "Folder: $folder"
puts "SVG: [dict get $result svg]"
puts "CSV: [dict get $result csv]"
puts "Residues: [dict get $result residue_count]"
puts "Slices: [dict get $result slice_count]"
puts "Range: [dict get $result min]..[dict get $result max]"
exit 0
