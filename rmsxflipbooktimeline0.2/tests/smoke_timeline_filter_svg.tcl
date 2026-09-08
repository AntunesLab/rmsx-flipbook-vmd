################################################################################
# RMSX Flipbook Timeline filter and SVG smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline filter/SVG smoke failed: $message"
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

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
} else {
    set plugin_parent [file normalize [file join [pwd] workspace_plugins]]
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

set rows [list \
    [dict create index 0 resid 1 resname GLY chain A label "A:1 GLY" selection "resid 1" row_mode residue] \
    [dict create index 1 resid 2 resname SER chain A label "A:2 SER" selection "resid 2" row_mode residue] \
    [dict create index 2 resid 3 resname TYR chain A label "A:3 TYR" selection "resid 3" row_mode residue]]
set columns [list \
    [dict create index 0 frame 0 label F0 target_type frame] \
    [dict create index 1 frame 1 label F1 target_type frame] \
    [dict create index 2 frame 2 label F2 target_type frame] \
    [dict create index 3 frame 3 label F3 target_type frame]]
set values [list \
    {0.1 2.0 5.0} \
    {0.2 2.5 6.0} \
    {0.3 7.0 7.5} \
    {4.0 8.0 9.0}]

set dataset [::RMSXFlipbookTimeline::Matrix::create \
    title "Filter SVG Smoke" \
    value_label displacement \
    unit A \
    source_type test \
    row_mode residue \
    column_mode frame \
    rows $rows \
    columns $columns \
    values $values]

set slice_dataset [::RMSXFlipbookTimeline::aggregate_timeline_to_slices \
    $dataset \
    slicing_mode slices \
    slices 2 \
    aggregation mean \
    representative last]
if {[dict get $slice_dataset column_count] != 2 || [dict get $slice_dataset column_mode] ne "slice"} {
    smoke_fail "continuous slice aggregation did not create two slice columns"
}
set first_slice_first_row [::RMSXFlipbookTimeline::Matrix::cell_value $slice_dataset 0 0]
if {abs($first_slice_first_row - 0.15) > 0.000001} {
    smoke_fail "continuous slice aggregation mean wrong: $first_slice_first_row"
}
set first_slice_column [lindex [dict get $slice_dataset columns] 0]
if {[dict get $first_slice_column target_type] ne "slice" || [dict get $first_slice_column representative_frame] != 1} {
    smoke_fail "slice aggregation did not preserve representative frame metadata: $first_slice_column"
}

set shown [::RMSXFlipbookTimeline::show_timeline_dataset \
    $dataset \
    draw 0 \
    pick 0 \
    threshold_min 0 \
    threshold_max 3 \
    scale_min -1.5 \
    scale_max 11.5]
if {[dict get $shown rows] != 3 || [dict get $shown columns] != 4 || [dict get $shown drawn] != 0} {
    smoke_fail "unexpected headless show result: $shown"
}
if {[dict get $shown min] != -1.5 || [dict get $shown max] != 11.5} {
    smoke_fail "headless show did not report overridden color scale: $shown"
}

set scrubbed [::RMSXFlipbookTimeline::select_timeline_slice 2]
if {[dict get $scrubbed kind] ne "column" || [dict get $scrubbed column] != 2} {
    smoke_fail "unexpected headless slice scrub result: $scrubbed"
}

set filtered_result [::RMSXFlipbookTimeline::filter_timeline_current 0 3 0 2 2 draw 0 pick 0]
set filtered [dict get $filtered_result dataset]
if {[dict get $filtered row_count] != 2} {
    smoke_fail "expected two filtered rows, got [dict get $filtered row_count]"
}
if {[dict get [lindex [dict get $filtered rows] 0] resid] ne "1"} {
    smoke_fail "expected residue 1 to remain after filtering"
}
if {[dict get [lindex [dict get $filtered rows] 1] resid] ne "2"} {
    smoke_fail "expected residue 2 to remain after filtering"
}

set tmp_dir [file normalize [file join /tmp rmsxflipbooktimeline-filter-smoke-[pid]]]
file delete -force $tmp_dir
file mkdir $tmp_dir
set svg_path [file join $tmp_dir timeline.svg]
::RMSXFlipbookTimeline::write_timeline_svg \
    $dataset \
    $svg_path \
    palette viridis \
    width 640 \
    threshold_min 0 \
    threshold_max 3 \
    scale_min -1.5 \
    scale_max 11.5

if {![file exists $svg_path]} {
    smoke_fail "SVG was not written: $svg_path"
}
set svg [read_file $svg_path]
foreach needle {"<svg" "<rect" "<line" "Filter SVG Smoke" "A:1 GLY" "F0" "displacement" "Threshold count (0 to 3)" "-1.5" "11.5"} {
    if {[string first $needle $svg] < 0} {
        smoke_fail "SVG missing expected text: $needle"
    }
}

set categorical_dataset [::RMSXFlipbookTimeline::Matrix::create \
    title "Secondary Structure Smoke" \
    value_label struct \
    value_kind categorical \
    categories [list \
        [dict create value H label "H alpha helix" color "#d95f02"] \
        [dict create value E label "E beta strand" color "#1b9e77"] \
        [dict create value C label "C coil" color "#f0f0f0"]] \
    source_type test \
    row_mode residue \
    column_mode frame \
    rows $rows \
    columns [lrange $columns 0 1] \
    values [list {H E C} {C H E}]]
set categorical_slices [::RMSXFlipbookTimeline::aggregate_timeline_to_slices \
    $categorical_dataset \
    slicing_mode slices \
    slices 1 \
    aggregation auto]
if {[dict get $categorical_slices value_kind] ne "categorical"} {
    smoke_fail "categorical slice aggregation should stay categorical"
}
if {[::RMSXFlipbookTimeline::Matrix::cell_value $categorical_slices 0 0] ne "H"} {
    smoke_fail "categorical slice aggregation should use mode with first-seen tie break"
}
set categorical_svg_path [file join $tmp_dir secondary_structure.svg]
::RMSXFlipbookTimeline::write_timeline_svg \
    $categorical_dataset \
    $categorical_svg_path \
    palette viridis \
    width 640
set categorical_svg [read_file $categorical_svg_path]
foreach needle {"Secondary Structure Smoke" "struct" "H alpha helix" "E beta strand" "C coil" "#d95f02" "#1b9e77" "#f0f0f0"} {
    if {[string first $needle $categorical_svg] < 0} {
        smoke_fail "categorical SVG missing expected text/color: $needle"
    }
}

set binary_dataset [::RMSXFlipbookTimeline::Matrix::create \
    title "Binary Event Smoke" \
    value_label "H-bond" \
    value_kind binary \
    categories [list \
        [dict create value 0 label "0 inactive" color "#f3f4f6"] \
        [dict create value 1 label "1 active" color "#2563eb"]] \
    source_type test \
    row_mode free_selection \
    column_mode frame \
    rows [lrange $rows 0 1] \
    columns [lrange $columns 0 1] \
    values [list {0 1} {1 0}]]
set binary_slices [::RMSXFlipbookTimeline::aggregate_timeline_to_slices \
    $binary_dataset \
    slicing_mode slices \
    slices 1 \
    aggregation auto]
if {[dict get $binary_slices value_kind] ne "fraction"} {
    smoke_fail "binary slice aggregation should become occupancy fraction"
}
if {abs([::RMSXFlipbookTimeline::Matrix::cell_value $binary_slices 0 0] - 0.5) > 0.000001} {
    smoke_fail "binary occupancy slice aggregation wrong"
}
set binary_svg_path [file join $tmp_dir binary_event.svg]
::RMSXFlipbookTimeline::write_timeline_svg \
    $binary_dataset \
    $binary_svg_path \
    palette viridis \
    width 640
set binary_svg [read_file $binary_svg_path]
foreach needle {"Binary Event Smoke" "0 inactive" "1 active" "#f3f4f6" "#2563eb"} {
    if {[string first $needle $binary_svg] < 0} {
        smoke_fail "binary SVG missing expected text/color: $needle"
    }
}

set png_path [file join $tmp_dir timeline.png]
if {[catch {package require Tk} tk_err]} {
    puts "RMSX Flipbook Timeline rich PNG smoke skipped: Tk unavailable: $tk_err"
} else {
    ::RMSXFlipbookTimeline::write_timeline_png \
        $dataset \
        $png_path \
        palette viridis \
        width 640 \
        threshold_min 0 \
        threshold_max 3 \
        scale_min -1.5 \
        scale_max 11.5

    if {![file exists $png_path] || [file size $png_path] < 500} {
        smoke_fail "PNG was not written with useful content: $png_path"
    }
    set probe [image create photo -file $png_path]
    try {
        set width [$probe width]
        set height [$probe height]
        if {$width < 500 || $height < 150} {
            smoke_fail "PNG dimensions were unexpectedly small: ${width}x${height}"
        }
        set samples [list \
            [$probe get 130 22] \
            [$probe get 130 86] \
            [$probe get 140 174] \
            [$probe get 130 [expr {$height - 34}]]]
        set nonwhite 0
        foreach pixel $samples {
            if {$pixel ne {255 255 255}} {
                incr nonwhite
            }
        }
        if {$nonwhite < 3} {
            smoke_fail "PNG did not contain expected title/threshold/heatmap/legend pixels: $samples"
        }
    } finally {
        catch {image delete $probe}
    }
}

file delete -force $tmp_dir
puts "RMSX Flipbook Timeline filter/SVG smoke passed"
exit 0
