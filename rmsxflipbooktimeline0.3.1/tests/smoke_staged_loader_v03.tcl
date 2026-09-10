lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set fixture [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files 1UBQ_rmsx chain_7_rmsx]
set before_files [lsort [glob -nocomplain -directory $fixture * .*]]
set source [mol new [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files 1UBQ.pdb] type pdb waitfor all]
set old_source_view [::RMSXFlipbookTimeline::Style::capture_view_matrices [list $source]]
set result [::RMSXFlipbookTimeline::load_folder $fixture]
assert {[dict get $result molecules] == 3} "Wrong slice count"
assert {[lsort [glob -nocomplain -directory $fixture * .*]] eq $before_files} "Read-only load wrote source metadata"
assert {[::RMSXFlipbookTimeline::Style::capture_view_matrices [list $source]] eq $old_source_view} "Loading changed an unrelated molecule's view"
set ids [molinfo list]
set active [::RMSXFlipbookTimeline::Results::get]
set view [::RMSXFlipbookTimeline::Scene::snapshot]
assert {[catch {::RMSXFlipbookTimeline::load_folder [file join $fixture does-not-exist]}]} "Invalid folder was accepted"
assert {[molinfo list] eq $ids && [::RMSXFlipbookTimeline::Results::get] eq $active} "Invalid load destroyed the current result"
set broken [file join $::env(RMSX_TEST_WORKDIR) broken]
file mkdir $broken
file copy [file join $fixture slice_1_first_frame.pdb] [file join $broken slice_1_first_frame.pdb]
set fp [open [file join $broken slice_2_first_frame.pdb] w]; puts $fp "END"; close $fp
assert {[catch {::RMSXFlipbookTimeline::load_folder $broken}]} "Empty second slice accepted"
assert {[molinfo list] eq $ids} "Partial PDB loading leaked molecules"
assert {[::RMSXFlipbookTimeline::Results::get] eq $active} "Partial load replaced current result"
rename ::RMSXFlipbookTimeline::Style::apply ::RMSXFlipbookTimeline::Style::saved_apply
proc ::RMSXFlipbookTimeline::Style::apply {args} {error "injected style failure"}
try {
    assert {[catch {::RMSXFlipbookTimeline::load_folder $fixture}]} "Style failure swallowed"
} finally {
    rename ::RMSXFlipbookTimeline::Style::apply {}
    rename ::RMSXFlipbookTimeline::Style::saved_apply ::RMSXFlipbookTimeline::Style::apply
}
assert {[molinfo list] eq $ids} "Style failure leaked molecules"
assert {[::RMSXFlipbookTimeline::Results::get] eq $active} "Style failure replaced result"
proc reject_activation {candidate} {error "injected activation failure"}
assert {[catch {::RMSXFlipbookTimeline::load_folder $fixture activation_callback reject_activation}]} "Activation failure swallowed"
assert {[molinfo list] eq $ids} "Activation failure leaked molecules"
assert {[::RMSXFlipbookTimeline::Results::get] eq $active} "Activation failure replaced result"
set after [::RMSXFlipbookTimeline::Scene::snapshot]
assert {[dict get $after values] eq [dict get $view values]} "Failed activation changed scene properties"
assert {[dict get $after views] eq [dict get $view views]} "Failed activation changed camera"
::RMSXFlipbookTimeline::reset
assert {[molinfo list] eq [list $source]} "Remove deleted an unrelated molecule or leaked a flipbook"
puts "Staged loader v0.3 smoke passed"
quit
