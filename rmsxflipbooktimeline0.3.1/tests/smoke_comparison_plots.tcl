lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
package require Tk
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set folder [file join $::env(RMSX_TEST_WORKDIR) outputs native-rmsx-real-multichain-protease combined]
::RMSXFlipbookTimeline::load_folder $folder
set current [::RMSXFlipbookTimeline::Results::get]
# Explicit nonuniform frame metadata tests boundary mapping (no time invented).
set columns {}; foreach bounds {{10 12} {13 20} {21 21} {22 24} {25 27} {28 30} {31 33} {34 36} {37 39}} {
    lappend columns [dict create frame_start [lindex $bounds 0] frame_end [lindex $bounds 1]]
}
dict set current dataset columns $columns
::RMSXFlipbookTimeline::Results::update $current
set prepared [::RMSXFlipbookTimeline::PlotWindow::prepare folder $folder show_summary_chart 0 show_slice_rmsd_chart 0]
toplevel .comparison
canvas .comparison.c -width 950 -height 800
pack .comparison.c
::RMSXFlipbookTimeline::PlotWindow::draw_prepared .comparison.c $prepared
::RMSXFlipbookTimeline::HeatmapTools::activate .comparison.c
update
set view [dict get $::RMSXFlipbookTimeline::PlotWindow::context_views .comparison.c]
assert {[llength [dict get $view zones]] == 4} "Both chains need RMSD and RMSF zones"
assert {[::RMSXFlipbookTimeline::PlotWindow::context_column_for_frame $columns 13] == 1} "RMSD boundary must use actual slice metadata"
assert {[::RMSXFlipbookTimeline::PlotWindow::context_column_for_frame $columns 21] == 2} "Single-frame slices must map correctly"
set target_row -1
foreach rec [dict get $prepared layout cell_records] {
    if {[dict get $rec chain] eq "B" && [dict get $rec resid] == 17} {set target_row [dict get $rec row]; set target_record $rec; break}
}
assert {$target_row >= 0} "Missing B:17 fixture"
::RMSXFlipbookTimeline::Navigation::choose .comparison.c [list $target_row 4]
assert {[llength [.comparison.c find withtag comparison_marker]] == 3} "Heatmap selection needs RMSD markers on both chains and RMSF on selected chain"
set zone [lindex [dict get $view zones] 3]
set x [expr {([dict get $zone x0]+[dict get $zone x1])/2.0}]
set y [dict get $target_record center_y]
set hit [::RMSXFlipbookTimeline::PlotWindow::context_hit $view $x $y [list 0 4]]
assert {[dict get $hit coordinate] eq [list $target_row 4]} "RMSF must select B:17, preserving slice"
# Real Tk pointer events exercise the same route as an actual chart click.
event generate .comparison.c <Motion> -x [expr {int($x)}] -y [expr {int($y)}]
event generate .comparison.c <Button-1> -x [expr {int($x)}] -y [expr {int($y)}]
assert {[dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] eq [list $target_row 4]} "Chart click did not update current result"
set reps $::RMSXFlipbookTimeline::PlotWindow::highlight_reps
assert {[llength $reps] == 1} "Chart click should highlight one slice"
lassign [lindex $reps 0] molid repname
set rep [mol repindex $molid $repname]
assert {$rep >= 0} "Chart highlight representation no longer exists"
set picked [atomselect $molid [lindex [molinfo $molid get [list "selection $rep"]] 0]]
assert {[lsort -unique [$picked get chain]] eq {B}} "RMSF selected wrong chain"
assert {[lsort -unique [$picked get resid]] eq {17}} "RMSF selected wrong residue"
$picked delete
# Click the chain-B RMSD plot at frame 16: preserve B:17, choose actual slice 2.
set rmsd_zone [lindex [dict get $view zones] 2]
set x [expr {[dict get $rmsd_zone x0]+(16.0-[dict get $rmsd_zone frame_min])/([dict get $rmsd_zone frame_max]-[dict get $rmsd_zone frame_min])*([dict get $rmsd_zone x1]-[dict get $rmsd_zone x0])}]
set y [expr {([dict get $rmsd_zone y0]+[dict get $rmsd_zone y1])/2.0}]
event generate .comparison.c <Button-1> -x [expr {int($x)}] -y [expr {int($y)}]
assert {[dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] eq [list $target_row 1]} "RMSD click lost selected residue or chose wrong slice"
assert {[string match {*RMSD*Å*slice 2} $::RMSXFlipbookTimeline::PlotWindow::status_var]} "RMSD hover/click status missing value or slice"
# Masked chart selections remain linked in the plots without opaque spheres.
set masked_row -1
foreach rec [dict get $prepared layout cell_records] {
    if {[dict get $rec chain] eq "B" && [dict get $rec resid] == 48} {
        assert {[dict get $rec masked]} "Expected B:48 to be masked"
        set masked_row [dict get $rec row]
        break
    }
}
assert {$masked_row >= 0} "Missing masked B:48 fixture"
::RMSXFlipbookTimeline::Navigation::choose .comparison.c [list $masked_row 1]
assert {[dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] eq [list $masked_row 1]} "Masked selection lost its identity"
assert {[llength [.comparison.c find withtag comparison_marker]] == 3} "Masked selection lost comparison markers"
assert {$::RMSXFlipbookTimeline::PlotWindow::highlight_reps eq {}} "Masked selection added opaque spheres"
::RMSXFlipbookTimeline::Navigation::choose .comparison.c [list $target_row 1]
# Reject input into a stale result canvas.
set saved [::RMSXFlipbookTimeline::Results::get]
::RMSXFlipbookTimeline::Results::publish [dict merge $saved [dict create selected_cell {0 0}]]
::RMSXFlipbookTimeline::PlotWindow::context_event .comparison.c $x $y 1
assert {[dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] eq {0 0}} "Stale comparison canvas changed new result"
::RMSXFlipbookTimeline::Results::publish $saved
# A second canvas must retain independent geometry and not accumulate bindings.
canvas .comparison.second -width 950 -height 800
::RMSXFlipbookTimeline::PlotWindow::draw_prepared .comparison.second $prepared
::RMSXFlipbookTimeline::HeatmapTools::activate .comparison.second
::RMSXFlipbookTimeline::PlotWindow::draw_prepared .comparison.c $prepared
::RMSXFlipbookTimeline::HeatmapTools::activate .comparison.c
assert {[llength [regexp -all -inline context_event [bind .comparison.c <Button-1>]]] == 1} "Redraw duplicated chart click bindings"
::RMSXFlipbookTimeline::Navigation::choose .comparison.c [list $target_row 4]
assert {[llength [.comparison.c find withtag comparison_marker]] == 3} "Popout stole embedded geometry"
::RMSXFlipbookTimeline::Navigation::key .comparison.c Escape
assert {[llength [.comparison.c find withtag comparison_marker]] == 0} "Escape left comparison markers"
destroy .comparison
assert {![dict exists $::RMSXFlipbookTimeline::PlotWindow::context_views .comparison.c]} "Destroyed canvas retained comparison state"
::RMSXFlipbookTimeline::show_dashboard
::RMSXFlipbookTimeline::Dashboard::load_folder_with_view $folder {}
update
set embedded $::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_canvas
assert {[llength [regexp -all -inline context_event [bind $embedded <Button-1>]]] == 1} "Dashboard navigation replaced comparison click handler"
assert {[dict get [grid info $embedded] -row] == 2} "Activated canvas overlaps comparison controls"
set ev [dict get $::RMSXFlipbookTimeline::PlotWindow::context_views $embedded]
set ez [lindex [dict get $ev zones] 3]
set ep [lindex [dict get $ev layout panels] 1]
set local [lsearch -exact [dict get $ep row_indices] $target_row]
set ex [expr {([dict get $ez x0]+[dict get $ez x1])/2.0}]
set ey [expr {[dict get $ez y0]+($local+0.5)/[dict get $ep row_count]*([dict get $ez y1]-[dict get $ez y0])}]
event generate $embedded <Button-1> -x [expr {int(round($ex-[$embedded canvasx 0]))}] -y [expr {int(round($ey-[$embedded canvasy 0]))}]
assert {[lindex [dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] 0] == $target_row} "Embedded comparison click failed: [dict get [::RMSXFlipbookTimeline::Results::get] selected_cell]; wanted=$target_row; status=$::RMSXFlipbookTimeline::PlotWindow::status_var"
puts "Comparison plots smoke passed"
quit
