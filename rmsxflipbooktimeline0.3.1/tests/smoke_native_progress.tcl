################################################################################
# RMSX Flipbook Timeline native progress callback smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native progress smoke failed: $message"
    exit 1
}

proc assert_true {condition message} {
    if {!$condition} {
        smoke_fail $message
    }
}

proc assert_contains {haystack needle message} {
    if {[string first $needle $haystack] < 0} {
        smoke_fail "$message: expected '$needle' in '$haystack'"
    }
}

set ::progress_events {}
set ::cancel_events {}

proc record_progress {event} {
    if {[dict exists $event stage] && [dict get $event stage] eq "started" && [dict exists $event molid]} {
        set molid [dict get $event molid]
        if {[info commands molinfo] ne "" && [lsearch -exact [molinfo list] $molid] != -1} {
            set drawn 1
            catch {set drawn [molinfo $molid get drawn]}
            if {$drawn} {
                smoke_fail "cleanup-only native analysis molecule should be hidden while running: $molid"
            }
        }
    }
    lappend ::progress_events $event
    return ""
}

proc cancel_on_first_slice {event} {
    lappend ::cancel_events $event
    if {[dict exists $event stage] && [dict get $event stage] eq "slice"} {
        return "cancel"
    }
    return ""
}

proc progress_stages {events} {
    set stages {}
    foreach event $events {
        if {[dict exists $event stage]} {
            lappend stages [dict get $event stage]
        }
    }
    return $stages
}

proc count_stage {events stage} {
    set count 0
    foreach event $events {
        if {[dict exists $event stage] && [dict get $event stage] eq $stage} {
            incr count
        }
    }
    return $count
}

proc run_smoke {} {
    global auto_path
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

    set topology [file normalize [file join $workspace_root fixtures upstream test_files 1UBQ.pdb]]
    set trajectory [file normalize [file join $workspace_root fixtures upstream test_files mon_sys.dcd]]
    if {![file exists $topology] || ![file exists $trajectory]} {
        smoke_fail "Missing 1UBQ smoke inputs"
    }

    set output_dir [file normalize [file join $workspace_root outputs native-progress-smoke]]
    set cancel_dir [file normalize [file join $workspace_root outputs native-progress-cancel-smoke]]
    catch {file delete -force $output_dir}
    catch {file delete -force $cancel_dir}

    if {[catch {
        ::RMSXFlipbookTimeline::run_native_all_chain_analysis \
            $topology \
            $trajectory \
            $output_dir \
            -num_slices 2 \
            -start_frame 0 \
            -end_frame 20 \
            -overwrite 1 \
            -cleanup 1 \
            -analysis_type protein \
            -progress_callback record_progress \
            -verbose 0
    } result]} {
        smoke_fail "run_native_all_chain_analysis with progress failed: $result"
    }

    set stages [progress_stages $::progress_events]
    foreach required_stage {
        all_chain_preparing
        all_chain_started
        chain_started
        preparing
        started
        slice
        writing_outputs
        writing_slices
        rmsf
        rmsd
        complete
        chain_complete
        all_chain_complete
    } {
        assert_true [expr {[lsearch -exact $stages $required_stage] >= 0}] "missing progress stage $required_stage in $stages"
    }
    assert_true [expr {[count_stage $::progress_events slice] == 2}] "expected 2 slice progress events, got [count_stage $::progress_events slice]"
    assert_true [expr {[dict get $result combined_slice_count] == 2}] "expected 2 generated slices"
    assert_true [file isfile [file join $output_dir .rmsx_output_manifest.tcldict]] "all-chain progress run did not commit an ownership manifest"
    set ownership [::RMSXFlipbookTimeline::OutputTxn::verify_owned $output_dir]
    assert_true [expr {[dict get $ownership schema] == 2 && [dict get $ownership complete]}] "progress result is not a verified complete output"

    if {![catch {
        ::RMSXFlipbookTimeline::run_native_analysis \
            $topology \
            $trajectory \
            $cancel_dir \
            -chain 7 \
            -num_slices 3 \
            -start_frame 0 \
            -end_frame 30 \
            -overwrite 1 \
            -cleanup 1 \
            -analysis_type protein \
            -progress_callback cancel_on_first_slice \
            -verbose 0
    } cancel_error]} {
        smoke_fail "native analysis did not stop after progress callback cancellation"
    }
    assert_contains $cancel_error "cancelled by progress callback" "cancel error was unclear"
    assert_true [expr {[count_stage $::cancel_events slice] == 1}] "expected cancellation on first slice"

    return ""
}

run_smoke
puts "RMSX Flipbook Timeline native progress smoke passed"
quit
