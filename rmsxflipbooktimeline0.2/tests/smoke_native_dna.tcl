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
        return $rows
    } finally {
        catch {close $fp}
    }
}

proc write_dna_fixture_dcd {topology out_dcd {frames 10}} {
    mol new $topology type pdb waitfor all
    set molid [molinfo top get id]
    set all_sel [atomselect $molid "all"]
    set p_sel [atomselect $molid "nucleic and name P"]
    set backbone_sel [atomselect $molid "nucleic and backbone"]

    try {
        if {[$p_sel num] == 0} {
            smoke_fail "VMD did not recognize P atoms in the bundled DNA fixture"
        }
        if {[$backbone_sel num] == 0} {
            smoke_fail "VMD did not recognize nucleic backbone atoms in the bundled DNA fixture"
        }

        set base_coords [$all_sel get {x y z}]
        for {set frame 1} {$frame < $frames} {incr frame} {
            animate dup frame 0 $molid
        }

        for {set frame 0} {$frame < $frames} {incr frame} {
            $all_sel frame $frame
            set shifted {}
            set atom_index 0
            foreach xyz $base_coords {
                set phase [expr {double($frame) * 0.35 + double($atom_index) * 0.011}]
                set dx [expr {0.18 * sin($phase)}]
                set dy [expr {0.12 * cos($phase * 0.7)}]
                set dz [expr {0.08 * sin($phase * 1.3)}]
                lappend shifted [list \
                    [expr {[lindex $xyz 0] + $dx}] \
                    [expr {[lindex $xyz 1] + $dy}] \
                    [expr {[lindex $xyz 2] + $dz}]]
                incr atom_index
            }
            $all_sel set {x y z} $shifted
        }

        animate write dcd $out_dcd beg 0 end [expr {$frames - 1}] sel $all_sel waitfor all
    } finally {
        catch {$all_sel delete}
        catch {$p_sel delete}
        catch {$backbone_sel delete}
        catch {mol delete $molid}
    }

    if {![file exists $out_dcd]} {
        smoke_fail "Synthetic DNA DCD was not written: $out_dcd"
    }
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

set topology ""
if {[info exists ::env(RMSXFLIPBOOKTIMELINE_DNA_FIXTURE)] && $::env(RMSXFLIPBOOKTIMELINE_DNA_FIXTURE) ne ""} {
    set topology [file normalize $::env(RMSXFLIPBOOKTIMELINE_DNA_FIXTURE)]
}
if {![file exists $topology]} {
    puts "RMSX Flipbook Timeline DNA smoke skipped: set RMSXFLIPBOOKTIMELINE_DNA_FIXTURE to a bdna.pdb fixture."
    if {[info commands quit] ne ""} {
        quit
    }
    exit 0
}

set fixture_dir [file join $workspace_root outputs native-rmsx-dna-fixture]
file mkdir $fixture_dir
set trajectory [file join $fixture_dir bdna_synthetic.dcd]
write_dna_fixture_dcd $topology $trajectory 10

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
