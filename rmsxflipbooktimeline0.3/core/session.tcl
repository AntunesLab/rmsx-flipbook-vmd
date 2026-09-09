# Current result and cooperative operation state. No Tk dependency on package load.
namespace eval ::RMSXFlipbookTimeline::Results {
    variable current {}
    variable serial 0
    proc get {} { variable current; return $current }
    proc notify {} {
        if {[info commands ::RMSXFlipbookTimeline::Dashboard::refresh_result_header] ne ""} {
            ::RMSXFlipbookTimeline::Dashboard::refresh_result_header
        }
    }
    proc publish {record} {
        variable current
        variable serial
        dict size $record
        dict set record id [incr serial]
        if {![dict exists $record status]} { dict set record status complete }
        set current $record
        notify
        return $current
    }
    proc update {changes} {
        variable current
        if {$current eq {}} { error "No current result" }
        set id [dict get $current id]
        set current [dict merge $current $changes]
        dict set current id $id
        notify
        return $current
    }
    proc clear {} { variable current; set current {}; notify; return {} }
}

namespace eval ::RMSXFlipbookTimeline::Operation {
    variable current {}
    variable serial 0
    variable observer ""
    variable servicing 0
    variable last_service 0
    proc get {} { variable current; return $current }
    proc running {} {
        variable current
        return [expr {$current ne {} && [dict get $current state] in {running cancelling}}]
    }
    proc set_observer {command} { variable observer; set observer $command }
    proc notify {} {
        variable observer
        variable current
        if {$observer ne ""} { uplevel #0 [list {*}$observer $current] }
    }
    proc begin {kind {details {}}} {
        variable current
        variable serial
        variable last_service
        if {[running]} { error "An operation is already running" }
        set last_service 0
        set current [dict merge $details [dict create id [incr serial] kind $kind state running phase preparing cancel_requested 0 started_ms [clock milliseconds] message "Preparing $kind…"]]
        notify
        return [dict get $current id]
    }
    proc request_cancel {} {
        variable current
        if {![running]} { return 0 }
        dict set current cancel_requested 1
        dict set current state cancelling
        dict set current message "Stopping at the next safe checkpoint…"
        notify
        return 1
    }
    proc checkpoint {event} {
        variable current
        variable servicing
        variable last_service
        if {![running]} { return "" }
        set token [dict get $current id]
        if {![dict get $current cancel_requested]} {
            if {[dict exists $event stage]} { dict set current phase [dict get $event stage] }
            dict set current event $event
            if {[dict exists $event message]} { dict set current message [dict get $event message] }
        }
        set now [clock milliseconds]
        if {!$servicing && $now - $last_service >= 75} {
            set last_service $now
            set servicing 1
            try {
                notify
                if {[info commands update] ne "" && [info commands winfo] ne ""} { update }
            } finally { set servicing 0 }
        }
        if {![running] || [dict get $current id] != $token || [dict get $current cancel_requested]} {
            return -code error -errorcode {RMSXFLIPBOOK CANCELLED} "Operation cancelled"
        }
        return ""
    }
    proc finish {state {message ""}} {
        variable current
        if {$current eq {}} { return {} }
        if {$state ni {complete cancelled failed partial}} { error "Invalid operation outcome: $state" }
        dict set current state $state
        dict set current finished_ms [clock milliseconds]
        if {$message ne ""} { dict set current message $message }
        notify
        return $current
    }
    proc cancelled {options} {
        return [expr {[dict exists $options -errorcode] && [lrange [dict get $options -errorcode] 0 1] eq {RMSXFLIPBOOK CANCELLED}}]
    }
}
