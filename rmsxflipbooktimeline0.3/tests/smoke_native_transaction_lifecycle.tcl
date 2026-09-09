set package_dir [file dirname [file dirname [file normalize [info script]]]]
set repo [file dirname $package_dir]
lappend auto_path $package_dir
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
if {[info commands molinfo] eq ""} {error "VMD is required for native lifecycle validation"}
set fixtures [file join $repo fixtures]
if {[info exists ::env(RMSX_TEST_WORKDIR)]} {set fixtures [file join $::env(RMSX_TEST_WORKDIR) fixtures]}
set topology [file join $fixtures upstream test_files 1UBQ.pdb]
set trajectory [file join $fixtures upstream test_files mon_sys.dcd]
set temporary_channel [file tempfile root]
close $temporary_channel
file delete $root
set root [file normalize $root]
file mkdir $root
set owned_before [molinfo list]
proc cancel_on_started {event} {
    if {[dict get $event stage] eq "started"} {return cancel}
    return ""
}
try {
    set failed [file join $root invalid]
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $failed -frame_offset 999999 -num_slices 3 -verbose 0}]} "Invalid frame offset accepted"
    assert {[molinfo list] eq $owned_before} "Invalid frame offset leaked a molecule"
    assert {![file exists $failed]} "Invalid frame offset published output"
    set failed [file join $root cancelled]
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $failed -num_slices 3 -verbose 0 -progress_callback cancel_on_started} message options]} "Cancellation did not interrupt analysis"
    assert {[dict get $options -errorcode] eq {RMSXFLIPBOOK CANCELLED}} "Cancellation code changed"
    assert {[molinfo list] eq $owned_before} "Early callback cancellation leaked a molecule"
    assert {![file exists $failed]} "Cancelled analysis published output"
    set output [file join $root complete]
    set result [::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $output -num_slices 3 -chain 7 -verbose 0]
    assert {[dict get $result published] == 1} "Analysis did not publish"
    assert {[dict get $result residue_count] == 76 && [dict get $result slice_count] == 3} "Unexpected native output dimensions"
    assert {[molinfo list] eq $owned_before} "Successful analysis leaked a working molecule"
    set dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $output]
    assert {[dict get $dataset unit] eq "Å" && [dict get $dataset value_label] eq "RMSX"} "Native metric units were not restored from provenance"
    set log_output [file join $root transformed]
    set log_result [::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $log_output -num_slices 3 -chain 7 -verbose 0 -log_transform 1 -csv_name custom.csv]
    set log_dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $log_output]
    assert {[dict get $log_dataset unit] eq "unitless" && [dict get $log_dataset value_label] eq "ln(1 + RMSX)"} "Transformed data was labeled with raw distance units"
    assert {[dict get $log_dataset provenance method transform] eq "ln1p"} "Log transform provenance was lost"
    set original [::RMSXFlipbookTimeline::OutputTxn::inventory $output]
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $output -overwrite 1 -num_slices 3 -progress_callback cancel_on_started -verbose 0}]} "Replacement cancellation did not interrupt analysis"
    assert {[::RMSXFlipbookTimeline::OutputTxn::inventory $output] eq $original} "Cancelled replacement changed previous output bytes"
    assert {[molinfo list] eq $owned_before} "Cancelled replacement leaked a molecule"
    puts "RMSX native transaction lifecycle smoke passed"
} finally {file delete -force $root}
