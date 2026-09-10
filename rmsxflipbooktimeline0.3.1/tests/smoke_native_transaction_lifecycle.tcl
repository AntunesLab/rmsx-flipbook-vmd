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
set ::completed_chains 0
proc fail_on_later_chain {event} {
    if {[dict get $event stage] eq "chain_complete"} {incr ::completed_chains}
    if {[dict get $event stage] eq "chain_started" && [dict get $event chain_index] == 2} {return -code error -errorcode {RMSX_TEST LATE_CHAIN} "Injected later-chain failure"}
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
    set result [::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $output -num_slices 3 -chain 7 -verbose 0 -rmsd_time_step 0.04888821]
    assert {[dict get $result published] == 1} "Analysis did not publish"
    assert {[dict get $result residue_count] == 76 && [dict get $result slice_count] == 3} "Unexpected native output dimensions"
    assert {[molinfo list] eq $owned_before} "Successful analysis leaked a working molecule"
    set dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $output]
    assert {[dict get $dataset unit] eq "Å" && [dict get $dataset value_label] eq "RMSX"} "Native metric units were not restored from provenance"
    set column [lindex [dict get $dataset columns] 0]
    assert {[dict get $column frame_start] == 0 && [dict get $column frame_end] > 0 && [dict get $column time_unit] eq "ps"} "Native slice frame/time bounds were lost"
    set log_output [file join $root transformed]
    set log_result [::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $log_output -num_slices 3 -chain 7 -verbose 0 -log_transform 1 -csv_name custom.csv]
    set log_dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $log_output]
    assert {[dict get $log_dataset unit] eq "unitless" && [dict get $log_dataset value_label] eq "ln(1 + RMSX)"} "Transformed data was labeled with raw distance units"
    assert {[dict get $log_dataset provenance method transform] eq "ln1p"} "Log transform provenance was lost"
    set unknown_output [file join $root unknown_time]
    set unknown [::RMSXFlipbookTimeline::NativeAnalysis::run_all_chains $topology $trajectory $unknown_output -num_slices 3 -verbose 0 -time_known 0 -name_style rmsx]
    assert {[dict get $unknown method time_unit] eq "unknown" && [dict get $unknown method time_step_ps] eq ""} "Unknown time acquired a physical unit"
    set child [lindex [dict get $unknown chain_results] 0]
    set data [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv [dict get $child rmsd_csv]]
    assert {[dict get $data header] eq {Frame RMSD}} "Unknown time wrote invented physical times"
    assert {[string match *_frames.csv [file tail [dict get $child csv]]]} "Unknown time filename invented nanoseconds"
    set unknown_dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder [dict get $child output_dir]]
    set column [lindex [dict get $unknown_dataset columns] 0]
    assert {[dict exists $column frame_start] && ![dict exists $column time] && ![dict exists $column time_unit]} "Unknown-time matrix invented physical column times"
    set original [::RMSXFlipbookTimeline::OutputTxn::inventory $output]
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $output -overwrite 1 -num_slices 3 -progress_callback cancel_on_started -verbose 0}]} "Replacement cancellation did not interrupt analysis"
    assert {[::RMSXFlipbookTimeline::OutputTxn::inventory $output] eq $original} "Cancelled replacement changed previous output bytes"
    assert {[molinfo list] eq $owned_before} "Cancelled replacement leaked a molecule"
    rename ::RMSXFlipbookTimeline::ResidueIdentity::write_pdb_body ::RMSXFlipbookTimeline::ResidueIdentity::saved_writer
    proc ::RMSXFlipbookTimeline::ResidueIdentity::write_pdb_body {selection path} {
        set fp [open $path w]; puts $fp "partial output"; close $fp
        return -code error -errorcode {RMSX_TEST WRITE} "Injected PDB writer failure"
    }
    try {
        assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $output -overwrite 1 -num_slices 3 -verbose 0}]} "Injected writer failure did not stop analysis"
    } finally {
        rename ::RMSXFlipbookTimeline::ResidueIdentity::write_pdb_body {}
        rename ::RMSXFlipbookTimeline::ResidueIdentity::saved_writer ::RMSXFlipbookTimeline::ResidueIdentity::write_pdb_body
    }
    assert {[::RMSXFlipbookTimeline::OutputTxn::inventory $output] eq $original && [molinfo list] eq $owned_before} "Writer failure changed previous bytes or leaked a molecule"
    set multi_topology [file join $fixtures upstream test_files protease_backbone.pdb]
    set multi_trajectory [file join $fixtures upstream test_files short_protease_backbone.dcd]
    set multi_output [file join $root multichain]
    set multi [::RMSXFlipbookTimeline::NativeAnalysis::run_all_chains $multi_topology $multi_trajectory $multi_output -num_slices 3 -start_frame 0 -end_frame 8 -verbose 0]
    foreach key {chain_dirs csv_paths} {
        foreach path [dict get $multi $key] {assert {[file exists $path]} "Published $key still references private staging: $path"}
    }
    foreach child [dict get $multi chain_results] {
        foreach key {csv rmsd_csv} {assert {[file exists [dict get $child $key]]} "Published child result references private staging"}
    }
    foreach directory [linsert [dict get $multi chain_dirs] 0 $multi_output] {
        set metadata [::RMSXFlipbookTimeline::OutputTxn::read_dict [file join $directory .rmsx_output_manifest.tcldict]]
        assert {[string first .rmsx-txn- $metadata] < 0} "Published ownership/provenance metadata contains a private staging path"
    }
    set prior_multi [::RMSXFlipbookTimeline::OutputTxn::inventory $multi_output]
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::run_all_chains $multi_topology $multi_trajectory $multi_output -num_slices 3 -start_frame 0 -end_frame 8 -verbose 0 -overwrite 1 -progress_callback fail_on_later_chain}]} "Later-chain failure did not stop analysis"
    assert {$::completed_chains == 1} "Failure was not injected after a completed first chain"
    assert {[::RMSXFlipbookTimeline::OutputTxn::inventory $multi_output] eq $prior_multi && [molinfo list] eq $owned_before} "Later-chain failure changed previous bytes or leaked a molecule"
    puts "RMSX native transaction lifecycle smoke passed"
} finally {file delete -force $root}
