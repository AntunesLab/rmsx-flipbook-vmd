source [file join $::env(RMSX_TEST_PACKAGE) visualization principal_view.tcl]
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set points {{-10 0 0} {10 0 0} {0 2 0} {0 -2 0} {0 0 1} {0 0 -1}}
# Rotate about two axes and translate; the longest direction must still become Y.
set transformed {}
foreach p $points {
    lassign $p x y z
    set xx [expr {0.6*$x-0.8*$y}];set yy [expr {0.8*$x+0.6*$y}]
    lappend transformed [list [expr {$xx+17}] [expr {0.8*$yy-0.6*$z-9}] [expr {0.6*$yy+0.8*$z+23}]]
}
set answer [::RMSXFlipbookTimeline::PrincipalView::axes $transformed]
set matrix [dict get $answer matrix];set center [dict get $answer center]
set values [dict get $answer eigenvalues]
foreach actual $values expected {33.3333333333333 1.33333333333333 0.33333333333333} {assert {abs($actual-$expected)<1e-8} "Covariance eigenvalue changed under rigid motion"}
set point [lindex $transformed 1];set projected {}
foreach row [lrange $matrix 0 2] {
    set value 0.0
    foreach a [lrange $row 0 2] x $point c $center {set value [expr {$value+$a*($x-$c)}]}
    lappend projected $value
}
assert {abs([lindex $projected 0])<1e-8 && abs(abs([lindex $projected 1])-10)<1e-8 && abs([lindex $projected 2])<1e-8} "Longest axis is not screen-vertical"
foreach test [list {{0 0 0}} {{0 0 -4} {0 0 4}} {{1 0 0} {-1 0 0} {0 1 0} {0 -1 0} {0 0 1} {0 0 -1}}] {
    set axes [dict get [::RMSXFlipbookTimeline::PrincipalView::axes $test] matrix]
    for {set i 0} {$i<3} {incr i} {
        for {set j 0} {$j<3} {incr j} {
            set dot 0.0
            foreach x [lrange [lindex $axes $i] 0 2] y [lrange [lindex $axes $j] 0 2] {set dot [expr {$dot+$x*$y}]}
            assert {abs($dot-($i==$j))<1e-8} "Degenerate geometry produced a nonorthogonal basis"
        }
    }
}
assert {[catch {::RMSXFlipbookTimeline::PrincipalView::axes {}}]} "Empty geometry accepted"
puts "Principal-axis mathematical regression passed"
