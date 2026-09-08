################################################################################
# RMSX Flipbook Timeline native SVG heatmap smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline heatmap SVG smoke failed: $message"
    exit 1
}

proc read_file {path} {
    set fp [open $path r]
    try {
        return [read $fp]
    } finally {
        catch {close $fp}
    }
}

proc write_file {path payload} {
    set fp [open $path w]
    try {
        puts -nonewline $fp $payload
    } finally {
        catch {close $fp}
    }
}

proc write_no_chain_matrix {source_csv output_csv} {
    set source_text [read_file $source_csv]
    set no_chain_lines {}
    foreach line [split [string trim $source_text] "\n"] {
        set fields [split $line ","]
        set trimmed_fields [list [lindex $fields 0]]
        foreach value [lrange $fields 2 end] {
            lappend trimmed_fields $value
        }
        lappend no_chain_lines [join $trimmed_fields ","]
    }
    write_file $output_csv [join $no_chain_lines "\n"]
    return ""
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

set source_csv [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files example1 chain_7_rmsx rmsx_mon_sys_0.015_ns.csv]
if {![file exists $source_csv]} {
    smoke_fail "Reference RMSX CSV missing: $source_csv"
}

set output_dir [file join $workspace_root outputs native-rmsx-heatmap]
file mkdir $output_dir
foreach path [glob -nocomplain -directory $output_dir "*.csv"] {
    file delete $path
}
foreach path [glob -nocomplain -directory $output_dir "*.svg"] {
    file delete $path
}
file copy -force $source_csv [file join $output_dir rmsx_vmd_native.csv]

write_file [file join $output_dir rmsx_aaa_bad.csv] "Group,Rank,ResidueID,ChainID,TimeSlice,RMSX\nTop,1,42,7,slice_4.dcd,9.616\n"

set summary_path [file join $output_dir rmsx_summary.csv]
write_file $summary_path "Group,Rank,ResidueID,ChainID,TimeSlice,RMSX\nTop,1,42,7,slice_4.dcd,9.616\n"

if {[catch {
    ::RMSXFlipbookTimeline::write_heatmap_svg \
        $output_dir \
        -title "RMSX Heatmap Smoke" \
        -palette inferno \
        -custom_fill_label "Custom Motion" \
        -interpolate 1 \
        -output_name smoke_heatmap.svg
} result]} {
    smoke_fail "write_heatmap_svg failed: $result"
}

set svg_path [dict get $result svg]
if {![file exists $svg_path]} {
    smoke_fail "SVG heatmap was not written: $svg_path"
}
if {[dict get $result residue_count] != 76} {
    smoke_fail "Expected 76 heatmap residues, got [dict get $result residue_count]"
}
if {[dict get $result slice_count] != 9} {
    smoke_fail "Expected 9 heatmap slices, got [dict get $result slice_count]"
}
if {[dict get $result max] <= [dict get $result min]} {
    smoke_fail "Expected informative heatmap value range"
}
if {[dict get $result palette] ne "inferno"} {
    smoke_fail "Expected inferno heatmap palette, got [dict get $result palette]"
}
if {[dict get $result fill_label] ne "Custom Motion"} {
    smoke_fail "Expected custom heatmap fill label, got [dict get $result fill_label]"
}
if {![dict get $result interpolate]} {
    smoke_fail "Expected heatmap interpolate flag in result"
}

if {[catch {
    set svg [read_file $svg_path]
} err]} {
    smoke_fail "Could not read SVG heatmap: $err"
}
foreach needle {"<svg" "<rect" "RMSX Heatmap Smoke" "rmsx_vmd_native.csv" "Custom Motion" "interpolate=true" "shape-rendering=\"auto\"" "#000004"} {
    if {[string first $needle $svg] < 0} {
        smoke_fail "SVG did not contain expected text: $needle"
    }
}

if {[file tail [dict get $result csv]] ne "rmsx_vmd_native.csv"} {
    smoke_fail "Expected heatmap to ignore rmsx_summary.csv and use rmsx_vmd_native.csv, got [dict get $result csv]"
}

set no_chain_csv [file join $output_dir legacy_no_chain.csv]
write_no_chain_matrix $source_csv $no_chain_csv

if {[catch {
    ::RMSXFlipbookTimeline::write_heatmap_svg \
        $output_dir \
        -csv $no_chain_csv \
        -title "RMSX Heatmap No Chain Smoke" \
        -output_name smoke_no_chain_heatmap.svg
} no_chain_result]} {
    smoke_fail "write_heatmap_svg failed for no-ChainID matrix: $no_chain_result"
}
if {[dict get $no_chain_result residue_count] != 76 || [dict get $no_chain_result slice_count] != 9} {
    smoke_fail "Unexpected no-ChainID heatmap dimensions: $no_chain_result"
}

puts "RMSX Flipbook Timeline heatmap SVG smoke passed"
puts "SVG: $svg_path"
puts "CSV: [dict get $result csv]"
puts "Residues: [dict get $result residue_count]"
puts "Slices: [dict get $result slice_count]"
puts "Range: [dict get $result min]..[dict get $result max]"
exit 0
