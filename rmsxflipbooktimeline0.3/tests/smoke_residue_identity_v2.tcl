set package_dir [file dirname [file dirname [file normalize [info script]]]]
lappend auto_path $package_dir
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set temporary_channel [file tempfile root]
close $temporary_channel
file delete $root
set root [file normalize $root]
file mkdir $root
try {
    set records {}
    foreach tuple {{A SEG1 42 {} 0} {A SEG1 42 A 0} {A SEG2 42 {} 0} {X SEG3 42 {} 0} {{} SEG3 42 {} 0} {A SEG1 42 {} 1}} {
        lassign $tuple chain segid resid insertion ordinal
        set i [llength $records]
        lappend records [dict create identity_schema 2 row_id r$i index $i resid $resid chain $chain segid $segid insertion $insertion ordinal $ordinal resname ALA]
    }
    set keys [lmap record $records {::RMSXFlipbookTimeline::ResidueIdentity::key $record}]
    assert {[llength [lsort -unique $keys]] == 6} "Distinct residue identities collided"
    set columns {{slice_1.dcd {1 2 3 4 5 6}} {slice_2.dcd {6 5 4 3 2 1}}}
    set csv [file join $root rmsx_identity.csv]
    ::RMSXFlipbookTimeline::NativeAnalysis::write_csv $csv $records $columns
    set data [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $csv]
    assert {[lrange [dict get $data header] 0 4] eq {ResidueID ChainID SegID InsertionCode ResidueOrdinal}} "Full identity CSV header missing"
    set parsed [::RMSXFlipbookTimeline::NativeAnalysis::csv_to_records_and_columns $data]
    set restored [dict get $parsed residue_records]
    assert {[lmap record $restored {::RMSXFlipbookTimeline::ResidueIdentity::key $record}] eq $keys} "CSV identities changed"
    assert {[dict get $parsed slice_columns] eq $columns} "CSV numeric matrix changed"
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::write_csv [file join $root legacy.csv] $records $columns legacy}]} "Ambiguous legacy export accepted"

    set masks {}
    foreach record $records {dict set record masked [expr {[dict get $record index] % 2}]; lappend masks $record}
    ::RMSXFlipbookTimeline::NativeAnalysis::write_mask_metadata [file join $root masked_residues.csv] $masks
    set masks2 [::RMSXFlipbookTimeline::NativeAnalysis::read_mask_metadata_file [file join $root masked_residues.csv]]
    assert {[lmap record $masks2 {::RMSXFlipbookTimeline::ResidueIdentity::key $record}] eq $keys} "Mask identities changed"
    assert {[lmap record $masks2 {dict get $record masked}] eq {0 1 0 1 0 1}} "Mask flags changed"

    set dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_csv $csv]
    ::RMSXFlipbookTimeline::NativeAnalysis::write_mask_metadata [file join $root masked_residues.csv] [lreverse $masks]
    set reordered [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_csv $csv]
    assert {[lmap row [dict get $reordered rows] {dict get $row masked}] eq {0 1 0 1 0 1}} "Reordered mask file changed residue flags"
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::align_mask_metadata $records [list [lindex $masks 0] [lindex $masks 0]]}]} "Duplicate mask identities accepted"
    assert {[dict get $dataset provenance method transform] eq "unknown"} "Legacy data invented transform provenance"
    set tml [file join $root identity.tml]
    ::RMSXFlipbookTimeline::TimelineIO::write_tml $dataset $tml
    set again [::RMSXFlipbookTimeline::TimelineIO::read_tml $tml]
    assert {[dict get $again row_count] == 6} "TML merged distinct residues"
    assert {[dict get $again values] eq [dict get $dataset values]} "TML numeric values changed"
    assert {[lmap row [dict get $again rows] {::RMSXFlipbookTimeline::ResidueIdentity::key $row}] eq $keys} "TML identity metadata changed"
    assert {[dict get $again row_mode] eq "residue"} "TML did not restore residue dataset semantics"

    # Quoted CSV fields use the same reader as native outputs.
    set quoted [file join $root quoted.csv]
    ::RMSXFlipbookTimeline::NativeAnalysis::write_simple_csv $quoted {first second} [list [list {A,"B} "line1\nline2"]]
    set again [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $quoted]
    assert {[dict get $again rows] eq [list [list {A,"B} "line1\nline2"]]} "CSV quote/newline round trip failed"
    puts "RMSX residue identity v2 smoke passed"
} finally {file delete -force $root}
