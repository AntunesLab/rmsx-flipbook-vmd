################################################################################
# RMSX Flipbook Timeline VMD-native real multi-chain smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native real multi-chain smoke failed: $message"
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

proc file_contains {path needle} {
    set fp [open $path r]
    try {
        set text [read $fp]
        return [expr {[string first $needle $text] >= 0}]
    } finally {
        catch {close $fp}
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

set topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files protease_backbone.pdb]
set trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files short_protease_backbone.dcd]
if {![file exists $topology] || ![file exists $trajectory]} {
    smoke_fail "Packaged protease multi-chain fixture is missing"
}

set output_base [file join $workspace_root outputs native-rmsx-real-multichain-protease]
file mkdir $output_base

set guard_output [file normalize [file join "/tmp" "rmsxflipbooktimeline_multichain_slice_guard_[pid]"]]
catch {file delete -force $guard_output}
if {[catch {
    ::RMSXFlipbookTimeline::run_native_all_chain_analysis \
        $topology \
        $trajectory \
        $guard_output \
        -num_slices 5 \
        -start_frame 0 \
        -end_frame 8 \
        -overwrite 1 \
        -cleanup 1 \
        -mask_selection "resid 25:26" \
        -verbose 0
} guard_err]} {
    if {[string first "RMSX requires at least 2 frames per slice" $guard_err] < 0} {
        smoke_fail "Unexpected RMSX slice-size guard message: $guard_err"
    }
} else {
    smoke_fail "Expected 5 RMSX slices across 9 frames to be rejected"
}
catch {file delete -force $guard_output}

if {[catch {
    ::RMSXFlipbookTimeline::run_native_all_chain_analysis \
        $topology \
        $trajectory \
        $output_base \
        -num_slices 3 \
        -start_frame 0 \
        -end_frame 8 \
        -overwrite 1 \
        -cleanup 1 \
        -mask_selection "resid 25:26" \
        -verbose 0
} result]} {
    smoke_fail "run_native_all_chain_analysis failed: $result"
}

set chains [dict get $result chains]
if {$chains ne {A B}} {
    smoke_fail "Expected real protease chains A B, got $chains"
}
if {[dict get $result combined_slice_count] != 3} {
    smoke_fail "Expected 3 combined slices, got [dict get $result combined_slice_count]"
}

set combined_dir [dict get $result output_dir]
if {![file isdirectory $combined_dir]} {
    smoke_fail "Combined output directory missing: $combined_dir"
}
foreach slice {1 2 3} {
    set path [file join $combined_dir "slice_${slice}_first_frame.pdb"]
    if {![file exists $path]} {
        smoke_fail "Combined real multi-chain slice missing: $path"
    }
}

foreach chain $chains {
    set chain_dir [file join $output_base "chain_${chain}_rmsx"]
    foreach name {rmsx_vmd_native.csv rmsd.csv rmsf.csv rmsx_summary.csv masked_residues.csv slice_1_first_frame.pdb slice_2_first_frame.pdb slice_3_first_frame.pdb} {
        set path [file join $chain_dir $name]
        if {![file exists $path]} {
            smoke_fail "Missing real chain $chain output: $path"
        }
    }
    set rows [read_csv_rows [file join $chain_dir rmsx_vmd_native.csv]]
    if {[llength $rows] != 99} {
        smoke_fail "Expected 98 protein residues plus header for chain $chain, got [llength $rows]"
    }
    if {[count_masked_rows [file join $chain_dir masked_residues.csv]] != 2} {
        smoke_fail "Expected 2 masked residues for real chain $chain"
    }
}

set combined_mask [dict get $result combined_mask_file]
if {$combined_mask eq "" || ![file exists $combined_mask]} {
    smoke_fail "Combined mask metadata was not written"
}
if {[llength [read_csv_rows $combined_mask]] != 197} {
    smoke_fail "Expected combined mask metadata header plus 196 rows"
}
if {[count_masked_rows $combined_mask] != 4} {
    smoke_fail "Expected 4 masked residues in real combined metadata"
}

