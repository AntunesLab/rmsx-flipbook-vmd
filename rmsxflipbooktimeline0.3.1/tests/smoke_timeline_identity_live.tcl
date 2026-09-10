# Exercise the live-selection adapter using deterministic VMD selection objects.
set package_dir [file dirname [file dirname [file normalize [info script]]]]
lappend auto_path $package_dir
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
namespace eval ::IdentityFixture {
    variable atoms {
        {index 0 residue 0 resid 42 chain {} segid SEG insertion {} resname ALA}
        {index 1 residue 0 resid 42 chain {} segid SEG insertion {} resname ALA}
        {index 2 residue 1 resid 42 chain X segid SEG insertion {} resname GLY}
        {index 3 residue 2 resid 42 chain X segid SEG insertion A resname SER}
        {index 4 residue 3 resid 42 chain X segid OTHER insertion {} resname VAL}
        {index 5 residue 4 resid 42 chain X segid SEG insertion {} resname GLY}
    }
    variable active {}
    variable serial 0
    proc selection {molid query args} {
        variable active; variable serial; variable atoms
        if {$molid eq "top"} {set molid 17}
        if {$molid != 17} {error "Unexpected source molecule"}
        set name ::IdentityFixture::sel[incr serial]
        if {$query eq "all" || [string match {*duplicate_keys*} $query]} {set selected $atoms} elseif {[string match {*residue 4*} $query]} {
            set selected [list [lindex $atoms 5]]
        } else {
            set selected [lmap i {0 2 3 4 5} {lindex $atoms $i}]
        }
        dict set active $name $selected
        interp alias {} $name {} ::IdentityFixture::dispatch $name
        return $name
    }
    proc dispatch {name method args} {
        variable active
        switch -- $method {
            num {return [llength [dict get $active $name]]}
            molid {return 17}
            get {
                set answer {}
                foreach atom [dict get $active $name] {
                    set values {}
                    foreach field [lindex $args 0] {lappend values [dict get $atom $field]}
                    lappend answer $values
                }
                return $answer
            }
            delete {dict unset active $name; rename $name {}; return}
            default {error "Unexpected selection method $method"}
        }
    }
}
set had_atomselect [expr {[info commands ::atomselect] ne ""}]
if {$had_atomselect} {rename ::atomselect ::IdentityFixture::real_atomselect}
interp alias {} ::atomselect {} ::IdentityFixture::selection
try {
    set rows [::RMSXFlipbookTimeline::TimelineAnalysis::residue_rows top all 0]
    assert {[llength $rows] == 5} "Representative rows did not retain five distinct residues"
    assert {[dict get [lindex $rows 0] chain] eq ""} "Blank chain was replaced by segment"
    assert {[dict get [lindex $rows 1] chain] eq "X"} "Genuine chain X was replaced by segment"
    assert {[dict get [lindex $rows 2] insertion] eq "A"} "Insertion code was lost"
    assert {[dict get [lindex $rows 3] segid] eq "OTHER"} "Overlapping segment was lost"
    assert {[dict get [lindex $rows 4] ordinal] == 1} "Repeated numbering did not receive distinct occurrence"
    assert {[lmap row $rows {dict get $row atom_index}] eq {0 2 3 4 5}} "Representative atom indices changed"
    assert {[lmap row $rows {::RMSXFlipbookTimeline::ResidueIdentity::selection $row 17}] eq {{residue 0} {residue 1} {residue 2} {residue 3} {residue 4}}} "Live selections are not exact VMD residue indices"
    assert {[lmap row $rows {dict get $row source_molid}] eq {17 17 17 17 17}} "Top was not resolved to concrete source molecule ID"
    set subset [::RMSXFlipbookTimeline::TimelineAnalysis::residue_rows 17 {residue 4} 0]
    assert {[dict get [lindex $subset 0] ordinal] == 1} "Filtering changed repeated-residue occurrence identity"
    set duplicate_rows [::RMSXFlipbookTimeline::TimelineAnalysis::residue_rows 17 duplicate_keys 0]
    assert {[lmap row $duplicate_rows {dict get $row atom_index}] eq {0 1 2 3 4 5}} "Alternate key atoms were dropped or reordered relative to calculator values"
    assert {[llength [lsort -unique [lmap row $duplicate_rows {dict get $row row_id}]]] == 6} "Alternate key atoms duplicated row IDs"
    assert {[::RMSXFlipbookTimeline::ResidueIdentity::key [lindex $duplicate_rows 0]] eq [::RMSXFlipbookTimeline::ResidueIdentity::key [lindex $duplicate_rows 1]]} "Alternate atoms invented distinct residue identity"
    assert {[dict size $::IdentityFixture::active] == 0} "Live identity adapter leaked atom selections"
    puts "RMSX Timeline live identity smoke passed"
} finally {
    rename ::atomselect {}
    if {$had_atomselect} {rename ::IdentityFixture::real_atomselect ::atomselect}
}

# The same script additionally exercises actual VMD selections when run by the
# VMD backend profile; the ordinary Tcl profile tests only the deterministic API.
if {[info commands molinfo] ne "" && [info commands mol] ne ""} {
    set fixtures [file join [file dirname $package_dir] fixtures]
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
    set source ""
    try {
        set source [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb $fixture]
        set rows [::RMSXFlipbookTimeline::TimelineAnalysis::residue_rows $source {residue 0 to 5} 0]
        assert {[llength $rows] == 6} "Actual VMD key selections merged distinct residues"
        assert {[lmap row $rows {::RMSXFlipbookTimeline::ResidueIdentity::key $row}] eq $tuples} "Actual VMD Timeline rows changed full identities"
        set i 0
        foreach row $rows {
            set picked [atomselect $source [::RMSXFlipbookTimeline::TimelinePlot::row_selection $row $source]]
            try {assert {[lsort -unique [$picked get residue]] eq [list $i]} "Actual Timeline highlight crossed residue boundary"} finally {$picked delete}
            incr i
        }
        set subset [::RMSXFlipbookTimeline::TimelineAnalysis::residue_rows $source {residue 5} 0]
        assert {[::RMSXFlipbookTimeline::ResidueIdentity::key [lindex $subset 0]] eq [lindex $tuples 5]} "Actual VMD filtered rows renumbered repeated residue identity"
        puts "RMSX Timeline actual VMD identity smoke passed"
    } finally {
        if {$source ne ""} {catch {mol delete $source}}
        file delete $fixture
    }
}
