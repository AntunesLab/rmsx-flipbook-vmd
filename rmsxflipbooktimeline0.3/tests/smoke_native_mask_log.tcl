################################################################################
# RMSX Flipbook Timeline VMD-native mask/log smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native mask/log smoke failed: $message"
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
set output_dir [file join $workspace_root outputs native-rmsx-mask-log chain_7_rmsx]

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
        -log_transform 1 \
        -mask_selection "resid 1:5; resid 48" \
        -time_known 1 -rmsd_time_step 0.04888821 \
        -verbose 0
} result]} {
    smoke_fail "run_native_analysis failed: $result"
}

if {![dict get $result log_transform]} {
    smoke_fail "native result did not report log_transform"
}
if {[dict get $result masked_residue_count] != 6} {
    smoke_fail "expected 6 masked residues, got [dict get $result masked_residue_count]"
}

set csv_path [dict get $result csv]
set rows [read_csv_rows $csv_path]
set header [lindex $rows 0]
if {[lindex $header 2] ne "slice_1_log.dcd" || [lindex $header end] ne "slice_9_log.dcd"} {
    smoke_fail "unexpected log-transform header: $header"
}

set mask_path [file join $output_dir masked_residues.csv]
if {![file exists $mask_path]} {
    smoke_fail "mask metadata was not written: $mask_path"
}

set mask_rows [read_csv_rows $mask_path]
set masked_count 0
set masked_indices {}
set unmasked_values {}
set masked_values {}
for {set i 1} {$i < [llength $mask_rows]} {incr i} {
    set mask_row [lindex $mask_rows $i]
    set is_masked [expr {[string tolower [lindex $mask_row 2]] eq "true"}]
    if {$is_masked} {
        incr masked_count
        lappend masked_indices [expr {$i - 1}]
    }

    set data_row [lindex $rows $i]
    foreach value [lrange $data_row 2 end] {
        if {$is_masked} {
            lappend masked_values [expr {double($value)}]
        } else {
            lappend unmasked_values [expr {double($value)}]
        }
    }
}

if {$masked_count != 6} {
    smoke_fail "expected 6 true rows in mask metadata, got $masked_count"
}
if {[llength $masked_values] == 0 || [llength $unmasked_values] == 0} {
    smoke_fail "mask/unmasked value sets were not populated"
}

set unmasked_min [lindex [lsort -real $unmasked_values] 0]
set unmasked_max [lindex [lsort -real $unmasked_values] end]
set masked_min [lindex [lsort -real $masked_values] 0]
set masked_max [lindex [lsort -real $masked_values] end]
if {$masked_min < $unmasked_min - 0.000001 || $masked_max > $unmasked_max + 0.000001} {
    smoke_fail "masked values were not clipped to unmasked range: masked=$masked_min..$masked_max unmasked=$unmasked_min..$unmasked_max"
}

set first_pdb [file join $output_dir slice_1_first_frame.pdb]
if {[catch {
    mol new $first_pdb type pdb waitfor all
    set molid [molinfo top get id]
    set sel [atomselect $molid "resid 1"]
    set betas [$sel get beta]
    $sel delete
    mol delete $molid
} err]} {
    smoke_fail "could not inspect first slice PDB: $err"
}
set beta_mean 0.0
foreach beta $betas {
    set beta_mean [expr {$beta_mean + double($beta)}]
}
set beta_mean [expr {$beta_mean / double([llength $betas])}]
set csv_resid1_slice1 [expr {double([lindex [lindex $rows 1] 2])}]
if {abs($beta_mean - $csv_resid1_slice1) > 0.02} {
    smoke_fail "PDB B-factor does not match log/masked CSV value: beta=$beta_mean csv=$csv_resid1_slice1"
}

if {[catch {::RMSXFlipbookTimeline::load_folder $output_dir palette viridis write_manifest 1 view_preset current} load_result]} {
    smoke_fail "load_folder failed: $load_result"
}
if {[dict get $load_result masked_residues] != 6} {
    smoke_fail "expected viewer to apply 6 masked residues, got [dict get $load_result masked_residues]"
}
set loaded_molecules [dict get $load_result molecules]
if {[dict get $load_result mask_marker_reps_added] != $loaded_molecules} {
    smoke_fail "expected one bright mask marker rep per molecule, got [dict get $load_result mask_marker_reps_added] for $loaded_molecules molecules"
}
if {[dict get $load_result mask_reps_added] != [expr {$loaded_molecules * 2}]} {
    smoke_fail "expected transparent and bright marker mask reps per molecule, got [dict get $load_result mask_reps_added] for $loaded_molecules molecules"
}

