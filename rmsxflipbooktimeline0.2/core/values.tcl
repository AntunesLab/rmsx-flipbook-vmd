################################################################################
# RMSX Flipbook Timeline value extraction and field assignment
################################################################################

namespace eval ::RMSXFlipbookTimeline::Values {
    proc list_min {values} {
        return [lindex [lsort -real $values] 0]
    }

    proc list_max {values} {
        return [lindex [lsort -real $values] end]
    }

    proc clamp {value min_val max_val} {
        if {$value < $min_val} {return $min_val}
        if {$value > $max_val} {return $max_val}
        return $value
    }

    proc residue_bfactor_records {molids} {
        set records {}
        foreach molid $molids {
            set sel_all [atomselect $molid "all"]
            set residue_keys [dict create]
            foreach atom_record [$sel_all get {resid chain segid}] {
                set resid [string trim [lindex $atom_record 0]]
                set chain [string trim [lindex $atom_record 1]]
                set segid [string trim [lindex $atom_record 2]]
                if {$chain eq "" || $chain eq "X"} {
                    set chain $segid
                }
                dict set residue_keys "$chain|$resid" [list $resid $chain]
            }
            $sel_all delete

            foreach key [lsort [dict keys $residue_keys]] {
                lassign [dict get $residue_keys $key] resid chain
                if {$chain eq ""} {
                    set selection "resid $resid"
                } else {
                    set selection "resid $resid and (chain $chain or segid $chain)"
                }
                set sel_res [atomselect $molid $selection]
                set betas [$sel_res get beta]
                set count [llength $betas]
                if {$count == 0} {
                    $sel_res delete
                    continue
                }

                set total 0.0
                foreach beta $betas {
                    set total [expr {$total + double($beta)}]
                }
                set mean [expr {$total / double($count)}]
                lappend records [dict create \
                    molid $molid \
                    resid $resid \
                    chain $chain \
                    value $mean \
                    atoms $count]
                $sel_res delete
            }
        }
        return $records
    }

    proc candidate_csv_files {folder} {
        if {$folder eq "" || ![file isdirectory $folder]} {
            return {}
        }

        set candidates {}
        foreach path [glob -nocomplain -directory [file normalize $folder] "*.csv"] {
            set name [file tail $path]
            set lowered [string tolower $name]
            if {$lowered eq "rmsd.csv" || $lowered eq "rmsf.csv" || $lowered eq "masked_residues.csv" || [string match "*summary*.csv" $lowered]} {
                continue
            }
            if {[string match "*_plot_*" $lowered]} {
                continue
            }
            if {[string match "rmsx*.csv" $lowered] || [string match "lddt*.csv" $lowered] || [string match "shift*.csv" $lowered]} {
                lappend candidates [file normalize $path]
            }
        }
        return [lsort $candidates]
    }

    proc slice_index_from_path {path} {
        set name [file tail $path]
        if {[regexp {^slice_([0-9]+)_first_frame\.pdb$} $name _ slice_index]} {
            return [expr {$slice_index + 0}]
        }
        return ""
    }

    proc csv_records {csv_path molids slice_files} {
        if {$csv_path eq "" || ![file exists $csv_path]} {
            return {}
        }

        set fp [open $csv_path r]
        set header_line [gets $fp]
        if {$header_line < 0} {
            close $fp
            return {}
        }
        set headers [split $header_line ","]

        set molid_by_column {}
        for {set i 0} {$i < [llength $slice_files]} {incr i} {
            set slice_index [slice_index_from_path [lindex $slice_files $i]]
            if {$slice_index eq ""} {
                continue
            }
            set expected "slice_${slice_index}.dcd"
            set column [lsearch -exact $headers $expected]
            if {$column >= 0} {
                dict set molid_by_column $column [lindex $molids $i]
            }
        }

        if {[dict size $molid_by_column] == 0} {
            close $fp
            return {}
        }

        set records {}
        while {[gets $fp line] >= 0} {
            set trimmed [string trim $line]
            if {$trimmed eq ""} {
                continue
            }

            set fields [split $trimmed ","]
            if {[llength $fields] < 3} {
                continue
            }

            set resid [string trim [lindex $fields 0]]
            set chain [string trim [lindex $fields 1]]
            if {$resid eq ""} {
                continue
            }

            foreach column [dict keys $molid_by_column] {
                if {$column >= [llength $fields]} {
                    continue
                }
                set value [string trim [lindex $fields $column]]
                if {$value eq "" || ![string is double -strict $value]} {
                    continue
                }
                lappend records [dict create \
                    molid [dict get $molid_by_column $column] \
                    resid $resid \
                    chain $chain \
                    value [expr {double($value)}]]
            }
        }
        close $fp

        return $records
    }

