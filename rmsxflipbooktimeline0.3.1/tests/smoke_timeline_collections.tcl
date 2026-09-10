# Ordinary Tcl: collection transactions and identity/frame remapping, with no GUI.
set package_dir [file dirname [file dirname [file normalize [info script]]]]
lappend auto_path $package_dir
package require rmsxflipbooktimeline 0.3
if {[info commands ::RMSXFlipbookTimeline::Collections::load] eq ""} {source [file join $package_dir core collections.tcl]}
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc full_row {chain segment resid insertion ordinal} {
    return [dict create identity_schema 2 chain $chain segid $segment resid $resid insertion $insertion ordinal $ordinal row_mode residue]
}
proc make_matrix {title rows frames} {
    set columns {}; set values {}
    foreach frame $frames {
        lappend columns [dict create frame $frame label "arbitrary label" target_type frame index [llength $columns]]
        lappend values [lrepeat [llength $rows] 1]
    }
    return [::RMSXFlipbookTimeline::Matrix::create title $title rows $rows columns $columns values $values provenance [dict create source_identity collection_fixture]]
}
namespace eval ::CollectionBindingFixture {
    variable active {}
    variable serial 0
    proc molinfo {id args} {
        if {$id eq "top"} {return 7}
        if {$id eq "list"} {return {7}}
        if {$id == 7 && $args eq {get numframes}} {return 40}
        error "Unexpected mocked molinfo: $id $args"
    }
    proc selection {molid query args} {
        variable serial; variable active
        set name ::CollectionBindingFixture::selection[incr serial]
        dict set active $name $query
        interp alias {} $name {} ::CollectionBindingFixture::dispatch $name
        return $name
    }
    proc dispatch {name method args} {
        variable active
        switch -- $method {
            num {return [expr {[dict get $active $name] eq "none" ? 0 : 4}]}
            molid {return 7}
            get {return {{0 42 {} SEG {} ALA} {1 42 X SEG {} ALA} {2 42 X SEG A ALA} {3 42 X SEG {} ALA}}}
            delete {dict unset active $name; rename $name {}; return}
        }
        error "Unexpected mocked selection method: $method"
    }
}
set rows [list [full_row {} SEG 42 {} 0] [full_row X SEG 42 {} 0] [full_row X SEG 42 A 0] [full_row X SEG 42 {} 1]]
set a [make_matrix First $rows {10 20 30}]
set b [make_matrix Second [lreverse $rows] {30 10 20}]
set mapped [::RMSXFlipbookTimeline::Collections::map_selection $a $b {0 1}]
assert {[dict get $mapped coordinate] eq {3 2}} "Selection followed row/column positions instead of residue identity and frame"
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $a $b {2 2}] coordinate] eq {1 0}} "Insertion code mapping failed"
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $a $b {3 2}] coordinate] eq {0 0}} "Repeated occurrence mapping failed"
set unmatched [make_matrix Unmatched [list [full_row A OTHER 99 {} 0]] {10 20 30}]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $a $unmatched {0 0}] status] eq "cleared"} "Absent residue selection was retained"
set wrong_frames [make_matrix Frames $rows {100 200 300}]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $a $wrong_frames {0 0}] coordinate] eq {}} "Column labels invented matching frame numbers"
set legacy [make_matrix Legacy [list [dict create chain X resid 42]] {10 20 30}]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $legacy $a {0 0}] coordinate] eq {}} "Ambiguous legacy identity merged residues"
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $a $legacy {1 0}] coordinate] eq {}} "Reverse legacy ambiguity accepted"
set unique [make_matrix Unique [list [full_row A SEG 1 {} 0]] {10}]
set old [make_matrix Old [list [dict create chain A segid SEG resid 1]] {10}]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $old $unique {0 0}] coordinate] eq {0 0}} "Unique legacy mapping rejected"
set duplicate [make_matrix Duplicate [list [full_row A SEG 1 {} 0] [full_row A SEG 1 {} 0]] {10}]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $unique $duplicate {0 0}] coordinate] eq {}} "Duplicate full identity accepted"
set other [dict replace $unique molid 99]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection [dict replace $unique molid 7] $other {0 0}] coordinate] eq {}} "Different explicit source molecules linked"
set anonymous [dict replace $a provenance {}]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $anonymous $anonymous {0 0}] coordinate] eq {}} "Absent provenance invented source identity"
set numeric_name [dict replace $a provenance [dict create mol_name 7]]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $numeric_name $numeric_name {0 0}] coordinate] eq {}} "Serialized integer molecule names treated as durable identity"
set source_a [dict replace $a provenance [dict create topology /input/a.pdb trajectory /input/a.dcd]]
set source_b [dict replace $b provenance [dict create topology /input/b.pdb trajectory /input/b.dcd]]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $source_a $source_b {0 1}] coordinate] eq {}} "Conflicting explicit source paths preserved selection"
set source_same [dict replace $b provenance [dict create source_paths {/input/a.pdb /input/a.dcd}]]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $source_a $source_same {0 1}] coordinate] eq {3 2}} "Equivalent supported source path metadata did not match"
set source_other_traj [dict replace $source_same provenance [dict create source_paths {/input/a.pdb /input/other.dcd}]]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $source_a $source_other_traj {0 1}] coordinate] eq {}} "Different trajectories with identical topology preserved selection"
set windows [dict replace $b columns [list [dict create frame_start 0 frame_end 14] [dict create frame_start 15 frame_end 29] [dict create frame_start 30 frame_end 44]]]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $a $windows {0 1}] coordinate] eq {3 1}} "Frame did not map to unique containing window"
set overlap [dict replace $windows columns [list [dict create frame_start 0 frame_end 25] [dict create frame_start 15 frame_end 29] [dict create frame_start 30 frame_end 44]]]
assert {[dict get [::RMSXFlipbookTimeline::Collections::map_selection $a $overlap {0 1}] coordinate] eq {}} "Overlapping windows chose arbitrary target"

