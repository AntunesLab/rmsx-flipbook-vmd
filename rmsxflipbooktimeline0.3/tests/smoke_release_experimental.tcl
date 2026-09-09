################################################################################
# RMSX/Flipbook Timeline 0.2 experimental feature-gate smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX/Flipbook Timeline experimental release smoke failed: $message"
    exit 1
}

set ::env(RMSXFLIPBOOKTIMELINE_EXPERIMENTAL) 1

set plugin_parent $::env(RMSX_TEST_REPO)
set plugin_dir [file join $plugin_parent rmsxflipbooktimeline0.3]
if {![file isdirectory $plugin_dir]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

if {![::RMSXFlipbookTimeline::experimental_enabled]} {
    smoke_fail "experimental features should be enabled when env flag is set before package load"
}

foreach command {
    ::RMSXFlipbookTimeline::ViewerPlot::show
    ::RMSXFlipbookTimeline::AngleOverlay::apply
} {
    if {[info commands $command] eq ""} {
        smoke_fail "experimental command missing with feature gate enabled: $command"
    }
}

if {[catch {source [file join $plugin_dir gui dashboard_window.tcl]} err]} {
    smoke_fail "dashboard source failed: $err"
}

set metrics [::RMSXFlipbookTimeline::Dashboard::metric_values]
foreach metric {
    cross_correlation
    x
    y
    z
    user_field
    residue_function
    selection_empty
    test_free_selection
    rmsd_tool
} {
    if {[lsearch -exact $metrics $metric] < 0} {
        smoke_fail "experimental metric missing with feature gate enabled: $metric"
    }
}

puts "RMSX/Flipbook Timeline experimental release smoke passed"
if {[info commands quit] ne ""} {
    quit
}
exit 0
