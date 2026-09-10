# Requires Tk; the capability-aware manifest must not mark this passed headless.
lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
package require Tk
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc close_enough {a b} {expr {abs($a-$b) < 0.01}}
namespace eval ::HeatmapZoomSmoke {
    variable chosen {}
    variable records {}
    proc select {canvas record} {
        variable chosen
        set chosen [list [dict get $record row] [dict get $record column]]
        $canvas delete smoke_selection
        $canvas create rectangle [dict get $record x0] [dict get $record y0] [dict get $record x1] [dict get $record y1] -outline red -tags smoke_selection
        return $chosen
    }
    proc clear {canvas} {$canvas delete smoke_selection}
    proc draw {canvas} {
        variable records
        $canvas delete all
        set records {}
        for {set row 0} {$row < 30} {incr row} {
            for {set col 0} {$col < 5} {incr col} {
                set x0 [expr {130+$col*70.0}]; set y0 [expr {40+$row*8.0}]
                set record [dict create row $row column $col x0 $x0 y0 $y0 x1 [expr {$x0+70}] y1 [expr {$y0+8}] center_x [expr {$x0+35}] center_y [expr {$y0+4}]]
                lappend records $record
                $canvas create rectangle $x0 $y0 [expr {$x0+70}] [expr {$y0+8}] -fill "#21918c" -outline {} -tags pickable
            }
            if {$row % 5 == 0} {$canvas create text 122 [expr {44+$row*8}] -anchor e -text "A:$row" -font TkDefaultFont}
        }
        $canvas configure -scrollregion {0 0 500 320}
        ::RMSXFlipbookTimeline::Navigation::attach $canvas $records [list ::HeatmapZoomSmoke::select $canvas] [list ::HeatmapZoomSmoke::clear $canvas]
        set labels {}
        for {set row 0} {$row < 30} {incr row} {dict set labels $row "A:GLY[expr {$row+1}]"}
        ::RMSXFlipbookTimeline::Navigation::row_labels $canvas $labels
    }
    proc click_cell {canvas row col} {
        set x [expr {165+$col*70.0}]; set y [expr {44+$row*8.0}]
        lassign [::RMSXFlipbookTimeline::Navigation::to_canvas $canvas $x $y] x y
        set x [expr {int(round($x-[$canvas canvasx 0]))}]
        set y [expr {int(round($y-[$canvas canvasy 0]))}]
        event generate $canvas <Motion> -x $x -y $y
        event generate $canvas <ButtonPress-1> -x $x -y $y
        event generate $canvas <ButtonRelease-1> -x $x -y $y
        update
    }
}
set top .rmsx_heatmap_zoom_smoke
catch {destroy $top}
toplevel $top
wm geometry $top 580x370+30+30
canvas $top.c -background white -width 560 -height 340
pack $top.c -fill both -expand 1
set c $top.c
try {
    ::HeatmapZoomSmoke::draw $c
    update
    set first [$c find withtag pickable]
    set initial [$c coords [lindex $first 0]]
    ::RMSXFlipbookTimeline::Navigation::zoom $c 1.4 1
    set state [::RMSXFlipbookTimeline::Navigation::zoom_state $c]
    assert {[close_enough [dict get $state x] 1.4] && [close_enough [dict get $state y] 1]} "Independent X zoom also changed Y"
    ::RMSXFlipbookTimeline::Navigation::zoom $c 1 1.5
    set state [::RMSXFlipbookTimeline::Navigation::zoom_state $c]
    assert {[close_enough [dict get $state x] 1.4] && [close_enough [dict get $state y] 1.5]} "Independent Y zoom also changed X"
    ::HeatmapZoomSmoke::click_cell $c 3 1
    assert {$::HeatmapZoomSmoke::chosen eq {3 1}} "Mouse event hit the wrong cell after zoom"
    lassign [$c coords smoke_selection] x0 y0 x1 y1
    assert {[close_enough $x0 280] && [close_enough $y0 96]} "Callback selection marker used stale unscaled geometry"
    focus -force $c
    event generate $c <KeyPress-Right>
    update
    assert {$::HeatmapZoomSmoke::chosen eq {3 2}} "Keyboard selection failed after zoom"
    lassign [::RMSXFlipbookTimeline::Navigation::to_canvas $c 235 64] sx sy
    lassign [::RMSXFlipbookTimeline::Navigation::to_model $c $sx $sy] mx my
    assert {[close_enough $mx 235] && [close_enough $my 64]} "Comparison-chart coordinate round trip failed"
    ::RMSXFlipbookTimeline::Navigation::attach $c $::HeatmapZoomSmoke::records [list ::HeatmapZoomSmoke::select $c] [list ::HeatmapZoomSmoke::clear $c]
    assert {[close_enough [dict get [::RMSXFlipbookTimeline::Navigation::zoom_state $c] x] 1.4]} "Reattaching reset a live canvas transform"
    ::RMSXFlipbookTimeline::Navigation::reset_zoom $c
    assert {[$c coords [lindex $first 0]] eq $initial} "Reset failed to restore original canvas geometry"
    ::RMSXFlipbookTimeline::Navigation::fit $c
    set state [::RMSXFlipbookTimeline::Navigation::zoom_state $c]
    assert {[dict get $state x] > 0 && [dict get $state y] > 0} "Fit produced an invalid transform"
    set region [$c cget -scrollregion]
    assert {[lindex $region 2]-[lindex $region 0] <= [winfo width $c]} "Fit left horizontal overflow"
    assert {[lindex $region 3]-[lindex $region 1] <= [winfo height $c]} "Fit left vertical overflow"
    ::RMSXFlipbookTimeline::Navigation::every_residue $c
    set labels [$c find withtag navigation_row_label]
    assert {[llength $labels] == 30} "Every residue omitted axis labels"
    assert {[$c itemcget [lindex $labels 0] -text] eq "A:GLY1"} "Every residue lost authoritative residue labels"
    set state [::RMSXFlipbookTimeline::Navigation::zoom_state $c]
    assert {8*[dict get $state y] >= [font metrics TkDefaultFont -linespace]+4} "Every residue labels would overlap"
    set bbox [$c bbox [lindex $labels 0]]
    assert {[lindex $bbox 2] > [lindex $bbox 0]} "Every residue labels are not rendered"
    ::RMSXFlipbookTimeline::Navigation::fit $c
    assert {[llength [$c find withtag navigation_row_label]] == 0} "Fit retained dense residue labels"
    ::RMSXFlipbookTimeline::Navigation::reset_zoom $c
    # Genuine right-drag events exercise the same path as all four UI views.
    event generate $c <ButtonPress-3> -x 140 -y 50
    event generate $c <B3-Motion> -x 320 -y 200
    event generate $c <ButtonRelease-3> -x 320 -y 200
    update
    set state [::RMSXFlipbookTimeline::Navigation::zoom_state $c]
    assert {[dict get $state x] > 2 && [dict get $state y] > 2} "Rectangle event zoom was ignored"
    assert {[llength [$c find withtag navigation_zoom_box]] == 0} "Rectangle zoom left a selection box"
    # Redrawing a resized canvas starts with unscaled data and never doubles
    # its transform; the pop-out must also retain an independent view.
    ::HeatmapZoomSmoke::draw $c
    assert {[dict get [::RMSXFlipbookTimeline::Navigation::zoom_state $c] x] == 1} "Redraw reused a stale transform"
    canvas $top.other -width 120 -height 100
    ::HeatmapZoomSmoke::draw $top.other
    ::RMSXFlipbookTimeline::Navigation::zoom $c 2 1
    assert {[dict get [::RMSXFlipbookTimeline::Navigation::zoom_state $top.other] x] == 1} "Zoom leaked into another canvas"
    assert {[catch {::RMSXFlipbookTimeline::Navigation::zoom $c 0 1}]} "Zero zoom factor was accepted"
    assert {[catch {::RMSXFlipbookTimeline::Navigation::zoom $c Inf 1}]} "Infinite zoom factor was accepted"
    set ::heatmap_zoom_parent_wheel 0
    bind $top <MouseWheel> {incr ::heatmap_zoom_parent_wheel}
    event generate $c <MouseWheel> -delta -120
    update
    assert {$::heatmap_zoom_parent_wheel == 0} "Canvas wheel also scrolled its parent page"
    puts "Heatmap zoom smoke passed: independent axes, rectangle events, transformed mouse/keyboard selection, labels, fit, redraw, and view isolation"
} finally {
    destroy $top
}
