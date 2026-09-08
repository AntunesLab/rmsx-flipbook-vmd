################################################################################
# RMSX Flipbook Timeline VMD-native analysis smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native analysis smoke failed: $message"
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

proc assert_csv_parity {actual_path reference_path tolerance} {
    set actual_rows [read_csv_rows $actual_path]
    set reference_rows [read_csv_rows $reference_path]

    if {[llength $actual_rows] != [llength $reference_rows]} {
        smoke_fail "CSV row count mismatch: actual [llength $actual_rows], reference [llength $reference_rows]"
    }

    set actual_header [lindex $actual_rows 0]
    set reference_header [lindex $reference_rows 0]
    if {$actual_header ne $reference_header} {
        smoke_fail "CSV header mismatch"
    }

    set max_diff 0.0
    set max_where ""
    for {set row 1} {$row < [llength $actual_rows]} {incr row} {
        set actual [lindex $actual_rows $row]
        set reference [lindex $reference_rows $row]
        if {[llength $actual] != [llength $reference]} {
            smoke_fail "CSV column count mismatch at row $row"
        }
        if {[lrange $actual 0 1] ne [lrange $reference 0 1]} {
            smoke_fail "CSV residue metadata mismatch at row $row"
        }
        for {set col 2} {$col < [llength $actual]} {incr col} {
            set diff [expr {abs(double([lindex $actual $col]) - double([lindex $reference $col]))}]
            if {$diff > $max_diff} {
                set max_diff $diff
                set max_where "row $row col $col"
            }
            if {$diff > $tolerance} {
                smoke_fail "CSV parity failed at row $row col $col: diff $diff > $tolerance"
            }
        }
    }

    return [dict create max_diff $max_diff max_where $max_where]
}

proc assert_numeric_csv_parity {actual_path reference_path tolerance {metadata_columns {}}} {
    set actual_rows [read_csv_rows $actual_path]
    set reference_rows [read_csv_rows $reference_path]

    if {[llength $actual_rows] != [llength $reference_rows]} {
        smoke_fail "CSV row count mismatch: actual [llength $actual_rows], reference [llength $reference_rows]"
    }

    set actual_header [lindex $actual_rows 0]
    set reference_header [lindex $reference_rows 0]
    if {$actual_header ne $reference_header} {
        smoke_fail "CSV header mismatch: $actual_header != $reference_header"
    }

    set max_diff 0.0
    set max_where ""
    for {set row 1} {$row < [llength $actual_rows]} {incr row} {
        set actual [lindex $actual_rows $row]
        set reference [lindex $reference_rows $row]
        if {[llength $actual] != [llength $reference]} {
            smoke_fail "CSV column count mismatch at row $row"
        }

        for {set col 0} {$col < [llength $actual]} {incr col} {
            if {[lsearch -exact $metadata_columns $col] >= 0} {
                if {[lindex $actual $col] ne [lindex $reference $col]} {
                    smoke_fail "CSV metadata mismatch at row $row col $col: [lindex $actual $col] != [lindex $reference $col]"
                }
                continue
            }

            set diff [expr {abs(double([lindex $actual $col]) - double([lindex $reference $col]))}]
            if {$diff > $max_diff} {
                set max_diff $diff
                set max_where "row $row col $col"
            }
            if {$diff > $tolerance} {
                smoke_fail "CSV numeric parity failed at row $row col $col: diff $diff > $tolerance"
            }
        }
    }

    return [dict create max_diff $max_diff max_where $max_where]
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
set reference_csv [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files example1 chain_7_rmsx rmsx_mon_sys_0.015_ns.csv]
set reference_rmsd_csv [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files example1 chain_7_rmsx rmsd.csv]
set reference_rmsf_csv [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files example1 chain_7_rmsx rmsf.csv]
set output_dir [file join $workspace_root outputs native-rmsx-1ubq-9 chain_7_rmsx]

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
        -rmsd_time_step 0.04888821 \
        -verbose 0
} result]} {
    smoke_fail "run_native_analysis failed: $result"
}

set csv_path [dict get $result csv]
if {![file exists $csv_path]} {
    smoke_fail "Native RMSX CSV was not written: $csv_path"
}

if {[catch {
    set fp [open $csv_path r]
    set header [gets $fp]
    set first_row [gets $fp]
    close $fp
} err]} {
    catch {close $fp}
    smoke_fail "Could not inspect native RMSX CSV: $err"
}

set header_fields [split $header ","]
set row_fields [split $first_row ","]

if {[llength $header_fields] != 11} {
    smoke_fail "Expected 11 CSV columns, got [llength $header_fields]"
}
if {[lindex $header_fields 0] ne "ResidueID" || [lindex $header_fields 1] ne "ChainID"} {
    smoke_fail "Unexpected native RMSX CSV header: $header"
}
if {[lindex $row_fields 1] ne "7"} {
    smoke_fail "Expected ChainID 7 in first data row, got [lindex $row_fields 1]"
}

set values {}
foreach field [lrange $row_fields 2 end] {
    lappend values [expr {double($field)}]
}
set min_value [lindex [lsort -real $values] 0]
set max_value [lindex [lsort -real $values] end]
if {$max_value <= $min_value} {
    smoke_fail "Native RMSX first residue values are flat: $min_value..$max_value"
}

