################################################################################
# RMSX Flipbook Timeline GUI native slice-size command smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline GUI native slice-size command smoke failed: $message"
    exit 1
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
    set workspace_root [file dirname $plugin_parent]
} else {
    set workspace_root [pwd]
    set plugin_parent [file normalize [file join $workspace_root workspace_plugins]]
    set plugin_dir [file join $plugin_parent rmsxflipbooktimeline0.2]
}

if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.2]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

if {[catch {source [file join $plugin_dir gui main_window.tcl]} err]} {
    smoke_fail "GUI source failed: $err"
}
if {[namespace which ::RMSXFlipbookTimeline::GUI::run_native_analysis] eq ""} {
    smoke_fail "GUI run_native_analysis command was not loaded"
}
if {$::RMSXFlipbookTimeline::GUI::native_end ne "-1"} {
    smoke_fail "Expected GUI native_end default -1, got $::RMSXFlipbookTimeline::GUI::native_end"
}

rename ::RMSXFlipbookTimeline::run_native_analysis ::RMSXFlipbookTimeline::run_native_analysis_real
rename ::RMSXFlipbookTimeline::run_native_all_chain_analysis ::RMSXFlipbookTimeline::run_native_all_chain_analysis_real
rename ::RMSXFlipbookTimeline::load_folder ::RMSXFlipbookTimeline::load_folder_real

set ::rmsxflipbooktimeline_gui_smoke_calls {}

proc ::RMSXFlipbookTimeline::run_native_analysis {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_gui_smoke_calls [dict create proc single args $args output_dir $output_dir]
    return [dict create output_dir $output_dir csv [file join $output_dir rmsx_vmd_native.csv] slice_count 3]
}

proc ::RMSXFlipbookTimeline::run_native_all_chain_analysis {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_gui_smoke_calls [dict create proc all args $args output_dir $output_dir]
    return [dict create output_dir [file join $output_dir combined] csv_paths {} chains {A B} combined_slice_count 3]
}

proc ::RMSXFlipbookTimeline::load_folder {folder args} {
    return [dict create files 3 molecules 3 raw_min 0.0 raw_max 1.0 spacing 1.0 spacing_mode auto]
}

proc run_gui_command_smoke {chain expected_proc} {
    global workspace_root

    set ::RMSXFlipbookTimeline::GUI::native_topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ.pdb]
    set ::RMSXFlipbookTimeline::GUI::native_trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files mon_sys.dcd]
    set ::RMSXFlipbookTimeline::GUI::native_output [file join $workspace_root outputs gui-native-slice-size-command-smoke]
    set ::RMSXFlipbookTimeline::GUI::native_chain $chain
    set ::RMSXFlipbookTimeline::GUI::native_slices 9
    set ::RMSXFlipbookTimeline::GUI::native_slice_size 105
    set ::RMSXFlipbookTimeline::GUI::native_start 0
    set ::RMSXFlipbookTimeline::GUI::native_end -1
    set ::RMSXFlipbookTimeline::GUI::native_time_step 0.04888821
    set ::RMSXFlipbookTimeline::GUI::timeline_metric RMSX
    set ::RMSXFlipbookTimeline::GUI::native_metric RMSX
    set ::RMSXFlipbookTimeline::GUI::native_analysis_type protein
    set ::RMSXFlipbookTimeline::GUI::native_log_transform 0
    set ::RMSXFlipbookTimeline::GUI::native_mask_selection ""

    set before [llength $::rmsxflipbooktimeline_gui_smoke_calls]
    if {[catch {::RMSXFlipbookTimeline::GUI::run_native_analysis} err]} {
        smoke_fail "GUI run_native_analysis errored for chain '$chain': $err"
    }
    if {[llength $::rmsxflipbooktimeline_gui_smoke_calls] != [expr {$before + 1}]} {
        smoke_fail "Expected one native command for chain '$chain'"
    }

    set call [lindex $::rmsxflipbooktimeline_gui_smoke_calls end]
    if {[dict get $call proc] ne $expected_proc} {
        smoke_fail "Expected $expected_proc command for chain '$chain', got [dict get $call proc]"
    }

    set args [dict get $call args]
    set slice_idx [lsearch -exact $args -slice_size]
    if {$slice_idx < 0 || [lindex $args [expr {$slice_idx + 1}]] != 105} {
        smoke_fail "Expected -slice_size 105 in GUI command args, got $args"
    }
    if {[lsearch -exact $args -num_slices] >= 0} {
        smoke_fail "GUI command should not include -num_slices when native_slice_size is set: $args"
    }
    set end_idx [lsearch -exact $args -end_frame]
    if {$end_idx < 0 || [lindex $args [expr {$end_idx + 1}]] != -1} {
        smoke_fail "Expected -end_frame -1 in GUI command args, got $args"
    }
}

run_gui_command_smoke 7 single
run_gui_command_smoke all all

puts "RMSX Flipbook Timeline GUI native slice-size command smoke passed"
quit
