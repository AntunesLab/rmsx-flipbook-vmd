################################################################################
# RMSX Flipbook Timeline VMD-native shift-map smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native shift-map smoke failed: $message"
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

proc beta_range {pdb_path} {
    set molid [mol new $pdb_path type pdb waitfor all]
    try {
        set sel [atomselect $molid "all"]
        try {
            set betas [$sel get beta]
            return [list [lindex [lsort -real $betas] 0] [lindex [lsort -real $betas] end]]
        } finally {
            catch {$sel delete}
        }
    } finally {
        catch {mol delete $molid}
    }
}

proc ca_distance_at_resid {topology trajectory resid frame_offset traj_frame} {
    set molid [mol new $topology type pdb waitfor all]
    try {
        mol addfile $trajectory type dcd waitfor all molid $molid
        set ref_frame $frame_offset
        set cur_frame [expr {$traj_frame + $frame_offset}]
        set ref [atomselect $molid "protein and name CA and resid $resid and (segid 7 or chain 7)" frame $ref_frame]
        set cur [atomselect $molid "protein and name CA and resid $resid and (segid 7 or chain 7)" frame $cur_frame]
        try {
            if {[$ref num] != 1 || [$cur num] != 1} {
                smoke_fail "Expected one CA atom for resid $resid, got [$ref num] reference and [$cur num] current"
            }
            set r [lindex [$ref get {x y z}] 0]
            set c [lindex [$cur get {x y z}] 0]
            set dx [expr {double([lindex $c 0]) - double([lindex $r 0])}]
            set dy [expr {double([lindex $c 1]) - double([lindex $r 1])}]
            set dz [expr {double([lindex $c 2]) - double([lindex $r 2])}]
            return [expr {sqrt(($dx * $dx) + ($dy * $dy) + ($dz * $dz))}]
        } finally {
            catch {$ref delete}
            catch {$cur delete}
        }
    } finally {
        catch {mol delete $molid}
    }
}

proc validate_shift_map_result {result topology trajectory output_dir} {
    if {[dict get $result residue_count] != 76} {
        smoke_fail "Expected 76 shift-map residues, got [dict get $result residue_count]"
    }
    if {[dict get $result slice_count] != 9} {
        smoke_fail "Expected 9 shift-map slices, got [dict get $result slice_count]"
    }
    if {[file tail [dict get $result csv]] ne "rmsx_mon_sys_0.015_ns.csv"} {
        smoke_fail "Unexpected shift-map CSV name: [file tail [dict get $result csv]]"
    }

    set rows [read_csv_rows [dict get $result csv]]
    if {[llength $rows] != 77} {
        smoke_fail "Expected CSV header plus 76 rows, got [llength $rows]"
    }
    set header [lindex $rows 0]
    if {[lindex $header 2] ne "slice_1.dcd" || [lindex $header end] ne "slice_9.dcd"} {
        smoke_fail "Unexpected shift-map CSV header: $header"
    }

    set first_row [lindex $rows 1]
    if {abs(double([lindex $first_row 2])) > 0.000001} {
        smoke_fail "Expected reference slice shift to be zero, got [lindex $first_row 2]"
    }

    set slice_size [dict get [dict get $result plan] slice_size]
    set expected_slice_2 [ca_distance_at_resid $topology $trajectory 1 1 $slice_size]
    set actual_slice_2 [expr {double([lindex $first_row 3])}]
    if {abs($actual_slice_2 - $expected_slice_2) > 0.00001} {
        smoke_fail "Shift-map slice 2 mismatch: expected $expected_slice_2, got $actual_slice_2"
    }

    set slice1_pdb [file join $output_dir slice_1_first_frame.pdb]
    set slice2_pdb [file join $output_dir slice_2_first_frame.pdb]
    if {![file exists $slice1_pdb] || ![file exists $slice2_pdb]} {
        smoke_fail "Expected shift-map slice PDBs were not written"
    }
    set b1 [beta_range $slice1_pdb]
    set b2 [beta_range $slice2_pdb]
    if {[lindex $b1 1] > 0.000001} {
        smoke_fail "Expected reference PDB B-factors to be zero, got $b1"
    }
    if {[lindex $b2 1] <= [lindex $b2 0]} {
        smoke_fail "Expected non-flat shift-map B-factors in slice 2, got $b2"
    }

    if {[catch {
        ::RMSXFlipbookTimeline::load_folder $output_dir write_manifest 1
    } load_result]} {
        smoke_fail "load_folder failed for shift-map output: $load_result"
    }
    if {[dict get $load_result files] != 9} {
        smoke_fail "Expected loader to find 9 shift-map slices, got [dict get $load_result files]"
    }

    if {[catch {
        ::RMSXFlipbookTimeline::write_heatmap_svg \
            $output_dir \
            -title "Native Shift Map Smoke" \
            -output_name shiftmap_heatmap.svg
    } heatmap_result]} {
        smoke_fail "write_heatmap_svg failed for shift-map output: $heatmap_result"
    }
    if {![file exists [dict get $heatmap_result svg]]} {
        smoke_fail "Shift-map heatmap SVG was not written"
    }

    return [dict create actual_slice_2 $actual_slice_2 heatmap [dict get $heatmap_result svg]]
}

