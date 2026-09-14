lappend auto_path $::env(RMSX_TEST_PACKAGE)
package require rmsxflipbooktimeline
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set root $::env(RMSX_TEST_WORKDIR)
::RMSXFlipbookTimeline::load_folder [file join $root fixtures seed_outputs reviewer-protease-9 combined] palette viridis view_preset principal
set ids [::RMSXFlipbookTimeline::state_get molids]
# Make one gap deliberately unequal, so a uniform label grid cannot pass.
set centers [dict get [::RMSXFlipbookTimeline::Render::projected_bounds $ids] centers]
set gap [expr {[lindex $centers 1 0]-[lindex $centers 0 0]}]
set id [lindex $ids 3]
set g [::RMSXFlipbookTimeline::Style::normalize_matrix [molinfo $id get global_matrix]]
lset g 0 3 [expr {[lindex $g 0 3]+0.07*$gap}]
::RMSXFlipbookTimeline::Style::set_molecule_matrix $id global_matrix [dict create global_matrix $g]
set png [file join $root outputs labels.png]
set image_result [::RMSXFlipbookTimeline::Render::render_current output_name $png width 1200]
set svgpath [file join $root outputs labels.svg]
::RMSXFlipbookTimeline::Render::figure_svg $image_result [::RMSXFlipbookTimeline::Results::get] $png $svgpath
set fp [open $svgpath r]; fconfigure $fp -encoding utf-8; set svg [read $fp]; close $fp
# Independent visual reference: silhouette bounds in the actual native PNG.
# The nine upright structures are separated by white columns in this fixture.
set photo [image create photo -file $png]
set runs {}; set start -1
for {set x 0} {$x < [image width $photo]} {incr x} {
    set occupied 0
    for {set y 0} {$y < [image height $photo]} {incr y 2} {
        lassign [$photo get $x $y] r g b
        if {min($r,$g,$b) < 240} {set occupied 1; break}
    }
    if {$occupied && $start < 0} {set start $x}
    if {!$occupied && $start >= 0} {
        if {$x-$start > 8} {lappend runs [list $start [expr {$x-1}]]}
        set start -1
    }
}
image delete $photo
assert {[llength $runs] == 9} "Expected nine separated molecular silhouettes: $runs"
set i 1; set errors {}
foreach run $runs {
    set pattern [format {<text x="([0-9.]+)"[^>]*text-anchor="middle"[^>]*>Slice %d</text>} $i]
    assert {[regexp $pattern $svg unused label_x]} "Missing centered label $i"
    set silhouette_center [expr {([lindex $run 0]+[lindex $run 1])/2.0}]
    set error [expr {abs(($label_x-32)-$silhouette_center)}]
    # Atom-center projection and visible tube radius can differ by a few pixels.
    assert {$error < 6} "Slice $i label misses molecular center by $error pixels"
    lappend errors $error
    incr i
}
puts "Figure label errors against native PNG silhouette centers: $errors"
puts "Figure label alignment smoke passed"
quit
