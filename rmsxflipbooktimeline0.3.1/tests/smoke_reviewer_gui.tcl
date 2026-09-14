# External GUI harness owns process completion; reviewer runtime never exits VMD.
set package_dir $::env(RMSX_TEST_PACKAGE)
lappend auto_path $package_dir
package require rmsxflipbooktimeline
source -encoding utf-8 [file join $package_dir gui reviewer.tcl]
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc assert_reviewer_plot_frames {current} {
    set prepared [::RMSXFlipbookTimeline::PlotWindow::prepare folder [dict get $current folder]]
    set layout [dict get $prepared layout]
    set expected {}
    foreach column [dict get $current dataset columns] {
        lappend expected "[dict get $column frame_start]–[dict get $column frame_end]"
    }
    assert {[dict get $layout x_axis_title] eq "Frames" && [dict get $layout x_axis_unit] eq ""} "Comparison plot invented physical time"
    assert {[dict get $layout x_axis_labels] eq $expected} "Comparison plot did not use current-result frame windows"
    foreach record [dict get $layout cell_records] {
        set message [::RMSXFlipbookTimeline::PlotWindow::status_for_record $record]
        assert {[string first ", frames " $message] >= 0 && [string first ", time " $message] < 0} "Heatmap hover/click status mislabeled frame bounds as time"
    }
}
set review_guard [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files 1UBQ.pdb]]
set review_guard_drawn [molinfo $review_guard get drawn]
set reviewer_stage 0
proc reviewer_next {} {
    global reviewer_stage review_guard review_guard_drawn
    if {[::RMSXFlipbookTimeline::Operation::running]} {after 100 reviewer_next; return}
    set current [::RMSXFlipbookTimeline::Results::get]
    switch -- $reviewer_stage {
        0 {
            assert {$current ne {} && [dict get $current reviewer_preview] && [llength [dict get $current molids]] == 9} "Automatic nine-slice precomputed preview did not load"
            assert {$::RMSXFlipbookTimeline::Dashboard::native_total_frames == 316 && $::RMSXFlipbookTimeline::Dashboard::native_end == 314} "Single preview source count or selected range is incorrect"
            assert {$::RMSXFlipbookTimeline::Dashboard::native_time_step eq "" && $::RMSXFlipbookTimeline::Dashboard::native_detected_time_step_ps eq ""} "Reviewer inferred physical time"
            assert {[dict get [lindex [dict get $current dataset columns] end] frame_end] == 314} "Preview export bounds are missing"
            foreach column [dict get $current dataset columns] {assert {[dict exists $column slice_molid] && ![dict exists $column time]} "Preview metadata lost slice linking or invented time"}
            assert {[molinfo $review_guard get drawn] eq $review_guard_drawn} "Preview changed an unrelated molecule's visibility"
            set before [molinfo list]
            ::RMSXFlipbookTimeline::Reviewer::reopen [::RMSXFlipbookTimeline::build_id]
            assert {[molinfo list] eq $before} "Reopen duplicated molecules"
            set top $::RMSXFlipbookTimeline::Dashboard::top
            assert {[llength [$top.tabs tabs]] == 5 && [winfo exists $top.header.reviewer]} "Reviewer changed the five tabs or omitted toolbar"
            assert {[catch {::RMSXFlipbookTimeline::Reviewer::reopen different_build}]} "Different build reopened without rejection"
            assert_reviewer_plot_frames $current
            ::RMSXFlipbookTimeline::Reviewer::quick_check
        }
        1 {
            assert {[dict get $::RMSXFlipbookTimeline::Reviewer::report status] eq "PASS"} "Quick Check did not pass: $::RMSXFlipbookTimeline::Reviewer::report"
            assert {[file isfile "[file rootname $::RMSXFlipbookTimeline::Reviewer::report_path].json"]} "Machine-readable report is missing"
            assert {[llength [dict get $current molids]] == 9 && [dict get $current reviewer_preview]} "Quick Check replaced the displayed preview"
            ::RMSXFlipbookTimeline::Reviewer::select_example multi
        }
        2 {
            assert {[llength [dict get $current molids]] == 9 && [dict get $current reviewer_preview]} "Multi preview did not load"
            assert {$::RMSXFlipbookTimeline::Dashboard::native_mask_selection eq {resid 25:26} && $::RMSXFlipbookTimeline::Dashboard::native_end == 26} "Multi inputs/mask not configured"
            assert {$::RMSXFlipbookTimeline::Dashboard::native_time_step eq "" && $::RMSXFlipbookTimeline::Dashboard::native_detected_time_step_ps eq ""} "Multi reviewer inferred physical time"
            assert_reviewer_plot_frames $current
            set run [::RMSXFlipbookTimeline::Dashboard::easy_child actions].run
            assert {[$run cget -state] ne "disabled"} "Existing Run button is disabled for reviewer inputs"
            $run invoke
        }
        3 {
            assert {[dict get [::RMSXFlipbookTimeline::Operation::get] state] eq "complete"} "Fresh Run failed"
            assert {![dict exists $current reviewer_preview] && [dict get $current dataset column_count] == 9} "Fresh result is still labeled precomputed or has wrong window count"
            assert {$::RMSXFlipbookTimeline::Dashboard::native_total_frames == 27} "Fresh Run included the topology frame in the trajectory count"
            foreach column [dict get $current dataset columns] {assert {![dict exists $column time]} "Fresh reviewer Run invented physical time"}
            assert {[molinfo $review_guard get drawn] eq $review_guard_drawn} "Fresh Run changed unrelated visibility"
            assert_reviewer_plot_frames $current
            ::RMSXFlipbookTimeline::Reviewer::quick_check
        }
        4 {
            assert {[dict get $::RMSXFlipbookTimeline::Reviewer::report status] eq "PASS"} "Multichain Quick Check did not pass: $::RMSXFlipbookTimeline::Reviewer::report"
            assert {[dict get $current dataset column_count] == 9 && ![dict exists $current reviewer_preview]} "Multichain Quick Check replaced the fresh result"
            ::RMSXFlipbookTimeline::Reviewer::quick_check
            ::RMSXFlipbookTimeline::Operation::request_cancel
        }
        5 {
            assert {[dict get $::RMSXFlipbookTimeline::Reviewer::report status] eq "CANCELLED"} "Quick Check cancellation not recorded"
            assert {[dict get [::RMSXFlipbookTimeline::Operation::get] state] eq "cancelled"} "Cancellation did not settle operation"
            assert {[lsearch -exact [molinfo list] $review_guard] >= 0} "Reviewer deleted unrelated molecule"
            puts "RMSX reviewer GUI smoke passed"
            quit
            return
        }
    }
    incr reviewer_stage
    after 100 reviewer_next
}
::RMSXFlipbookTimeline::Reviewer::launch $::env(RMSX_TEST_WORKDIR) [::RMSXFlipbookTimeline::build_id]
after 100 reviewer_next
