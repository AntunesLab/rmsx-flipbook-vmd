# Reproducible native VMD examples; no external analysis/image dependencies.
# Set RMSX_EXAMPLE_REPO and RMSX_EXAMPLE_OUTPUT before launching windowed VMD.
proc rmsx_meeting_examples {} {
    set root [file normalize $::env(RMSX_EXAMPLE_REPO)]
    set out [file normalize $::env(RMSX_EXAMPLE_OUTPUT)]
    lappend ::auto_path $root
    package require rmsxflipbooktimeline 0.3
    set fixtures [file join $root fixtures upstream test_files]
    file mkdir $out
    set single [::RMSXFlipbookTimeline::run_native_analysis [file join $fixtures 1UBQ.pdb] [file join $fixtures mon_sys.dcd] [file join $out ubiquitin] -chain 7 -num_slices 3 -start_frame 0 -end_frame 26 -verbose 0]
    ::RMSXFlipbookTimeline::load_folder [dict get $single output_dir]
    ::RMSXFlipbookTimeline::Results::update [dict create label {Ubiquitin · local fluctuations}]
    ::RMSXFlipbookTimeline::write_flipbook_figure [file join $out ubiquitin.svg]
    set multi [::RMSXFlipbookTimeline::run_native_all_chain_analysis [file join $fixtures protease_backbone.pdb] [file join $fixtures short_protease_backbone.dcd] [file join $out protease] -num_slices 3 -start_frame 0 -end_frame 26 -mask_selection {resid 25:26} -verbose 0]
    ::RMSXFlipbookTimeline::load_folder [dict get $multi combined_dir]
    ::RMSXFlipbookTimeline::Results::update [dict create label {HIV protease · two-chain masked example}]
    ::RMSXFlipbookTimeline::write_flipbook_figure [file join $out protease.svg]
    set fp [open [file join $out COMPLETED.tcldict] w]
    puts $fp [dict create complete 1 version $::RMSXFlipbookTimeline::version vmd [vmdinfo version] single $single multi $multi]
    close $fp
    puts "RMSX_MEETING_EXAMPLES_COMPLETE $out"
}
if {[catch {rmsx_meeting_examples} message options]} {
    puts stderr "RMSX_MEETING_EXAMPLES_FAILED $message\n[dict get $options -errorinfo]"
    exit 1
}
quit
