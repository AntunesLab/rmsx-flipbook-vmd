################################################################################
# Timeline .tml import/export
################################################################################

namespace eval ::RMSXFlipbookTimeline::TimelineIO {
    proc dataset_value {dataset key {default ""}} {
        if {[dict exists $dataset $key]} {
            return [dict get $dataset $key]
        }
        return $default
    }

    proc header_value {headers key {default ""}} {
        if {[dict exists $headers $key]} {
            return [dict get $headers $key]
        }
        return $default
    }

    proc header_list {headers key} {
        set raw [header_value $headers $key ""]
        if {[string trim $raw] eq ""} {
            return {}
        }
        if {[catch {llength $raw}]} {
            return {}
        }
        return $raw
    }

    proc comment_list {items} {
        return [list {*}$items]
    }

    proc columns_from_headers {headers count} {
        set labels [header_list $headers RMSXFLIPBOOK_COLUMN_LABELS]
        set columns {}
        for {set frame 0} {$frame < $count} {incr frame} {
            set label $frame
            if {$frame < [llength $labels]} {
                set label [lindex $labels $frame]
            }
            lappend columns [dict create index $frame frame $frame label $label target_type frame]
        }
        return $columns
    }

    proc tml_provenance {filename headers} {
        set provenance [dict create file $filename]
        foreach {header_key provenance_key} {
            FILE_VERSION file_version
            CREATOR creator
            MOL_NAME mol_name
            NUM_FRAMES num_frames
            NUM_ITEMS num_items
            FREE_SELECTION free_selection
        } {
            if {[dict exists $headers $header_key]} {
                dict set provenance $provenance_key [dict get $headers $header_key]
            }
        }
        return $provenance
    }

