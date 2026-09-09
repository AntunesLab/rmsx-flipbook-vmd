################################################################################
# RMSX Flipbook Timeline multi-chain plot window drawing smoke test
#
# Usage:
#   vmd -dispdev win -e tests/smoke_plot_window_multichain_draw.tcl
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline multi-chain plot drawing smoke failed: $message"
    exit 1
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

if {[catch {package require Tk} tk_err]} {
    puts "RMSX Flipbook Timeline multi-chain plot drawing smoke skipped: Tk unavailable ($tk_err)"
    quit
}

set folder [file join $workspace_root outputs native-rmsx-real-multichain-protease combined]
if {![file isdirectory $folder]} {
    smoke_fail "Expected real multi-chain combined folder is missing: $folder"
}

if {[catch {
    ::RMSXFlipbookTimeline::show_plot_window \
        folder $folder \
        palette turbo \
        draw 1 \
        pick 0
} plot_result]} {
    smoke_fail "show_plot_window draw failed: $plot_result"
}

if {[dict get $plot_result chain_panels] != 2 || ![dict get $plot_result split_by_chain]} {
    smoke_fail "Expected 2 split chain panels, got $plot_result"
}
if {![winfo exists .rmsxflipbooktimeline_plot]} {
    smoke_fail "Plot window was not created"
}
if {[llength [.rmsxflipbooktimeline_plot.outer.canvas find all]] <= 0} {
    smoke_fail "Plot canvas is empty"
}
if {[dict get $plot_result masked_rows] != 4 || [dict get $plot_result masked_cells] != 12} {
    smoke_fail "Expected 4 masked rows and 12 masked cells, got $plot_result"
}
if {[llength [.rmsxflipbooktimeline_plot.outer.canvas find withtag mask_hatch]] <= 0} {
    smoke_fail "Plot canvas is missing mask hatch overlays"
}
if {[llength [.rmsxflipbooktimeline_plot.outer.canvas find withtag mask_rail]] != 0} {
    smoke_fail "Plot canvas should not draw separate mask row rails"
}

puts "RMSX Flipbook Timeline multi-chain plot drawing smoke passed"
after 750 quit
