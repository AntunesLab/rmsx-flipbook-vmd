################################################################################
# RMSX Flipbook Timeline fixed slice-size native smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native slice-size smoke failed: $message"
    exit 1
}

proc read_csv_rows {path} {
    set fp [open $path r]
    try {
        set rows {}
        while {[gets $fp line] >= 0} {
            if {[string trim $line] eq ""} {
                continue
            }
            lappend rows [split $line ","]
        }
        return [::TestHarness::legacy_numeric_rows $rows]
    } finally {
        catch {close $fp}
    }
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
}

if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.3]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

set topology [file join $workspace_root fixtures upstream test_files 1UBQ.pdb]
set trajectory [file join $workspace_root fixtures upstream test_files mon_sys.dcd]
set output_dir [file join $workspace_root outputs native-rmsx-slice-size-smoke chain_7_rmsx]

if {[catch {
    ::RMSXFlipbookTimeline::run_native_analysis \
        $topology \
        $trajectory \
        $output_dir \
        -chain 7 \
        -slice_size 105 \
        -start_frame 0 \
        -end_frame 314 \
        -overwrite 1 \
        -cleanup 1 \
        -rmsd_time_step 0.04888821 \
        -verbose 0
} result]} {
    smoke_fail "run_native_analysis with -slice_size failed: $result"
}

if {[dict get $result slice_count] != 3} {
    smoke_fail "Expected 3 slices from -slice_size 105, got [dict get $result slice_count]"
}
if {[dict get [dict get $result plan] slice_size] != 105} {
    smoke_fail "Expected plan slice_size 105, got [dict get [dict get $result plan] slice_size]"
}
if {[dict get [dict get $result plan] adjusted_frames] != 315} {
    smoke_fail "Expected adjusted_frames 315, got [dict get [dict get $result plan] adjusted_frames]"
}

set rows [read_csv_rows [dict get $result csv]]
set header [lindex $rows 0]
if {[llength $header] != 5} {
    smoke_fail "Expected ResidueID, ChainID, and 3 slice columns, got $header"
}
if {[lindex $header 2] ne "slice_1.dcd" || [lindex $header end] ne "slice_3.dcd"} {
    smoke_fail "Unexpected fixed-size slice headers: $header"
}

foreach idx {1 2 3} {
    set pdb_path [file join $output_dir "slice_${idx}_first_frame.pdb"]
    if {![file exists $pdb_path]} {
        smoke_fail "Expected fixed-size slice PDB was not written: $pdb_path"
    }
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder $output_dir write_manifest 1
} load_result]} {
    smoke_fail "load_folder failed for fixed slice-size output: $load_result"
}
if {[dict get $load_result files] != 3} {
    smoke_fail "Expected loader to find 3 fixed-size slices, got [dict get $load_result files]"
}

puts "RMSX Flipbook Timeline native slice-size smoke passed"
puts "CSV: [dict get $result csv]"
puts "Slices: [dict get $result slice_count]"
puts "Slice size: [dict get [dict get $result plan] slice_size]"
quit