foreach name {rmsx_vmd_native.csv rmsd.csv rmsd_by_chain.csv rmsf.csv rmsx_summary.csv} {
    set path [file join $combined_dir $name]
    if {![file exists $path]} {
        smoke_fail "Missing real combined analysis sidecar: $path"
    }
}
if {[dict get $result csv] ne [file join $combined_dir rmsx_vmd_native.csv]} {
    smoke_fail "Expected combined result csv path to point at combined folder, got [dict get $result csv]"
}
if {[dict get $result combined_row_count] != 196} {
    smoke_fail "Expected 196 combined matrix rows, got [dict get $result combined_row_count]"
}
if {[llength [read_csv_rows [file join $combined_dir rmsx_vmd_native.csv]]] != 197} {
    smoke_fail "Expected combined matrix header plus 196 rows"
}
if {[llength [read_csv_rows [file join $combined_dir rmsf.csv]]] != 197} {
    smoke_fail "Expected combined RMSF header plus 196 rows"
}
if {[lindex [read_csv_rows [file join $combined_dir rmsf.csv]] 0] ne {ResidueID ChainID RMSF}} {
    smoke_fail "Expected combined RMSF to include ChainID"
}
if {[llength [read_csv_rows [file join $combined_dir rmsd.csv]]] != 10} {
    smoke_fail "Expected combined RMSD header plus 9 frame rows"
}
if {[llength [read_csv_rows [file join $combined_dir rmsd_by_chain.csv]]] != 19} {
    smoke_fail "Expected chain RMSD header plus 18 chain/frame rows"
}

if {[catch {
    ::RMSXFlipbookTimeline::write_report_svg \
        $combined_dir \
        -palette turbo \
        -output_name rmsx_report.svg
} report_result]} {
    smoke_fail "write_report_svg failed for real combined multi-chain output: $report_result"
}
if {![file exists [dict get $report_result svg]]} {
    smoke_fail "Real combined multi-chain report SVG was not written"
}
if {[dict get $report_result residue_count] != 196 || [dict get $report_result rmsf_points] != 196} {
    smoke_fail "Expected combined report to include 196 residues and RMSF points, got $report_result"
}
if {![dict get $report_result split_by_chain] || [dict get $report_result chain_panels] != 2} {
    smoke_fail "Expected combined report to split into 2 chain panels, got $report_result"
}
if {[dict get $report_result chains] ne {A B}} {
    smoke_fail "Expected combined report chain order A B, got [dict get $report_result chains]"
}
foreach needle {"RMSX Heatmap by Chain" "Chain A" "Chain B"} {
    if {![file_contains [dict get $report_result svg] $needle]} {
        smoke_fail "Combined multi-chain report SVG is missing expected content: $needle"
    }
}

if {[catch {
    ::RMSXFlipbookTimeline::show_plot_window \
        folder $combined_dir \
        palette turbo \
        draw 0 \
        pick 0
} plot_result]} {
    smoke_fail "show_plot_window failed for real combined multi-chain output: $plot_result"
}
if {![dict get $plot_result split_by_chain] || [dict get $plot_result chain_panels] != 2} {
    smoke_fail "Expected combined plot to split into 2 chain panels, got $plot_result"
}
if {[dict get $plot_result chains] ne {A B}} {
    smoke_fail "Expected combined plot chain order A B, got [dict get $plot_result chains]"
}
if {[dict get $plot_result summary_points] != 6} {
    smoke_fail "Expected combined plot to include per-chain slice summary points, got $plot_result"
}
if {[dict get $plot_result cells] != 588 || [dict get $plot_result rows] != 196} {
    smoke_fail "Expected combined plot to include 588 cells and 196 rows, got $plot_result"
}
if {[dict get $plot_result rmsf_points] != 196} {
    smoke_fail "Expected combined plot to include 196 RMSF points, got $plot_result"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $combined_dir \
        rep Lines \
        quality Fast \
        palette turbo \
        write_manifest 0 \
        spacing auto \
        apply_mask 1 \
        view_preset current
} load_result]} {
    smoke_fail "load_folder failed for real multi-chain combined output: $load_result"
}
if {[dict get $load_result files] != 3} {
    smoke_fail "Expected loader to find 3 real combined slices, got [dict get $load_result files]"
}
if {[dict get $load_result mapped_values] != 588} {
    smoke_fail "Expected loader to map 588 chain-aware B-factor residue values, got [dict get $load_result mapped_values]"
}
if {[dict get $load_result masked_residues] != 4} {
    smoke_fail "Expected loader to apply 4 real masked residues, got [dict get $load_result masked_residues]"
}

puts "RMSX Flipbook Timeline native real multi-chain smoke passed"
puts "Output: $combined_dir"
puts "Chains: $chains"
puts "Combined slices: [dict get $result combined_slice_count]"
exit 0
