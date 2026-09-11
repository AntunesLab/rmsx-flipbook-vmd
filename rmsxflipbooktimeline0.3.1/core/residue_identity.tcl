# One residue identity contract for analysis, serialization, and picking.
namespace eval ::RMSXFlipbookTimeline::ResidueIdentity {
    proc value {record field {default ""}} {
        if {[dict exists $record $field]} {
            set value [dict get $record $field]
            if {$field in {chain segid insertion} && [string trim $value] eq ""} {return ""}
            return $value
        }
        return $default
    }
    proc key {record} {
        return [list [value $record chain] [value $record segid] [value $record resid] [value $record insertion] [value $record ordinal 0]]
    }
    proc legacy_key {record} {return [list [value $record chain] [value $record resid]]}
    proc full {record} {return [expr {[value $record identity_schema 0] == 2}]}
    proc from_selection {selection} {
        set atoms [$selection get {residue resid chain segid insertion resname}]
        set records {}
        set seen {}
        set counts {}
        set molid [$selection molid]
        foreach atom $atoms {
            lassign $atom residue resid chain segid insertion resname
            foreach field {chain segid insertion} {if {[string trim [set $field]] eq ""} {set $field ""}}
            if {[dict exists $seen $residue]} {continue}
            dict set seen $residue 1
            set tuple [list $chain $segid $resid $insertion]
            set ordinal [expr {[dict exists $counts $tuple] ? [dict get $counts $tuple] : 0}]
            dict incr counts $tuple
            set index [llength $records]
            lappend records [dict create identity_schema 2 row_id r$index index $index residue $residue source_molid $molid resid $resid chain $chain segid $segid insertion $insertion ordinal $ordinal resname $resname]
        }
        return $records
    }
    proc portable {record} {
        set out {}
        foreach field {identity_schema row_id index resid chain segid insertion ordinal resname label} {
            if {[dict exists $record $field]} {dict set out $field [dict get $record $field]}
        }
        return $out
    }
    proc legacy_unique {records} {
        set seen {}
        foreach record $records {
            set k [legacy_key $record]
            if {[dict exists $seen $k]} {return 0}
            dict set seen $k 1
        }
        return 1
    }
    proc literal {text} {return "\"[string map [list \\ \\\\ \" \\\"] $text]\""}
    proc portable_selection {record} {
        set clauses [list "resid [literal [value $record resid]]"]
        if {[full $record]} {
            foreach field {chain segid insertion} {
                set text [value $record $field]
                if {$field eq "insertion" && $text eq ""} {set text " "}
                if {$field eq "chain" && $text eq ""} {
                    lappend clauses {chain "" " "}
                } else {lappend clauses "$field [literal $text]"}
            }
        } elseif {[value $record chain] ne ""} {
            set id [literal [value $record chain]]
            lappend clauses "(chain $id or segid $id)"
        } elseif {[value $record segid] ne ""} {
            lappend clauses "segid [literal [value $record segid]]"
        }
        return [join $clauses " and "]
    }
    proc matches {requested actual} {
        if {[value $requested resid] ne [value $actual resid]} {return 0}
        if {[full $requested]} {return [expr {[key $requested] eq [key $actual]}]}
        set chain [value $requested chain]
        if {$chain ne "" && $chain ne [value $actual chain] && $chain ne [value $actual segid]} {return 0}
        set segid [value $requested segid]
        if {$segid ne "" && $segid ne [value $actual segid]} {return 0}
        return 1
    }
    proc resolve {record records {molid ""}} {
        if {$molid ne "" && [value $record source_molid] eq $molid && [dict exists $record residue]} {
            foreach actual $records {
                if {[dict get $actual residue] == [dict get $record residue] && [value $actual resid] eq [value $record resid]} {return $actual}
            }
        }
        set matches {}
        foreach actual $records {if {[matches $record $actual]} {lappend matches $actual}}
        if {[llength $matches] != 1} {
            error "Residue [label $record] maps to [llength $matches] residues; use full residue identity instead of ambiguous legacy numbering"
        }
        return [lindex $matches 0]
    }
    proc selection {record {molid ""}} {
        if {$molid eq ""} {
            if {[value $record ordinal 0] > 0} {error "Repeated residue identity requires a target molecule for exact selection"}
            return [portable_selection $record]
        }
        if {[value $record source_molid] eq $molid && [dict exists $record residue]} {return "residue [dict get $record residue]"}
        set sel [atomselect $molid all]
        try {set actual [resolve $record [from_selection $sel] $molid]} finally {$sel delete}
        return "residue [dict get $actual residue]"
    }
    proc label {record} {
        set chain [value $record chain]
        set segid [value $record segid]
        set id "[value $record resid][value $record insertion]"
        if {$chain ne ""} {set id "$chain:$id"}
        if {$segid ne "" && $segid ne $chain} {set id "$segid/$id"}
        if {[value $record ordinal 0] > 0} {append id " #[expr {[value $record ordinal]+1}]"}
        return $id
    }
    proc csv_header {} {return {ResidueID ChainID SegID InsertionCode ResidueOrdinal}}
    proc csv_fields {record} {return [list [value $record resid] [value $record chain] [value $record segid] [value $record insertion] [value $record ordinal 0]]}
    proc csv_record {header fields index} {
        set out [dict create index $index row_id r$index chain ""]
        foreach column {ResidueID ChainID SegID InsertionCode ResidueOrdinal} field {resid chain segid insertion ordinal} {
            set at [lsearch -exact $header $column]
            if {$at >= 0} {dict set out $field [lindex $fields $at]}
        }
        if {[dict exists $out ordinal] && (![string is integer -strict [dict get $out ordinal]] || [dict get $out ordinal] < 0)} {error "Invalid residue occurrence ordinal in CSV row [expr {$index+1}]"}
        if {[lsearch -exact $header InsertionCode] >= 0 && [lsearch -exact $header SegID] >= 0 && [lsearch -exact $header ResidueOrdinal] >= 0} {dict set out identity_schema 2}
        return $out
    }
    proc pdb_atom_records {text} {
        set records {}; set previous {}; set group -1
        foreach line [split $text \n] {
            set kind [string trim [string range $line 0 5]]
            if {$kind eq "ENDMDL"} {break}
            if {$kind eq "TER"} {set previous {}; continue}
            if {$kind ni {ATOM HETATM}} {continue}
            if {[string length $line] < 27} {error "Truncated PDB atom record"}
            set resid [string trim [string range $line 22 25]]
            if {![regexp {^[+-]?[0-9]+$} $resid]} {error "PDB residue number is not supported by VMD identity restoration: $resid"}
            scan $resid %d resid
            set record [dict create name [string trim [string range $line 12 15]] resname [string trim [string range $line 17 19]] chain [string trim [string range $line 21 21]] resid $resid insertion [string trim [string range $line 26 26]] segid [string trim [string range $line 72 75]]]
            set tuple [list [key $record] [dict get $record resname]]
            if {$tuple ne $previous} {incr group; set previous $tuple}
            dict set record group $group
            lappend records $record
        }
        if {![llength $records]} {error "PDB contains no atom records"}
        return $records
    }
    proc restore_pdb_identity {molid path} {
        set input [open $path r]
        try {set records [pdb_atom_records [read $input]]} finally {close $input}
        set sel [atomselect $molid all]
        try {
            set actual [$sel get {name resname resid insertion residue}]
            if {[llength $actual] != [llength $records]} {error "PDB atom count changed; residue identity cannot be restored"}
            set mapping {}; set reverse {}; set chains {}; set segments {}
            foreach atom $actual record $records {
                lassign $atom name resname resid insertion residue
                if {$name ne [dict get $record name] || $resname ne [dict get $record resname] || $resid ne [dict get $record resid] || [string trim $insertion] ne [dict get $record insertion]} {
                    error "PDB atom order or residue fields changed; residue identity cannot be restored"
                }
                set source [dict get $record group]
                if {([dict exists $mapping $source] && [dict get $mapping $source] != $residue) ||
                    ([dict exists $reverse $residue] && [dict get $reverse $residue] != $source)} {
                    error "VMD merged or split PDB residues; reload through ResidueIdentity::load_pdb to preserve identity"
                }
                dict set mapping $source $residue
                dict set reverse $residue $source
                # VMD stores chain as one character. Empty Tcl strings become
                # NUL and make its PDB writer emit a corrupt atom record.
                set chain [dict get $record chain]
                if {$chain eq ""} {set chain " "}
                lappend chains $chain
                lappend segments [dict get $record segid]
            }
            # Insertion codes are immutable in VMD; validate their exact value.
            # Chain and segment are restored only after every atom has passed.
            set previous_chains [$sel get chain]; set previous_segments [$sel get segid]
            try {
                $sel set chain $chains
                $sel set segid $segments
            } on error {message options} {
                catch {$sel set chain $previous_chains}
                catch {$sel set segid $previous_segments}
                return -options $options $message
            }
        } finally {$sel delete}
        return $molid
    }
    proc vmd_load_pdb {path} {return [mol new $path type pdb waitfor all]}
    proc write_pdb {selection path} {
        return [::RMSXFlipbookTimeline::OutputTxn::atomic_write $path [list [namespace current]::write_pdb_body $selection]]
    }
    proc write_pdb_body {selection path} {
        if {$::tcl_platform(platform) eq "windows"} {
            # VMD's native writer cannot open deeply nested Windows paths.
            # Tcl can copy to them, so keep native I/O in an owned temp file
            # and retain the surrounding output transaction and destination.
            set channel [file tempfile native_path rmsx_pdb_]
            close $channel
            try {
                $selection writepdb $native_path
                file copy -force $native_path $path
            } finally {file delete $native_path}
        } else {
            $selection writepdb $path
        }
        set input [open $path rb]
        try {set text [read $input]} finally {close $input}
        set lines {}
        foreach line [split $text \n] {
            if {[string trim [string range $line 0 5]] in {ATOM HETATM TER} && [string range $line 21 21] eq "\u0000"} {
                set line [string replace $line 21 21 " "]
            }
            if {[string first "\u0000" $line] >= 0} {error "VMD produced an invalid PDB record containing NUL outside the blank chain field"}
            lappend lines $line
        }
        set text [join $lines \n]
        set records [pdb_atom_records $text]
        set fields {name resname resid chain segid insertion}
        set original [$selection get $fields]
        if {[llength $original] != [llength $records]} {error "PDB export changed atom count"}
        set index 0
        foreach atom $original record $records {
            set expected {}
            foreach field $fields item $atom {dict set expected $field $item}
            foreach field $fields {
                if {[value $expected $field] ne [value $record $field]} {
                    error "PDB cannot preserve $field for selected atom $index; choose a structure format that can represent its full residue identity"
                }
            }
            incr index
        }
        set output [open $path wb]
        try {puts -nonewline $output $text} finally {close $output}
        return $path
    }
    proc load_pdb {path {loader_prefix ::RMSXFlipbookTimeline::ResidueIdentity::vmd_load_pdb}} {
        set path [file normalize $path]
        set input [open $path r]
        try {set text [read $input]} finally {close $input}
        set records [pdb_atom_records $text]
        set used [lsort -unique [lmap record $records {dict get $record chain}]]
        set temporary ""; set load_path $path; set molid ""; set prior_top ""
        catch {set prior_top [molinfo top]}
        try {
            if {[lsearch -exact $used ""] >= 0} {
                set escape ""
                foreach candidate [split {ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789~!@#$%^&*()_+-=} ""] {
                    if {[lsearch -exact $used $candidate] < 0} {set escape $candidate; break}
                }
                if {$escape eq ""} {error "PDB uses every available chain code; blank-chain identity cannot be encoded safely"}
                set output [file tempfile temporary rmsx_identity_]
                try {
                    foreach line [split $text \n] {
                        if {[string trim [string range $line 0 5]] in {ATOM HETATM TER} && [string trim [string range $line 21 21]] eq "" && [string length $line] >= 22} {
                            set line [string replace $line 21 21 $escape]
                        }
                        puts $output $line
                    }
                } finally {close $output}
                set load_path $temporary
            }
            set molid [uplevel #0 [list {*}$loader_prefix $load_path]]
            if {![string is integer -strict $molid] || [lsearch -exact [molinfo list] $molid] < 0} {error "VMD could not load PDB: $path"}
            restore_pdb_identity $molid $path
            catch {mol rename $molid [file tail $path]}
            return $molid
        } on error {message options} {
            if {$molid ne "" && [lsearch -exact [molinfo list] $molid] >= 0} {
                set owned_top [expr {[molinfo top] == $molid}]
                catch {mol delete $molid}
                if {$owned_top && [lsearch -exact [molinfo list] $prior_top] >= 0} {catch {mol top $prior_top}}
            }
            return -options $options $message
        } finally {
            if {$temporary ne ""} {catch {file delete $temporary}}
        }
    }
}
