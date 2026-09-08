################################################################################
# RMSX Flipbook Timeline CSV fallback smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline CSV fallback smoke failed: $message"
    exit 1
}

proc range_of {values} {
    set sorted [lsort -real $values]
    return [list [lindex $sorted 0] [lindex $sorted end]]
}

set plugin_parent [file normalize [file join [pwd] workspace_plugins]]
if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.2]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}
lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

if {$argc < 1} {
    smoke_fail "Usage: smoke_csv_fallback.tcl <rmsx-output-folder>"
}

set folder [lindex $argv 0]
if {[catch {::RMSXFlipbookTimeline::load_folder $folder palette viridis write_manifest 1} result]} {
    smoke_fail "load_folder failed: $result"
}

if {[dict get $result value_source] ne "csv"} {
    smoke_fail "expected CSV value source, got [dict get $result value_source]"
}
if {![file exists [dict get $result value_file]]} {
    smoke_fail "value CSV was not recorded"
}
if {[dict get $result raw_max] <= [dict get $result raw_min]} {
    smoke_fail "CSV values did not produce a useful raw range"
}

set values {}
foreach molid [dict get $result molids] {
    set sel [atomselect $molid all]
    set values [concat $values [$sel get user2]]
    $sel delete
}
set user2_range [range_of $values]
if {[lindex $user2_range 0] == [lindex $user2_range 1]} {
    smoke_fail "user2 did not vary after CSV fallback"
}

puts "RMSX Flipbook Timeline CSV fallback smoke passed"
quit
