################################################################################
# RMSX Flipbook Timeline neighborhood headless smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline neighborhood smoke failed: $message"
    flush stdout
    exit 1
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

set plan [::RMSXFlipbookTimeline::NeighborhoodFlipbook::frame_plan 10 0 4 1]
if {$plan ne {0 1 2 3 4}} {
    smoke_fail "start-clipped frame plan was $plan"
}

set plan [::RMSXFlipbookTimeline::NeighborhoodFlipbook::frame_plan 10 9 4 1]
if {$plan ne {5 6 7 8 9}} {
    smoke_fail "end-clipped frame plan was $plan"
}

set plan [::RMSXFlipbookTimeline::NeighborhoodFlipbook::frame_plan 10 5 2 2]
if {$plan ne {1 3 5 7 9}} {
    smoke_fail "stepped frame plan was $plan"
}

set rows [list \
    [dict create index 0 label "A:1 GLY" selection "resid 1"] \
    [dict create index 1 label "A:2 SER" selection "resid 2"]]
set columns [list \
    [dict create index 0 frame 0 label 0] \
    [dict create index 1 frame 5 label 5] \
    [dict create index 2 frame 9 label 9]]
set values [list \
    {0.0 1.0} \
    {0.5 0.0} \
    {1.0 1.0}]
set dataset [::RMSXFlipbookTimeline::Matrix::create \
    title "Neighborhood numeric" \
    value_label displacement \
    source_type live_trajectory \
    row_mode residue \
    column_mode frame \
    rows $rows \
    columns $columns \
    values $values \
    min 0 \
    max 1]

set col [::RMSXFlipbookTimeline::NeighborhoodFlipbook::column_index_for_frame $dataset 5]
if {$col != 1} {
    smoke_fail "exact frame-to-column match expected 1, got $col"
}

set color_info [::RMSXFlipbookTimeline::NeighborhoodFlipbook::cell_color_for_frame $dataset 0 2 5 viridis 0 1]
if {![dict get $color_info matched] || [dict get $color_info column] != 1 || [dict get $color_info value] != 0.5} {
    smoke_fail "exact frame color info was $color_info"
}

set color_info [::RMSXFlipbookTimeline::NeighborhoodFlipbook::cell_color_for_frame $dataset 0 2 7 viridis 0 1]
if {[dict get $color_info matched] || [dict get $color_info column] != 2 || [dict get $color_info value] != 1.0} {
    smoke_fail "fallback aggregate color info was $color_info"
}

set cat_dataset [dict merge $dataset [dict create \
    title "Neighborhood categorical" \
    value_label secondary_structure \
    value_kind categorical \
    categories [list \
        [dict create value H label helix color "#d95f02"] \
        [dict create value E label strand color "#1b9e77"]] \
    values [list {H E} {E H} {H E}]]]
set color_info [::RMSXFlipbookTimeline::NeighborhoodFlipbook::cell_color_for_frame $cat_dataset 1 1 5 viridis 0 1]
if {[dict get $color_info color] ne "#d95f02"} {
    smoke_fail "categorical color should use category color, got $color_info"
}

set status [::RMSXFlipbookTimeline::NeighborhoodFlipbook::show_for_selection $dataset [dict create row 0 column 1]]
if {[dict get $status enabled] != 0 || [string first "live VMD trajectory" [dict get $status message]] < 0} {
    smoke_fail "unsupported headless dataset should return a disabled VMD message, got $status"
}

puts "RMSX Flipbook Timeline neighborhood headless smoke passed."