if {[catch {
    ::RMSXFlipbookTimeline::show_plot_window \
        folder $output_dir \
        palette viridis \
        draw 0 \
        pick 0
} plot_result]} {
    smoke_fail "show_plot_window failed for masked output: $plot_result"
}
if {[dict get $plot_result masked_rows] != 6} {
    smoke_fail "expected 6 masked rows in plot window, got $plot_result"
}
if {[dict get $plot_result masked_cells] != 54} {
    smoke_fail "expected 54 masked heatmap cells in plot window, got $plot_result"
}
if {[catch {
    ::RMSXFlipbookTimeline::select_plot_window_cell 0 0
} selected_masked]} {
    smoke_fail "select_plot_window_cell failed for masked cell: $selected_masked"
}
if {![dict exists $selected_masked masked] || ![dict get $selected_masked masked]} {
    smoke_fail "expected selected residue 1/slice 1 plot cell to be marked masked, got $selected_masked"
}
if {[catch {::RMSXFlipbookTimeline::clear_plot_window} clear_plot]} {
    smoke_fail "clear_plot_window failed after masked plot check: $clear_plot"
}

if {[catch {
    ::RMSXFlipbookTimeline::write_heatmap_svg \
        $output_dir \
        -output_name masked_heatmap.svg
} heatmap_svg_result]} {
    smoke_fail "write_heatmap_svg failed for masked output: $heatmap_svg_result"
}
set heatmap_svg_path [dict get $heatmap_svg_result svg]
set fp [open $heatmap_svg_path r]
set heatmap_svg_text [read $fp]
close $fp
if {[string first {Masked rows are dimmed and hatched.} $heatmap_svg_text] < 0} {
    smoke_fail "masked heatmap SVG does not describe the hatch overlay"
}
if {[string first {stroke="#111827"} $heatmap_svg_text] < 0} {
    smoke_fail "masked heatmap SVG does not contain dark hatch strokes"
}

if {[catch {::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $output_dir} timeline_dataset]} {
    smoke_fail "read_rmsx_folder failed for masked output: $timeline_dataset"
}
if {[::RMSXFlipbookTimeline::Matrix::masked_row_count $timeline_dataset] != 6} {
    smoke_fail "Timeline RMSX dataset did not preserve 6 masked rows"
}
set timeline_svg_path [file join $output_dir timeline_masked_heatmap.svg]
if {[catch {
    ::RMSXFlipbookTimeline::TimelinePlot::write_svg $timeline_dataset $timeline_svg_path
} timeline_svg_result]} {
    smoke_fail "Timeline write_svg failed for masked output: $timeline_svg_result"
}
set fp [open $timeline_svg_path r]
set timeline_svg_text [read $fp]
close $fp
if {[string first {stroke="#111827"} $timeline_svg_text] < 0} {
    smoke_fail "Timeline masked SVG does not contain dark hatch strokes"
}

set summary_path [dict get $result summary_csv]
if {![file exists $summary_path]} {
    smoke_fail "summary CSV was not written: $summary_path"
}
set summary_rows [read_csv_rows $summary_path]
if {[dict get $result summary_top_count] != 3 || [dict get $result summary_bottom_count] != 3} {
    smoke_fail "expected 3 top and 3 bottom summary rows, got top=[dict get $result summary_top_count] bottom=[dict get $result summary_bottom_count]"
}
for {set i 1} {$i < [llength $summary_rows]} {incr i} {
    set row [lindex $summary_rows $i]
    set resid [lindex $row 2]
    if {$resid in {1 2 3 4 5 48}} {
        smoke_fail "masked residue $resid appeared in summary row: $row"
    }
}

puts "RMSX Flipbook Timeline native mask/log smoke passed"
puts "CSV: $csv_path"
puts "Mask: $mask_path"
puts "Summary: $summary_path"
puts "Masked values: $masked_min..$masked_max"
puts "Unmasked values: $unmasked_min..$unmasked_max"
puts "Loaded molecules: [dict get $load_result molecules]"

quit
