lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
package require Tk
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc pause {milliseconds} {set ::explore_wait 0; after $milliseconds {set ::explore_wait 1}; vwait ::explore_wait}
proc await_replay {canvas} {
    set deadline [expr {[clock milliseconds]+8000}]
    while {[dict get [::RMSXFlipbookTimeline::HeatmapTools::state $canvas] replay] ne {} && [clock milliseconds] < $deadline} {pause 40}
    assert {[dict get [::RMSXFlipbookTimeline::HeatmapTools::state $canvas] replay] eq {}} "Replay timer did not finish"
}
proc pixel {canvas row col} {
    set rec [dict get $::RMSXFlipbookTimeline::Navigation::views $canvas cells [list $row $col]]
    lassign [::RMSXFlipbookTimeline::Navigation::to_canvas $canvas [expr {([dict get $rec x0]+[dict get $rec x1])/2.0}] [expr {([dict get $rec y0]+[dict get $rec y1])/2.0}]] x y
    return [list [expr {int($x-[$canvas canvasx 0])}] [expr {int($y-[$canvas canvasy 0])}]]
}
proc brush {canvas row0 col0 row1 col1 {add 0}} {
    lassign [pixel $canvas $row0 $col0] x0 y0
    lassign [pixel $canvas $row1 $col1] x1 y1
    event generate $canvas <Motion> -x $x0 -y $y0
    event generate $canvas <ButtonPress-1> -x $x0 -y $y0 -state [expr {$add ? 5 : 1}]
    event generate $canvas <Motion> -x $x1 -y $y1 -state [expr {$add ? 261 : 257}]
    event generate $canvas <ButtonRelease-1> -x $x1 -y $y1 -state [expr {$add ? 5 : 1}]
    update
}
set input [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files 1UBQ.pdb]
set trajectory [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files mon_sys.dcd]
set source [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb $input]
# load_pdb returns the molecule ID.
mol addfile $trajectory type dcd first 0 last 7 waitfor all molid $source
set unrelated [mol new $input type pdb waitfor all]
set unrelated_reps [molinfo $unrelated get numreps]
rmsxflipbooktimeline
set ds [::RMSXFlipbookTimeline::TimelineAnalysis::calculate $source displacement first_frame 0 last_frame 7]
::RMSXFlipbookTimeline::show_timeline_dataset $ds
set pop $::RMSXFlipbookTimeline::TimelinePlot::canvas
::RMSXFlipbookTimeline::Dashboard::draw_embedded_heatmap $ds
set embedded $::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_canvas
update
assert {[::RMSXFlipbookTimeline::HeatmapTools::valid $pop]} "Pop-out did not bind the current result"
assert {[::RMSXFlipbookTimeline::HeatmapTools::valid $embedded]} "Embedded view did not bind the current result"
# Use the larger visible pop-out for actual marquee events.
brush $pop 3 1 5 3
set event [dict get [::RMSXFlipbookTimeline::HeatmapTools::state $pop] event]
assert {[dict get $event rows] eq {3 4 5}} "Shift-drag rows wrong: $event"
assert {[dict get $event columns] eq {1 2 3}} "Shift-drag columns wrong: $event"
brush $pop 8 1 8 3 1
set event [dict get [::RMSXFlipbookTimeline::HeatmapTools::state $pop] event]
assert {[dict get $event rows] eq {3 4 5 8}} "Ctrl+Shift did not add rows"
set before [molinfo $source get numreps]
set pins [::RMSXFlipbookTimeline::HeatmapTools::pin $pop]
assert {[llength $pins] == 1} "Live rows did not create one owned representation"
assert {[molinfo $source get numreps] == $before+1} "Pin count wrong"
assert {[molinfo $unrelated get numreps] == $unrelated_reps} "Pins changed unrelated molecules"
::RMSXFlipbookTimeline::Navigation::zoom $pop 1.25 1.2
assert {[llength [$pop find withtag event_selection]] == 4} "Zoom lost event overlay"
assert {[llength [$pop find withtag pinned_selection]] == 4} "Zoom lost pinned overlay"
molinfo $source set frame 6
mol top $unrelated
assert {[::RMSXFlipbookTimeline::HeatmapTools::play $pop 20] == 3} "Replay did not use selected source frames"
await_replay $pop
assert {[dict get [::RMSXFlipbookTimeline::HeatmapTools::state $pop] replay] eq {}} "Replay timer did not finish"
assert {[molinfo $source get frame] == 6} "Replay failed to restore the user's frame"
assert {[molinfo top] == $unrelated} "Replay failed to restore top molecule"
::RMSXFlipbookTimeline::HeatmapTools::play $pop 30
molinfo $source set frame 7
await_replay $pop
assert {[molinfo $source get frame] == 7} "Stop overwrote a later user frame change"
assert {[dict get [::RMSXFlipbookTimeline::HeatmapTools::state $pop] replay] eq {}} "Replay ignored an external frame change"
::RMSXFlipbookTimeline::HeatmapTools::play $pop 30
mol top $unrelated
await_replay $pop
assert {[molinfo top] == $unrelated} "Replay overwrote a later top-molecule change"
::RMSXFlipbookTimeline::HeatmapTools::pin $pop
assert {[dict get [::RMSXFlipbookTimeline::Results::get] pinned_rows] eq {}} "Unpin left stale result metadata"
::RMSXFlipbookTimeline::HeatmapTools::clear_event $pop
assert {[molinfo $source get numreps] == $before} "Clearing leaked pin/replay reps"
# Live threshold controls leave authoritative values unchanged.
set ds_before [dict get [::RMSXFlipbookTimeline::Results::get] dataset]
::RMSXFlipbookTimeline::ThresholdControls::set_range $pop 0 100
pause 150
assert {[dict get [::RMSXFlipbookTimeline::Results::get] dataset] eq $ds_before} "Threshold exploration changed the result"
# A foreign dataset must not borrow the active generation or select molecules.
canvas .foreign
set foreign $ds; dict set foreign title "Different result"
set ::foreign_calls 0
::RMSXFlipbookTimeline::Navigation::attach .foreign [dict values [::RMSXFlipbookTimeline::HeatmapTools::cells $pop]] {apply {{rec} {incr ::foreign_calls}}} {}
::RMSXFlipbookTimeline::HeatmapTools::attach .foreign $foreign
::RMSXFlipbookTimeline::HeatmapTools::activate .foreign
assert {![::RMSXFlipbookTimeline::HeatmapTools::valid .foreign]} "Foreign plot borrowed active generation"
::RMSXFlipbookTimeline::Navigation::choose .foreign {2 0}
assert {$::foreign_calls == 0} "Inactive plot invoked structure callback"
destroy .foreign
# Switch compatible saved datasets through the real selector controller.
set collection [file join $::env(RMSX_TEST_WORKDIR) outputs exploration_collection]
file mkdir $collection
::RMSXFlipbookTimeline::TimelineIO::write_tml $ds [file join $collection a.tml]
set second $ds; dict set second title Second
::RMSXFlipbookTimeline::TimelineIO::write_tml $second [file join $collection b.tml]
::RMSXFlipbookTimeline::Collections::load $collection $source
set committed [::RMSXFlipbookTimeline::Results::get]
::RMSXFlipbookTimeline::Navigation::choose $embedded {1 0}
assert {[::RMSXFlipbookTimeline::Results::get] eq $committed} "Stale embedded view changed the new result"
set c $::RMSXFlipbookTimeline::TimelinePlot::canvas
::RMSXFlipbookTimeline::Navigation::choose $c {4 3}
set switched [::RMSXFlipbookTimeline::Collections::select 1]
assert {[dict get $switched selected_cell] eq {4 3}} "Collection switch lost compatible selected residue/frame"
assert {[dict get [::RMSXFlipbookTimeline::Results::get] dataset title] eq "Second"} "Collection export target did not switch"
# Native mode pins the exact residues on every owned slice.
set folder [file join $::env(RMSX_TEST_WORKDIR) outputs native-rmsx-1ubq-9 chain_7_rmsx]
::RMSXFlipbookTimeline::Dashboard::load_folder_with_view $folder {}
set c $::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_canvas
update
set ids [::RMSXFlipbookTimeline::state_get molids]
assert {[llength $ids] == 9} "Native fixture did not have nine structures"
set counts {}; foreach id $ids {dict set counts $id [molinfo $id get numreps]}
::RMSXFlipbookTimeline::Navigation::choose $c {2 0}
set counts {}; foreach id $ids {dict set counts $id [molinfo $id get numreps]}
set reps [::RMSXFlipbookTimeline::HeatmapTools::pin $c]
assert {[llength $reps] == 9} "Pinned row was not present across all nine structures"
foreach id $ids {assert {[molinfo $id get numreps] == [dict get $counts $id]+1} "Pin missing on slice $id"}
set ev [::RMSXFlipbookTimeline::HeatmapTools::range_event [::RMSXFlipbookTimeline::HeatmapTools::cells $c] {2 1} {3 3}]
::RMSXFlipbookTimeline::HeatmapTools::set_event $c $ev
assert {[::RMSXFlipbookTimeline::HeatmapTools::replay_mode [dict get [::RMSXFlipbookTimeline::HeatmapTools::state $c] dataset]] eq "windows"} "Native replay mislabeled as live frames"
::RMSXFlipbookTimeline::HeatmapTools::play $c 30
::RMSXFlipbookTimeline::Operation::begin test
assert {[dict get [::RMSXFlipbookTimeline::HeatmapTools::state $c] replay] eq {}} "Starting analysis left replay running"
::RMSXFlipbookTimeline::Operation::finish complete
# Expanded controls scroll at the compact window size, leaving the matrix usable.
::RMSXFlipbookTimeline::PlotWindow::show folder $folder
set compact $::RMSXFlipbookTimeline::PlotWindow::canvas
set win [winfo toplevel $compact]
wm geometry $win 600x540
set ::RMSXFlipbookTimeline::HeatmapTools::expanded($compact) 1
::RMSXFlipbookTimeline::HeatmapTools::toggle $compact
::RMSXFlipbookTimeline::ThresholdControls::toggle $compact
update
set panel [dict get [::RMSXFlipbookTimeline::HeatmapTools::state $compact] panel]
assert {[winfo height $compact] >= 180} "Expanded tools crowded out the compact heatmap"
assert {[winfo width $panel.detail.content] <= [winfo width $panel]} "Tools exceeded the compact window width"
$panel.detail.viewport yview moveto 1
assert {[lindex [$panel.detail.viewport yview] 1] > 0.99} "Expanded tools could not scroll to their final controls"
set old_font_size [font actual TkDefaultFont -size]
try {
    font configure TkDefaultFont -size [expr {int(ceil(abs($old_font_size)*1.25))}]
    update
    assert {[winfo height $compact] >= 180} "Larger fonts crowded out the heatmap"
    assert {[winfo reqwidth $panel.detail.content.zoom] <= [winfo width $panel]} "Zoom controls clipped at larger font size"
} finally {font configure TkDefaultFont -size $old_font_size}
# Closing releases hooks/timers/pins while retaining displayed molecules.
::RMSXFlipbookTimeline::Dashboard::close_window
pause 60
foreach id $ids {assert {[lsearch -exact [molinfo list] $id] >= 0} "Close deleted a slice"}
assert {[molinfo $unrelated get numreps] == $unrelated_reps} "Cleanup changed unrelated representations"
assert {[dict get [::RMSXFlipbookTimeline::HeatmapTools::state $c] reps] eq {}} "Close leaked pin representations"
::RMSXFlipbookTimeline::reset
assert {[lsearch -exact [molinfo list] $unrelated] >= 0} "Remove deleted an unrelated molecule"
puts "Heatmap exploration smoke passed: events, pins, live replay, window replay, thresholds, collections, cleanup"
quit
