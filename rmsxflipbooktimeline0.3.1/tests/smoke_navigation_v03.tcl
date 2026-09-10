lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set cells {}
foreach row {4 9 2} y {10 30 50} {
    foreach col {0 1 2} {dict set cells [list $row $col] [dict create row $row column $col y0 $y]}
}
assert {[::RMSXFlipbookTimeline::Navigation::next_coordinate $cells {4 1} Down] eq {9 1}} "Navigation does not follow rendered chain order"
assert {[::RMSXFlipbookTimeline::Navigation::next_coordinate $cells {9 1} Down] eq {2 1}} "Cross-chain Down lost column"
assert {[::RMSXFlipbookTimeline::Navigation::next_coordinate $cells {2 1} Control-Home] eq {4 0}} "Ctrl+Home incorrect"
assert {[::RMSXFlipbookTimeline::Navigation::next_coordinate $cells {4 1} Control-End] eq {2 2}} "Ctrl+End incorrect"
assert {[::RMSXFlipbookTimeline::Navigation::next_coordinate $cells {4 0} Left] eq {4 0}} "Left should stop at edge"
assert {[::RMSXFlipbookTimeline::Navigation::next_coordinate $cells {} Return] eq {4 0}} "Enter should select initial cell"
puts "Navigation v0.3 smoke passed"