    proc csv_records_from_folder {folder molids slice_files} {
        foreach csv_path [candidate_csv_files $folder] {
            set records [csv_records $csv_path $molids $slice_files]
            if {[llength $records] > 0} {
                return [dict create records $records csv_file $csv_path]
            }
        }
        return [dict create records {} csv_file ""]
    }

    proc normalize_values {values} {
        if {[llength $values] == 0} {
            error "Cannot normalize an empty RMSX value list"
        }

        set raw_min [list_min $values]
        set raw_max [list_max $values]
        set normalized {}

        if {$raw_min == $raw_max} {
            foreach _ $values {
                lappend normalized 5.0
            }
        } else {
            set range [expr {$raw_max - $raw_min}]
            foreach value $values {
                set norm [expr {(($value - $raw_min) / $range) * 10.0}]
                lappend normalized [clamp $norm 0.0 10.0]
            }
        }

        return [dict create \
            raw_min $raw_min \
            raw_max $raw_max \
            norm_min [list_min $normalized] \
            norm_max [list_max $normalized] \
            values $normalized]
    }

    proc value_range_is_informative {records} {
        if {[llength $records] == 0} {
            return 0
        }

        set values {}
        foreach record $records {
            lappend values [dict get $record value]
        }
        return [expr {[list_min $values] != [list_max $values]}]
    }

    proc selection_for_record {record} {
        set resid [dict get $record resid]
        set chain ""
        if {[dict exists $record chain]} {
            set chain [dict get $record chain]
        }

        if {$chain eq ""} {
            return "resid $resid"
        }
        return "resid $resid and (chain $chain or segid $chain)"
    }

    proc assign_record_value {record thickness norm} {
        set molid [dict get $record molid]
        set selection [selection_for_record $record]
        set sel [atomselect $molid $selection]
        if {[$sel num] == 0 && [dict exists $record chain] && [dict get $record chain] ne ""} {
            $sel delete
            set sel [atomselect $molid "resid [dict get $record resid]"]
        }

        set atom_count [$sel num]
        if {$atom_count > 0} {
            $sel set user [lrepeat $atom_count $thickness]
            $sel set user2 [lrepeat $atom_count $norm]
        }
        $sel delete
        return $atom_count
    }

    proc assign_from_bfactors {molids args} {
        set defaults [dict create user_scale 1.0 user_offset 2.0 source_folder "" slice_files {}]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set records [residue_bfactor_records $molids]
        if {[llength $records] == 0} {
            error "No residue B-factor values found in loaded RMSX slice PDBs"
        }
        set value_source "bfactor"
        set value_file ""

        if {![value_range_is_informative $records]} {
            set csv_result [csv_records_from_folder \
                [dict get $opts source_folder] \
                $molids \
                [dict get $opts slice_files]]
            set csv_records [dict get $csv_result records]
            if {[value_range_is_informative $csv_records]} {
                set records $csv_records
                set value_source "csv"
                set value_file [dict get $csv_result csv_file]
            }
        }

        set raw_values {}
        foreach record $records {
            lappend raw_values [dict get $record value]
        }

        set norm_result [normalize_values $raw_values]
        set norm_values [dict get $norm_result values]
        set user_scale [dict get $opts user_scale]
        set user_offset [dict get $opts user_offset]

        set assigned_atoms 0
        for {set i 0} {$i < [llength $records]} {incr i} {
            set record [lindex $records $i]
            set norm [lindex $norm_values $i]
            set thickness [clamp [expr {$user_scale * $norm + $user_offset}] 0.0 10.0]

            incr assigned_atoms [assign_record_value $record $thickness $norm]
        }

        dict set norm_result source $value_source
        dict set norm_result value_file $value_file
        dict set norm_result record_count [llength $records]
        dict set norm_result assigned_atoms $assigned_atoms

        if {$value_source eq "csv"} {
            puts [format {RMSX Flipbook Timeline: mapped %d CSV residue values from %s, raw range %.3f..%.3f} \
                [llength $records] [file tail $value_file] [dict get $norm_result raw_min] [dict get $norm_result raw_max]]
        } else {
            puts [format {RMSX Flipbook Timeline: mapped %d B-factor residue values, raw range %.3f..%.3f} \
                [llength $records] [dict get $norm_result raw_min] [dict get $norm_result raw_max]]
        }

        return $norm_result
    }
}
