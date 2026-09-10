package require Tcl 8.6
set package_dir [file dirname [file dirname [info script]]]
source -encoding utf-8 [file join $package_dir rmsxflipbooktimeline.tcl]
source -encoding utf-8 [file join $package_dir visualization threshold_controls.tcl]
proc expect {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set rows {}; set columns {}
for {set i 0} {$i < 6} {incr i} {lappend rows [dict create index $i resid [expr {$i+1}]]}
for {set i 0} {$i < 4} {incr i} {lappend columns [dict create index $i frame $i]}
lset rows 3 [dict create index 3 resid 4 masked 1]
# Avoid Matrix::create's historical nonfinite value-range path. validate accepts
# the same column-major dataset, including real missing/nonfinite observations.
set dataset [dict create rows $rows columns $columns value_kind continuous \
    values {{1 2 {} 2 NaN Inf} {2 3 1 2 -Inf 2} {3 2 2 2 2 2} {2 1 3 2 2 2}}]
set original $dataset
set answer [::RMSXFlipbookTimeline::ThresholdControls::analyze $dataset {min 1 max 2 min_frames 3}]
expect {[dict get $answer counts] eq {2 3 4 4}} "Inclusive bounds, mask, missing or nonfinite counts were wrong: $answer"
expect {[dict get $answer eligible_counts] eq {2 4 5 5}} "Eligible counts include invalid or masked observations"
expect {[dict get $answer row_passes] eq {3 3 2 0 2 3}} "Passing columns were not counted independently"
expect {[dict get $answer qualifying_rows] eq {0 1 5}} "Persistence incorrectly required consecutive frames"
expect {[dict get $answer peak_count] == 4} "Peak count was wrong"
expect {$dataset eq $original} "Analysis mutated the authoritative dataset"
set restricted [::RMSXFlipbookTimeline::ThresholdControls::analyze $dataset {min 1 max 2 first_column 1 last_column 2 min_frames 2}]
expect {[dict get $restricted qualifying_rows] eq {2 5}} "Persistence did not respect inclusive column bounds"
set exact [::RMSXFlipbookTimeline::ThresholdControls::analyze $dataset {min 2 max 2}]
expect {[dict get $exact counts] eq {1 2 4 3}} "Equal threshold bounds were not inclusive"
expect {[catch {::RMSXFlipbookTimeline::ThresholdControls::analyze $dataset {min 3 max 2}}]} "Reversed thresholds were accepted"
expect {[catch {::RMSXFlipbookTimeline::ThresholdControls::analyze $dataset {min NaN}}]} "NaN threshold was accepted"
expect {[catch {::RMSXFlipbookTimeline::ThresholdControls::analyze $dataset {min_frames 0}}]} "Zero persistence was accepted"
expect {[catch {::RMSXFlipbookTimeline::ThresholdControls::analyze $dataset {first_column 3 last_column 2}}]} "Reversed column range was accepted"
foreach value {NaN Inf -Inf +Infinity {} missing} {expect {![::RMSXFlipbookTimeline::ThresholdControls::finite $value]} "Accepted nonfinite value $value"}

set meta_masked $dataset
dict set meta_masked mask_metadata [list {} [dict create masked 1]]
expect {[dict get [::RMSXFlipbookTimeline::ThresholdControls::analyze $meta_masked {min 1 max 2}] counts] eq {1 3 3 3}} "Mask metadata was ignored"
set categorical [dict create rows [lrange $rows 0 2] columns [lrange $columns 0 2] value_kind categorical \
    categories [list [dict create value H label Helix] [dict create value E label Sheet] [dict create value C label Coil]] \
    values {{H E C} {E H {}} {H NaN E}}]
set categories [::RMSXFlipbookTimeline::ThresholdControls::analyze $categorical {categories H min_frames 2}]
expect {[dict get $categories counts] eq {1 1 1}} "Category selection counted unselected values"
expect {[dict get $categories qualifying_rows] eq {0}} "Categorical persistence was incorrect"
expect {[dict get $categories eligible_counts] eq {3 2 2}} "Categorical missing/nonfinite cells were eligible"
expect {[dict get [::RMSXFlipbookTimeline::ThresholdControls::analyze $categorical {categories {}}] counts] eq {0 0 0}} "Empty category selection selected everything"
set binary [dict replace $categorical value_kind binary categories {} values {{0 1 0} {1.0 0 1} {1 1 0}}]
expect {[dict get [::RMSXFlipbookTimeline::ThresholdControls::analyze $binary {categories 1}] counts] eq {1 2 2}} "Binary categories did not match equivalent numbers"

# Debounce and lifetime checks use the real Tcl timer queue, without Tk stubs.
set ::RMSXFlipbookTimeline::ThresholdControls::debounce_ms 5
::RMSXFlipbookTimeline::ThresholdControls::update_dataset .threshold_test $dataset
::RMSXFlipbookTimeline::ThresholdControls::set_range .threshold_test 0 3
set first_timer [dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_test] pending]
::RMSXFlipbookTimeline::ThresholdControls::set_range .threshold_test 2 2
expect {[lsearch -exact [after info] $first_timer] < 0} "Debounce retained the superseded callback"
after 20 {set ::threshold_wait 1}
vwait ::threshold_wait
set state [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_test]
expect {[dict get $state render_count] == 1} "Debounced changes computed more than once"
expect {[dict get $state analysis counts] eq {1 2 4 3}} "Debounce did not apply the final range"
expect {[dict get $state pending] eq {}} "Completed callback retained its timer handle"
::RMSXFlipbookTimeline::ThresholdControls::set_range .threshold_test 1 2
set stale [dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_test] generation]
::RMSXFlipbookTimeline::ThresholdControls::update_dataset .threshold_test $categorical
::RMSXFlipbookTimeline::ThresholdControls::apply_pending .threshold_test $stale
expect {[dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_test] dataset] eq $categorical} "Stale callback replaced the new dataset"
::RMSXFlipbookTimeline::ThresholdControls::set_options .threshold_test {categories H enabled 1}
set pending [dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_test] pending]
::RMSXFlipbookTimeline::ThresholdControls::detach .threshold_test
expect {[lsearch -exact [after info] $pending] < 0} "Detach leaked a timer"
expect {[::RMSXFlipbookTimeline::ThresholdControls::state .threshold_test] eq {}} "Detach leaked view state"
::RMSXFlipbookTimeline::ThresholdControls::update_dataset .threshold_busy $dataset
::RMSXFlipbookTimeline::Operation::begin test
::RMSXFlipbookTimeline::ThresholdControls::set_range .threshold_busy 1 2
after 20 {set ::threshold_wait 2}
vwait ::threshold_wait
expect {[dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_busy] render_count] == 0} "Threshold callback ran during an operation"
::RMSXFlipbookTimeline::Operation::finish complete
after 20 {set ::threshold_wait 3}
vwait ::threshold_wait
expect {[dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_busy] render_count] == 1} "Deferred thresholds did not resume after operation"
::RMSXFlipbookTimeline::ThresholdControls::detach .threshold_busy

