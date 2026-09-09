package require Tcl 8.6
source [file join [file dirname [file dirname [info script]]] rmsxflipbooktimeline.tcl]
proc expect {expression message} { if {![uplevel 1 [list expr $expression]]} { error $message } }
if {[info commands mol] eq ""} { error "This test requires VMD" }
set fixtures [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files]
set source [mol new [file join $fixtures 1UBQ.pdb] waitfor all]
mol addfile [file join $fixtures mon_sys.dcd] first 0 last 3 waitfor all molid $source
set expected_rows [llength [::RMSXFlipbookTimeline::TimelineAnalysis::residue_rows $source protein 0]]
molinfo $source set frame 2
set before [lsort [atomselect list]]
set ::event_count 0
proc cancel_frame {event} {
    incr ::event_count
    if {[dict get $event stage] eq "calculating" && [dict get $event completed] >= 1} { return cancel }
    return ""
}
set failed [catch {::RMSXFlipbookTimeline::TimelineAnalysis::calculate $source displacement selection protein first_frame 0 last_frame 4 progress_callback cancel_frame} message options]
expect {$failed && [::RMSXFlipbookTimeline::Operation::cancelled $options]} "Timeline cancellation failed: $message; options: $options"
expect {[molinfo $source get frame] == 2} "Timeline cancellation did not restore source frame"
expect {[lsort [atomselect list]] eq $before} "Timeline cancellation leaked selections"
set other [mol new atoms 1]
mol top $source
proc change_top {event} { mol top $::other; return "" }
set dataset [::RMSXFlipbookTimeline::TimelineAnalysis::calculate top displacement selection protein first_frame 0 last_frame 4 progress_callback change_top]
expect {[dict get $dataset row_count] == $expected_rows} "A top-molecule change redirected calculation"
expect {[molinfo top] == $source} "Timeline did not restore the original top molecule"
mol delete $source
mol delete $other
puts "RMSX Flipbook Timeline cancellation smoke passed"
