################################################################################
# RMSX Flipbook Timeline VMD-native all-chain smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native all-chain smoke failed: $message"
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

proc count_masked_rows {mask_path} {
    set rows [read_csv_rows $mask_path]
    set count 0
    foreach row [lrange $rows 1 end] {
        if {[string tolower [lindex $row 2]] eq "true"} {
            incr count
        }
    }
    return $count
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

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

# Curated bytes are verified by run_tests.py before this process starts.
# Regenerate only with scripts/generate_native_test_fixtures.tcl.
set fixture_dir [file join $workspace_root fixtures generated]
set topology [file join $fixture_dir two_chain_1ubq.pdb]
set trajectory [file join $fixture_dir two_chain_1ubq.dcd]
foreach input [list $topology $trajectory] {
    if {![file isfile $input]} { smoke_fail "Required curated fixture is missing: $input" }
}

set output_base [file join $workspace_root outputs native-rmsx-all-chain]
if {[catch {
    ::RMSXFlipbookTimeline::run_native_all_chain_analysis \
        $topology \
        $trajectory \
        $output_base \
        -selection all \
        -analysis_selection "name CA" \
        -num_slices 3 \
        -start_frame 0 \
        -end_frame 8 \
        -overwrite 1 \
        -cleanup 1 \
        -log_transform 1 \
        -mask_selection "resid 1:2" \
        -verbose 0
} result]} {
    smoke_fail "run_native_all_chain_analysis failed: $result"
}

set chains [dict get $result chains]
if {$chains ne {A B}} {
    smoke_fail "Expected chains A B, got $chains"
}
if {[dict get $result combined_slice_count] != 3} {
    smoke_fail "Expected 3 combined slice files, got [dict get $result combined_slice_count]"
}

set combined_dir [dict get $result output_dir]
if {![file isdirectory $combined_dir]} {
    smoke_fail "Combined output directory missing: $combined_dir"
}
foreach slice {1 2 3} {
    set path [file join $combined_dir "slice_${slice}_first_frame.pdb"]
    if {![file exists $path]} {
        smoke_fail "Combined slice missing: $path"
    }
}

foreach chain {A B} {
    set chain_dir [file join $output_base "chain_${chain}_rmsx"]
    foreach name {rmsx_vmd_native.csv rmsd.csv rmsf.csv rmsx_summary.csv masked_residues.csv slice_1_first_frame.pdb slice_2_first_frame.pdb slice_3_first_frame.pdb} {
        set path [file join $chain_dir $name]
        if {![file exists $path]} {
            smoke_fail "Missing chain $chain output: $path"
        }
    }
    set rows [read_csv_rows [file join $chain_dir rmsx_vmd_native.csv]]
    if {[llength $rows] != 77} {
        smoke_fail "Expected 76 residue rows plus header for chain $chain, got [llength $rows]"
    }
    if {[lindex [lindex $rows 0] 2] ne "slice_1_log.dcd"} {
        smoke_fail "Expected log-transformed slice columns for chain $chain"
    }
    if {[count_masked_rows [file join $chain_dir masked_residues.csv]] != 2} {
        smoke_fail "Expected 2 masked residues for chain $chain"
    }
}

set combined_mask [dict get $result combined_mask_file]
if {$combined_mask eq "" || ![file exists $combined_mask]} {
    smoke_fail "Combined mask metadata was not written"
}
if {[llength [read_csv_rows $combined_mask]] != 153} {
    smoke_fail "Expected combined mask metadata header plus 152 rows"
}
if {[count_masked_rows $combined_mask] != 4} {
    smoke_fail "Expected 4 masked residues in combined metadata"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $combined_dir \
        rep Lines \
        quality Fast \
        write_manifest 0 \
        spacing auto \
        apply_mask 1 \
        view_preset current
} load_result]} {
    smoke_fail "load_folder failed for native all-chain combined output: $load_result"
}
if {[dict get $load_result files] != 3} {
    smoke_fail "Expected loader to find 3 combined slices, got [dict get $load_result files]"
}
if {[dict get $load_result masked_residues] != 4} {
    smoke_fail "Expected loader to apply 4 masked residues, got [dict get $load_result masked_residues]"
}

puts "RMSX Flipbook Timeline native all-chain smoke passed"
exit 0
