# Sustained native rotate commands must not scale or shear atom coordinates.
lappend auto_path $::env(RMSX_TEST_PACKAGE)
package require rmsxflipbooktimeline
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set mid [mol new [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files protease_backbone.pdb] waitfor all]
::RMSXFlipbookTimeline::state_set molids [list $mid]
# An oblique view exposes accumulated VMD matrix rounding that identity misses.
molinfo $mid set rotate_matrix [list [transmult [transaxis x 37] [transaxis y 28] [transaxis z 19]]]
set sel [atomselect $mid all]
set initial_center [measure center $sel]
set initial_rg [measure rgyr $sel]
set initial_radii [lmap point [$sel get {x y z}] {vecdist $point $initial_center}]
set initial_values [$sel get {beta user user2}]
::RMSXFlipbookTimeline::install_mouse_rotation
try {
    for {set i 0} {$i < 10000} {incr i} {
        rotate x by 0.3
        rotate y by 0.2
    }
    set center [measure center $sel]
    set final_rg [measure rgyr $sel]
    assert {abs($final_rg-$initial_rg) < 0.01} "Sustained rotation changed molecular size: $initial_rg -> $final_rg"
    assert {[vecdist $center $initial_center] < 0.01} "Rotation moved the molecule's center"
    set max_error 0.0
    foreach radius $initial_radii point [$sel get {x y z}] {
        set max_error [expr {max($max_error,abs([vecdist $point $center]-$radius))}]
    }
    assert {$max_error < 0.01} "Sustained rotation distorted residue distances: $max_error A"
    assert {[$sel get {beta user user2}] eq $initial_values} "Rotation changed scientific fields"
    assert {[dict get [::RMSXFlipbookTimeline::mouse_rotation_status] intercepted] >= 20000} "Native rotation interception was not exercised"
    puts "Rigid rotation: 20000 commands; radius drift [expr {$final_rg-$initial_rg}] A; maximum radial error $max_error A"
} finally {
    ::RMSXFlipbookTimeline::uninstall_mouse_rotation
    $sel delete
}
quit
