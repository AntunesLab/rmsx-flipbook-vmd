################################################################################
# RMSX Flipbook Timeline dashboard command smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline dashboard command smoke failed: $message"
    exit 1
}

proc assert_equal {actual expected message} {
    if {$actual ne $expected} {
        smoke_fail "$message: expected '$expected', got '$actual'"
    }
}

proc option_value {args key} {
    set index [lsearch -exact $args $key]
    if {$index < 0 || [llength $args] <= [expr {$index + 1}]} {
        return ""
    }
    return [lindex $args [expr {$index + 1}]]
}

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
    set plugin_dir [file join $plugin_parent rmsxflipbooktimeline0.3]
}

set ::env(RMSXFLIPBOOKTIMELINE_EXPERIMENTAL) 1
lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

if {[info commands rmsxflipbooktimeline_dashboard] eq ""} {
    smoke_fail "dashboard callback command missing"
}
if {[info commands ::RMSXFlipbookTimeline::GUI::show] ne ""} {
    smoke_fail "classic GUI should not be sourced by package require alone"
}

if {[catch {source [file join $plugin_dir gui dashboard_window.tcl]} err]} {
    smoke_fail "dashboard source failed: $err"
}

if {[info commands ::RMSXFlipbookTimeline::Dashboard::show] eq ""} {
    smoke_fail "dashboard show command missing"
}

::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "" "output display marker should be blank before any flipbook is displayed"
set ::RMSXFlipbookTimeline::Dashboard::native_output [file join $::env(TMPDIR) rmsx-dashboard-out]
set ::RMSXFlipbookTimeline::Dashboard::displayed_flipbook_path [file join $::env(TMPDIR) rmsx-dashboard-out combined]
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "" "output-parent marker should not confuse the committed result with setup"
set ::RMSXFlipbookTimeline::Dashboard::displayed_flipbook_path [file join $::env(TMPDIR) rmsx-dashboard-other combined]
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "" "next-run folder must not imply current-result failure"
set ::RMSXFlipbookTimeline::Dashboard::native_output ""
set ::RMSXFlipbookTimeline::Dashboard::displayed_flipbook_path ""
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator

assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_route RMSX] native "RMSX route"
assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_route secondary_structure] timeline "secondary_structure route"
assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_panel cross_correlation] cross_correlation "cross-correlation panel"
assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_panel residue_function] residue_function "residue-function panel"
if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::metric_values_for_group Primary] RMSX] < 0} {
    smoke_fail "Primary metric group should include RMSX"
}
if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::metric_values_for_group Contacts] cross_correlation] < 0} {
    smoke_fail "Contacts metric group should include cross_correlation"
}
foreach metric {RMSX displacement secondary_structure cross_correlation residue_function} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::current_metric_values] $metric] < 0} {
        smoke_fail "dashboard metric metadata values should include $metric"
    }
}
foreach metric {RMSX Shift-Map 1-lDDT} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::native_metric_values] $metric] < 0} {
        smoke_fail "native metric values should include $metric"
    }
}
foreach metric {Displacement SS {Native contacts} cross_correlation residue_function} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::timeline_metric_values] $metric] < 0} {
        smoke_fail "Timeline metric values should include $metric"
    }
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::native_metric_values] $metric] >= 0} {
        smoke_fail "native metric values should not include Timeline-only metric $metric"
    }
}
assert_equal $::RMSXFlipbookTimeline::Dashboard::native_time_step 0.049 "dashboard default frame step"
assert_equal $::RMSXFlipbookTimeline::Dashboard::native_total_time_ns auto "dashboard total-time override should default to auto"
foreach palette {viridis magma inferno plasma cividis rocket mako turbo BWR RWB RGB} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::palette_values] $palette] < 0} {
        smoke_fail "palette values should include $palette"
    }
}
set ::RMSXFlipbookTimeline::Dashboard::palette turbo
::RMSXFlipbookTimeline::Dashboard::persist_common_state
assert_equal $::RMSXFlipbookTimeline::Dashboard::palette turbo "dashboard palette variable should update"
assert_equal [::RMSXFlipbookTimeline::state_get palette ""] turbo "dashboard palette should persist to plugin state"

set metadata_dir [file normalize [file join $::env(TMPDIR) rmsxflipbooktimeline-dashboard-metadata-[pid]]]
file mkdir $metadata_dir
set metadata_traj [file join $metadata_dir sample.dcd]
set fp [open $metadata_traj w]
puts $fp "placeholder"
close $fp
set fp [open [file join $metadata_dir sample.log] w]
puts $fp "timestep 2 fs"
puts $fp "DCDfreq 500"
close $fp
set timing [::RMSXFlipbookTimeline::Dashboard::metadata_time_estimate $metadata_traj 101]
assert_equal [format "%.3f" [dict get $timing step_ps]] 1.000 "metadata timestep/frequency should estimate per-frame ps"
file delete -force $metadata_dir

set ::RMSXFlipbookTimeline::Dashboard::native_total_frames 317
set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end -1
set ::RMSXFlipbookTimeline::Dashboard::native_total_time_ns auto
set ::RMSXFlipbookTimeline::Dashboard::native_detected_time_step_ps 0.04888821
set ::RMSXFlipbookTimeline::Dashboard::native_time_step 0.049
assert_equal [format "%.8f" [::RMSXFlipbookTimeline::Dashboard::effective_time_step_ps_for_run]] 0.04888821 "rounded displayed step should preserve exact detected step for analysis"

