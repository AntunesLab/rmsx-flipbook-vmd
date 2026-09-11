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

# Ordinary figure exports retain editable, separate slice and frame/time lines
# so nine long frame ranges do not run into their neighboring annotations.
set png [file join $output_dir figure-pixel.png]
set png_bytes [binary decode base64 {iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6nAAAAABJRU5ErkJggg==}]
set fp [open $png wb]; puts -nonewline $fp $png_bytes; close $fp
set columns {}
for {set i 0} {$i < 9} {incr i} {
    lappend columns [dict create frame_start [expr {$i*35}] frame_end [expr {($i+1)*35-1}]]
}
set figure_result [dict create label {Nine slices & frames} metric RMSX units Å dataset [dict create columns $columns]]
set image_result [dict create width 2400 height 208 molecules 9]
set figure [file join $output_dir nine-frame-figure.svg]
::RMSXFlipbookTimeline::Render::figure_svg $image_result $figure_result $png $figure
set fp [open $figure r]; fconfigure $fp -encoding utf-8; set svg [read $fp]; close $fp
foreach i {0 1 2 3 4 5 6 7 8} {
    set slice "Slice [expr {$i+1}]"
    set frames "frames [expr {$i*35}]–[expr {($i+1)*35-1}]"
    set label_pattern [format {<text[^>]* y="([0-9]+)"[^>]*>%s</text>} $slice]
    set frame_pattern [format {<text[^>]* y="([0-9]+)"[^>]*>%s</text>} $frames]
    if {![regexp $label_pattern $svg unused label_y] || ![regexp $frame_pattern $svg unused frame_y] || $frame_y != $label_y+16} {
        smoke_fail "Expected separate editable slice/frame lines for $slice"
    }
}
if {[string first [::RMSXFlipbookTimeline::Render::xml $figure_result] $svg] < 0 || [string first [binary encode base64 -maxlen 0 $png_bytes] $svg] < 0} {
    smoke_fail "Figure annotation layout changed scientific metadata or embedded PNG"
}
dict set figure_result dataset columns [list [dict create time 1.25 time_unit ns frame_start 0 frame_end 34]]
::RMSXFlipbookTimeline::Render::figure_svg [dict replace $image_result molecules 1] $figure_result $png $figure
if {![file_contains $figure {>1.25 ns</text>}] || [file_contains $figure {>frames 0–34</text>}]} {
    smoke_fail "Known physical time lost precedence over frame labels"
}

puts "RMSX Flipbook Timeline native report SVG smoke passed"
puts "SVG: [dict get $result svg]"
puts "CSV: [dict get $result csv]"
puts "Residues: [dict get $result residue_count]"
puts "Slices: [dict get $result slice_count]"
puts "Range: [dict get $result min]..[dict get $result max]"
exit 0
