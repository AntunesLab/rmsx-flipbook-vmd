lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set folder [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files 1UBQ_rmsx chain_7_rmsx]
color Display Background blue
set background [::RMSXFlipbookTimeline::Scene::read background]
set palette [::RMSXFlipbookTimeline::Scene::read palette]
set live_before {}
foreach key {rendermode antialias} {
    if {![catch {::RMSXFlipbookTimeline::Scene::read $key} value]} {dict set live_before $key $value}
}
set transparent [material settings Transparent]
user add key u {puts CUSTOM_BEFORE}
::RMSXFlipbookTimeline::load_folder $folder
set ids [molinfo list]
set display_background [::RMSXFlipbookTimeline::Scene::read background]
::RMSXFlipbookTimeline::Hotkeys::install
::RMSXFlipbookTimeline::install_mouse_rotation
::RMSXFlipbookTimeline::cleanup_side_effects 0 {window input}
assert {[molinfo list] eq $ids} "Closing removed the scene"
assert {[::RMSXFlipbookTimeline::Scene::read background] eq $display_background} "Closing changed scene appearance"
set keys [::RMSXFlipbookTimeline::Hotkeys::key_bindings]
assert {[lindex [dict get $keys u] 0] eq {puts CUSTOM_BEFORE}} "Closing failed to restore custom hotkey"
::RMSXFlipbookTimeline::reset
assert {[molinfo list] eq {}} "Remove leaked plugin molecules"
assert {[::RMSXFlipbookTimeline::Scene::read background] eq $background} "Remove failed to restore background"
assert {[::RMSXFlipbookTimeline::Scene::read palette] eq $palette} "Remove failed to restore palette"
dict for {key value} $live_before {
    assert {[::RMSXFlipbookTimeline::Scene::read $key] eq $value} "Remove failed to restore $key"
}
assert {[material settings Transparent] eq $transparent} "Plugin modified shared Transparent material"
::RMSXFlipbookTimeline::load_folder $folder
color Display Background red
if {[dict exists $live_before antialias]} {display antialias off}
if {[dict exists $live_before rendermode] && [display get rendermode] ne "Normal"} {display rendermode Normal}
set red [::RMSXFlipbookTimeline::Scene::read background]
::RMSXFlipbookTimeline::Hotkeys::install
user add key u {puts CUSTOM_AFTER}
::RMSXFlipbookTimeline::reset
assert {[::RMSXFlipbookTimeline::Scene::read background] eq $red} "Cleanup overwrote later user background"
if {[dict exists $live_before antialias]} {assert {[display get antialias] eq "off"} "Cleanup overwrote later antialias setting"}
if {[dict exists $live_before rendermode]} {assert {[display get rendermode] eq "Normal"} "Cleanup overwrote later render mode"}
assert {[lindex [dict get [::RMSXFlipbookTimeline::Hotkeys::key_bindings] u] 0] eq {puts CUSTOM_AFTER}} "Cleanup overwrote later hotkey edit"
set order {}
::RMSXFlipbookTimeline::Effects::register test_first {lappend ::order first} operation 1
::RMSXFlipbookTimeline::Effects::register test_bad {lappend ::order bad; error fail} operation 1
::RMSXFlipbookTimeline::Effects::register test_last {lappend ::order last} operation 1
assert {[catch {::RMSXFlipbookTimeline::Effects::cleanup_all {operation}}]} "Cleanup error disappeared"
assert {$order eq {last bad first}} "Cleanup order wrong or stopped after failure"
::RMSXFlipbookTimeline::Effects::unregister test_bad
puts "Session lifecycle v0.3 smoke passed"
quit
