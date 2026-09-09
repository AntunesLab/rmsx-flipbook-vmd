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
        set out {}
        foreach molid $molids {
            set all [atomselect $molid all]
            try {set records [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $all]} finally {$all delete}
            foreach record $records {
                set sel [atomselect $molid "residue [dict get $record residue]"]
                try {
                    set values [$sel get beta]
                    set total 0.0
                    foreach value $values {set total [expr {$total + double($value)}]}
                    dict set record molid $molid
                    dict set record atoms [llength $values]
                    dict set record value [expr {$total / double([llength $values])}]
                    lappend out $record
                } finally {$sel delete}
            }
        }
        return $out
    }

    proc candidate_csv_files {folder} {
        if {$folder eq "" || ![file isdirectory $folder]} {
            return {}
        }

        set candidates {}; set custom {}
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
            } elseif {![catch {::RMSXFlipbookTimeline::NativeAnalysis::csv_to_records_and_columns [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $path]}]} {
                lappend custom [file normalize $path]
            }
        }
        return [concat [lsort $candidates] [lsort $custom]]
    }

    proc slice_index_from_path {path} {
        set name [file tail $path]
        if {[regexp {^slice_([0-9]+)_first_frame\.pdb$} $name _ slice_index]} {
            return [expr {$slice_index + 0}]
        }
        return ""
    }

    proc csv_records {csv_path molids slice_files} {
        if {$csv_path eq "" || ![file exists $csv_path]} {return {}}
        set parsed [::RMSXFlipbookTimeline::NativeAnalysis::csv_to_records_and_columns [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $csv_path]]
        set column_map {}
        foreach item [dict get $parsed slice_columns] {
            if {[regexp {^slice_([0-9]+)(_log)?\.dcd$} [lindex $item 0] _ number]} {dict set column_map [expr {int($number)}] [lindex $item 1]}
        }
        set out {}
        foreach molid $molids path $slice_files {
            set number [slice_index_from_path $path]
            if {![dict exists $column_map $number]} {continue}
            set all [atomselect $molid all]
            try {set actual [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $all]} finally {$all delete}
            foreach requested [dict get $parsed residue_records] value [dict get $column_map $number] {
                set record [::RMSXFlipbookTimeline::ResidueIdentity::resolve $requested $actual $molid]
                dict set record molid $molid
                dict set record value [expr {double($value)}]
                lappend out $record
            }
        }
        return $out
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
        return [::RMSXFlipbookTimeline::ResidueIdentity::selection $record [dict get $record molid]]
    }

    proc assign_record_value {record thickness norm} {
        set molid [dict get $record molid]
        set sel [atomselect $molid [selection_for_record $record]]
        try {
            set count [$sel num]
            if {$count == 0} {error "Residue has no atoms: [::RMSXFlipbookTimeline::ResidueIdentity::label $record]"}
            $sel set user [lrepeat $count $thickness]
            $sel set user2 [lrepeat $count $norm]
            return $count
        } finally {$sel delete}
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