    proc loaded_slice_molid_map {} {
        set out [dict create]
        set files [::RMSXFlipbookTimeline::state_get slice_files {}]
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $files] == 0 || [llength $files] != [llength $molids]} {
            return $out
        }
        foreach file $files molid $molids {
            dict set out [file normalize $file] $molid
        }
        return $out
    }

    proc attach_slice_targets {dataset folder} {
        set folder [file normalize $folder]
        if {[catch {::RMSXFlipbookTimeline::Loader::discover_slice_files $folder} slice_files]} {
            return $dataset
        }

        set molid_by_file [loaded_slice_molid_map]
        set file_by_number {}
        foreach path $slice_files {
            set number [::RMSXFlipbookTimeline::Values::slice_index_from_path $path]
            dict set file_by_number $number [file normalize $path]
        }
        set columns {}
        set old_columns [dict get $dataset columns]
        for {set col 0} {$col < [llength $old_columns]} {incr col} {
            set column [lindex $old_columns $col]
            catch {dict unset column slice_molid}
            catch {dict unset column slice_file}
            dict set column target_type slice
            set number [expr {$col + 1}]
            set source [dataset_value $column source_column [dataset_value $column label]]
            if {[regexp {^slice_([0-9]+)} $source _ parsed_number]} {set number [expr {int($parsed_number)}]}
            dict set column slice_number $number
            if {[dict exists $file_by_number $number]} {
                set slice_file [dict get $file_by_number $number]
                dict set column slice_file $slice_file
                if {[dict exists $molid_by_file $slice_file]} {dict set column slice_molid [dict get $molid_by_file $slice_file]}
            }
            lappend columns $column
        }
        dict set dataset columns $columns
        return [::RMSXFlipbookTimeline::Matrix::validate $dataset]
    }

    proc read_rmsx_csv {csv_path args} {
        set defaults [dict create molid "" title "" value_label ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set csv_path [file normalize $csv_path]
        if {![file exists $csv_path]} {
            error "RMSX CSV file does not exist: $csv_path"
        }

        set csv_data [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $csv_path]
        set parsed [::RMSXFlipbookTimeline::NativeAnalysis::csv_to_records_and_columns $csv_data]
        set residue_records [dict get $parsed residue_records]
        set slice_columns [dict get $parsed slice_columns]
        set mask_metadata [::RMSXFlipbookTimeline::NativeAnalysis::read_mask_metadata_file \
            [file join [file dirname $csv_path] masked_residues.csv]]
        set mask_metadata [::RMSXFlipbookTimeline::NativeAnalysis::align_mask_metadata $residue_records $mask_metadata]
        set method [::RMSXFlipbookTimeline::NativeAnalysis::csv_method_metadata $csv_path]

        set rows {}
        for {set row_index 0} {$row_index < [llength $residue_records]} {incr row_index} {
            set record [lindex $residue_records $row_index]
            set resid [dict get $record resid]
            set chain ""
            if {[dict exists $record chain]} {
                set chain [string trim [dict get $record chain]]
            }
            set selection [::RMSXFlipbookTimeline::ResidueIdentity::portable_selection $record]
            if {[dict get $opts molid] ne ""} {
                set selection [::RMSXFlipbookTimeline::ResidueIdentity::selection $record [dict get $opts molid]]
            }
            set masked 0
            if {[llength $mask_metadata] > $row_index} {
                set masked [expr {[dict exists [lindex $mask_metadata $row_index] masked] && [dict get [lindex $mask_metadata $row_index] masked]}]
            }
            lappend rows [dict merge $record [dict create \
                label [::RMSXFlipbookTimeline::NativeAnalysis::residue_record_label $record] \
                selection $selection \
                row_mode residue \
                masked $masked]]
        }

        set columns {}
        set values {}
        for {set col 0} {$col < [llength $slice_columns]} {incr col} {
            set item [lindex $slice_columns $col]
            set label [lindex $item 0]
            set column [dict create \
                index $col \
                slice_index $col \
                label $label \
                target_type slice \
                source_column $label]
            if {[dict exists $method plan] && [regexp {^slice_([0-9]+)} $label _ number]} {
                set plan [dict get $method plan]
                set start [expr {[dict get $plan start_frame] + ($number-1)*[dict get $plan slice_size]}]
                set end $start
                if {[dict get $method metric] eq "rmsx"} {set end [expr {$start+[dict get $plan slice_size]-1}]}
                dict set column frame_start $start
                dict set column frame_end $end
                if {[dict get $method time_known] && [dict get $method time_step_ps] ne ""} {
                    set origin [dict get $method parameters rmsd_time_origin]
                    set step [dict get $method time_step_ps]
                    dict set column time [expr {$origin+$start*$step}]
                    dict set column time_end [expr {$origin+$end*$step}]
                    dict set column time_unit ps
                }
            }
            lappend columns $column
            lappend values [lindex $item 1]
        }

        set title [string trim [dict get $opts title]]
        if {$title eq ""} {
            set title [file tail $csv_path]
        }
        set value_label [string trim [dict get $opts value_label]]
        if {$value_label eq ""} {
            set value_label [dict get $method value_label]
        }

        return [::RMSXFlipbookTimeline::Matrix::create \
            title $title \
            value_label $value_label \
            unit [dict get $method unit] \
            source_type rmsx_csv \
            row_mode residue \
            column_mode slice \
            molid [dict get $opts molid] \
            rows $rows \
            columns $columns \
            values $values \
            mask_metadata $mask_metadata \
            provenance [dict create file $csv_path method $method]]
    }

    proc read_rmsx_folder {folder args} {
        set defaults [dict create csv "" molid "" title "" value_label ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set folder [file normalize $folder]
        set csv_path [::RMSXFlipbookTimeline::NativeAnalysis::resolve_folder_csv $folder [dict get $opts csv]]
        set dataset [read_rmsx_csv \
            $csv_path \
            molid [dict get $opts molid] \
            title [dict get $opts title] \
            value_label [dict get $opts value_label]]
        set dataset [attach_slice_targets $dataset $folder]
        dict set dataset provenance [dict merge [dict get $dataset provenance] [dict create folder $folder]]
        return [::RMSXFlipbookTimeline::Matrix::validate $dataset]
    }

    proc write_tml {dataset filename} {
        return [::RMSXFlipbookTimeline::OutputTxn::atomic_write $filename [list [namespace current]::write_tml_body $dataset]]
    }

    proc write_tml_body {dataset filename} {
        set filename [file normalize $filename]
        set fp [open $filename w]
        fconfigure $fp -encoding utf-8 -translation lf
        try {
            puts $fp "# VMD Timeline data file"
            puts $fp "# FILE_VERSION= 1.4"
            puts $fp "# CREATOR= $::tcl_platform(user)"
            set mol_name ""
            if {[dict exists $dataset molid]} {
                set mol_name [dict get $dataset molid]
            }
            puts $fp "# MOL_NAME= $mol_name"
            puts $fp "# DATA_TITLE= [dict get $dataset value_label]"
            puts $fp "# NUM_FRAMES= [llength [dict get $dataset columns]]"
            puts $fp "# NUM_ITEMS= [llength [dict get $dataset rows]]"
            set free_selection [expr {[dict get $dataset row_mode] eq "free_selection"}]
            set seen {}
            set portable_rows {}
            foreach row [dict get $dataset rows] {
                lappend portable_rows [::RMSXFlipbookTimeline::ResidueIdentity::portable $row]
                set key [list [dataset_value $row resid] [dataset_value $row chain] [dataset_value $row segid]]
                if {[dict exists $seen $key] || [dataset_value $row insertion] ne "" || [dataset_value $row ordinal 0] > 0} {set free_selection 1}
                dict set seen $key 1
            }
            set metadata [dict create schema 2 rows $portable_rows]
            foreach key {row_mode column_mode value_kind categories mask_metadata columns provenance min max} {
                if {[dict exists $dataset $key]} {dict set metadata $key [dict get $dataset $key]}
            }
            set encoded [binary encode base64 -maxlen 0 [encoding convertto utf-8 $metadata]]
            puts $fp "# RMSXFLIPBOOK_METADATA_V2= $encoded"
            puts $fp "# FREE_SELECTION= $free_selection"
            puts $fp "# RMSXFLIPBOOK_DATASET_TITLE= [dataset_value $dataset title]"
            puts $fp "# RMSXFLIPBOOK_UNIT= [dataset_value $dataset unit]"
            puts $fp "# RMSXFLIPBOOK_ROW_MODE= [dataset_value $dataset row_mode]"
            puts $fp "# RMSXFLIPBOOK_COLUMN_MODE= [dataset_value $dataset column_mode]"
            set row_labels {}
            set row_selections {}
            foreach row [dict get $dataset rows] {
                lappend row_labels [::RMSXFlipbookTimeline::Matrix::row_label $row]
                lappend row_selections [::RMSXFlipbookTimeline::Matrix::row_selection $row]
            }
            set column_labels {}
            foreach column [dict get $dataset columns] {
                lappend column_labels [::RMSXFlipbookTimeline::Matrix::column_label $column]
            }
            puts $fp "# RMSXFLIPBOOK_ROW_LABELS= [comment_list $row_labels]"
            puts $fp "# RMSXFLIPBOOK_ROW_SELECTIONS= [comment_list $row_selections]"
            puts $fp "# RMSXFLIPBOOK_COLUMN_LABELS= [comment_list $column_labels]"
            puts $fp "#"

            set rows [dict get $dataset rows]
            set columns [dict get $dataset columns]
            if {$free_selection} {
                for {set row 0} {$row < [llength $rows]} {incr row} {
                    set row_item [lindex $rows $row]
                    puts $fp "freeSelLabel [::RMSXFlipbookTimeline::Matrix::row_label $row_item]"
                    puts $fp "freeSelString [::RMSXFlipbookTimeline::Matrix::row_selection $row_item]"
                    for {set col 0} {$col < [llength $columns]} {incr col} {
                        puts $fp "$col [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row $col]"
                    }
                }
            } else {
                for {set col 0} {$col < [llength $columns]} {incr col} {
                    for {set row 0} {$row < [llength $rows]} {incr row} {
                        set row_item [lindex $rows $row]
                        set resid [expr {[dict exists $row_item resid] ? [dict get $row_item resid] : ""}]
                        set chain [expr {[dict exists $row_item chain] ? [dict get $row_item chain] : ""}]
                        set segid [expr {[dict exists $row_item segid] ? [dict get $row_item segid] : ""}]
                        if {$segid eq ""} {
                            set segid "{}"
                        }
                        puts $fp "$resid $chain $segid $col [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row $col]"
                    }
                }
            }
        } finally {
            catch {close $fp}
        }
        return $filename
    }

    proc blank_values {count} {
        return [lrepeat $count null]
    }

    proc frame_columns {count} {
        set columns {}
        for {set frame 0} {$frame < $count} {incr frame} {
            lappend columns [dict create index $frame frame $frame label $frame target_type frame]
        }
        return $columns
    }

    proc read_tml {filename args} {
        set defaults [dict create molid ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set filename [file normalize $filename]
        set fp [open $filename r]
        fconfigure $fp -encoding utf-8
        set lines {}
        set headers [dict create]
        set num_frames 0
        set free_selection 0
        try {
            while {[gets $fp line] >= 0} {
                set line [string trimright $line]
                if {$line eq ""} {
                    continue
                }
                if {[string match "#*" $line]} {
                    if {[regexp {^# *([^=]+)= *(.*)$} $line _ key value]} {
                        set key [string trim $key]
                        dict set headers $key $value
                    }
                    if {[regexp {^# DATA_TITLE= (.*)$} $line _ value]} {
                        dict set headers DATA_TITLE $value
                    } elseif {[regexp {^# NUM_FRAMES= *([0-9]+)} $line _ value]} {
                        set num_frames [expr {int($value)}]
                    } elseif {[regexp {^# FREE_SELECTION= *(.+)$} $line _ value]} {
                        set free_selection [expr {int([string trim $value])}]
                    }
                    continue
                }
                lappend lines $line
            }
        } finally {
            catch {close $fp}
        }

        if {$free_selection} {
            set dataset [read_free_selection $filename $headers $num_frames [dict get $opts molid] $lines]
        } else {
            set dataset [read_residue_selection $filename $headers $num_frames [dict get $opts molid] $lines]
        }
        if {[dict exists $headers RMSXFLIPBOOK_METADATA_V2]} {
            set metadata [encoding convertfrom utf-8 [binary decode base64 [dict get $headers RMSXFLIPBOOK_METADATA_V2]]]
            if {[catch {dict get $metadata schema} schema] || $schema != 2} {error "Invalid TML residue metadata"}
            if {[llength [dict get $metadata rows]] != [dict get $dataset row_count]} {error "TML identity row count does not match values"}
            set merged {}
            foreach row [dict get $dataset rows] identity [dict get $metadata rows] {
                lappend merged [dict merge $row $identity]
            }
            dict set dataset rows $merged
            foreach key {row_mode column_mode value_kind categories mask_metadata columns min max} {
                if {[dict exists $metadata $key]} {dict set dataset $key [dict get $metadata $key]}
            }
            if {[dict exists $metadata provenance]} {
                dict set dataset provenance [dict merge [dict get $metadata provenance] [dict get $dataset provenance]]
            }
            set dataset [::RMSXFlipbookTimeline::Matrix::validate $dataset]
        }
        return $dataset
    }

    proc ensure_free_row {rows_var row_values_var item num_frames} {
        upvar 1 $rows_var rows $row_values_var row_values
        while {[llength $rows] <= $item} {
            set index [llength $rows]
            set row_values($index) [blank_values $num_frames]
            lappend rows [dict create \
                index $index \
                label "selection $index" \
                selection "" \
                row_mode free_selection]
        }
    }

    proc read_free_selection {filename headers num_frames molid lines} {
        set title [header_value $headers DATA_TITLE "Timeline data"]
        set rows {}
        array set row_values {}
        set item -1
        foreach line $lines {
            if {[regexp {^freeSelLabel +([0-9]+) +(.*)$} $line _ item_num label]} {
                set item [expr {int($item_num)}]
                ensure_free_row rows row_values $item $num_frames
                set row [lindex $rows $item]
                dict set row label $label
                lset rows $item $row
            } elseif {[regexp {^freeSelLabel +(.*)$} $line _ label]} {
                incr item
                ensure_free_row rows row_values $item $num_frames
                set row [lindex $rows $item]
                dict set row label $label
                lset rows $item $row
            } elseif {[regexp {^freeSelString +([0-9]+) +(.*)$} $line _ item_num selection]} {
                set item [expr {int($item_num)}]
                ensure_free_row rows row_values $item $num_frames
                set row [lindex $rows $item]
                dict set row selection $selection
                lset rows $item $row
            } elseif {[regexp {^freeSelString +(.*)$} $line _ selection]} {
                if {$item < 0} {set item 0}
                ensure_free_row rows row_values $item $num_frames
                set row [lindex $rows $item]
                dict set row selection $selection
                lset rows $item $row
            } elseif {[regexp {^([0-9]+) +([0-9]+) +(.*)$} $line _ frame item_num value]} {
                set item_num [expr {int($item_num)}]
                ensure_free_row rows row_values $item_num $num_frames
                set values $row_values($item_num)
                if {$frame >= [llength $values]} {
                    set missing [expr {$frame - [llength $values] + 1}]
                    set values [concat $values [lrepeat $missing null]]
                    set num_frames [llength $values]
                }
                lset values $frame $value
                set row_values($item_num) $values
            } elseif {[regexp {^([0-9]+) +(.*)$} $line _ frame value]} {
                if {$item < 0} {
                    error "Timeline file data appeared before freeSelLabel: $filename"
                }
                ensure_free_row rows row_values $item $num_frames
                set values $row_values($item)
                if {$frame >= [llength $values]} {
                    set missing [expr {$frame - [llength $values] + 1}]
                    set values [concat $values [lrepeat $missing null]]
                    set num_frames [llength $values]
                }
                lset values $frame $value
                set row_values($item) $values
            }
        }
        for {set row 0} {$row < [llength $rows]} {incr row} {
            set row_item [lindex $rows $row]
            if {[string trim [dict get $row_item label]] eq ""} {
                dict set row_item label [dict get $row_item selection]
                lset rows $row $row_item
            }
        }

        set values {}
        for {set frame 0} {$frame < $num_frames} {incr frame} {
            set column_values {}
            for {set row 0} {$row < [llength $rows]} {incr row} {
                lappend column_values [lindex $row_values($row) $frame]
            }
            lappend values $column_values
        }
        return [::RMSXFlipbookTimeline::Matrix::create \
            title [header_value $headers RMSXFLIPBOOK_DATASET_TITLE [file tail $filename]] \
            value_label $title \
            unit [header_value $headers RMSXFLIPBOOK_UNIT ""] \
            source_type tml \
            row_mode free_selection \
            column_mode frame \
            molid $molid \
            rows $rows \
            columns [columns_from_headers $headers $num_frames] \
            values $values \
            provenance [tml_provenance $filename $headers]]
    }

    proc read_residue_selection {filename headers num_frames molid lines} {
        set title [header_value $headers DATA_TITLE "Timeline data"]
        set custom_labels [header_list $headers RMSXFLIPBOOK_ROW_LABELS]
        set custom_selections [header_list $headers RMSXFLIPBOOK_ROW_SELECTIONS]
        set rows {}
        array set row_index_by_key {}
        array set row_values {}
        set max_frame -1
        foreach line $lines {
            if {![regexp {^([^ ]+) +([^ ]*) +([^ ]+) +([0-9]+) +(.*)$} $line _ resid chain segid frame value]} {
                continue
            }
            if {$segid eq "{}"} {
                set segid ""
            }
            set key [list $resid $chain $segid]
            if {![info exists row_index_by_key($key)]} {
                set row_index [llength $rows]
                set row_index_by_key($key) $row_index
                set selection "resid $resid"
                if {[string trim $chain] ne ""} {
                    if {[string trim $segid] ne "" && [string trim $segid] ne [string trim $chain]} {
                        append selection " and (chain $chain or segid $segid)"
                    } else {
                        append selection " and (chain $chain or segid $chain)"
                    }
                } elseif {[string trim $segid] ne ""} {
                    append selection " and segid $segid"
                }
                if {$row_index < [llength $custom_selections] && [string trim [lindex $custom_selections $row_index]] ne ""} {
                    set selection [lindex $custom_selections $row_index]
                }
                set label [string trim "$chain:$resid" ":"]
                if {$row_index < [llength $custom_labels] && [string trim [lindex $custom_labels $row_index]] ne ""} {
                    set label [lindex $custom_labels $row_index]
                }
                lappend rows [dict create \
                    index $row_index \
                    resid $resid \
                    resname "" \
                    chain $chain \
                    segid $segid \
                    label $label \
                    selection $selection \
                    row_mode residue]
                set row_values($row_index) [blank_values [expr {max($num_frames, $frame + 1)}]]
            }
            set row_index $row_index_by_key($key)
            set values $row_values($row_index)
            if {$frame >= [llength $values]} {
                set values [concat $values [lrepeat [expr {$frame - [llength $values] + 1}] null]]
            }
            lset values $frame $value
            set row_values($row_index) $values
            if {$frame > $max_frame} {
                set max_frame $frame
            }
        }
        if {$num_frames <= 0} {
            set num_frames [expr {$max_frame + 1}]
        }

        set values {}
        for {set frame 0} {$frame < $num_frames} {incr frame} {
            set column_values {}
            for {set row 0} {$row < [llength $rows]} {incr row} {
                set row_vals $row_values($row)
                if {$frame < [llength $row_vals]} {
                    lappend column_values [lindex $row_vals $frame]
                } else {
                    lappend column_values null
                }
            }
            lappend values $column_values
        }
        return [::RMSXFlipbookTimeline::Matrix::create \
            title [header_value $headers RMSXFLIPBOOK_DATASET_TITLE [file tail $filename]] \
            value_label $title \
            unit [header_value $headers RMSXFLIPBOOK_UNIT ""] \
            source_type tml \
            row_mode residue \
            column_mode frame \
            molid $molid \
            rows $rows \
            columns [columns_from_headers $headers $num_frames] \
            values $values \
            provenance [tml_provenance $filename $headers]]
    }

    proc load_collection {directory args} {
        set defaults [dict create molid ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set directory [file normalize $directory]
        set datasets {}
        foreach filename [lsort -dictionary [glob -nocomplain -directory $directory *.tml *.TML]] {
            lappend datasets [read_tml $filename molid [dict get $opts molid]]
        }
        return $datasets
    }
}
