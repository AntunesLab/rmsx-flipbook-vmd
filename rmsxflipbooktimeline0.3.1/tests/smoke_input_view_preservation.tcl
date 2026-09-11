lappend auto_path $::env(RMSX_TEST_PACKAGE)
package require rmsxflipbooktimeline
source -encoding utf-8 [file join $::env(RMSX_TEST_PACKAGE) gui dashboard_window.tcl]
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set root $::env(RMSX_TEST_WORKDIR)
set topology [file join $root fixtures upstream test_files protease_backbone.pdb]
set trajectory [file join $root fixtures upstream test_files short_protease_backbone.dcd]
set first [mol new [file join $root fixtures upstream test_files 1UBQ.pdb] waitfor all]
set second [mol new $topology waitfor all]
rotate x by 31
rotate z by 17
scale by 0.42
mol off $second
mol top $first
set ::existing_ids [molinfo list]
set ::existing_views [::RMSXFlipbookTimeline::Style::capture_view_matrices $::existing_ids]
set visibility [lmap id $::existing_ids {molinfo $id get drawn}]
set ::checkpoints 0
proc verify_input_view {event} {
    incr ::checkpoints
    assert {[::RMSXFlipbookTimeline::Style::capture_view_matrices $::existing_ids] eq $::existing_views} "Input checkpoint changed an existing view"
    foreach id [molinfo list] {
        if {$id ni $::existing_ids} {assert {![molinfo $id get drawn]} "Temporary input is visible at a checkpoint"}
    }
    if {[info exists ::cancel_input]} {error "deliberate input cancellation"}
}
set ::RMSXFlipbookTimeline::NativeAnalysis::working_scopes [list [dict create callback verify_input_view molids {} cleanup 1 prior_top $first]]
try {
    set loaded [::RMSXFlipbookTimeline::NativeAnalysis::load_trajectory $topology $trajectory hidden 1]
    assert {$::checkpoints >= 2} "Trajectory checkpoints were not exercised"
    assert {[::RMSXFlipbookTimeline::Style::capture_view_matrices $::existing_ids] eq $::existing_views} "Loading trajectory changed existing matrices"
    ::RMSXFlipbookTimeline::NativeAnalysis::release_working_molecule [dict get $loaded molid]
    set ::cancel_input 1
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::load_trajectory $topology $trajectory hidden 1} message]} "Cancellation was ignored"
    assert {[string match *deliberate* $message]} "Unexpected cancellation error: $message"
    unset ::cancel_input
    assert {[molinfo list] eq $::existing_ids} "Cancelled load leaked a molecule"
} finally {
    set ::RMSXFlipbookTimeline::NativeAnalysis::working_scopes {}
}
set ::RMSXFlipbookTimeline::Dashboard::native_topology $topology
set ::RMSXFlipbookTimeline::Dashboard::native_trajectory $trajectory
set result_before [::RMSXFlipbookTimeline::Results::get]
set count [::RMSXFlipbookTimeline::Dashboard::read_total_frames_from_trajectory 1]
assert {$count == 27} "Incorrect frame count: $count"
assert {[molinfo list] eq $::existing_ids} "Frame counting leaked a molecule"
assert {[molinfo top] == $first} "Frame counting changed the user's top molecule"
assert {[::RMSXFlipbookTimeline::Style::capture_view_matrices $::existing_ids] eq $::existing_views} "Frame counting changed the current view"
assert {[lmap id $::existing_ids {molinfo $id get drawn}] eq $visibility} "Input inspection changed visibility"
assert {[::RMSXFlipbookTimeline::Results::get] eq $result_before} "Input inspection changed the current result"
puts "Input loading preserves existing views, visibility and frame-count top molecule"
