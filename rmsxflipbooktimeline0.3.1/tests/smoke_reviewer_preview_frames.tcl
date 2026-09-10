# Verify the displayed preview structures against the actual bundled frame
# coordinates; alignment is used only for this comparison, never for analysis.
set package_dir $::env(RMSX_TEST_PACKAGE)
lappend auto_path $package_dir
package require rmsxflipbooktimeline
source -encoding utf-8 [file join $package_dir gui reviewer.tcl]
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
foreach kind {single multi} {
    set spec [::RMSXFlipbookTimeline::Reviewer::example_spec $::env(RMSX_TEST_WORKDIR) $kind]
    set data [::RMSXFlipbookTimeline::Reviewer::preview_dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder [dict get $spec preview]] $spec]
    set representatives [::RMSXFlipbookTimeline::Reviewer::fixture_rows $spec]
    assert {[llength $representatives] == [dict get $spec rows]} "Preview shape differs from the actual protein/CA representative selection"
    set live [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb [dict get $spec topology]]
    animate delete beg 0 end -1 $live
    mol addfile [dict get $spec trajectory] molid $live waitfor all
    assert {[molinfo $live get numframes] == [dict get $spec total_frames]} "Reviewer source frame count is incorrect"
    set all [atomselect $live all]
    set atom_indices {}; set index 0
    foreach identity [$all get {segname resid insertion resname name}] {
        assert {![dict exists $atom_indices $identity]} "Ambiguous fixture atom identity"
        dict set atom_indices $identity $index
        incr index
    }
    $all delete
    foreach column [dict get $data columns] {
        set number [dict get $column slice_number]
        set candidate [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb [dict get $column slice_file]]
        set seed [atomselect $candidate all]
        set wanted [$seed get {segname resid insertion resname name}]
        set indices [lmap identity $wanted {dict get $atom_indices $identity}]
        set source [atomselect $live "index [join $indices { }]" frame [dict get $column frame_start]]
        assert {[$source num] == [$seed num] && [$source get {segname resid insertion resname name}] eq $wanted} "Preview atoms do not match the trajectory identity/count"
        if {$kind eq "multi"} {
            assert {[$source get chain] eq [$seed get chain]} "Preview changed multichain identity"
        } else {
            assert {[lsort -unique [$source get chain]] eq {{}} && [lsort -unique [$seed get chain]] eq {X}} "Unexpected legacy single-chain conversion"
        }
        $seed move [measure fit $seed $source]
        set rmsd [measure rmsd $seed $source]
        assert {$rmsd <= 0.002} "Preview $kind slice $number does not match frame [dict get $column frame_start]: RMSD=$rmsd"
        assert {![dict exists $column time] && ![dict exists $column time_unit] && [dict get $column frame_end] == [dict get $column frame_start]+[dict get $spec span]-1} "Preview has invented time or invalid bounds"
        puts "Verified $kind slice=$number frames=[dict get $column frame_start]-[dict get $column frame_end] atoms=[$seed num] rmsd=$rmsd"
        $source delete; $seed delete; mol delete $candidate
    }
    mol delete $live
}
puts "RMSX reviewer preview frames smoke passed"
quit
