# Reviewer pure logic must stay usable without importing Tk or launching VMD.
set package_dir [file dirname [file dirname [file normalize [info script]]]]
lappend auto_path $package_dir
package require rmsxflipbooktimeline
source -encoding utf-8 [file join $package_dir gui reviewer.tcl]
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set root [file join [file dirname $package_dir] {review fixture with spaces}]
set single [::RMSXFlipbookTimeline::Reviewer::example_spec $root single]
set multi [::RMSXFlipbookTimeline::Reviewer::example_spec $root multi]
assert {[dict get $single last] == 314 && [dict get $single chain] eq "7" && [dict get $single span] == 35} "Single reviewer defaults changed"
assert {[dict get $multi last] == 26 && [dict get $multi chain] eq "all" && [dict get $multi mask] eq {resid 25:26} && [dict get $multi span] == 3} "Multi reviewer defaults changed"
assert {[dict get $single slices] == 9 && [dict get $multi slices] == 9} "Reviewer does not configure nine slices"
assert {[catch {::RMSXFlipbookTimeline::Reviewer::example_spec $root unknown}]} "Invalid example accepted"
set data [::RMSXFlipbookTimeline::Matrix::create rows {{resid 1} {resid 2}} columns {{frame 0} {frame 9}} values {{0 1} {2 3}}]
::RMSXFlipbookTimeline::Reviewer::check_dataset $data 2 2
assert {[catch {::RMSXFlipbookTimeline::Reviewer::check_dataset [dict replace $data values {{0 0} {0 0}}] 2 2}]} "All-zero fresh RMSX incorrectly passed"
assert {[catch {::RMSXFlipbookTimeline::Reviewer::check_dataset [dict replace $data values {{Inf 1} {2 3}}] 2 2}]} "Nonfinite matrix incorrectly passed"
set ::RMSXFlipbookTimeline::Reviewer::build [string repeat a 64]
set ::RMSXFlipbookTimeline::Reviewer::report [dict create status PASS environment [dict create tcl [info patchlevel] path {C:\review "quoted"}] checks [list [dict create name calculation status RUNNING detail start] [dict create name calculation status PASS detail {finite values}]]]
set json [::RMSXFlipbookTimeline::Reviewer::report_json]
assert {[string first [format {"stages":%c%c"name":"calculation","status":"PASS"} 91 123] $json] >= 0} "Final stages include stale running state"
assert {[string first [format {"checks":%c%c"name":"calculation","status":"RUNNING"} 91 123] $json] >= 0} "Progress history is missing"
assert {[::RMSXFlipbookTimeline::Reviewer::json_string "a\nb\"c"] eq {"a\nb\"c"}} "JSON string escaping failed"
# A failed later attempt replaces the in-memory success before preflight, and
# a failed atomic receipt write keeps the original failure and existing files.
set fp [file tempfile temp rmsx-reviewer-failure-]
close $fp
file delete $temp
file mkdir $temp
set temp [file normalize $temp]
namespace eval ::RMSXFlipbookTimeline::Dashboard {}
proc ::RMSXFlipbookTimeline::Dashboard::unique_run_path {args} {return [file join $::temp check]}
rename ::RMSXFlipbookTimeline::Reviewer::preflight ::RMSXFlipbookTimeline::Reviewer::real_preflight
proc ::RMSXFlipbookTimeline::Reviewer::preflight {root} {error "injected missing reviewer input"}
set ::RMSXFlipbookTimeline::Reviewer::workspace $temp
try {
    assert {[catch {::RMSXFlipbookTimeline::Reviewer::_quick_check} failure]} "Failed preflight was accepted"
    assert {[dict get $::RMSXFlipbookTimeline::Reviewer::report status] eq "FAIL"} "Failed preflight retained prior PASS"
    set fp [open [file join $temp check report.json] r]
    try {set receipt [read $fp]} finally {close $fp}
    assert {[string first {"status":"FAIL"} $receipt] >= 0} "Failed preflight did not save a failure receipt"
    set sentinel "existing report must survive failed write"
    ::RMSXFlipbookTimeline::Reviewer::write_text $sentinel [file join $temp check report.txt]
    rename ::RMSXFlipbookTimeline::Reviewer::write_text ::RMSXFlipbookTimeline::Reviewer::real_write_text
    proc ::RMSXFlipbookTimeline::Reviewer::write_text {args} {error "injected receipt write failure"}
    try {
        dict set ::RMSXFlipbookTimeline::Reviewer::report status PASS
        assert {[catch {::RMSXFlipbookTimeline::Reviewer::_quick_check} failure]} "Receipt failure was accepted"
        assert {[string first "injected missing reviewer input" $failure] >= 0 && [string first "injected receipt write failure" $failure] >= 0} "Receipt write hid original preflight error"
        assert {[dict get $::RMSXFlipbookTimeline::Reviewer::report status] eq "FAIL"} "Receipt failure retained PASS"
        set fp [open [file join $temp check report.txt] r]
        try {set existing [read $fp]} finally {close $fp}
        assert {$existing eq $sentinel} "Failed receipt write clobbered existing destination"
    } finally {
        rename ::RMSXFlipbookTimeline::Reviewer::write_text {}
        rename ::RMSXFlipbookTimeline::Reviewer::real_write_text ::RMSXFlipbookTimeline::Reviewer::write_text
    }
    # Failed initialization remembers the verified workspace, and same-build
    # reload retries initialization without requiring a fresh interpreter.
    set identity [::RMSXFlipbookTimeline::build_id]
    assert {[catch {::RMSXFlipbookTimeline::Reviewer::launch $temp $identity}]} "Injected launch preflight passed"
    assert {$::RMSXFlipbookTimeline::Reviewer::workspace eq $temp && !$::RMSXFlipbookTimeline::Reviewer::active} "Failed launch lost its retry workspace"
    proc ::RMSXFlipbookTimeline::Reviewer::preflight {root} {return {}}
    rename ::RMSXFlipbookTimeline::show_dashboard ::RMSXFlipbookTimeline::real_show_dashboard
    proc ::RMSXFlipbookTimeline::show_dashboard {} {error "injected UI construction failure"}
    try {
        assert {[catch {::RMSXFlipbookTimeline::Reviewer::reopen $identity} failure] && [string first "UI construction" $failure] >= 0} "Inactive reviewer could not retry preflight"
        proc ::RMSXFlipbookTimeline::show_dashboard {} {return .reviewer_mock}
        proc ::vmd_install_extension {args} {}
        proc ::RMSXFlipbookTimeline::Dashboard::set_status {args} {}
        set prior_result [::RMSXFlipbookTimeline::Results::get]
        set ::RMSXFlipbookTimeline::Results::current [dict create label retained]
        try {
            assert {[::RMSXFlipbookTimeline::Reviewer::reopen $identity] eq ".reviewer_mock"} "Same-build retry after UI failure did not reopen"
        } finally {
            set ::RMSXFlipbookTimeline::Results::current $prior_result
            rename ::vmd_install_extension {}
            rename ::RMSXFlipbookTimeline::Dashboard::set_status {}
        }
    } finally {
        rename ::RMSXFlipbookTimeline::show_dashboard {}
        rename ::RMSXFlipbookTimeline::real_show_dashboard ::RMSXFlipbookTimeline::show_dashboard
    }
    # A previously indexed copy of the same version must not win the optional
    # source launcher. The selected path includes spaces and a Unicode name.
    set mock_repo [file join $temp {source launcher π}]
    set mock_package [file join $mock_repo [file tail $package_dir]]
    file mkdir $mock_package
    set selected_version $::RMSXFlipbookTimeline::version
    ::RMSXFlipbookTimeline::Reviewer::write_text $selected_version [file join $mock_package VERSION]
    ::RMSXFlipbookTimeline::Reviewer::write_text {
        namespace eval ::RMSXFlipbookTimeline {
            variable basedir [file dirname [info script]]
            proc package_root {} {variable basedir; return $basedir}
            proc build_id {} {return source-checkout}
        }
        namespace eval ::RMSXFlipbookTimeline::Reviewer {
            variable active 1
            proc launch {args} {error "Already-active source launch should reopen"}
            proc reopen {identity} {return reopened-selected-copy}
        }
        package provide rmsxflipbooktimeline [string trim [read [set channel [open [file join [file dirname [info script]] VERSION] r]]]]
        close $channel
    } [file join $mock_package rmsxflipbooktimeline.tcl]
    ::RMSXFlipbookTimeline::Reviewer::write_text [format {package ifneeded rmsxflipbooktimeline %s [list source -encoding utf-8 [file join $dir rmsxflipbooktimeline.tcl]]} $selected_version] [file join $mock_package pkgIndex.tcl]
    set child [interp create]
    try {
        $child eval {set RMSX_REVIEWER_START_LIBRARY_ONLY 1}
        $child eval [list source -encoding utf-8 [file join [file dirname $package_dir] scripts reviewer_start.tcl]]
        $child eval [list package ifneeded rmsxflipbooktimeline $selected_version {error "wrong previously indexed copy loaded"}]
        assert {[$child eval [list ::RMSXReviewerStart::start $mock_repo]] eq "reopened-selected-copy"} "Source launcher used a stale same-version index"
        assert {[$child eval {::RMSXFlipbookTimeline::package_root}] eq $mock_package} "Source launcher selected wrong package root"
    } finally {interp delete $child}
} finally {
    rename ::RMSXFlipbookTimeline::Reviewer::preflight {}
    rename ::RMSXFlipbookTimeline::Reviewer::real_preflight ::RMSXFlipbookTimeline::Reviewer::preflight
    rename ::RMSXFlipbookTimeline::Dashboard::unique_run_path {}
    file delete -force $temp
}
assert {[info commands winfo] eq ""} "Reviewer pure logic loaded Tk"
puts "RMSX reviewer runtime smoke passed"
