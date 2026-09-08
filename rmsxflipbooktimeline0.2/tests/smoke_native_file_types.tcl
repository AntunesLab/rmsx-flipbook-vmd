################################################################################
# RMSX Flipbook Timeline native file type autodetect/override smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native file type smoke failed: $message"
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

set source_topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ.pdb]
set source_trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files mon_sys.dcd]
set fixture_dir [file join $workspace_root outputs native-file-type-smoke-fixtures]
set output_dir [file join $workspace_root outputs native-file-type-smoke chain_7_rmsx]
file mkdir $fixture_dir
set topology [file join $fixture_dir 1UBQ.rmsxtop]
set trajectory [file join $fixture_dir mon_sys.rmsxtraj]
file copy -force $source_topology $topology
file copy -force $source_trajectory $trajectory

if {[catch {
    ::RMSXFlipbookTimeline::run_native_analysis \
        $topology \
        $trajectory \
        $output_dir \
        -chain 7 \
        -topology_type pdb \
        -trajectory_type dcd \
        -frame_offset auto \
        -num_slices 3 \
        -start_frame 0 \
        -end_frame 314 \
        -overwrite 1 \
        -cleanup 1 \
        -rmsd_time_step 0.04888821 \
        -verbose 0
} result]} {
    smoke_fail "run_native_analysis with explicit file types failed: $result"
}

if {[dict get $result topology_type] ne "pdb"} {
    smoke_fail "Expected resolved topology_type pdb, got [dict get $result topology_type]"
}
if {[dict get $result trajectory_type] ne "dcd"} {
    smoke_fail "Expected resolved trajectory_type dcd, got [dict get $result trajectory_type]"
}
if {[dict get $result frame_offset] != 1} {
    smoke_fail "Expected auto frame_offset 1 for PDB+DCD, got [dict get $result frame_offset]"
}
if {[dict get $result initial_frame_count] != 1} {
    smoke_fail "Expected initial_frame_count 1 for PDB topology, got [dict get $result initial_frame_count]"
}
if {[dict get $result slice_count] != 3} {
    smoke_fail "Expected 3 slices, got [dict get $result slice_count]"
}
if {![file exists [dict get $result csv]]} {
    smoke_fail "Expected native CSV was not written: [dict get $result csv]"
}
if {![file exists [file join $output_dir slice_3_first_frame.pdb]]} {
    smoke_fail "Expected third slice PDB was not written"
}

puts "RMSX Flipbook Timeline native file type smoke passed"
puts "Topology type: [dict get $result topology_type]"
puts "Trajectory type: [dict get $result trajectory_type]"
puts "Frame offset: [dict get $result frame_offset]"
puts "CSV: [dict get $result csv]"
quit
