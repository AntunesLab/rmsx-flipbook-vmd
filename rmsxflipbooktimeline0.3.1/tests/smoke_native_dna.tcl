################################################################################
# RMSX Flipbook Timeline VMD-native DNA preset smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native DNA smoke failed: $message"
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

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

# Curated bytes are verified by run_tests.py before this process starts.
# Regenerate only with scripts/generate_native_test_fixtures.tcl.
set topology [file join $workspace_root fixtures dna bdna.pdb]
set trajectory [file join $workspace_root fixtures generated bdna_synthetic.dcd]
foreach input [list $topology $trajectory] {
    if {![file isfile $input]} { smoke_fail "Required curated fixture is missing: $input" }
}

set output_dir [file join $workspace_root outputs native-rmsx-dna chain_A_rmsx]
if {[catch {
    ::RMSXFlipbookTimeline::run_native_analysis \
        $topology \
        $trajectory \
        $output_dir \
        -chain A \
        -analysis_type dna \
        -num_slices 3 \
        -start_frame 0 \
        -end_frame 8 \
        -overwrite 1 \
        -cleanup 1 \
        -name_style rmsx \
        -manual_length_ns 0.001 \
        -verbose 0
} result]} {
    smoke_fail "run_native_analysis failed for DNA preset: $result"
}

if {[dict get $result residue_count] != 12} {
    smoke_fail "Expected 12 analyzed DNA residues for chain A, got [dict get $result residue_count]"
}
if {[dict get $result slice_count] != 3} {
    smoke_fail "Expected 3 DNA slices, got [dict get $result slice_count]"
}
if {[file tail [dict get $result csv]] ne "rmsx_bdna_synthetic_0.00100_ns.csv"} {
    smoke_fail "Unexpected DNA RMSX-style CSV name: [file tail [dict get $result csv]]"
}

set rows [read_csv_rows [dict get $result csv]]
if {[llength $rows] != 13} {
    smoke_fail "Expected DNA CSV header plus 12 rows, got [llength $rows]"
}
if {[lindex [lindex $rows 1] 1] ne "A"} {
    smoke_fail "Expected DNA ChainID A in first row"
}

set first_pdb [file join $output_dir slice_1_first_frame.pdb]
if {![file exists $first_pdb]} {
    smoke_fail "DNA slice PDB was not written: $first_pdb"
}

if {[catch {
    mol new $first_pdb type pdb waitfor all
    set molid [molinfo top get id]
    set sel [atomselect $molid "all"]
    set betas [$sel get beta]
    $sel delete
    mol delete $molid
} err]} {
    smoke_fail "Could not inspect DNA PDB B-factors: $err"
}
set beta_min [lindex [lsort -real $betas] 0]
set beta_max [lindex [lsort -real $betas] end]
if {$beta_max <= $beta_min} {
    smoke_fail "DNA PDB B-factors are flat: $beta_min..$beta_max"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $output_dir \
        rep Lines \
        quality Fast \
        write_manifest 0
} load_result]} {
    smoke_fail "load_folder failed for DNA output: $load_result"
}
if {[dict get $load_result files] != 3} {
    smoke_fail "Expected loader to find 3 DNA slices, got [dict get $load_result files]"
}

puts "RMSX Flipbook Timeline native DNA smoke passed"
puts "CSV: [dict get $result csv]"
puts "Residues: [dict get $result residue_count]"
puts "Slices: [dict get $result slice_count]"
puts "PDB beta range: $beta_min..$beta_max"
exit 0