# The same test can also run under the real Tk GUI harness. Its portable run
# above does not claim widget, pointer, or graphics coverage.
if {[info commands winfo] ne ""} {
    toplevel .threshold_smoke
    wm geometry .threshold_smoke 680x500
    canvas .threshold_smoke.heat -width 300 -height 160
    pack .threshold_smoke.heat -fill both -expand 1
    set records {}
    for {set row 0} {$row < 6} {incr row} {
        for {set column 0} {$column < 4} {incr column} {
            set x0 [expr {10+$column*20}]; set y0 [expr {10+$row*10}]
            set record [dict create row $row column $column x0 $x0 y0 $y0 x1 [expr {$x0+20}] y1 [expr {$y0+10}]]
            lappend records $record
            .threshold_smoke.heat create rectangle $x0 $y0 [expr {$x0+20}] [expr {$y0+10}] -fill gray -tags pickable
        }
    }
    proc threshold_selected {record} {set ::threshold_picked [list [dict get $record row] [dict get $record column]]; return $::threshold_picked}
    ::RMSXFlipbookTimeline::Navigation::attach .threshold_smoke.heat $records threshold_selected {set ::threshold_picked {}}
    set frame [::RMSXFlipbookTimeline::ThresholdControls::attach .threshold_smoke .threshold_smoke.heat $dataset]
    pack $frame -fill x
    ::RMSXFlipbookTimeline::ThresholdControls::toggle .threshold_smoke.heat
    update idletasks
    expect {[winfo ismapped $frame.body]} "Threshold disclosure did not show its controls"
    ::RMSXFlipbookTimeline::ThresholdControls::set_options .threshold_smoke.heat {min 1 max 2 min_frames 3 enabled 1}
    after 20 {set ::threshold_wait 4}
    vwait ::threshold_wait
    expect {[llength [.threshold_smoke.heat find withtag threshold_qualifying]] == 3} "Persistence did not highlight the qualifying heatmap rows"
    ::RMSXFlipbookTimeline::Navigation::choose .threshold_smoke.heat {2 0}
    ::RMSXFlipbookTimeline::ThresholdControls::select_column .threshold_smoke.heat 2
    expect {$::threshold_picked eq {2 2}} "Count-bar selection did not retain the current row"
    set id [dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_smoke.heat] id]
    expect {[string first "Column 2: 4 passing / 5 eligible" $::RMSXFlipbookTimeline::ThresholdControls::ui($id,summary)] == 0} "Current-column statistics did not follow bar selection"
    if {[info commands ::RMSXFlipbookTimeline::Navigation::zoom] ne ""} {
        ::RMSXFlipbookTimeline::Navigation::zoom .threshold_smoke.heat 2 3
        ::RMSXFlipbookTimeline::ThresholdControls::refresh .threshold_smoke.heat
        set box [.threshold_smoke.heat coords [lindex [.threshold_smoke.heat find withtag threshold_qualifying] 0]]
        expect {$box eq {20.0 30.0 180.0 60.0}} "Threshold outline did not follow the Navigation transform: $box"
    }
    ::RMSXFlipbookTimeline::ThresholdControls::clear .threshold_smoke.heat
    after 20 {set ::threshold_wait 5}
    vwait ::threshold_wait
    expect {[llength [.threshold_smoke.heat find withtag threshold_qualifying]] == 0} "Clear retained persistence outlines"
    ::RMSXFlipbookTimeline::ThresholdControls::update_dataset .threshold_smoke.heat $categorical
    expect {[winfo exists $frame.body.inputs.c0] && ![winfo exists $frame.body.inputs.minscale]} "Categorical replacement did not switch to category toggles"
    set id [dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_smoke.heat] id]
    set ::RMSXFlipbookTimeline::ThresholdControls::ui($id,category,1) 0
    set ::RMSXFlipbookTimeline::ThresholdControls::ui($id,category,2) 0
    ::RMSXFlipbookTimeline::ThresholdControls::read_controls .threshold_smoke.heat
    after 20 {set ::threshold_wait 6}
    vwait ::threshold_wait
    expect {[dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_smoke.heat] analysis counts] eq {1 1 1}} "Category toggle UI did not update counts"
    ::RMSXFlipbookTimeline::ThresholdControls::set_options .threshold_smoke.heat {categories E enabled 1}
    set pending [dict get [::RMSXFlipbookTimeline::ThresholdControls::state .threshold_smoke.heat] pending]
    destroy .threshold_smoke
    expect {[::RMSXFlipbookTimeline::ThresholdControls::state .threshold_smoke.heat] eq {}} "Window destruction retained threshold state"
    expect {[lsearch -exact [after info] $pending] < 0} "Window destruction retained its threshold timer"
    puts "Live threshold real Tk controls passed"
}
puts "Live threshold controls smoke passed"