proc validate_all_chain_shift_map {result} {
    if {[dict get $result metric] ne "shift_map"} {
        smoke_fail "Expected all-chain shift-map metric tag, got [dict get $result metric]"
    }
    if {[dict get $result chains] ne "7"} {
        smoke_fail "Expected all-chain shift-map to discover only chain 7, got [dict get $result chains]"
    }
    if {[llength [dict get $result csv_paths]] != 1} {
        smoke_fail "Expected one all-chain shift-map CSV, got [dict get $result csv_paths]"
    }
    if {[dict get $result combined_slice_count] != 3} {
        smoke_fail "Expected 3 all-chain shift-map slices, got [dict get $result combined_slice_count]"
    }
    if {![file isdirectory [dict get $result output_dir]]} {
        smoke_fail "All-chain shift-map output folder missing: [dict get $result output_dir]"
    }
    if {[catch {
        ::RMSXFlipbookTimeline::load_folder [dict get $result output_dir] write_manifest 1
    } load_result]} {
        smoke_fail "load_folder failed for all-chain shift-map output: $load_result"
    }
    if {[dict get $load_result files] != 3} {
        smoke_fail "Expected loader to find 3 all-chain shift-map slices, got [dict get $load_result files]"
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

set topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ.pdb]
set trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files mon_sys.dcd]
if {![file exists $topology] || ![file exists $trajectory]} {
    smoke_fail "Missing 1UBQ smoke inputs"
}

set output_dir [file join $workspace_root outputs native-shiftmap-1ubq-9 chain_7_shiftmap]
file mkdir [file dirname $output_dir]
set all_chain_output [file join $workspace_root outputs native-shiftmap-all-1ubq]

if {[catch {
    ::RMSXFlipbookTimeline::run_native_shift_map \
        $topology \
        $trajectory \
        $output_dir \
        -chain 7 \
        -num_slices 9 \
        -start_frame 0 \
        -end_frame 314 \
        -overwrite 1 \
        -cleanup 1 \
        -name_style rmsx \
        -manual_length_ns 0.015 \
        -rmsd_time_step 0.04888821 \
        -verbose 0
} result]} {
    smoke_fail "run_native_shift_map failed: $result"
}

if {[catch {
    set validation [validate_shift_map_result $result $topology $trajectory $output_dir]
} err]} {
    smoke_fail "Shift-map validation failed: $err"
}

if {[catch {
    ::RMSXFlipbookTimeline::run_native_all_chain_shift_map \
        $topology \
        $trajectory \
        $all_chain_output \
        -num_slices 3 \
        -start_frame 0 \
        -end_frame 104 \
        -overwrite 1 \
        -cleanup 1 \
        -verbose 0
} all_chain_result]} {
    smoke_fail "run_native_all_chain_shift_map failed: $all_chain_result"
}

if {[catch {
    validate_all_chain_shift_map $all_chain_result
} err]} {
    smoke_fail "All-chain shift-map validation failed: $err"
}

puts "RMSX Flipbook Timeline native shift-map smoke passed"
puts "CSV: [dict get $result csv]"
puts "Residues: [dict get $result residue_count]"
puts "Slices: [dict get $result slice_count]"
puts "Slice 2 resid 1 shift: [dict get $validation actual_slice_2]"
puts "Heatmap: [dict get $validation heatmap]"
puts "All-chain output: [dict get $all_chain_result output_dir]"
exit 0
