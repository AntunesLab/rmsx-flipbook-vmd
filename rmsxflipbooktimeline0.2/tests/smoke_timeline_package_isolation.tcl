################################################################################
# RMSX Flipbook Timeline package isolation smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline package isolation smoke failed: $message"
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

if {![file isdirectory [file join $plugin_parent rmsxflipbook0.1]]} {
    smoke_fail "native plugin directory not found under $plugin_parent"
}
if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.2]]} {
    smoke_fail "timeline plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbook 0.1} err]} {
    smoke_fail "native package require failed: $err"
}
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "timeline package require failed: $err"
}

if {![namespace exists ::RMSXFlipbook]} {
    smoke_fail "native namespace missing"
}
if {![namespace exists ::RMSXFlipbookTimeline]} {
    smoke_fail "timeline namespace missing"
}

if {[package provide rmsxflipbook] ne "0.1"} {
    smoke_fail "native package version changed"
}
if {[package provide rmsxflipbooktimeline] ne "0.2"} {
    smoke_fail "timeline package version missing"
}

foreach command {
    calculate_timeline
    aggregate_timeline_to_slices
    show_timeline_dataset
    show_live_timeline
    show_timeline_tml
    read_timeline_tml
    write_timeline_tml
    load_timeline_collection
    filter_timeline_current
    copy_timeline_to_user
    write_timeline_svg
    write_timeline_png
    write_current_timeline_png
} {
    if {[info commands ::RMSXFlipbookTimeline::$command] eq ""} {
        smoke_fail "timeline command missing: $command"
    }
    if {[info commands ::RMSXFlipbook::$command] ne ""} {
        smoke_fail "timeline command leaked into native namespace: $command"
    }
}

if {[info commands rmsxflipbooktimeline] eq ""} {
    smoke_fail "timeline VMD callback command missing"
}
if {[info commands rmsxflipbook] eq ""} {
    smoke_fail "native VMD callback command missing"
}

puts "RMSX Flipbook Timeline package isolation smoke passed"
exit 0
