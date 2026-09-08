################################################################################
# RMSX Flipbook Timeline stale-output regression smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline stale-output smoke failed: $message"
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
}

if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.2]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

set topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ.pdb]
set trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files mon_sys.dcd]
set output_dir [file join $workspace_root outputs native-rmsx-stale-output chain_7_rmsx]
file mkdir $output_dir

set stale10 [file join $output_dir slice_10_first_frame.pdb]
set stale13 [file join $output_dir slice_13_first_frame.pdb]
file copy -force $topology $stale10
file copy -force $topology $stale13

if {[catch {
    ::RMSXFlipbookTimeline::run_native_analysis \
        $topology \
        $trajectory \
        $output_dir \
        -chain 7 \
        -num_slices 9 \
        -start_frame 0 \
        -end_frame 314 \
        -overwrite 1 \
        -cleanup 1 \
        -verbose 0
} result]} {
    smoke_fail "run_native_analysis failed: $result"
}

if {[file exists $stale10] || [file exists $stale13]} {
    smoke_fail "stale slice files were not removed before native analysis"
}

set slice_files [::RMSXFlipbookTimeline::Loader::discover_slice_files $output_dir]
if {[llength $slice_files] != 9} {
    smoke_fail "expected 9 slice files after cleanup, found [llength $slice_files]: $slice_files"
}

if {[dict get $result deleted_previous_slices] < 2} {
    smoke_fail "expected at least 2 deleted previous slices, got [dict get $result deleted_previous_slices]"
}

if {[catch {::RMSXFlipbookTimeline::load_folder $output_dir palette viridis write_manifest 1} load_result]} {
    smoke_fail "load_folder failed after native analysis: $load_result"
}

if {[dict get $load_result files] != 9 || [dict get $load_result molecules] != 9} {
    smoke_fail "expected loader to display 9 molecules, got files=[dict get $load_result files] molecules=[dict get $load_result molecules]"
}

puts "RMSX Flipbook Timeline stale-output smoke passed"
puts "Output: $output_dir"
puts "Deleted previous slices: [dict get $result deleted_previous_slices]"
puts "Loaded molecules: [dict get $load_result molecules]"

quit