set first_pdb [file join $output_dir slice_1_first_frame.pdb]
if {![file exists $first_pdb]} {
    smoke_fail "Native RMSX first slice PDB was not written: $first_pdb"
}

if {[catch {
    mol new $first_pdb type pdb waitfor all
    set molid [molinfo top get id]
    set sel [atomselect $molid "all"]
    set betas [$sel get beta]
    $sel delete
    mol delete $molid
} err]} {
    smoke_fail "Could not inspect native RMSX PDB B-factors: $err"
}

set beta_min [lindex [lsort -real $betas] 0]
set beta_max [lindex [lsort -real $betas] end]
if {$beta_max <= $beta_min} {
    smoke_fail "Native RMSX PDB B-factors are flat: $beta_min..$beta_max"
}

if {![file exists $reference_csv]} {
    smoke_fail "Reference RMSX CSV is missing: $reference_csv"
}
set parity [assert_csv_parity $csv_path $reference_csv 0.00001]

set rmsd_path [dict get $result rmsd_csv]
if {![file exists $rmsd_path]} {
    smoke_fail "Native RMSD CSV was not written: $rmsd_path"
}
if {![file exists $reference_rmsd_csv]} {
    smoke_fail "Reference RMSD CSV is missing: $reference_rmsd_csv"
}
set rmsd_parity [assert_numeric_csv_parity $rmsd_path $reference_rmsd_csv 0.0001]

set rmsf_path [dict get $result rmsf_csv]
if {![file exists $rmsf_path]} {
    smoke_fail "Native RMSF CSV was not written: $rmsf_path"
}
if {![file exists $reference_rmsf_csv]} {
    smoke_fail "Reference RMSF CSV is missing: $reference_rmsf_csv"
}
set rmsf_parity [assert_numeric_csv_parity $rmsf_path $reference_rmsf_csv 0.0001 {0}]

if {[dict get $result rmsd_frame_count] != 315} {
    smoke_fail "Expected 315 RMSD rows, got [dict get $result rmsd_frame_count]"
}
if {[dict get $result rmsf_residue_count] != 76} {
    smoke_fail "Expected 76 RMSF residue rows, got [dict get $result rmsf_residue_count]"
}
if {[dict get $result summary_top_count] != 3 || [dict get $result summary_bottom_count] != 3} {
    smoke_fail "Expected 3 top and 3 bottom summary rows, got top=[dict get $result summary_top_count] bottom=[dict get $result summary_bottom_count]"
}

set summary_path [dict get $result summary_csv]
if {![file exists $summary_path]} {
    smoke_fail "Native RMSX summary CSV was not written: $summary_path"
}
set summary_rows [read_csv_rows $summary_path]
if {[llength $summary_rows] != 7} {
    smoke_fail "Expected summary header plus 6 rows, got [llength $summary_rows]"
}
if {[lindex [lindex $summary_rows 0] 0] ne "Group" || [lindex [lindex $summary_rows 0] end] ne "RMSX"} {
    smoke_fail "Unexpected summary header: [lindex $summary_rows 0]"
}

set named_output_dir [file join $workspace_root outputs native-rmsx-name-style chain_7_rmsx]
if {[catch {
    ::RMSXFlipbookTimeline::run_native_analysis \
        $topology \
        $trajectory \
        $named_output_dir \
        -chain 7 \
        -analysis_type protein \
        -num_slices 3 \
        -start_frame 0 \
        -end_frame 8 \
        -overwrite 1 \
        -cleanup 1 \
        -name_style rmsx \
        -manual_length_ns 0.015 \
        -verbose 0
} named_result]} {
    smoke_fail "RMSX-style name run failed: $named_result"
}
set named_csv [dict get $named_result csv]
if {[file tail $named_csv] ne "rmsx_mon_sys_0.015_ns.csv"} {
    smoke_fail "Unexpected RMSX-style CSV name: [file tail $named_csv]"
}
if {![file exists $named_csv]} {
    smoke_fail "RMSX-style named CSV was not written: $named_csv"
}

puts "RMSX Flipbook Timeline native analysis smoke passed"
puts "CSV: $csv_path"
puts "RMSD CSV: $rmsd_path"
puts "RMSF CSV: $rmsf_path"
puts "Summary CSV: $summary_path"
puts "RMSX-style CSV: $named_csv"
puts "Residue count: [dict get $result residue_count]"
puts "Slice count: [dict get $result slice_count]"
puts "RMSD frame count: [dict get $result rmsd_frame_count]"
puts "RMSF residue count: [dict get $result rmsf_residue_count]"
puts "Summary counts: top=[dict get $result summary_top_count] bottom=[dict get $result summary_bottom_count]"
puts "First-row range: $min_value..$max_value"
puts "PDB beta range: $beta_min..$beta_max"
puts "Reference parity max diff: [dict get $parity max_diff] ([dict get $parity max_where])"
puts "RMSD parity max diff: [dict get $rmsd_parity max_diff] ([dict get $rmsd_parity max_where])"
puts "RMSF parity max diff: [dict get $rmsf_parity max_diff] ([dict get $rmsf_parity max_where])"

quit
