# Legacy UI forwards native setup into the shared dashboard operation/safety path.
package require Tcl 8.6
source [file join $::env(RMSX_TEST_PACKAGE) rmsxflipbooktimeline.tcl]
source [file join $::env(RMSX_TEST_PACKAGE) gui dashboard_window.tcl]
source [file join $::env(RMSX_TEST_PACKAGE) gui main_window.tcl]
proc expect {expression message} { if {![uplevel 1 [list expr $expression]]} { error $message } }
rename ::RMSXFlipbookTimeline::Dashboard::run_native_metric ::RMSXFlipbookTimeline::Dashboard::run_native_metric_real
proc ::RMSXFlipbookTimeline::Dashboard::run_native_metric {} {
    set ::captured {}
    foreach name {native_topology native_trajectory native_output native_chain native_slices native_slice_size native_slicing_mode native_start native_end native_metric} {
        dict set ::captured $name [set ::RMSXFlipbookTimeline::Dashboard::$name]
    }
    return [dict create delegated 1]
}
set ::RMSXFlipbookTimeline::GUI::native_topology topology.pdb
set ::RMSXFlipbookTimeline::GUI::native_trajectory trajectory.dcd
set ::RMSXFlipbookTimeline::GUI::native_output output-parent
set ::RMSXFlipbookTimeline::GUI::native_start 0
set ::RMSXFlipbookTimeline::GUI::native_end -1
foreach chain {7 all} {
    set ::RMSXFlipbookTimeline::GUI::native_chain $chain
    set ::RMSXFlipbookTimeline::GUI::native_slice_size 105
    set result [::RMSXFlipbookTimeline::GUI::run_native_analysis]
    expect {[dict get $result delegated] == 1} "Legacy run bypassed shared operation"
    expect {[dict get $::captured native_slice_size] == 105} "Lost slice size"
    expect {[dict get $::captured native_slicing_mode] eq "slice_size"} "Wrong slice mode"
    expect {[dict get $::captured native_chain] eq $chain} "Lost chain selection"
    expect {[dict get $::captured native_end] == -1} "Lost final-frame sentinel"
    expect {[dict get $::captured native_output] eq "output-parent"} "Changed output parent"
}
set ::RMSXFlipbookTimeline::GUI::native_slice_size ""
set ::RMSXFlipbookTimeline::GUI::native_slices 9
::RMSXFlipbookTimeline::GUI::run_native_analysis
expect {[dict get $::captured native_slicing_mode] eq "slices"} "Legacy count mode is not forwarded"
puts "RMSX Flipbook Timeline GUI native slice-size command smoke passed"
quit
