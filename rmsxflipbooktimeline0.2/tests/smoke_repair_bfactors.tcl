################################################################################
# RMSX Flipbook Timeline B-factor repair smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline B-factor repair smoke failed: $message"
    exit 1
}

proc beta_range {pdb_path} {
    mol new $pdb_path type pdb waitfor all
    set molid [molinfo top get id]
    set sel [atomselect $molid "all"]
    set betas [$sel get beta]
    $sel delete
    mol delete $molid
    return [list [lindex [lsort -real $betas] 0] [lindex [lsort -real $betas] end]]
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

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

set source_dir [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ_rmsx chain_7_rmsx]
set output_dir [file join $workspace_root outputs native-rmsx-repair chain_7_rmsx]
file mkdir $output_dir

foreach path [glob -nocomplain -directory $output_dir "slice_*_first_frame.pdb"] {
    file delete $path
}
foreach path [glob -nocomplain -directory $output_dir "*.csv"] {
    file delete $path
}

file copy -force [file join $source_dir rmsx_mon_sys_0.015_ns.csv] $output_dir
foreach slice {1 2 3} {
    file copy -force [file join $source_dir "slice_${slice}_first_frame.pdb"] $output_dir
}

set first_pdb [file join $output_dir slice_1_first_frame.pdb]
set before [beta_range $first_pdb]
if {[lindex $before 1] > [lindex $before 0]} {
    smoke_fail "Expected copied fixture B-factors to be flat before repair, got $before"
}

if {[catch {
    ::RMSXFlipbookTimeline::repair_folder_bfactors $output_dir
} result]} {
    smoke_fail "repair_folder_bfactors failed: $result"
}
if {[dict get $result updated_count] != 3} {
    smoke_fail "Expected 3 repaired slice PDBs, got [dict get $result updated_count]"
}

set after [beta_range $first_pdb]
if {[lindex $after 1] <= [lindex $after 0]} {
    smoke_fail "Expected repaired B-factors to be non-flat, got $after"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $output_dir \
        quality Fast \
        write_manifest 0
} load_result]} {
    smoke_fail "load_folder failed after repair: $load_result"
}
if {[dict get $load_result files] != 3} {
    smoke_fail "Expected loader to find 3 repaired slices, got [dict get $load_result files]"
}
if {[dict get $load_result value_source] ne "bfactor"} {
    smoke_fail "Expected repaired folder to use bfactor values, got [dict get $load_result value_source]"
}

puts "RMSX Flipbook Timeline B-factor repair smoke passed"
puts "Folder: $output_dir"
puts "CSV: [dict get $result csv]"
puts "Updated files: [dict get $result updated_count]"
puts "Before beta range: $before"
puts "After beta range: $after"
exit 0
