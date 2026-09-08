################################################################################
# RMSX Flipbook Timeline generic matrix dataset model
################################################################################

namespace eval ::RMSXFlipbookTimeline::Matrix {
    proc is_numeric {value} {
        return [string is double -strict [string trim $value]]
    }

    proc value_range {values} {
        set initialized 0
        set min_val 0.0
        set max_val 1.0
        foreach column $values {
            foreach value $column {
                if {![is_numeric $value]} {
                    continue
                }
                set numeric [expr {double($value)}]
                if {!$initialized} {
                    set min_val $numeric
                    set max_val $numeric
                    set initialized 1
                } else {
                    if {$numeric < $min_val} {set min_val $numeric}
                    if {$numeric > $max_val} {set max_val $numeric}
                }
            }
        }
        if {!$initialized} {
            return [list 0.0 1.0]
        }
        if {$min_val == $max_val} {
            set max_val [expr {$min_val + 1.0}]
        }
        return [list $min_val $max_val]
    }

    proc validate {dataset} {
        foreach key {rows columns values} {
            if {![dict exists $dataset $key]} {
                error "Timeline dataset is missing required key '$key'"
            }
        }
        set rows [dict get $dataset rows]
        set columns [dict get $dataset columns]
        set values [dict get $dataset values]
        if {[llength $values] != [llength $columns]} {
            error "Timeline dataset has [llength $columns] columns but [llength $values] value columns"
        }
        set row_count [llength $rows]
        set col_index 0
        foreach column_values $values {
            if {[llength $column_values] != $row_count} {
                error "Timeline value column $col_index has [llength $column_values] rows, expected $row_count"
            }
            incr col_index
        }
        return $dataset
    }

