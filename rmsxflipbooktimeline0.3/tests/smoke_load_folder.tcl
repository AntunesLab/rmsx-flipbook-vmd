################################################################################
# RMSX Flipbook Timeline text-mode smoke test
#
# Usage:
#   vmd -dispdev text -e tests/smoke_load_folder.tcl -args /path/to/rmsx/output [palette]
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline smoke failed: $message"
    exit 1
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

if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.3]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {$argc < 1} {
    smoke_fail "Usage: smoke_load_folder.tcl <rmsx-output-folder> \[palette\]"
}

set folder [lindex $argv 0]
set palette "viridis"
if {$argc >= 2} {
    set palette [lindex $argv 1]
}

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

if {[catch {::RMSXFlipbookTimeline::load_folder $folder palette $palette write_manifest 1} result]} {
    smoke_fail "load_folder failed: $result"
}
puts "RMSX Flipbook Timeline smoke result: $result"

if {[dict get $result molecules] < 1} {
    smoke_fail "no molecules loaded"
}

if {[dict get $result files] < 1} {
    smoke_fail "no slice files discovered"
}

if {[dict get $result view_preset] ne "rmsx"} {
    smoke_fail "expected rmsx view preset on load, got $result"
}

set manifest [dict get $result manifest]
if {$manifest eq "" || ![file exists $manifest]} {
    smoke_fail "manifest was not written"
}

puts "RMSX Flipbook Timeline smoke passed"
quit
