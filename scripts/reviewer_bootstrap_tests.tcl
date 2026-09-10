# Portable bootstrap scenarios. This simulates play's complete-command evaluation;
# real VMD state-file loading is separately qualified by the graphical tests.
package require Tcl 8.6
proc expect {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc vmdinfo {args} {return bootstrap-test}
proc play_like {path {continue_errors 0}} {
    set channel [open $path r]
    fconfigure $channel -encoding utf-8
    set command ""
    try {
        while {[gets $channel line] >= 0} {
            append command $line \n
            if {[info complete $command]} {
                if {$continue_errors} {
                    catch {uplevel #0 $command}
                } else {
                    uplevel #0 $command
                }
                set command ""
            }
        }
        if {[string trim $command] ne ""} {error "Incomplete generated Tcl command"}
    } finally {close $channel}
}

set scenario [lindex $argv 0]
set first [lindex $argv 1]
set before_path $::auto_path
switch -- $scenario {
    extract {
        play_like $first
        expect {$::RMSXFlipbookTimeline::Reviewer::launches == 1} "Runtime was not launched once"
        puts "WORKSPACE=$::RMSXReviewBootstrap::last_workspace"
        puts "BUILD_ID=[::RMSXFlipbookTimeline::build_id]"
    }
    repeat {
        play_like $first
        set workspace $::RMSXFlipbookTimeline::Reviewer::workspace
        set before [glob -nocomplain -directory [file dirname $workspace] rmsx-review-*]
        play_like $first
        expect {$::RMSXFlipbookTimeline::Reviewer::workspace eq $workspace} "Repeated load changed workspace"
        expect {$::RMSXReviewBootstrap::last_workspace eq $workspace} "Repeated load lost diagnostic workspace"
        expect {$::RMSXFlipbookTimeline::Reviewer::launches == 1 && $::RMSXFlipbookTimeline::Reviewer::reopens == 1} "Repeated load recreated the runtime"
        expect {[glob -nocomplain -directory [file dirname $workspace] rmsx-review-*] eq $before} "Repeated load extracted a second workspace"
        puts "WORKSPACE=$workspace"
    }
    different {
        play_like $first
        set workspace $::RMSXFlipbookTimeline::Reviewer::workspace
        set before [glob -nocomplain -directory [file dirname $workspace] rmsx-review-*]
        set caught [catch {play_like [lindex $argv 2]} message]
        expect {$caught && [string first "fresh VMD session" $message] >= 0} "Different loaded build was not rejected"
        expect {$::RMSXFlipbookTimeline::Reviewer::workspace eq $workspace} "Rejected build changed the active workspace"
        expect {[glob -nocomplain -directory [file dirname $workspace] rmsx-review-*] eq $before} "Rejected build created a workspace"
        puts "WORKSPACE=$workspace"
    }
    fail {
        package ifneeded rmsxflipbooktimeline 0.3.1 {error "prior package index must be preserved"}
        set ::env(RMSXFLIPBOOKTIMELINEDIR) prior-test-value
        set caught [catch {play_like $first} message]
        expect {$caught} "Damaged payload or package was accepted"
        expect {[package provide rmsxflipbooktimeline] eq ""} "Failure left a provided package"
        expect {![namespace exists ::RMSXFlipbookTimeline]} "Failure left package commands"
        expect {$::auto_path eq $before_path} "Failure changed auto_path"
        expect {[package ifneeded rmsxflipbooktimeline 0.3.1] eq {error "prior package index must be preserved"}} "Failure removed the prior package index"
        expect {$::env(RMSXFLIPBOOKTIMELINEDIR) eq "prior-test-value"} "Failure changed package environment"
        expect {[info commands ::rmsxflipbooktimeline] eq ""} "Failure left a public package command"
        expect {$::RMSXReviewBootstrap::last_workspace eq ""} "Failure retained extraction workspace"
        puts "EXPECTED_ERROR=$message"
    }
    runtimefail {
        set caught [catch {play_like $first} message]
        expect {$caught && [string first "retained for retry" $message] >= 0} "UI failure did not retain a diagnostic workspace"
        expect {[package provide rmsxflipbooktimeline] eq "0.3.1"} "UI failure discarded the loaded runtime"
        set workspace $::RMSXReviewBootstrap::last_workspace
        set channel [open [file join $workspace .rmsx_review_owner] r]
        try {set owner [read $channel]} finally {close $channel}
        expect {![::RMSXReviewBootstrap::cleanup_workspace $workspace [dict get $owner token] [dict get $owner build_id]]} "Rollback deleted an active reviewer workspace"
        expect {[file isdirectory $workspace]} "Active reviewer workspace disappeared"
        puts "WORKSPACE=$workspace"
    }
    stickyfail {
        play_like $first 1
        expect {$::RMSXReviewBootstrap::last_error ne ""} "Corruption did not latch a failure"
        expect {[package provide rmsxflipbooktimeline] eq ""} "Continued play activated a corrupt payload"
        expect {![namespace exists ::RMSXFlipbookTimeline]} "Continued play left package commands"
        expect {$::RMSXReviewBootstrap::last_workspace eq ""} "Corruption created a workspace"
        expect {$::auto_path eq $before_path} "Corruption changed package paths"
    }
    incomplete {
        play_like $first
        expect {$::RMSXReviewBootstrap::staging(timer) ne ""} "Incomplete load has no timer"
        set token $::RMSXReviewBootstrap::staging(token)
        ::RMSXReviewBootstrap::stage_timeout [expr {$token-1}]
        expect {$::RMSXReviewBootstrap::last_error eq ""} "Old timer affected a newer load"
        ::RMSXReviewBootstrap::stage_timeout $token
        expect {[string first "Incomplete reviewer file" $::RMSXReviewBootstrap::last_error] >= 0} "Missing commit has no useful diagnosis"
        expect {$::RMSXReviewBootstrap::staging(timer) eq ""} "Expired timer was not cleared"
        expect {[catch {::RMSXReviewBootstrap::stage commit}]} "Timed-out staging was allowed to commit"
        expect {[package provide rmsxflipbooktimeline] eq ""} "Timed-out payload activated a package"
        expect {$::RMSXReviewBootstrap::last_workspace eq ""} "Incomplete payload created a workspace"
    }
    unknown {
        namespace eval ::RMSXFlipbookTimeline {}
        proc ::RMSXFlipbookTimeline::build_id {} {return source-checkout}
        set caught [catch {play_like $first} message]
        expect {$caught && [string first "fresh VMD session" $message] >= 0} "Unknown loaded build was accepted"
        expect {[::RMSXFlipbookTimeline::build_id] eq "source-checkout"} "Unknown loaded build was overwritten"
        expect {$::auto_path eq $before_path} "Guard changed package search path"
    }
    default {error "Unknown bootstrap scenario: $scenario"}
}
puts "BOOTSTRAP_TEST_PASS $scenario"
