################################################################################
# RMSX Flipbook Timeline native SVG report smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native report SVG smoke failed: $message"
    exit 1
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

set folder [file join $workspace_root fixtures upstream test_files example1 chain_7_rmsx]
set output_dir [file join $workspace_root outputs native-rmsx-report-smoke]
file mkdir $output_dir
set output_path [file join $output_dir rmsx_report.svg]

if {[catch {
    ::RMSXFlipbookTimeline::write_report_svg \
        $folder \
        -output_name $output_path \
        -title "Native RMSX Report Smoke" \
        -palette magma
} result]} {
    smoke_fail "write_report_svg failed: $result"
}

if {![file exists [dict get $result svg]]} {
    smoke_fail "report SVG was not written: [dict get $result svg]"
}
if {[dict get $result residue_count] != 76} {
    smoke_fail "expected 76 residues, got [dict get $result residue_count]"
}
if {[dict get $result slice_count] != 9} {
    smoke_fail "expected 9 slices, got [dict get $result slice_count]"
}
if {[dict get $result rmsd_points] <= 0 || [dict get $result rmsf_points] <= 0} {
    smoke_fail "expected RMSD and RMSF points in report result: $result"
}
if {[dict get $result palette] ne "magma"} {
    smoke_fail "expected magma report palette, got [dict get $result palette]"
}
if {[dict get $result layout] ne "window_check"} {
    smoke_fail "expected default window_check report layout, got [dict get $result layout]"
}
if {[dict get $result chain_panels] != 1 || [dict get $result split_by_chain]} {
    smoke_fail "expected single-chain report to use one chain panel, got $result"
}
if {![dict get $result window_check]} {
    smoke_fail "expected default report window_check flag"
}
if {[dict get $result residue_correlation_n] <= 0 || [dict get $result global_correlation_n] <= 0} {
    smoke_fail "expected window-check correlation sample counts in report result: $result"
}
foreach key {residue_correlation_r residue_correlation_r2 global_correlation_r global_correlation_r2} {
    set value [dict get $result $key]
    if {![string is double -strict $value]} {
        smoke_fail "expected numeric $key in report result: $result"
    }
}

foreach needle {"RMSD" "Mean RMSD Per Slice" "Mean RMSX Per Slice" "RMSX Heatmap" "RMSF" "Window Check" "R^2" "#000004" "<polyline" "<rect"} {
    if {![file_contains [dict get $result svg] $needle]} {
        smoke_fail "report SVG is missing expected content: $needle"
    }
}

set triple_output [file join $output_dir rmsx_report_triple.svg]
if {[catch {
    ::RMSXFlipbookTimeline::write_report_svg \
        $folder \
        -output_name $triple_output \
        -title "Native RMSX Triple Smoke" \
        -palette viridis \
        -triple 1 \
        -window_check 0 \
        -custom_fill_label "Custom Motion" \
        -interpolate 1
} triple_result]} {
    smoke_fail "write_report_svg failed for triple layout: $triple_result"
}
if {[dict get $triple_result layout] ne "triple"} {
    smoke_fail "expected triple report layout, got [dict get $triple_result layout]"
}
if {![dict get $triple_result triple] || [dict get $triple_result window_check]} {
    smoke_fail "unexpected triple/window flags in report result: $triple_result"
}
if {[dict get $triple_result fill_label] ne "Custom Motion"} {
    smoke_fail "expected custom report fill label, got [dict get $triple_result fill_label]"
}
foreach needle {"layout=triple" "interpolate=true" "Custom Motion" "shape-rendering=\"auto\"" "RMSD" "RMSF"} {
    if {![file_contains [dict get $triple_result svg] $needle]} {
        smoke_fail "triple report SVG is missing expected content: $needle"
    }
}
foreach unexpected {"Window Check" "Mean RMSD Per Slice" "Mean RMSX Per Slice"} {
    if {[file_contains [dict get $triple_result svg] $unexpected]} {
        smoke_fail "triple report SVG unexpectedly contains: $unexpected"
    }
}

puts "RMSX Flipbook Timeline native report SVG smoke passed"
puts "SVG: [dict get $result svg]"
puts "CSV: [dict get $result csv]"
puts "Residues: [dict get $result residue_count]"
puts "Slices: [dict get $result slice_count]"
puts "Range: [dict get $result min]..[dict get $result max]"
exit 0
