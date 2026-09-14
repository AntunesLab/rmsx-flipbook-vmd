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

# Model Cocoa's delayed framebuffer resize and the Linux text-display mode
# setter that must not be called when restoring an unchanged mode.
source -encoding utf-8 [file join [file dirname [file dirname [info script]]] core effects.tcl]
proc tk {args} {return aqua}
set mock_size {1024 1024}
set mock_pending {}
set mock_updates 0
set mock_scale 1
set mock_drawing 1
set mock_resize_calls 0
set mock_resize_fail 0
proc display {args} {
    switch -- [lindex $args 0] {
        get {
            if {[lindex $args 1] eq "rendermode"} {return Normal}
            return $::mock_size
        }
        resize {
            incr ::mock_resize_calls
            if {$::mock_resize_fail} {error "Injected resize failure"}
            expect {!$::mock_drawing} "Cocoa resize ran with drawing enabled"
            set ::mock_pending [list [expr {[lindex $args 1]*$::mock_scale}] [expr {[lindex $args 2]*$::mock_scale}]]}
        update {
            switch -- [lindex $args 1] {
                status {return $::mock_drawing}
                off {set ::mock_drawing 0; return}
                on {set ::mock_drawing 1; return}
            }
            incr ::mock_updates
            if {$::mock_updates >= 2} {set ::mock_size $::mock_pending}
        }
        rendermode {error "Redundant native render-mode setter invoked"}
        default {error "Unexpected display command $args"}
    }
}
::RMSXFlipbookTimeline::Scene::write rendermode Normal
::RMSXFlipbookTimeline::Scene::resize_display 600 500
expect {$mock_size eq {600 500} && $mock_updates >= 4} "Cocoa resize returned before stable requested dimensions"
set mock_scale 2
::RMSXFlipbookTimeline::Scene::resize_display 800 600
expect {$mock_size eq {800 600}} "Retina resize did not converge to requested framebuffer size"
set rounded [::RMSXFlipbookTimeline::Scene::resize_display 801 601]
expect {$rounded eq {802 602}} "Native one-pixel rounding was not reported accurately"
expect {$mock_drawing && !$::RMSXFlipbookTimeline::Scene::resizing} "Resize leaked its guard"
set mock_drawing 0
::RMSXFlipbookTimeline::Scene::resize_display 600 500
expect {!$mock_drawing} "Resize enabled previously disabled drawing"
set mock_drawing 1
set mock_resize_fail 1
expect {[catch {::RMSXFlipbookTimeline::Scene::resize_display 700 500}]} "Injected resize error was swallowed"
expect {$mock_drawing && !$::RMSXFlipbookTimeline::Scene::resizing} "Failed resize leaked its guard"
rename display {}
rename tk {}
puts "Scene render-mode and asynchronous resize regressions passed"