set temporary_channel [file tempfile root]
close $temporary_channel
file delete $root
file mkdir $root
try {
    ::RMSXFlipbookTimeline::TimelineIO::write_tml $a [file join $root a.tml]
    ::RMSXFlipbookTimeline::TimelineIO::write_tml $b [file join $root b.TML]
    set receipt [::RMSXFlipbookTimeline::Collections::load $root "" draw 0 pick 0]
    assert {[::RMSXFlipbookTimeline::Collections::index] == 0 && [llength [::RMSXFlipbookTimeline::Collections::labels]] == 2} "Collection selector did not expose both datasets"
    ::RMSXFlipbookTimeline::Results::update [dict create selected_cell {0 1}]
    set receipt [::RMSXFlipbookTimeline::Collections::select 1]
    assert {[dict get $receipt selected_cell] eq {3 2}} "Loaded TML dataset switch lost portable identity/frame selection"
    assert {[dict get [::RMSXFlipbookTimeline::Results::get] dataset title] eq "Second"} "Switch did not update authoritative result"
    assert {[dict get [::RMSXFlipbookTimeline::Results::get] selected_cell] eq {3 2}} "Current result retained stale selection"
    set receipt [::RMSXFlipbookTimeline::Collections::select 0]
    assert {[dict get $receipt selected_cell] eq {0 1}} "Reverse collection switch did not preserve selection"
    set before [::RMSXFlipbookTimeline::Results::get]
    set before_items [::RMSXFlipbookTimeline::Collections::datasets]
    assert {[catch {::RMSXFlipbookTimeline::Collections::select 1 width not-a-number}]} "Invalid plot width did not fail"
    assert {[::RMSXFlipbookTimeline::Results::get] eq $before && [::RMSXFlipbookTimeline::Collections::index] == 0} "Failed switch replaced the current result or index"
    assert {[catch {::RMSXFlipbookTimeline::Collections::select 99}]} "Out-of-range collection index was accepted"
    # A malformed later file must prevent ANY replacement, including first data.
    set output [open [file join $root z.tml] w]
    puts $output "# NUM_FRAMES= 1\n# RMSXFLIPBOOK_METADATA_V2= invalid"
    close $output
    assert {[catch {::RMSXFlipbookTimeline::Collections::load $root "" draw 0 pick 0}]} "Malformed later collection dataset was accepted"
    assert {[::RMSXFlipbookTimeline::Results::get] eq $before && [::RMSXFlipbookTimeline::Collections::datasets] eq $before_items} "Failed collection load altered active dataset/collection"
    set id [::RMSXFlipbookTimeline::Operation::begin test]
    assert {[catch {::RMSXFlipbookTimeline::Collections::select 1}]} "Busy operation allowed collection switching"
    ::RMSXFlipbookTimeline::Operation::finish complete
    # Unbound imports must not inherit integer IDs saved on another VMD session.
    set stale [dict replace $a molid 9]
    dict set stale columns [list [dict create frame 10 molid 9 slice_molid 10]]
    dict set stale values [list [lrepeat 4 1]]
    set clean [::RMSXFlipbookTimeline::Collections::prepare_dataset $stale "" {}]
    assert {[dict get $clean molid] eq "" && ![dict exists [lindex [dict get $clean columns] 0] molid] && ![dict exists [lindex [dict get $clean columns] 0] slice_molid]} "Imported session IDs retained"
    # Explicit binding checks happen before activating any item. Stub only the
    # small VMD query surface; actual residue identities have a backend test.
    set saved_commands {}
    foreach command {molinfo atomselect} {
        if {[info commands ::$command] ne ""} {rename ::$command ::CollectionBindingFixture::real_$command; lappend saved_commands $command}
    }
    interp alias {} ::molinfo {} ::CollectionBindingFixture::molinfo
    interp alias {} ::atomselect {} ::CollectionBindingFixture::selection
    try {
        set binding_dir [file join $root binding]
        file mkdir $binding_dir
        ::RMSXFlipbookTimeline::TimelineIO::write_tml $a [file join $binding_dir a.tml]
        set outside [dict replace $b columns [list [dict create frame 10] [dict create frame 20] [dict create frame 500]]]
        ::RMSXFlipbookTimeline::TimelineIO::write_tml $outside [file join $binding_dir b.tml]
        assert {[catch {::RMSXFlipbookTimeline::Collections::load $binding_dir top draw 0 pick 0} message] && [string match {*outside molecule 7 frame range*} $message]} "Out-of-range later bound dataset did not fail"
        assert {[::RMSXFlipbookTimeline::Results::get] eq $before && [::RMSXFlipbookTimeline::Collections::datasets] eq $before_items} "Invalid binding replaced the active collection"
        set free [make_matrix Free [list [dict create row_mode free_selection selection none]] {10}]
        assert {[catch {::RMSXFlipbookTimeline::Collections::prepare_dataset $free 7 {}} message] && [string match {*selection is empty*} $message]} "Empty free selection was bound"
        set free [dict replace $free rows [list [dict create row_mode free_selection selection {}]]]
        assert {[catch {::RMSXFlipbookTimeline::Collections::prepare_dataset $free 7 {}} message] && [string match {*no selection to bind*} $message]} "Missing free selection was bound"
        assert {[dict size $::CollectionBindingFixture::active] == 0} "Failed explicit binding leaked selections"
    } finally {
        foreach command {molinfo atomselect} {rename ::$command {}}
        foreach command $saved_commands {rename ::CollectionBindingFixture::real_$command ::$command}
    }
    puts "RMSX Timeline collections smoke passed"
} finally {file delete -force $root}
