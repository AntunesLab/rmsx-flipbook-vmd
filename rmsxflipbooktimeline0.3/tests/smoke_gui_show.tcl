################################################################################
# RMSX Flipbook Timeline GUI smoke test
#
# Usage:
#   vmd -dispdev win -e tests/smoke_gui_show.tcl
################################################################################

set smoke_marker [file normalize [file join [pwd] outputs rmsxflipbooktimeline-gui-smoke.txt]]
file mkdir [file dirname $smoke_marker]

proc smoke_record {message} {
    global smoke_marker
    set fp [open $smoke_marker w]
    puts $fp $message
    close $fp
}

proc smoke_fail {message} {
    return -code error $message
}

proc run_smoke {} {
    set plugin_parent $::env(RMSX_TEST_REPO)
    if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.3]]} {
        smoke_fail "plugin directory not found under $plugin_parent"
    }

    lappend ::auto_path $plugin_parent

    if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
        smoke_fail "package require failed: $err"
    }

    if {[catch {package require Tk} err]} {
        puts "RMSX Flipbook Timeline GUI smoke skipped: Tk unavailable: $err"
        smoke_record "SKIP Tk unavailable: $err"
        return skip
    }

    if {[catch {rmsxflipbooktimeline_classic} err]} {
        smoke_fail "rmsxflipbooktimeline callback failed: $err"
    }

    if {![winfo exists .rmsxflipbooktimeline]} {
        smoke_fail "expected .rmsxflipbooktimeline window was not created"
    }

    foreach widget {
        .rmsxflipbooktimeline.native.slice_size_entry
        .rmsxflipbooktimeline.actions.repair
        .rmsxflipbooktimeline.actions.viewer_plot
        .rmsxflipbooktimeline.actions.heatmap
        .rmsxflipbooktimeline.actions.report
        .rmsxflipbooktimeline.view.mouse_toggle
        .rmsxflipbooktimeline.view.burst_run
        .rmsxflipbooktimeline.controls.metric_combo
        .rmsxflipbooktimeline.timeline.live
        .rmsxflipbooktimeline.timeline.scale_min_entry
        .rmsxflipbooktimeline.timeline.scale_max_entry
        .rmsxflipbooktimeline.timeline.tml_load
        .rmsxflipbooktimeline.timeline.collection_load
        .rmsxflipbooktimeline.timeline.collection_prev
        .rmsxflipbooktimeline.timeline.collection_next
        .rmsxflipbooktimeline.timeline.filter_apply
        .rmsxflipbooktimeline.timeline.copy_user
        .rmsxflipbooktimeline.timeline.export_svg
        .rmsxflipbooktimeline.timeline.rmsx_folder
        .rmsxflipbooktimeline.timeline.resfunc_entry
        .rmsxflipbooktimeline.timeline.resfunc_context_entry
        .rmsxflipbooktimeline.timeline.resfunc_value_entry
        .rmsxflipbooktimeline.timeline.resfunc_unit_entry
        .rmsxflipbooktimeline.actions.spacing_plus
        .rmsxflipbooktimeline.actions.thicker
    } {
        if {![winfo exists $widget]} {
            smoke_fail "expected GUI widget was not created: $widget"
        }
    }

    puts "RMSX Flipbook Timeline GUI smoke passed"
    smoke_record "PASS RMSX Flipbook Timeline GUI smoke passed"
    return pass
}

if {[catch {run_smoke} err]} {
    puts "RMSX Flipbook Timeline GUI smoke failed: $err"
    smoke_record "FAIL $err"
    error $err
} else {
    after 750 quit
}
