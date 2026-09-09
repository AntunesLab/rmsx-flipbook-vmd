# Standalone checks for the shared current result and cooperative cancellation.
source -encoding utf-8 [file join [file dirname [file dirname [info script]]] core session.tcl]
proc expect {expression message} { if {![uplevel 1 [list expr $expression]]} { error $message } }
set one [::RMSXFlipbookTimeline::Results::publish [dict create kind matrix label First dataset [dict create values {1 2}]]]
set id [dict get $one id]
set changed [::RMSXFlipbookTimeline::Results::update [dict create label Filtered id 999]]
expect {[dict get $changed id] == $id} "Update must preserve result identity"
expect {[dict get $changed dataset values] eq {1 2}} "Update must preserve dataset"
set token [::RMSXFlipbookTimeline::Operation::begin test]
expect {[catch {::RMSXFlipbookTimeline::Operation::begin duplicate}]} "Duplicate operation allowed"
::RMSXFlipbookTimeline::Operation::request_cancel
set failed [catch {::RMSXFlipbookTimeline::Operation::checkpoint [dict create stage frame completed 1 total 5]} message options]
expect {$failed && [::RMSXFlipbookTimeline::Operation::cancelled $options]} "Cancellation lost its error code"
::RMSXFlipbookTimeline::Operation::finish cancelled
expect {![::RMSXFlipbookTimeline::Operation::running]} "Cancellation did not release operation"
expect {[::RMSXFlipbookTimeline::Results::get] eq $changed} "Cancelled operation changed committed result"
set second [::RMSXFlipbookTimeline::Results::publish [dict create label Second]]
expect {[dict get $second id] > $id} "Result IDs must be monotonic"
::RMSXFlipbookTimeline::Results::clear
expect {[::RMSXFlipbookTimeline::Results::get] eq {}} "Result clear failed"
puts "RMSX Flipbook Timeline session operation smoke passed"