    proc create {args} {
        set defaults [dict create \
            title "Timeline Dataset" \
            value_label value \
            unit "" \
            source_type generic \
            row_mode residue \
            column_mode frame \
            value_kind continuous \
            categories {} \
            mask_metadata {} \
            molid "" \
            rows {} \
            columns {} \
            values {} \
            provenance {} \
            min "" \
            max ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set dataset [dict create]
        foreach key [dict keys $opts] {
            dict set dataset $key [dict get $opts $key]
        }
        set range [value_range [dict get $dataset values]]
        if {[string trim [dict get $dataset min]] eq ""} {
            dict set dataset min [lindex $range 0]
        }
        if {[string trim [dict get $dataset max]] eq ""} {
            dict set dataset max [lindex $range 1]
        }
        dict set dataset row_count [llength [dict get $dataset rows]]
        dict set dataset column_count [llength [dict get $dataset columns]]
        return [validate $dataset]
    }

    proc cell_value {dataset row column} {
        set values [dict get $dataset values]
        return [lindex [lindex $values $column] $row]
    }

    proc row_label {row} {
        if {[dict exists $row label] && [string trim [dict get $row label]] ne ""} {
            return [dict get $row label]
        }
        set resid [expr {[dict exists $row resid] ? [dict get $row resid] : ""}]
        set resname [expr {[dict exists $row resname] ? [dict get $row resname] : ""}]
        set chain [expr {[dict exists $row chain] ? [string trim [dict get $row chain]] : ""}]
        set label [string trim "$resid $resname"]
        if {$chain ne ""} {
            return "$chain:$label"
        }
        return $label
    }

    proc row_selection {row} {
        if {[dict exists $row selection] && [string trim [dict get $row selection]] ne ""} {
            return [dict get $row selection]
        }
        if {![dict exists $row resid]} {
            return ""
        }
        set clauses [list "resid [dict get $row resid]"]
        if {[dict exists $row chain] && [string trim [dict get $row chain]] ne ""} {
            lappend clauses "(chain [dict get $row chain] or segid [dict get $row chain])"
        } elseif {[dict exists $row segid] && [string trim [dict get $row segid]] ne ""} {
            lappend clauses "segid [dict get $row segid]"
        }
        return [join $clauses " and "]
    }

    proc column_label {column} {
        if {[dict exists $column label] && [string trim [dict get $column label]] ne ""} {
            return [dict get $column label]
        }
        if {[dict exists $column frame]} {
            return [dict get $column frame]
        }
        if {[dict exists $column index]} {
            return [dict get $column index]
        }
        return ""
    }

    proc as_plot_matrix {dataset} {
        set columns {}
        set values [dict get $dataset values]
        set index 0
        foreach column [dict get $dataset columns] {
            lappend columns [list [column_label $column] [lindex $values $index]]
            incr index
        }
        return [dict create \
            csv "" \
            residues [dict get $dataset rows] \
            columns $columns \
            mask_metadata [expr {[dict exists $dataset mask_metadata] ? [dict get $dataset mask_metadata] : {}}] \
            min [dict get $dataset min] \
            max [dict get $dataset max]]
    }

    proc row_masked {dataset row_index} {
        set row_index [expr {int($row_index)}]
        if {$row_index < 0} {
            return 0
        }
        if {[dict exists $dataset mask_metadata]} {
            set mask_metadata [dict get $dataset mask_metadata]
            if {[llength $mask_metadata] > $row_index} {
                set item [lindex $mask_metadata $row_index]
                if {[dict exists $item masked] && [dict get $item masked]} {
                    return 1
                }
            }
        }
        if {[dict exists $dataset rows]} {
            set rows [dict get $dataset rows]
            if {[llength $rows] > $row_index} {
                set row [lindex $rows $row_index]
                if {[dict exists $row masked] && [dict get $row masked]} {
                    return 1
                }
            }
        }
        return 0
    }

    proc masked_row_count {dataset} {
        set count 0
        set rows [dict get $dataset rows]
        for {set row 0} {$row < [llength $rows]} {incr row} {
            if {[row_masked $dataset $row]} {
                incr count
            }
        }
        return $count
    }

    proc threshold_counts {dataset min_value max_value} {
        set counts {}
        foreach column_values [dict get $dataset values] {
            set count 0
            foreach value $column_values {
                if {[is_numeric $value] && $value >= $min_value && $value <= $max_value} {
                    incr count
                }
            }
            lappend counts $count
        }
        return $counts
    }

    proc filter_rows {dataset min_value max_value frame_start frame_end frames_required} {
        set rows [dict get $dataset rows]
        set columns [dict get $dataset columns]
        set values [dict get $dataset values]
        set row_count [llength $rows]
        set col_count [llength $columns]
        set frame_start [expr {max(0, int($frame_start))}]
        set frame_end [expr {int($frame_end)}]
        if {$frame_end < 0} {
            set frame_end [expr {$col_count - 1}]
        } else {
            set frame_end [expr {min($col_count - 1, $frame_end)}]
        }
        set frames_required [expr {max(1, int($frames_required))}]
        if {$frame_end < $frame_start} {
            error "Filter frame range is empty: $frame_start to $frame_end"
        }

        set keep_indices {}
        for {set row 0} {$row < $row_count} {incr row} {
            set passes 0
            for {set col $frame_start} {$col <= $frame_end} {incr col} {
                set value [cell_value $dataset $row $col]
                if {[is_numeric $value] && $value >= $min_value && $value <= $max_value} {
                    incr passes
                }
            }
            if {$passes >= $frames_required} {
                lappend keep_indices $row
            }
        }

        set filtered_rows {}
        foreach row_index $keep_indices {
            lappend filtered_rows [lindex $rows $row_index]
        }

        set filtered_values {}
        foreach column_values $values {
            set out {}
            foreach row_index $keep_indices {
                lappend out [lindex $column_values $row_index]
            }
            lappend filtered_values $out
        }

        set provenance {}
        if {[dict exists $dataset provenance]} {
            set provenance [dict get $dataset provenance]
        }
        set filtered [dict merge $dataset [dict create \
            rows $filtered_rows \
            values $filtered_values \
            provenance [dict merge $provenance [dict create filtered_from [dict get $dataset title]]]]]
        set range [value_range $filtered_values]
        dict set filtered min [lindex $range 0]
        dict set filtered max [lindex $range 1]
        dict set filtered row_count [llength $filtered_rows]
        return [validate $filtered]
    }

    proc dataset_value_kind {dataset} {
        if {[dict exists $dataset value_kind]} {
            set kind [string tolower [string trim [dict get $dataset value_kind]]]
            if {$kind ne ""} {
                return $kind
            }
        }
        return continuous
    }

    proc dataset_value_label {dataset} {
        if {[dict exists $dataset value_label]} {
            return [string tolower [string map {" " "_" "-" "_"} [string trim [dict get $dataset value_label]]]]
        }
        return value
    }

    proc default_slice_aggregation {dataset method} {
        set method [string tolower [string map {" " "_" "-" "_"} [string trim $method]]]
        if {$method ne "" && $method ne "auto"} {
            return $method
        }
        set kind [dataset_value_kind $dataset]
        set label [dataset_value_label $dataset]
        if {$kind eq "categorical"} {
            return mode
        }
        if {$kind eq "binary"} {
            return occupancy
        }
        if {$label in {phi psi delta_phi delta_psi delta_phi_ delta_psi_}} {
            return circular_mean
        }
        return mean
    }

    proc first_nonempty {values} {
        foreach value $values {
            if {[string trim $value] ne ""} {
                return $value
            }
        }
        return ""
    }

    proc last_nonempty {values} {
        for {set i [expr {[llength $values] - 1}]} {$i >= 0} {incr i -1} {
            set value [lindex $values $i]
            if {[string trim $value] ne ""} {
                return $value
            }
        }
        return ""
    }

    proc numeric_values {values} {
        set out {}
        foreach value $values {
            if {[is_numeric $value]} {
                lappend out [expr {double($value)}]
            }
        }
        return $out
    }

    proc aggregate_mode {values} {
        array unset counts
        array unset first_seen
        set order {}
        foreach value $values {
            set key [string trim $value]
            if {$key eq ""} {
                continue
            }
            if {![info exists counts($key)]} {
                set counts($key) 0
                set first_seen($key) [llength $order]
                lappend order $key
            }
            incr counts($key)
        }
        if {[llength $order] == 0} {
            return ""
        }
        set best [lindex $order 0]
        foreach key $order {
            if {$counts($key) > $counts($best)} {
                set best $key
            }
        }
        return $best
    }

    proc aggregate_numeric {values method} {
        set nums [numeric_values $values]
        if {[llength $nums] == 0} {
            return 0.0
        }
        switch -- $method {
            max {
                set sorted [lsort -real $nums]
                return [lindex $sorted end]
            }
            min {
                set sorted [lsort -real $nums]
                return [lindex $sorted 0]
            }
            first {
                return [lindex $nums 0]
            }
            last {
                return [lindex $nums end]
            }
            occupancy {
                set active 0
                foreach value $nums {
                    if {$value != 0.0} {
                        incr active
                    }
                }
                return [expr {$active / double([llength $nums])}]
            }
            circular_mean {
                set pi [expr {acos(-1.0)}]
                set sum_sin 0.0
                set sum_cos 0.0
                foreach value $nums {
                    set radians [expr {$value * $pi / 180.0}]
                    set sum_sin [expr {$sum_sin + sin($radians)}]
                    set sum_cos [expr {$sum_cos + cos($radians)}]
                }
                if {abs($sum_sin) < 1.0e-12 && abs($sum_cos) < 1.0e-12} {
                    return 0.0
                }
                return [expr {atan2($sum_sin, $sum_cos) * 180.0 / $pi}]
            }
            mean -
            average -
            default {
                set total 0.0
                foreach value $nums {
                    set total [expr {$total + $value}]
                }
                return [expr {$total / double([llength $nums])}]
            }
        }
    }

    proc aggregate_values {dataset values method} {
        set method [default_slice_aggregation $dataset $method]
        switch -- $method {
            mode {
                return [aggregate_mode $values]
            }
            first {
                set value [first_nonempty $values]
                if {$value ne ""} {
                    return $value
                }
                return [aggregate_numeric $values first]
            }
            last {
                set value [last_nonempty $values]
                if {$value ne ""} {
                    return $value
                }
                return [aggregate_numeric $values last]
            }
            mean -
            average -
            max -
            min -
            occupancy -
            circular_mean {
                return [aggregate_numeric $values $method]
            }
            default {
                error "Unknown slice aggregation method '$method'"
            }
        }
    }

    proc representative_column_index {start_col end_col representative} {
        set representative [string tolower [string trim $representative]]
        switch -- $representative {
            last {
                return $end_col
            }
            middle -
            mid -
            center {
                return [expr {int(floor(($start_col + $end_col) / 2.0))}]
            }
            first -
            default {
                return $start_col
            }
        }
    }

    proc slice_plan {column_count args} {
        set defaults [dict create slicing_mode slices slices "" slice_size ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set column_count [expr {int($column_count)}]
        if {$column_count < 1} {
            error "Cannot aggregate an empty matrix into slices"
        }
        set mode [string tolower [string trim [dict get $opts slicing_mode]]]
        if {$mode eq ""} {
            set mode [expr {[string trim [dict get $opts slice_size]] ne "" ? "slice_size" : "slices"}]
        }

        if {$mode eq "slice_size" || $mode eq "frames_per_slice"} {
            set slice_size [string trim [dict get $opts slice_size]]
            if {![string is integer -strict $slice_size] || int($slice_size) < 1} {
                error "Frames per slice must be a positive integer"
            }
            set slice_size [expr {int($slice_size)}]
            set slices [expr {int($column_count / $slice_size)}]
            set leftover [expr {$column_count % $slice_size}]
        } else {
            set slices [string trim [dict get $opts slices]]
            if {![string is integer -strict $slices] || int($slices) < 1} {
                error "Slices must be a positive integer"
            }
            set slices [expr {int($slices)}]
            set slice_size [expr {int($column_count / $slices)}]
            set leftover [expr {$column_count - ($slice_size * $slices)}]
        }
        if {$slices < 1 || $slice_size < 1} {
            error "Not enough columns for the requested slice plan"
        }
        return [dict create \
            mode $mode \
            frames $column_count \
            slices $slices \
            slice_size $slice_size \
            used [expr {$slices * $slice_size}] \
            leftover $leftover]
    }

    proc aggregate_to_slices {dataset args} {
        set dataset [validate $dataset]
        set defaults [dict create \
            slicing_mode slices \
            slices "" \
            slice_size "" \
            aggregation auto \
            representative first]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set columns [dict get $dataset columns]
        set rows [dict get $dataset rows]
        set values [dict get $dataset values]
        set plan [slice_plan [llength $columns] \
            slicing_mode [dict get $opts slicing_mode] \
            slices [dict get $opts slices] \
            slice_size [dict get $opts slice_size]]
        set method [default_slice_aggregation $dataset [dict get $opts aggregation]]
        set representative [dict get $opts representative]
        set new_columns {}
        set new_values {}

        for {set slice 0} {$slice < [dict get $plan slices]} {incr slice} {
            set start_col [expr {$slice * [dict get $plan slice_size]}]
            set end_col [expr {$start_col + [dict get $plan slice_size] - 1}]
            set rep_col [representative_column_index $start_col $end_col $representative]
            set rep_column [lindex $columns $rep_col]
            set first_column [lindex $columns $start_col]
            set last_column [lindex $columns $end_col]
            set label [format "slice_%d" [expr {$slice + 1}]]
            set frame [target_frame_for_column $rep_column]
            lappend new_columns [dict merge $rep_column [dict create \
                index $slice \
                label $label \
                target_type slice \
                frame $frame \
                representative_frame $frame \
                source_column_start $start_col \
                source_column_end $end_col \
                frame_start [target_frame_for_column $first_column] \
                frame_end [target_frame_for_column $last_column] \
                frame_count [dict get $plan slice_size] \
                aggregation $method]]

            set col_values {}
            for {set row 0} {$row < [llength $rows]} {incr row} {
                set window_values {}
                for {set col $start_col} {$col <= $end_col} {incr col} {
                    lappend window_values [lindex [lindex $values $col] $row]
                }
                lappend col_values [aggregate_values $dataset $window_values $method]
            }
            lappend new_values $col_values
        }

        set provenance {}
        if {[dict exists $dataset provenance]} {
            set provenance [dict get $dataset provenance]
        }
        set new_kind [dataset_value_kind $dataset]
        set new_categories [expr {[dict exists $dataset categories] ? [dict get $dataset categories] : {}}]
        if {$method eq "occupancy"} {
            set new_kind fraction
            set new_categories {}
        }
        set title [dict get $dataset title]
        if {[string first "Slices" $title] < 0} {
            append title " (Slices)"
        }
        set aggregated [dict merge $dataset [dict create \
            title $title \
            column_mode slice \
            columns $new_columns \
            values $new_values \
            value_kind $new_kind \
            categories $new_categories \
            provenance [dict merge $provenance [dict create \
                column_mode slice \
                aggregation $method \
                representative $representative \
                slice_plan $plan]]]]
        set range [value_range $new_values]
        dict set aggregated min [lindex $range 0]
        dict set aggregated max [lindex $range 1]
        if {$new_kind eq "categorical"} {
            dict set aggregated min 0
            dict set aggregated max 1
        } elseif {$new_kind eq "fraction"} {
            dict set aggregated min 0
            dict set aggregated max 1
        }
        dict set aggregated row_count [llength $rows]
        dict set aggregated column_count [llength $new_columns]
        return [validate $aggregated]
    }

    proc target_molid_for_column {dataset column} {
        if {[dict exists $column slice_molid] && [string trim [dict get $column slice_molid]] ne ""} {
            return [dict get $column slice_molid]
        }
        if {[dict exists $column molid] && [string trim [dict get $column molid]] ne ""} {
            return [dict get $column molid]
        }
        if {[dict exists $dataset molid] && [string trim [dict get $dataset molid]] ne ""} {
            return [dict get $dataset molid]
        }
        return ""
    }

    proc target_frame_for_column {column} {
        if {[dict exists $column frame]} {
            return [dict get $column frame]
        }
        return 0
    }

    proc loaded_molid {molid} {
        return [expr {$molid ne "" && [info commands molinfo] ne "" && [lsearch -exact [molinfo list] $molid] != -1}]
    }

    proc dataset_target_columns {dataset} {
        set targets {}
        set columns [dict get $dataset columns]
        for {set col 0} {$col < [llength $columns]} {incr col} {
            set column [lindex $columns $col]
            set molid [target_molid_for_column $dataset $column]
            if {![loaded_molid $molid]} {
                continue
            }
            lappend targets [dict create \
                column $col \
                molid $molid \
                frame [target_frame_for_column $column]]
        }
        return $targets
    }

    proc copy_to_user {dataset field} {
        set valid_fields {user user2 user3 user4}
        if {[lsearch -exact $valid_fields $field] == -1} {
            error "User field must be one of: [join $valid_fields {, }]"
        }
        set targets [dataset_target_columns $dataset]
        if {[llength $targets] == 0} {
            error "Timeline dataset does not reference any loaded target molecules or frames"
        }

        set columns [dict get $dataset columns]
        set rows [dict get $dataset rows]
        set touched_molids {}
        foreach target $targets {
            set molid [dict get $target molid]
            set frame [dict get $target frame]
            if {[lsearch -exact $touched_molids $molid] == -1} {
                lappend touched_molids $molid
            }
            set all_sel [atomselect $molid all frame $frame]
            try {
                $all_sel set $field 0
            } finally {
                catch {$all_sel delete}
            }
        }

        for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            set row [lindex $rows $row_index]
            set selection [row_selection $row]
            if {$selection eq ""} {
                continue
            }
            foreach target $targets {
                set col [dict get $target column]
                set value [cell_value $dataset $row_index $col]
                if {![is_numeric $value]} {
                    continue
                }
                set sel [atomselect [dict get $target molid] $selection frame [dict get $target frame]]
                try {
                    if {[$sel num] > 0} {
                        $sel set $field $value
                    }
                } finally {
                    catch {$sel delete}
                }
            }
        }
        set primary_molid [lindex $touched_molids 0]
        return [dict create \
            molid $primary_molid \
            molids $touched_molids \
            field $field \
            rows [llength $rows] \
            columns [llength $targets]]
    }
}