set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end -1
set ::RMSXFlipbookTimeline::Dashboard::native_total_frames 1003
set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slices
set ::RMSXFlipbookTimeline::Dashboard::native_slices 8
set plan [::RMSXFlipbookTimeline::Dashboard::slicing_plan]
assert_equal [dict get $plan known] 1 "slice preview known for explicit total"
assert_equal [dict get $plan slices] 8 "slice-count mode slices"
assert_equal [dict get $plan slice_size] 125 "slice-count mode frames per slice"
assert_equal [dict get $plan leftover] 3 "slice-count mode leftover"

set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slice_size
set ::RMSXFlipbookTimeline::Dashboard::native_slice_size 120
set plan [::RMSXFlipbookTimeline::Dashboard::slicing_plan]
assert_equal [dict get $plan slices] 8 "slice-size mode slices"
assert_equal [dict get $plan used] 960 "slice-size mode used frames"
assert_equal [dict get $plan leftover] 43 "slice-size mode leftover"


# Native command routing, cancellation callback and immutable result path.
set ::calls {}
foreach {command kind} {
    run_native_analysis rmsx_single run_native_all_chain_analysis rmsx_all
    run_native_shift_map shift_single run_native_all_chain_shift_map shift_all
    run_native_lddt_map lddt_single run_native_all_chain_lddt_map lddt_all
} {
    rename ::RMSXFlipbookTimeline::$command ::RMSXFlipbookTimeline::${command}_real
    proc ::RMSXFlipbookTimeline::$command {topology trajectory output args} [format {
        file mkdir $output
        lappend ::calls [dict create kind %s output $output args $args]
        return [dict create output_dir $output csv [file join $output data.csv] slice_count 2 total_frame_count 1003]
    } $kind]
}
rename ::RMSXFlipbookTimeline::load_folder ::RMSXFlipbookTimeline::load_folder_real
proc ::RMSXFlipbookTimeline::load_folder {folder args} {
    ::RMSXFlipbookTimeline::state_set molids {}
    return [::RMSXFlipbookTimeline::Results::publish [dict create kind flipbook folder $folder metric RMSX]]
}
rename ::RMSXFlipbookTimeline::Dashboard::render_native_heatmap ::RMSXFlipbookTimeline::Dashboard::render_native_heatmap_real
proc ::RMSXFlipbookTimeline::Dashboard::render_native_heatmap {args} { return [dict create drawn 0] }
set parent [file join $workspace_root outputs dashboard-routing]
file mkdir $parent
set ::RMSXFlipbookTimeline::Dashboard::native_topology [file join $workspace_root fixtures upstream test_files 1UBQ.pdb]
set ::RMSXFlipbookTimeline::Dashboard::native_trajectory [file join $workspace_root fixtures upstream test_files mon_sys.dcd]
set ::RMSXFlipbookTimeline::Dashboard::native_output $parent
set ::RMSXFlipbookTimeline::Dashboard::native_slices 2
set ::RMSXFlipbookTimeline::Dashboard::native_slice_size 20
set ::RMSXFlipbookTimeline::Dashboard::native_end 39
set previous ""
foreach {metric prefix} {RMSX rmsx Shift-Map shift 1-lDDT lddt} {
    foreach {chain suffix} {7 single all all} {
        set ::RMSXFlipbookTimeline::Dashboard::native_metric $metric
        set ::RMSXFlipbookTimeline::Dashboard::native_chain $chain
        set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slices
        ::RMSXFlipbookTimeline::Dashboard::run_native_metric
        set call [lindex $::calls end]
        assert_equal [dict get $call kind] ${prefix}_${suffix} "metric/chain dispatch"
        assert_equal [option_value [dict get $call args] -num_slices] 2 "slice count argument"
        assert_equal [option_value [dict get $call args] -overwrite] 0 "dashboard must never force overwrite"
        assert_equal [option_value [dict get $call args] -progress_callback] ::RMSXFlipbookTimeline::Operation::checkpoint "dashboard progress callback"
        assert_equal [file dirname [dict get $call output]] [file normalize $parent] "new output must be under selected parent"
        if {[dict get $call output] eq $previous} { smoke_fail "repeated run reused output" }
        set previous [dict get $call output]
        assert_equal [::RMSXFlipbookTimeline::Dashboard::current_native_folder] $previous "current result path"
        assert_equal $::RMSXFlipbookTimeline::Dashboard::native_output $parent "output parent should remain unchanged"
    }
}
set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slice_size
::RMSXFlipbookTimeline::Dashboard::run_native_metric
set args [dict get [lindex $::calls end] args]
assert_equal [option_value $args -slice_size] 20 "slice-size argument"
assert_equal [option_value $args -num_slices] "" "slice-size mode must not send slice count"
# Human labels map back to stable calculation keys.
foreach {label key} {SS secondary_structure H-bonds hbonds {Salt bridges} salt_bridges {Native contacts} native_contacts Contacts inter_selection_contacts Δphi delta_phi 1-lDDT lddt} {
    assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_key $label] $key "display alias"
}
# Explicit loaded molecule wins even if file setup contains another trajectory.
proc molinfo {target args} {
    if {$target eq "list"} { return {5 8} }
    if {$target eq "top"} { return 8 }
    error "Unexpected molinfo $target $args"
}
set ::RMSXFlipbookTimeline::Dashboard::timeline_molid {5: source.pdb}
assert_equal [::RMSXFlipbookTimeline::Dashboard::dashboard_molid] 5 "Timeline source must use chosen molecule"
set ::RMSXFlipbookTimeline::Dashboard::timeline_molid top
assert_equal [::RMSXFlipbookTimeline::Dashboard::dashboard_molid] 8 "Top must resolve explicitly"
set ::RMSXFlipbookTimeline::Dashboard::timeline_molid 99
if {![catch {::RMSXFlipbookTimeline::Dashboard::dashboard_molid}]} { smoke_fail "missing molecule must be rejected" }
puts "RMSX Flipbook Timeline dashboard command smoke passed"
quit
