# Real geometry evidence, independent of merely assigning the user field.
lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline
set folder [file join $::env(RMSX_TEST_WORKDIR) fixtures seed_outputs native-rmsx-1ubq-9 chain_7_rmsx]
::RMSXFlipbookTimeline::load_folder $folder view_preset current
set molid [lindex [::RMSXFlipbookTimeline::state_get molids] 0]
set actual [lindex [lindex [molinfo $molid get {{representation 0}}] 0] 0]
if {[package vcompare [vmdinfo version] 2.0a1] < 0} {
    if {$actual ne "NewCartoon"} {error "Legacy VMD must default to a residue-modulating representation, got $actual"}
    if {[lsearch -exact [::RMSXFlipbookTimeline::Style::representation_choices] NewTube] >= 0} {error "Legacy VMD offers unavailable NewTube"}
} elseif {$actual ne "NewTube"} {error "Modern VMD lost its NewTube default"}
set before [::RMSXFlipbookTimeline::Scene::snapshot]
set selection [atomselect $molid all]
set original [$selection get user]
try {
    set evidence [::RMSXFlipbookTimeline::Render::verify_residue_thickness $molid [file join $::env(RMSX_TEST_WORKDIR) outputs]]
    if {[$selection get user] ne $original} {error "Thickness check changed scientific display values"}
    set after [::RMSXFlipbookTimeline::Scene::snapshot]
    foreach key {values views visibility top} {
        if {[dict get $before $key] ne [dict get $after $key]} {error "Thickness check failed to restore $key"}
    }
    puts "Residue thickness render passed: $evidence"
} finally {$selection delete}
quit
