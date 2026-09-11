lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set folder [file join $::env(RMSX_TEST_WORKDIR) fixtures seed_outputs reviewer-protease-9 combined]
set fixture [file join $folder slice_1_first_frame.pdb]
set source [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb $fixture]
set atoms [atomselect $source all]
set source_coords [$atoms get {x y z}]
set a [atomselect $source {chain A}];set b [atomselect $source {chain B}]
set separation [vecdist [measure center $a] [measure center $b]]
$a delete;$b delete
set result [::RMSXFlipbookTimeline::load_folder $folder]
assert {[dict get $result view_preset] eq "principal"} "Default result orientation is not principal axes"
assert {[$atoms get {x y z}] eq $source_coords} "Display orientation altered the unrelated source molecule"
set ids [dict get $result molids]
foreach id $ids {
    set s [atomselect $id {protein and name CA}]
    set answer [::RMSXFlipbookTimeline::PrincipalView::axes [$s get {x y z}]]
    $s delete
    assert {abs([lindex [dict get $answer axes] 0 1])>0.99999} "A slice's longest axis is not vertical"
}
set first [lindex $ids 0]
set a [atomselect $first {chain A}];set b [atomselect $first {chain B}]
assert {abs([vecdist [measure center $a] [measure center $b]]-$separation)<0.001} "Principal view changed the multichain interface"
$a delete;$b delete
set before [::RMSXFlipbookTimeline::PrincipalView::axes $source_coords]
::RMSXFlipbookTimeline::Hotkeys::rotate_all y 25
rock y by 2 -1
::RMSXFlipbookTimeline::reset_view
for {set tick 0} {$tick<10} {incr tick} {display update; display update ui}
set s [atomselect $first {protein and name CA}]
set answer [::RMSXFlipbookTimeline::PrincipalView::axes [$s get {x y z}]];$s delete
assert {abs([lindex [dict get $answer axes] 0 1])>0.99999} "Reset did not restore vertical principal orientation"
::RMSXFlipbookTimeline::Hotkeys::adjust_spacing 3
set bounds [::RMSXFlipbookTimeline::Render::projected_bounds $ids]
lassign [display get size] w h
set halfheight [expr {0.25*[display get height]}]
assert {[dict get $bounds xmin]>-$halfheight*$w/double($h) && [dict get $bounds xmax]<$halfheight*$w/double($h)} "Fitted row is outside the viewport"
assert {[$atoms get {x y z}] eq $source_coords} "Reset or spacing altered the source"
set manifest [file join $::env(RMSX_TEST_WORKDIR) outputs principal-session.tcldict]
::RMSXFlipbookTimeline::Manifest::write $manifest
set reloaded [::RMSXFlipbookTimeline::load_manifest $manifest]
assert {[dict get $reloaded view_preset] eq "principal"} "Manifest reload used a different default view"
assert {[::RMSXFlipbookTimeline::apply_view_preset] eq "principal"} "Public default view is not upright"
$atoms delete
puts "Principal display regression passed for nine multichain slices"
quit
