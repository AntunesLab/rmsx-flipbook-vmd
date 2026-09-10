set package_dir [file dirname [file dirname [file normalize [info script]]]]
set repo [file dirname $package_dir]
lappend auto_path $package_dir
package require rmsxflipbooktimeline 0.3
# Exercise the opt-in viewer's identity adapter without requiring a Tk window.
if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::build_records] eq ""} {
    source -encoding utf-8 [file join $package_dir visualization viewer_plot.tcl]
}
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set fixtures [file join $repo fixtures]
if {[info exists ::env(RMSX_TEST_WORKDIR)]} {set fixtures [file join $::env(RMSX_TEST_WORKDIR) fixtures]}
set tuples {{A SEG1 42 {} 0} {A SEG1 42 A 0} {A SEG2 42 {} 0} {X SEG3 42 {} 0} {{} SEG3 42 {} 0} {A SEG1 42 {} 1}}
set input [open [file join $fixtures upstream test_files 1UBQ.pdb] r]
set output [file tempfile fixture]
try {
    while {[gets $input line] >= 0} {
        if {[string range $line 0 5] in {{ATOM  } HETATM}} {
            set resid [string trim [string range $line 22 25]]
            if {[string is integer -strict $resid] && $resid >= 1 && $resid <= 6} {
                lassign [lindex $tuples [expr {$resid-1}]] chain segid resid insertion ordinal
                set line [format %-80s $line]
                set line [string replace $line 21 26 [format {%1s%4s%1s} $chain $resid $insertion]]
                set line [string replace $line 72 75 [format %-4s $segid]]
            }
        }
        puts $output $line
    }
} finally {close $input; close $output}
set molid [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb $fixture]
set snapshot ""; set path ""; set roundtrip ""; set roundtrip_path ""
try {
    set sel [atomselect $molid all]
    try {set records [lrange [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $sel] 0 5]} finally {$sel delete}
    set portable [lmap record $records {::RMSXFlipbookTimeline::ResidueIdentity::portable $record}]
    set channel [file tempfile roundtrip_path]
    close $channel
    set sel [atomselect $molid all]
    try {
        set original_coordinates [$sel get {x y z}]
        set original_identities [lmap record [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $sel] {::RMSXFlipbookTimeline::ResidueIdentity::key $record}]
        ::RMSXFlipbookTimeline::ResidueIdentity::write_pdb $sel $roundtrip_path
    } finally {$sel delete}
    set input [open $roundtrip_path rb]
    try {assert {[string first "\u0000" [read $input]] < 0} "PDB writer emitted an invalid blank-chain NUL byte"} finally {close $input}
    set roundtrip [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb $roundtrip_path]
    set sel [atomselect $roundtrip all]
    try {
        assert {[$sel get {x y z}] eq $original_coordinates} "Identity restoration changed coordinates"
        assert {[lmap record [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $sel] {::RMSXFlipbookTimeline::ResidueIdentity::key $record}] eq $original_identities} "PDB round trip merged blank/X, insertion or repeated residues"
    } finally {$sel delete}
    set n 0
    foreach record $portable tuple $tuples {
        assert {[::RMSXFlipbookTimeline::ResidueIdentity::key $record] eq $tuple} "Fixture identity changed: expected $tuple, found [::RMSXFlipbookTimeline::ResidueIdentity::key $record]"
        foreach selector {::RMSXFlipbookTimeline::ViewerPlot::selection_for_record ::RMSXFlipbookTimeline::ResidueIdentity::selection} {
            set sel [atomselect $molid [$selector $record $molid]]
            try {assert {[lsort -unique [$sel get residue]] eq [list $n]} "Viewer selection crossed a residue boundary"} finally {$sel delete}
        }
        set selection [::RMSXFlipbookTimeline::NeighborhoodFlipbook::row_identity_selection $record all $molid]
        set sel [atomselect $molid $selection]
        try {assert {[lsort -unique [$sel get residue]] eq [list $n]} "Neighborhood selection crossed a residue boundary"} finally {$sel delete}
        incr n
    }
    set legacy [dict create resid 42 chain A]
    assert {[catch {::RMSXFlipbookTimeline::NeighborhoodFlipbook::row_identity_selection $legacy all $molid}]} "Neighborhood silently accepted ambiguous legacy numbering"
    assert {[catch {::RMSXFlipbookTimeline::ViewerPlot::selection_for_record $legacy $molid}]} "Viewer silently accepted ambiguous legacy numbering"

    ::RMSXFlipbookTimeline::state_set molids [list $molid]
    set matrix [dict create residues $portable columns {{slice_1.dcd {1 2 3 4 5 6}}}]
    set layout [::RMSXFlipbookTimeline::ViewerPlot::build_records $matrix summary 0]
    set cells [dict get $layout records]
    assert {[lmap cell $cells {::RMSXFlipbookTimeline::ResidueIdentity::key $cell}] eq $tuples} "Viewer layout dropped residue identity fields"
    ::RMSXFlipbookTimeline::ViewerPlot::install_record_map $cells
    foreach record $records cell $cells {
        set mapped [::RMSXFlipbookTimeline::ViewerPlot::record_for_structure_identity 1 $record]
        assert {[dict get $mapped row] == [dict get $cell row]} "Reverse structure pick selected the wrong row"
    }
    assert {[catch {::RMSXFlipbookTimeline::ViewerPlot::record_for_structure_residue 1 42 A SEG1}]} "Legacy reverse pick guessed among insertion/occurrence variants"
    set missing [dict replace [lindex $records 0] segid ABSENT]
    assert {[::RMSXFlipbookTimeline::ViewerPlot::record_for_structure_identity 1 $missing] eq {}} "Reverse pick used a same-number fallback"

    # A subset PDB renumbers the second identical residue as occurrence zero.
    # The explicit atom-order map must still connect source occurrence one.
    set repeated [lindex $portable 5]
    set dataset [dict create rows [list $repeated]]
    set path [::RMSXFlipbookTimeline::NeighborhoodFlipbook::write_snapshot_pdb $molid 0 $dataset 0]
    set snapshot [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb $path]
    ::RMSXFlipbookTimeline::NeighborhoodFlipbook::install_snapshot_identity_map $molid 0 {residue 5} $snapshot
    set selection [::RMSXFlipbookTimeline::NeighborhoodFlipbook::row_identity_selection $repeated all $snapshot]
    set sel [atomselect $snapshot $selection]
    try {assert {[$sel num] == [molinfo $snapshot get numatoms] && [$sel num] > 0} "Snapshot subset lost repeated residue identity"} finally {$sel delete}
    assert {[catch {::RMSXFlipbookTimeline::NeighborhoodFlipbook::row_identity_selection [lindex $portable 0] all $snapshot}]} "Snapshot silently selected the wrong occurrence"

    # Segment-first all-chain groups must be disjoint even when a chain name
    # equals another segment name, and blank fields still form a valid group.
    set i 0
    foreach pair {{B A} {A B} {A {}} {{} {}}} {
        lassign $pair chain segid
        set sel [atomselect $molid "residue $i"]
        try {$sel set chain [list $chain]; $sel set segid [list $segid]} finally {$sel delete}
        incr i
    }
    set groups [::RMSXFlipbookTimeline::NativeAnalysis::chain_groups_for_molecule $molid {residue 0 to 3}]
    assert {[llength $groups] == 4} "Blank or colliding chain groups disappeared"
    set seen {}
    foreach group $groups {
        set sel [atomselect $molid [::RMSXFlipbookTimeline::NativeAnalysis::append_chain_selection {residue 0 to 3} $group $molid]]
        try {
            assert {[$sel num] > 0} "Discovered chain group is empty"
            foreach index [$sel get index] {
                assert {![dict exists $seen $index]} "All-chain groups overlap"
                dict set seen $index 1
            }
        } finally {$sel delete}
    }
    set sel [atomselect $molid {residue 0 to 3}]
    try {assert {[dict size $seen] == [$sel num]} "All-chain groups omitted atoms"} finally {$sel delete}
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::append_chain_selection all A $molid}]} "Ambiguous public chain alias guessed a selection"
    set protected_digest [::RMSXFlipbookTimeline::OutputTxn::digest $roundtrip_path]
    set sel [atomselect $molid {residue 0}]
    try {
        $sel set segid TOOLONG
        assert {[catch {::RMSXFlipbookTimeline::ResidueIdentity::write_pdb $sel $roundtrip_path}]} "PDB writer silently truncated residue identity"
    } finally {$sel delete}
    assert {[::RMSXFlipbookTimeline::OutputTxn::digest $roundtrip_path] eq $protected_digest} "Unrepresentable PDB export changed a prior file"
    puts "RMSX linked residue identity smoke passed"
} finally {
    if {$snapshot ne ""} {catch {mol delete $snapshot}}
    if {$roundtrip ne ""} {catch {mol delete $roundtrip}}
    if {$roundtrip_path ne ""} {catch {file delete $roundtrip_path}}
    if {$path ne ""} {catch {file delete $path}}
    catch {mol delete $molid}
    catch {file delete $fixture}
    ::RMSXFlipbookTimeline::state_set molids {}
}
