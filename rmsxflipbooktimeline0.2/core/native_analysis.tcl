################################################################################
# VMD-native RMSX analysis prototype
################################################################################

namespace eval ::RMSXFlipbookTimeline::NativeAnalysis {
    proc append_chain_selection {selection chain} {
        set cleaned [string trim $chain]
        if {$cleaned eq ""} {
            return $selection
        }
        return "($selection) and (segid $cleaned or chain $cleaned)"
    }

    proc csv_quote {value} {
        set text [format "%s" $value]
        if {[regexp {[,"\n\r]} $text]} {
            regsub -all {"} $text {""} text
            return "\"$text\""
        }
        return $text
    }

    proc write_csv {filename residue_records slice_columns} {
        set fp [open $filename w]
        try {
            set header {ResidueID ChainID}
            foreach item $slice_columns {
                lappend header [lindex $item 0]
            }
            puts $fp [join [lmap value $header {csv_quote $value}] ","]

            foreach record $residue_records {
                set row [list [dict get $record resid] [dict get $record chain]]
                foreach item $slice_columns {
                    lappend row [lindex [lindex $item 1] [dict get $record index]]
                }
                puts $fp [join [lmap value $row {csv_quote $value}] ","]
            }
        } finally {
            catch {close $fp}
        }
    }

    proc numeric_csv_value {value} {
        return [format "%.15g" [expr {double($value)}]]
    }

    proc write_rmsd_csv {filename rows} {
        set fp [open $filename w]
        try {
            puts $fp "Frame,Time,RMSD"
            foreach row $rows {
                puts $fp [join [list \
                    [numeric_csv_value [dict get $row frame]] \
                    [numeric_csv_value [dict get $row time]] \
                    [numeric_csv_value [dict get $row rmsd]]] ","]
            }
        } finally {
            catch {close $fp}
        }
    }

    proc write_rmsf_csv {filename residue_records values} {
        set fp [open $filename w]
        try {
            puts $fp "ResidueID,RMSF"
            foreach record $residue_records value $values {
                puts $fp [join [list \
                    [dict get $record resid] \
                    [numeric_csv_value $value]] ","]
            }
        } finally {
            catch {close $fp}
        }
    }

    proc residue_records_from_selection {selection} {
        set raw [$selection get {residue resid chain segid resname}]
        set seen [dict create]
        set records {}
        foreach atom $raw {
            set residue [lindex $atom 0]
            if {[dict exists $seen $residue]} {
                continue
            }
            dict set seen $residue 1

            set chain [string trim [lindex $atom 2]]
            set segid [string trim [lindex $atom 3]]
            if {$chain eq "" || $chain eq "X"} {
                set chain $segid
            }

            lappend records [dict create \
                residue $residue \
                resid [lindex $atom 1] \
                chain $chain \
                segid $segid \
                resname [lindex $atom 4] \
                index [llength $records]]
        }
        return $records
    }

    proc beta_values_for_selection {selection residue_records values} {
        set value_by_residue [dict create]
        foreach record $residue_records value $values {
            dict set value_by_residue [dict get $record residue] $value
        }

        set beta_values {}
        foreach residue [$selection get residue] {
            if {[dict exists $value_by_residue $residue]} {
                lappend beta_values [dict get $value_by_residue $residue]
            } else {
                lappend beta_values 0.0
            }
        }
        return $beta_values
    }

    proc beta_values_for_selection_by_record_key {selection residue_records values} {
        set value_by_key [dict create]
        foreach record $residue_records value $values {
            dict set value_by_key "[dict get $record chain]|[dict get $record resid]" $value
        }

        set beta_values {}
        foreach atom [$selection get {resid chain segid}] {
            set key [record_key_from_parts [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]]
            if {[dict exists $value_by_key $key]} {
                lappend beta_values [dict get $value_by_key $key]
            } else {
                lappend beta_values 0.0
            }
        }
        return $beta_values
    }

    proc format_values {values decimals} {
        set formatted {}
        set pattern "%.${decimals}f"
        foreach value $values {
            lappend formatted [format $pattern $value]
        }
        return $formatted
    }

    proc transform_mask_selection {selection} {
        set transformed $selection
        regsub -all {resid[[:space:]]+([0-9]+):([0-9]+)} $transformed {resid \1 to \2} transformed
        return $transformed
    }

    proc value_columns_log_transform {slice_columns decimals} {
        set transformed {}
        foreach item $slice_columns {
            set name [lindex $item 0]
            set values [lindex $item 1]
            set out_values {}
            foreach value $values {
                lappend out_values [format "%.${decimals}f" [expr {log(1.0 + double($value))}]]
            }
            set log_name [string map {".dcd" "_log.dcd"} $name]
            lappend transformed [list $log_name $out_values]
        }
        return $transformed
    }

    proc analysis_type_selections {analysis_type full_backbone} {
        set kind [string tolower [string trim $analysis_type]]
        switch -- $kind {
            dna -
            rna -
            nucleic -
            nucleicacid {
                set analysis_selection "nucleic and name P"
                if {$full_backbone} {
                    set full_selection "nucleic and backbone"
                } else {
                    set full_selection $analysis_selection
                }
            }
            generic {
                set analysis_selection "name CA"
                set full_selection $analysis_selection
            }
            default {
                set analysis_selection "protein and name CA"
                if {$full_backbone} {
                    set full_selection "protein and backbone"
                } else {
                    set full_selection $analysis_selection
                }
            }
        }
        return [dict create selection $full_selection analysis_selection $analysis_selection]
    }

    proc resolve_analysis_options {opts} {
        set presets [analysis_type_selections \
            [dict get $opts analysis_type] \
            [dict get $opts full_backbone]]
        if {[string trim [dict get $opts selection]] eq ""} {
            dict set opts selection [dict get $presets selection]
        }
        if {[string trim [dict get $opts analysis_selection]] eq ""} {
            dict set opts analysis_selection [dict get $presets analysis_selection]
        }
        return $opts
    }

    proc normalized_manual_length_ns {manual_length_ns manual_length manual_unit} {
        if {[string trim $manual_length_ns] ne ""} {
            return [expr {double($manual_length_ns)}]
        }
        if {[string trim $manual_length] eq ""} {
            return ""
        }

        set value [expr {double($manual_length)}]
        switch -- [string tolower [string trim $manual_unit]] {
            fs {
                return [expr {$value / 1000000.0}]
            }
            ps {
                return [expr {$value / 1000.0}]
            }
            default {
                return $value
            }
        }
    }

    proc format_simulation_length_ns {value} {
        set ns [expr {double($value)}]
        if {$ns == 0.0} {
            set decimals 3
        } elseif {$ns < 0.001} {
            set decimals 6
        } elseif {$ns < 0.01} {
            set decimals 5
        } else {
            set decimals 3
        }
        return [format "%.${decimals}f" $ns]
    }

    proc rmsx_style_output_name {trajectory prefix extension opts plan} {
        set manual_ns [normalized_manual_length_ns \
            [dict get $opts manual_length_ns] \
            [dict get $opts manual_length] \
            [dict get $opts manual_unit]]
        if {$manual_ns eq ""} {
            set frames [dict get $plan adjusted_frames]
            if {$frames <= 1} {
                set manual_ns 0.0
            } else {
                set manual_ns [expr {(($frames - 1) * double([dict get $opts rmsd_time_step])) / 1000.0}]
            }
        }

        set sim_name [file rootname [file tail $trajectory]]
        return "${prefix}_${sim_name}_[format_simulation_length_ns $manual_ns]_ns.${extension}"
    }

    proc resolve_csv_name {trajectory opts plan} {
        set explicit [string trim [dict get $opts csv_name]]
        if {$explicit ne ""} {
            return $explicit
        }
        set name_style [string tolower [string trim [dict get $opts name_style]]]
        if {$name_style in {rmsx rmsx_style python}} {
            return [rmsx_style_output_name \
                $trajectory \
                [dict get $opts csv_prefix] \
                csv \
                $opts \
                $plan]
        }
        if {[dict exists $opts native_csv_name]} {
            set native_name [string trim [dict get $opts native_csv_name]]
            if {$native_name ne ""} {
                return $native_name
            }
        }
        return rmsx_vmd_native.csv
    }

    proc record_key_from_parts {resid chain segid} {
        set clean_chain [string trim $chain]
        set clean_segid [string trim $segid]
        if {$clean_chain eq "" || $clean_chain eq "X"} {
            set clean_chain $clean_segid
        }
        return "$clean_chain|$resid"
    }

    proc record_key {record} {
        return "[dict get $record chain]|[dict get $record resid]"
    }

    proc build_mask_metadata {molid full_selection residue_records mask_selection vmd_frame} {
        set metadata {}
        foreach record $residue_records {
            lappend metadata [dict create \
                resid [dict get $record resid] \
                chain [dict get $record chain] \
                masked 0]
        }

        set cleaned [string trim $mask_selection]
        if {$cleaned eq ""} {
            return $metadata
        }

        set masked_keys [dict create]
        foreach clause [split $cleaned ";"] {
            set clause [string trim $clause]
            if {$clause eq ""} {
                continue
            }

            set vmd_clause [transform_mask_selection $clause]
            set sel [atomselect $molid "(($full_selection) and ($vmd_clause))" frame $vmd_frame]
            try {
                foreach atom [$sel get {resid chain segid}] {
                    dict set masked_keys [record_key_from_parts [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]] 1
                }
            } finally {
                catch {$sel delete}
            }
        }

        set updated {}
        foreach item $metadata record $residue_records {
            if {[dict exists $masked_keys [record_key $record]]} {
                dict set item masked 1
            }
            lappend updated $item
        }
        return $updated
    }

    proc write_mask_metadata {filename metadata} {
        set fp [open $filename w]
        try {
            puts $fp "ResidueID,ChainID,Masked"
            foreach item $metadata {
                set masked "False"
                if {[dict get $item masked]} {
                    set masked "True"
                }
                puts $fp [join [list [dict get $item resid] [dict get $item chain] $masked] ","]
            }
        } finally {
            catch {close $fp}
        }
    }

    proc summary_rows {residue_records slice_columns mask_metadata count} {
        set entries {}
        for {set row_index 0} {$row_index < [llength $residue_records]} {incr row_index} {
            if {[llength $mask_metadata] > $row_index && [dict get [lindex $mask_metadata $row_index] masked]} {
                continue
            }

            set record [lindex $residue_records $row_index]
            foreach item $slice_columns {
                set time_slice [lindex $item 0]
                set value [expr {double([lindex [lindex $item 1] $row_index])}]
                lappend entries [list \
                    $value \
                    [dict get $record resid] \
                    [dict get $record chain] \
                    $time_slice]
            }
        }

        if {[llength $entries] == 0 || $count <= 0} {
            return [dict create top {} bottom {}]
        }

        set top_entries [lrange [lsort -real -decreasing -index 0 $entries] 0 [expr {$count - 1}]]
        set bottom_entries [lrange [lsort -real -index 0 $entries] 0 [expr {$count - 1}]]
        return [dict create top $top_entries bottom $bottom_entries]
    }

    proc write_summary_csv {filename summary} {
        set fp [open $filename w]
        try {
            puts $fp "Group,Rank,ResidueID,ChainID,TimeSlice,RMSX"
            foreach group {top bottom} {
                set rank 1
                foreach entry [dict get $summary $group] {
                    puts $fp [join [list \
                        $group \
                        $rank \
                        [lindex $entry 1] \
                        [lindex $entry 2] \
                        [lindex $entry 3] \
                        [numeric_csv_value [lindex $entry 0]]] ","]
                    incr rank
                }
            }
        } finally {
            catch {close $fp}
        }
    }

    proc count_masked_metadata {mask_metadata} {
        set count 0
        foreach item $mask_metadata {
            if {[dict get $item masked]} {
                incr count
            }
        }
        return $count
    }

    proc clip_masked_slice_columns {slice_columns mask_metadata {allow_fully_masked 0} {clip_bounds ""}} {
        set masked_indices {}
        set unmasked_values {}
        for {set i 0} {$i < [llength $mask_metadata]} {incr i} {
            set is_masked [dict get [lindex $mask_metadata $i] masked]
            if {$is_masked} {
                lappend masked_indices $i
                continue
            }
            foreach item $slice_columns {
                lappend unmasked_values [expr {double([lindex [lindex $item 1] $i])}]
            }
        }

        if {[llength $masked_indices] == 0} {
            return [dict create columns $slice_columns masked_count 0 clip_min "" clip_max ""]
        }

        if {[llength $clip_bounds] == 2} {
            set clip_min [expr {double([lindex $clip_bounds 0])}]
            set clip_max [expr {double([lindex $clip_bounds 1])}]
        } elseif {[llength $unmasked_values] == 0} {
            if {$allow_fully_masked} {
                return [dict create columns $slice_columns masked_count [llength $masked_indices] clip_min "" clip_max ""]
            }
            error "All analyzed residues are masked. Remove some masks or include at least one unmasked residue."
        } else {
            set clip_min [lindex [lsort -real $unmasked_values] 0]
            set clip_max [lindex [lsort -real $unmasked_values] end]
        }

        set clipped_columns {}
        foreach item $slice_columns {
            set name [lindex $item 0]
            set values [lindex $item 1]
            set clipped_values {}
            for {set i 0} {$i < [llength $values]} {incr i} {
                set value [expr {double([lindex $values $i])}]
                if {[lsearch -exact $masked_indices $i] >= 0} {
                    if {$value < $clip_min} {
                        set value $clip_min
                    } elseif {$value > $clip_max} {
                        set value $clip_max
                    }
                }
                lappend clipped_values $value
            }
            lappend clipped_columns [list $name $clipped_values]
        }

        return [dict create \
            columns $clipped_columns \
            masked_count [llength $masked_indices] \
            clip_min $clip_min \
            clip_max $clip_max]
    }

    proc format_slice_columns {slice_columns decimals} {
        set formatted {}
        foreach item $slice_columns {
            lappend formatted [list [lindex $item 0] [format_values [lindex $item 1] $decimals]]
        }
        return $formatted
    }

    proc selection_coordinate_list {selection label} {
        set coords [$selection get {x y z}]
        if {[llength $coords] == 0} {
            error "$label selection returned no coordinates"
        }
        return $coords
    }

    proc ensure_representative_selection {selection records label} {
        set atom_count [$selection num]
        set residue_count [llength $records]
        if {$atom_count != $residue_count} {
            error "$label requires one representative atom per residue; selection returned $atom_count atoms for $residue_count residues"
        }
    }

    proc assert_matching_records {reference_records current_records label} {
        if {[llength $current_records] != [llength $reference_records]} {
            error "$label residue count changed: expected [llength $reference_records], got [llength $current_records]"
        }
        for {set i 0} {$i < [llength $reference_records]} {incr i} {
            set expected [record_key [lindex $reference_records $i]]
            set actual [record_key [lindex $current_records $i]]
            if {$actual ne $expected} {
                error "$label residue order changed at index $i: expected $expected, got $actual"
            }
        }
    }

    proc coordinate_distances {reference_coords current_coords decimals} {
        if {[llength $current_coords] != [llength $reference_coords]} {
            error "Coordinate count mismatch: expected [llength $reference_coords], got [llength $current_coords]"
        }

        set values {}
        for {set i 0} {$i < [llength $reference_coords]} {incr i} {
            set ref [lindex $reference_coords $i]
            set cur [lindex $current_coords $i]
            set dx [expr {double([lindex $cur 0]) - double([lindex $ref 0])}]
            set dy [expr {double([lindex $cur 1]) - double([lindex $ref 1])}]
            set dz [expr {double([lindex $cur 2]) - double([lindex $ref 2])}]
            lappend values [format "%.${decimals}f" [expr {sqrt(($dx * $dx) + ($dy * $dy) + ($dz * $dz))}]]
        }
        return $values
    }

    proc numeric_list {values label} {
        set normalized [string map {"," " "} [string trim $values]]
        set out {}
        foreach value $normalized {
            set value [string trim $value]
            if {$value eq ""} {
                continue
            }
            if {![string is double -strict $value]} {
                error "$label contains a non-numeric value: $value"
            }
            lappend out [expr {double($value)}]
        }
        if {[llength $out] == 0} {
            error "$label must contain at least one numeric value"
        }
        return $out
    }

    proc point_distance {a b} {
        set dx [expr {double([lindex $b 0]) - double([lindex $a 0])}]
        set dy [expr {double([lindex $b 1]) - double([lindex $a 1])}]
        set dz [expr {double([lindex $b 2]) - double([lindex $a 2])}]
        return [expr {sqrt(($dx * $dx) + ($dy * $dy) + ($dz * $dz))}]
    }

    proc pairwise_distances {coords} {
        set matrix {}
        set count [llength $coords]
        for {set i 0} {$i < $count} {incr i} {
            set row {}
            set a [lindex $coords $i]
            for {set j 0} {$j < $count} {incr j} {
                lappend row [point_distance $a [lindex $coords $j]]
            }
            lappend matrix $row
        }
        return $matrix
    }

    proc lddt_reference_model {reference_coords inclusion_radius} {
        set radius [expr {double($inclusion_radius)}]
        if {$radius <= 0.0} {
            error "lDDT inclusion_radius must be greater than 0"
        }

        set ref_dists [pairwise_distances $reference_coords]
        set neighbor_indices {}
        set count [llength $reference_coords]
        for {set i 0} {$i < $count} {incr i} {
            set neighbors {}
            set row [lindex $ref_dists $i]
            for {set j 0} {$j < $count} {incr j} {
                if {$i == $j} {
                    continue
                }
                if {[lindex $row $j] < $radius} {
                    lappend neighbors $j
                }
            }
            lappend neighbor_indices $neighbors
        }
        return [dict create distances $ref_dists neighbors $neighbor_indices]
    }

    proc lddt_instability_values {reference_model current_coords thresholds empty_neighbor_instability} {
        set threshold_values [numeric_list $thresholds "lDDT thresholds"]
        set ref_dists [dict get $reference_model distances]
        set neighbor_indices [dict get $reference_model neighbors]
        if {[llength $current_coords] != [llength $ref_dists]} {
            error "lDDT coordinate count mismatch: expected [llength $ref_dists], got [llength $current_coords]"
        }

        set current_dists [pairwise_distances $current_coords]
        set values {}
        for {set i 0} {$i < [llength $current_coords]} {incr i} {
            set neighbors [lindex $neighbor_indices $i]
            set neighbor_count [llength $neighbors]
            if {$neighbor_count == 0} {
                lappend values [expr {double($empty_neighbor_instability)}]
                continue
            }

            set score_total 0.0
            foreach threshold $threshold_values {
                set preserved 0
                foreach j $neighbors {
                    set ref_distance [lindex [lindex $ref_dists $i] $j]
                    set current_distance [lindex [lindex $current_dists $i] $j]
                    set diff [expr {abs(double($current_distance) - double($ref_distance))}]
                    if {$diff < $threshold} {
                        incr preserved
                    }
                }
                set score_total [expr {$score_total + ($preserved / double($neighbor_count))}]
            }

            set lddt [expr {$score_total / double([llength $threshold_values])}]
            lappend values [expr {1.0 - $lddt}]
        }
        return $values
    }

    proc guess_molfile_type {path role} {
        set ext [string tolower [file extension $path]]
        switch -- $ext {
            .pdb -
            .ent {
                return pdb
            }
            .psf {
                return psf
            }
            .gro {
                return gro
            }
            .mol2 {
                return mol2
            }
            .mae {
                return mae
            }
            .parm7 -
            .prmtop {
                return parm7
            }
            .dcd {
                return dcd
            }
            .xtc {
                return xtc
            }
            .trr {
                return trr
            }
            .nc -
            .netcdf {
                return netcdf
            }
            .crd {
                return crd
            }
            .rst7 -
            .inpcrd {
                return rst7
            }
            default {
                return ""
            }
        }
    }

    proc resolve_molfile_type {path requested role} {
        set cleaned [string tolower [string trim $requested]]
        if {$cleaned eq "" || $cleaned in {auto autodetect detect infer}} {
            return [guess_molfile_type $path $role]
        }
        return [string trim $requested]
    }

    proc load_structure_file {path requested_type} {
        set normalized [file normalize $path]
        set mol_type [resolve_molfile_type $normalized $requested_type topology]
        if {$mol_type eq ""} {
            mol new $normalized waitfor all
        } else {
            mol new $normalized type $mol_type waitfor all
        }
        set molid [molinfo top get id]
        return [dict create molid $molid type $mol_type]
    }

    proc add_coordinate_file {molid path requested_type} {
        set normalized [file normalize $path]
        set mol_type [resolve_molfile_type $normalized $requested_type trajectory]
        if {$mol_type eq ""} {
            mol addfile $normalized waitfor all molid $molid
        } else {
            mol addfile $normalized type $mol_type waitfor all molid $molid
        }
        return $mol_type
    }

    proc load_trajectory {topology trajectory args} {
        set defaults [dict create topology_type auto trajectory_type auto]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set top_info [load_structure_file $topology [dict get $opts topology_type]]
        set molid [dict get $top_info molid]
        set initial_frames [molinfo $molid get numframes]
        set trajectory_type [add_coordinate_file $molid $trajectory [dict get $opts trajectory_type]]
        set total_frames [molinfo $molid get numframes]
        return [dict create \
            molid $molid \
            topology_type [dict get $top_info type] \
            trajectory_type $trajectory_type \
            initial_frame_count $initial_frames \
            total_frame_count $total_frames]
    }

    proc hide_cleanup_molecule {molid opts} {
        if {![dict exists $opts cleanup] || ![dict get $opts cleanup]} {
            return
        }
        if {[info commands mol] eq "" || [info commands molinfo] eq ""} {
            return
        }
        if {[lsearch -exact [molinfo list] $molid] == -1} {
            return
        }
        catch {mol off $molid}
        catch {display update ui}
    }

    proc resolve_frame_offset {requested load_info} {
        set cleaned [string tolower [string trim $requested]]
        if {$cleaned eq "" || $cleaned in {auto autodetect detect infer}} {
            return [expr {int([dict get $load_info initial_frame_count])}]
        }
        if {![string is integer -strict $requested]} {
            error "frame_offset must be an integer or 'auto'"
        }
        set value [expr {int($requested)}]
        if {$value < 0} {
            error "frame_offset must be at least 0"
        }
        return $value
    }

    proc emit_progress {opts event} {
        if {![dict exists $opts progress_callback]} {
            return ""
        }
        set callback [dict get $opts progress_callback]
        if {[string trim $callback] eq ""} {
            return ""
        }

        if {![dict exists $event stage]} {
            dict set event stage progress
        }
        if {![dict exists $event message]} {
            dict set event message [dict get $event stage]
        }

        set code [catch {
            uplevel #0 [concat $callback [list $event]]
        } result result_options]
        if {$code != 0} {
            return -options $result_options $result
        }

        set lowered [string tolower [string trim $result]]
        if {$lowered in {cancel cancelled stop abort}} {
            error "Native analysis cancelled by progress callback"
        }
        return $result
    }

    proc output_sentinel_name {} {
        return ".rmsx_timeline_output_dir"
    }

    proc compatible_output_sentinel_names {} {
        return [list [output_sentinel_name] ".rmsx_output_dir"]
    }

    proc output_dir_entries {output_dir} {
        if {![file isdirectory $output_dir]} {
            return {}
        }

        set seen [dict create]
        set pairs {}
        foreach pattern [list * .*] {
            foreach path [glob -nocomplain -directory $output_dir $pattern] {
                set name [file tail $path]
                if {$name eq "." || $name eq ".."} {
                    continue
                }
                set normalized [file normalize $path]
                if {[dict exists $seen $normalized]} {
                    continue
                }
                dict set seen $normalized 1
                lappend pairs [list [string tolower $name] $normalized]
            }
        }

        set out {}
        foreach pair [lsort -dictionary -index 0 $pairs] {
            lappend out [lindex $pair 1]
        }
        return $out
    }

    proc output_dir_overwrite_preview {output_dir {limit 25}} {
        set entries [output_dir_entries $output_dir]
        if {[llength $entries] == 0} {
            return "No existing top-level entries would be deleted."
        }

        set lines {}
        set shown 0
        foreach path $entries {
            if {$shown >= $limit} {
                break
            }
            set suffix ""
            if {![catch {file type $path} type] && $type eq "link"} {
                set suffix "@"
            } elseif {[file isdirectory $path]} {
                set suffix "/"
            }
            lappend lines "- [file tail $path]$suffix"
            incr shown
        }
        if {[llength $entries] > $limit} {
            lappend lines "- ... ([expr {[llength $entries] - $limit}] more)"
        }

        return "Top-level entries that would be deleted:\n[join $lines \n]"
    }

    proc path_is_within {parent child} {
        set parent [file normalize $parent]
        set child [file normalize $child]
        if {$child eq $parent} {
            return 1
        }

        set separator "/"
        if {[string index $parent end] eq "/"} {
            set separator ""
        }
        return [string match "${parent}${separator}*" $child]
    }

    proc output_dir_safety_reason {output_dir {topology_file ""} {trajectory_file ""}} {
        set output_path [file normalize $output_dir]

        if {[file dirname $output_path] eq $output_path} {
            return "Refusing to overwrite '$output_path' because it is a filesystem root. Choose a dedicated RMSX output directory."
        }

        if {![catch {file normalize ~} home_path] && $output_path eq $home_path} {
            return "Refusing to overwrite '$output_path' because it is your home directory. Choose a dedicated RMSX output directory."
        }

        set cwd_path [file normalize [pwd]]
        if {$output_path eq $cwd_path} {
            return "Refusing to overwrite '$output_path' because it is the current working directory. Choose a dedicated RMSX output directory."
        }

        foreach input_file [list $topology_file $trajectory_file] {
            if {[string trim $input_file] eq ""} {
                continue
            }
            set input_path [file normalize $input_file]
            set input_parent [file dirname $input_path]

            if {$output_path eq $input_parent} {
                return "Refusing to overwrite '$output_path' because it is the same directory as the input file '[file tail $input_path]'. Choose a dedicated RMSX output directory."
            }

            if {[path_is_within $output_path $input_path]} {
                return "Refusing to overwrite '$output_path' because it contains the input file '$input_path'. Choose a dedicated RMSX output directory."
            }
        }

        return ""
    }

    proc is_output_benign_top_level_name {name} {
        return [expr {$name in [concat [compatible_output_sentinel_names] [list .DS_Store Thumbs.db]]}]
    }

    proc is_rmsx_managed_output_dir {output_dir} {
        if {![file exists $output_dir]} {
            return 1
        }
        if {![file isdirectory $output_dir]} {
            return 0
        }

        foreach path [output_dir_entries $output_dir] {
            set name [file tail $path]
            if {[is_output_benign_top_level_name $name]} {
                continue
            }
            if {[file isdirectory $path] && ($name eq "combined" || [string match "chain_*" $name])} {
                continue
            }
            return 0
        }
        return 1
    }

    proc output_dir_has_managed_contents {output_dir} {
        foreach path [output_dir_entries $output_dir] {
            set name [file tail $path]
            if {[is_output_benign_top_level_name $name]} {
                continue
            }
            return 1
        }
        return 0
    }

    proc write_output_dir_sentinel {output_dir} {
        file mkdir $output_dir
        set sentinel_path [file join $output_dir [output_sentinel_name]]
        set fp [open $sentinel_path w]
        try {
            puts $fp "managed_by=rmsx"
        } finally {
            catch {close $fp}
        }
        return $sentinel_path
    }

    proc prepare_managed_output_dir {output_dir args} {
        set defaults [dict create \
            overwrite 0 \
            verbose 1 \
            topology_file "" \
            trajectory_file ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set output_path [file normalize $output_dir]
        set preview [output_dir_overwrite_preview $output_path]
        set safety_reason [output_dir_safety_reason \
            $output_path \
            [dict get $opts topology_file] \
            [dict get $opts trajectory_file]]
        if {$safety_reason ne ""} {
            error "$safety_reason\n$preview"
        }

        if {[file exists $output_path] && ![file isdirectory $output_path]} {
            error "Output path '$output_path' exists but is not a directory."
        }

        if {[file exists $output_path]} {
            if {![is_rmsx_managed_output_dir $output_path]} {
                error "Refusing to overwrite '$output_path' because it does not look like an RMSX-managed output directory. Allowed top-level contents are 'combined', 'chain_*', and RMSX sentinel files ([join [compatible_output_sentinel_names] {, }]).\n$preview"
            }

            if {[dict get $opts overwrite]} {
                if {[dict get $opts verbose]} {
                    puts "Clearing main output directory: $output_path"
                }
                foreach path [output_dir_entries $output_path] {
                    file delete -force $path
                }
            } elseif {[output_dir_has_managed_contents $output_path]} {
                error "Output directory '$output_path' already contains RMSX-managed results. Pass -overwrite 1 to clear it.\n$preview"
            }
        } else {
            file mkdir $output_path
            if {[dict get $opts verbose]} {
                puts "Created main output directory: $output_path"
            }
        }

        set sentinel_path [write_output_dir_sentinel $output_path]
        return [dict create output_dir $output_path sentinel $sentinel_path]
    }

    proc clean_previous_slice_outputs {output_dir} {
        set deleted {}
        foreach path [glob -nocomplain -directory $output_dir "slice_*_first_frame.pdb"] {
            set name [file tail $path]
            if {[regexp {^slice_[0-9]+_first_frame\.pdb$} $name]} {
                file delete $path
                lappend deleted [file normalize $path]
            }
        }
        return $deleted
    }

    proc unique_sorted {values} {
        set seen [dict create]
        set out {}
        foreach value $values {
            set cleaned [string trim $value]
            if {$cleaned eq ""} {
                continue
            }
            if {![dict exists $seen $cleaned]} {
                dict set seen $cleaned 1
                lappend out $cleaned
            }
        }
        return [lsort -dictionary $out]
    }

    proc discover_valid_chains {topology analysis_selection {topology_type auto}} {
        set top_info [load_structure_file [file normalize $topology] $topology_type]
        set molid [dict get $top_info molid]
        set chains {}
        try {
            set sel [atomselect $molid $analysis_selection frame 0]
            try {
                foreach atom [$sel get {chain segid}] {
                    set chain [string trim [lindex $atom 0]]
                    set segid [string trim [lindex $atom 1]]
                    if {$segid ne ""} {
                        lappend chains $segid
                    } elseif {$chain ne ""} {
                        lappend chains $chain
                    }
                }
            } finally {
                catch {$sel delete}
            }

            set valid {}
            foreach chain [unique_sorted $chains] {
                set chain_sel [atomselect $molid [append_chain_selection $analysis_selection $chain] frame 0]
                try {
                    if {[$chain_sel num] > 0} {
                        lappend valid $chain
                    }
                } finally {
                    catch {$chain_sel delete}
                }
            }
            return $valid
        } finally {
            catch {mol delete $molid}
        }
    }

    proc clean_previous_combined_outputs {output_dir} {
        set deleted [clean_previous_slice_outputs $output_dir]
        foreach name {
            masked_residues.csv
            rmsx_flipbook_timeline_manifest.tcldict
            rmsx_vmd_native.csv
            lddt_vmd_native.csv
            rmsd.csv
            rmsd_by_chain.csv
            rmsf.csv
            rmsx_summary.csv
            rmsx_heatmap.svg
            rmsx_report.svg
        } {
            set path [file join $output_dir $name]
            if {[file exists $path]} {
                file delete $path
                lappend deleted [file normalize $path]
            }
        }
        return $deleted
    }

    proc combine_pdb_files {chain_dirs combined_dir args} {
        set defaults [dict create overwrite 0 verbose 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        if {[llength $chain_dirs] == 0} {
            error "No chain directories were provided for combined PDB output"
        }

        file mkdir $combined_dir
        set deleted {}
        if {[dict get $opts overwrite]} {
            set deleted [clean_previous_combined_outputs $combined_dir]
        }

        set first_dir [lindex $chain_dirs 0]
        set pairs {}
        foreach path [glob -nocomplain -directory $first_dir "slice_*_first_frame.pdb"] {
            set name [file tail $path]
            if {[regexp {^slice_([0-9]+)_first_frame\.pdb$} $name _ slice_index]} {
                lappend pairs [list [expr {$slice_index + 0}] $name]
            }
        }
        set pairs [lsort -integer -index 0 $pairs]
        if {[llength $pairs] == 0} {
            error "No slice PDB files found in $first_dir"
        }

        set written {}
        foreach pair $pairs {
            set pdb_name [lindex $pair 1]
            set out_path [file join $combined_dir $pdb_name]
            if {![dict get $opts overwrite] && [file exists $out_path]} {
                error "Combined slice output already exists: $out_path"
            }

            set combined_lines {}
            set first_file 1
            foreach chain_dir $chain_dirs {
                set in_path [file join $chain_dir $pdb_name]
                if {![file exists $in_path]} {
                    error "Missing $pdb_name in chain directory $chain_dir"
                }
                set fp [open $in_path r]
                try {
                    while {[gets $fp line] >= 0} {
                        if {$first_file} {
                            if {![string match "END*" $line]} {
                                lappend combined_lines $line
                            }
                        } elseif {[string match "ATOM*" $line] || [string match "HETATM*" $line]} {
                            lappend combined_lines $line
                        }
                    }
                } finally {
                    catch {close $fp}
                }
                set first_file 0
            }
            lappend combined_lines "END"

            set fp [open $out_path w]
            try {
                foreach line $combined_lines {
                    puts $fp $line
                }
            } finally {
                catch {close $fp}
            }
            lappend written [file normalize $out_path]
        }

        if {[dict get $opts verbose]} {
            puts "  Combined [llength $written] slice PDB files into $combined_dir"
        }
        return [dict create files $written deleted $deleted]
    }

    proc chain_id_from_output_dir {chain_dir} {
        set name [file tail [file normalize $chain_dir]]
        if {[regexp {^chain_(.+)_(rmsx|shiftmap|lddtmap)$} $name _ chain _suffix]} {
            return $chain
        }
        if {[regexp {^chain_(.+)$} $name _ chain]} {
            return $chain
        }
        return ""
    }

    proc combined_csv_name {csv_paths fallback_name} {
        set cleaned [string trim $fallback_name]
        if {$cleaned ne ""} {
            return $cleaned
        }
        if {[llength $csv_paths] > 0} {
            return [file tail [lindex $csv_paths 0]]
        }
        return "rmsx_vmd_native.csv"
    }

    proc combine_matrix_csvs {csv_paths combined_dir args} {
        set defaults [dict create csv_name "" summary_name rmsx_summary.csv summary_n 3 overwrite 0]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        if {[llength $csv_paths] == 0} {
            error "No matrix CSV files were provided for combined output"
        }

        file mkdir $combined_dir
        set header {}
        set rows {}
        foreach csv_path $csv_paths {
            set csv_data [read_simple_csv $csv_path]
            set parsed [csv_to_records_and_columns $csv_data]
            if {[llength [dict get $parsed residue_records]] == 0} {
                continue
            }
            set current_header [dict get $csv_data header]
            if {[llength $header] == 0} {
                set header $current_header
            } elseif {$current_header ne $header} {
                error "Cannot combine matrix CSVs with different headers: $csv_path"
            }
            foreach row [dict get $csv_data rows] {
                lappend rows $row
            }
        }
        if {[llength $rows] == 0} {
            error "Combined matrix CSV would be empty"
        }

        set csv_path [file join $combined_dir [combined_csv_name $csv_paths [dict get $opts csv_name]]]
        if {![dict get $opts overwrite] && [file exists $csv_path]} {
            error "Combined matrix CSV already exists: $csv_path"
        }
        write_simple_csv $csv_path $header $rows

        set summary_path ""
        set summary_name [string trim [dict get $opts summary_name]]
        if {$summary_name ne ""} {
            set summary_path [file join $combined_dir $summary_name]
            if {![dict get $opts overwrite] && [file exists $summary_path]} {
                error "Combined summary CSV already exists: $summary_path"
            }
            write_summary_from_csv $csv_path $summary_path [expr {int([dict get $opts summary_n])}]
        }

        return [dict create csv $csv_path summary_csv $summary_path row_count [llength $rows]]
    }

    proc combine_rmsf_csvs {chain_dirs combined_dir args} {
        set defaults [dict create output_name rmsf.csv overwrite 0]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set rows {}
        foreach chain_dir $chain_dirs {
            set chain [chain_id_from_output_dir $chain_dir]
            set rmsf_path [file join $chain_dir rmsf.csv]
            if {![file exists $rmsf_path]} {
                continue
            }
            set csv_data [read_simple_csv $rmsf_path]
            set header [dict get $csv_data header]
            set resid_index [csv_column_index $header ResidueID]
            set rmsf_index [csv_column_index $header RMSF]
            set chain_index [lsearch -exact $header ChainID]
            foreach row [dict get $csv_data rows] {
                set row_chain $chain
                if {$chain_index >= 0} {
                    set row_chain [string trim [lindex $row $chain_index]]
                }
                lappend rows [list \
                    [string trim [lindex $row $resid_index]] \
                    $row_chain \
                    [string trim [lindex $row $rmsf_index]]]
            }
        }
        if {[llength $rows] == 0} {
            return ""
        }

        set out_path [file join $combined_dir [dict get $opts output_name]]
        if {![dict get $opts overwrite] && [file exists $out_path]} {
            error "Combined RMSF CSV already exists: $out_path"
        }
        write_simple_csv $out_path {ResidueID ChainID RMSF} $rows
        return $out_path
    }

    proc combine_rmsd_csvs {chain_dirs combined_dir args} {
        set defaults [dict create output_name rmsd.csv by_chain_name rmsd_by_chain.csv overwrite 0]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set frame_order {}
        set by_frame [dict create]
        set chain_rows {}
        foreach chain_dir $chain_dirs {
            set chain [chain_id_from_output_dir $chain_dir]
            set rmsd_path [file join $chain_dir rmsd.csv]
            if {![file exists $rmsd_path]} {
                continue
            }
            set csv_data [read_simple_csv $rmsd_path]
            set header [dict get $csv_data header]
            set frame_index [csv_column_index $header Frame]
            set time_index [csv_column_index $header Time]
            set rmsd_index [csv_column_index $header RMSD]
            foreach row [dict get $csv_data rows] {
                set frame [string trim [lindex $row $frame_index]]
                set time [string trim [lindex $row $time_index]]
                set rmsd [string trim [lindex $row $rmsd_index]]
                if {![string is double -strict $rmsd]} {
                    continue
                }
                set key "$frame|$time"
                if {![dict exists $by_frame $key]} {
                    dict set by_frame $key [list $frame $time {}]
                    lappend frame_order $key
                }
                set entry [dict get $by_frame $key]
                set values [lindex $entry 2]
                lappend values [expr {double($rmsd)}]
                dict set by_frame $key [list $frame $time $values]
                lappend chain_rows [list $chain $frame $time $rmsd]
            }
        }
        if {[llength $frame_order] == 0} {
            return [dict create rmsd_csv "" rmsd_by_chain_csv ""]
        }

        set mean_rows {}
        foreach key $frame_order {
            set entry [dict get $by_frame $key]
            set values [lindex $entry 2]
            set total 0.0
            foreach value $values {
                set total [expr {$total + double($value)}]
            }
            set mean [expr {$total / double([llength $values])}]
            lappend mean_rows [list [lindex $entry 0] [lindex $entry 1] [numeric_csv_value $mean]]
        }

        set out_path [file join $combined_dir [dict get $opts output_name]]
        if {![dict get $opts overwrite] && [file exists $out_path]} {
            error "Combined RMSD CSV already exists: $out_path"
        }
        write_simple_csv $out_path {Frame Time RMSD} $mean_rows

        set by_chain_path [file join $combined_dir [dict get $opts by_chain_name]]
        if {![dict get $opts overwrite] && [file exists $by_chain_path]} {
            error "Combined chain RMSD CSV already exists: $by_chain_path"
        }
        write_simple_csv $by_chain_path {ChainID Frame Time RMSD} $chain_rows

        return [dict create rmsd_csv $out_path rmsd_by_chain_csv $by_chain_path]
    }

    proc write_combined_analysis_sidecars {chain_dirs csv_paths combined_dir args} {
        set defaults [dict create csv_name "" summary_n 3 overwrite 0]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set matrix_result [combine_matrix_csvs \
            $csv_paths \
            $combined_dir \
            -csv_name [dict get $opts csv_name] \
            -summary_n [dict get $opts summary_n] \
            -overwrite [dict get $opts overwrite]]
        set rmsd_result [combine_rmsd_csvs \
            $chain_dirs \
            $combined_dir \
            -overwrite [dict get $opts overwrite]]
        set rmsf_path [combine_rmsf_csvs \
            $chain_dirs \
            $combined_dir \
            -overwrite [dict get $opts overwrite]]

        return [dict create \
            csv [dict get $matrix_result csv] \
            summary_csv [dict get $matrix_result summary_csv] \
            row_count [dict get $matrix_result row_count] \
            rmsd_csv [dict get $rmsd_result rmsd_csv] \
            rmsd_by_chain_csv [dict get $rmsd_result rmsd_by_chain_csv] \
            rmsf_csv $rmsf_path]
    }

    proc sidecars_from_chain_result {result} {
        set summary_csv ""
        if {[dict exists $result summary_csv]} {
            set summary_csv [dict get $result summary_csv]
        }
        set rmsd_csv ""
        if {[dict exists $result rmsd_csv]} {
            set rmsd_csv [dict get $result rmsd_csv]
        }
        set rmsf_csv ""
        if {[dict exists $result rmsf_csv]} {
            set rmsf_csv [dict get $result rmsf_csv]
        }
        set row_count 0
        if {[dict exists $result residue_count]} {
            set row_count [dict get $result residue_count]
        }

        return [dict create \
            csv [dict get $result csv] \
            summary_csv $summary_csv \
            row_count $row_count \
            rmsd_csv $rmsd_csv \
            rmsd_by_chain_csv "" \
            rmsf_csv $rmsf_csv]
    }

    proc read_mask_metadata_file {filename} {
        set metadata {}
        if {![file exists $filename]} {
            return $metadata
        }
        set fp [open $filename r]
        try {
            set first 1
            while {[gets $fp line] >= 0} {
                if {[string trim $line] eq ""} {
                    continue
                }
                if {$first} {
                    set first 0
                    continue
                }
                set fields [split $line ","]
                set masked_text [string tolower [string trim [lindex $fields 2]]]
                set masked [expr {$masked_text in {1 true yes masked}}]
                lappend metadata [dict create \
                    resid [lindex $fields 0] \
                    chain [lindex $fields 1] \
                    masked $masked]
            }
        } finally {
            catch {close $fp}
        }
        return $metadata
    }

    proc write_combined_mask_metadata {chain_dirs combined_dir} {
        set combined {}
        foreach chain_dir $chain_dirs {
            set mask_path [file join $chain_dir masked_residues.csv]
            foreach item [read_mask_metadata_file $mask_path] {
                lappend combined $item
            }
        }
        if {[llength $combined] == 0} {
            return ""
        }
        set out_path [file join $combined_dir masked_residues.csv]
        write_mask_metadata $out_path $combined
        return $out_path
    }

    proc read_simple_csv {filename} {
        set fp [open $filename r]
        try {
            set rows {}
            while {[gets $fp line] >= 0} {
                if {[string trim $line] eq ""} {
                    continue
                }
                lappend rows [split $line ","]
            }
        } finally {
            catch {close $fp}
        }
        if {[llength $rows] == 0} {
            error "CSV file is empty: $filename"
        }
        return [dict create header [lindex $rows 0] rows [lrange $rows 1 end]]
    }

    proc write_simple_csv {filename header rows} {
        set fp [open $filename w]
        try {
            puts $fp [join [lmap value $header {csv_quote $value}] ","]
            foreach row $rows {
                puts $fp [join [lmap value $row {csv_quote $value}] ","]
            }
        } finally {
            catch {close $fp}
        }
    }

    proc matrix_slice_header {name} {
        return [regexp {^slice_[0-9]+(_log)?\.dcd$} [string trim $name]]
    }

    proc residue_record_label {record} {
        set resid [dict get $record resid]
        set chain ""
        if {[dict exists $record chain]} {
            set chain [string trim [dict get $record chain]]
        }
        if {$chain eq ""} {
            return $resid
        }
        return "$chain:$resid"
    }

    proc csv_to_records_and_columns {csv_data} {
        set header [dict get $csv_data header]
        set rows [dict get $csv_data rows]
        if {[llength $header] < 2 || [string trim [lindex $header 0]] ne "ResidueID"} {
            error "CSV does not look like an RMSX matrix: expected ResidueID followed by slice_*.dcd columns"
        }

        set chain_index -1
        set slice_start 1
        if {[llength $header] >= 3 && [string trim [lindex $header 1]] eq "ChainID"} {
            set chain_index 1
            set slice_start 2
        }

        set slice_names [lrange $header $slice_start end]
        if {[llength $slice_names] == 0} {
            error "CSV does not look like an RMSX matrix: no slice_*.dcd columns"
        }
        foreach slice_name $slice_names {
            if {![matrix_slice_header $slice_name]} {
                error "CSV does not look like an RMSX matrix: unexpected value column '$slice_name'"
            }
        }

        set residue_records {}
        set slice_columns {}
        foreach slice_name $slice_names {
            lappend slice_columns [list $slice_name {}]
        }

        set row_index 0
        foreach row $rows {
            set resid [string trim [lindex $row 0]]
            if {$resid eq ""} {
                continue
            }
            set chain ""
            if {$chain_index >= 0} {
                set chain [string trim [lindex $row $chain_index]]
            }
            lappend residue_records [dict create \
                resid $resid \
                chain $chain \
                index $row_index]

            for {set col $slice_start} {$col < [llength $header]} {incr col} {
                set value [string trim [lindex $row $col]]
                if {![string is double -strict $value]} {
                    error "CSV does not look like an RMSX matrix: non-numeric value '$value' in column '[lindex $header $col]'"
                }
                set column_index [expr {$col - $slice_start}]
                set item [lindex $slice_columns $column_index]
                set values [lindex $item 1]
                lappend values $value
                lset slice_columns $column_index [list [lindex $item 0] $values]
            }
            incr row_index
        }
        return [dict create residue_records $residue_records slice_columns $slice_columns]
    }

    proc compute_global_csv_value_range {csv_paths} {
        set values {}
        foreach csv_path $csv_paths {
            set csv_data [read_simple_csv $csv_path]
            set rows [dict get $csv_data rows]
            set mask_metadata [read_mask_metadata_file [file join [file dirname $csv_path] masked_residues.csv]]
            for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
                if {[llength $mask_metadata] > $row_index && [dict get [lindex $mask_metadata $row_index] masked]} {
                    continue
                }
                set row [lindex $rows $row_index]
                foreach value [lrange $row 2 end] {
                    lappend values [expr {double($value)}]
                }
            }
        }
        if {[llength $values] == 0} {
            error "No unmasked RMSX values were found across the native all-chain outputs"
        }
        set sorted [lsort -real $values]
        return [list [lindex $sorted 0] [lindex $sorted end]]
    }

    proc clip_csv_masked_rows {csv_path clip_bounds decimals} {
        set csv_data [read_simple_csv $csv_path]
        set header [dict get $csv_data header]
        set rows [dict get $csv_data rows]
        set mask_metadata [read_mask_metadata_file [file join [file dirname $csv_path] masked_residues.csv]]
        set clip_min [expr {double([lindex $clip_bounds 0])}]
        set clip_max [expr {double([lindex $clip_bounds 1])}]

        set out_rows {}
        for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            set row [lindex $rows $row_index]
            if {[llength $mask_metadata] > $row_index && [dict get [lindex $mask_metadata $row_index] masked]} {
                set out_row [lrange $row 0 1]
                foreach value [lrange $row 2 end] {
                    set clipped [expr {double($value)}]
                    if {$clipped < $clip_min} {
                        set clipped $clip_min
                    } elseif {$clipped > $clip_max} {
                        set clipped $clip_max
                    }
                    lappend out_row [format "%.${decimals}f" $clipped]
                }
                lappend out_rows $out_row
            } else {
                lappend out_rows $row
            }
        }
        write_simple_csv $csv_path $header $out_rows
        return [dict create header $header rows $out_rows mask_metadata $mask_metadata]
    }

    proc write_summary_from_csv {csv_path summary_path summary_n} {
        set csv_data [read_simple_csv $csv_path]
        set parsed [csv_to_records_and_columns $csv_data]
        set mask_metadata [read_mask_metadata_file [file join [file dirname $csv_path] masked_residues.csv]]
        set summary [summary_rows \
            [dict get $parsed residue_records] \
            [dict get $parsed slice_columns] \
            $mask_metadata \
            $summary_n]
        write_summary_csv $summary_path $summary
        return $summary
    }

    proc update_slice_pdb_bfactors_from_csv {output_dir csv_path} {
        set csv_data [read_simple_csv $csv_path]
        set parsed [csv_to_records_and_columns $csv_data]
        set residue_records [dict get $parsed residue_records]
        set slice_columns [dict get $parsed slice_columns]
        set updated {}

        foreach item $slice_columns {
            set name [lindex $item 0]
            if {![regexp {^slice_([0-9]+)} $name _ slice]} {
                continue
            }
            set pdb_path [file join $output_dir "slice_${slice}_first_frame.pdb"]
            if {![file exists $pdb_path]} {
                continue
            }
            set molid [mol new $pdb_path type pdb waitfor all]
            try {
                set sel [atomselect $molid "all"]
                try {
                    set beta_values [beta_values_for_selection_by_record_key $sel $residue_records [lindex $item 1]]
                    $sel set beta $beta_values
                    set tmp_path "${pdb_path}.tmp"
                    $sel writepdb $tmp_path
                    file rename -force $tmp_path $pdb_path
                    lappend updated [file normalize $pdb_path]
                } finally {
                    catch {$sel delete}
                }
            } finally {
                catch {mol delete $molid}
            }
        }
        return $updated
    }

    proc repair_folder_bfactors {folder args} {
        set defaults [dict create csv ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set output_dir [file normalize $folder]
        if {![file isdirectory $output_dir]} {
            error "RMSX folder does not exist: $output_dir"
        }

        set csv_path [string trim [dict get $opts csv]]
        if {$csv_path eq ""} {
            set candidates [::RMSXFlipbookTimeline::Values::candidate_csv_files $output_dir]
            if {[llength $candidates] == 0} {
                error "No RMSX CSV file found in $output_dir"
            }
            set csv_path [lindex $candidates 0]
        } else {
            set csv_path [file normalize $csv_path]
            if {![file exists $csv_path]} {
                error "RMSX CSV file does not exist: $csv_path"
            }
        }

        set updated [update_slice_pdb_bfactors_from_csv $output_dir $csv_path]
        if {[llength $updated] == 0} {
            error "No slice PDB files were updated from $csv_path"
        }

        return [dict create \
            folder $output_dir \
            csv $csv_path \
            updated_files $updated \
            updated_count [llength $updated]]
    }

    proc xml_escape {text} {
        set out [format "%s" $text]
        set out [string map {& &amp; < &lt; > &gt; \" &quot;} $out]
        return $out
    }

    proc palette_hex_colors {palette} {
        switch -nocase -- [string trim $palette] {
            magma {
                return {#000004 #120D32 #331068 #5A167E #7D2482 #A3307E #C83E73 #E95562 #F97C5D #FEA873 #FED395 #FCFDBF}
            }
            inferno {
                return {#000004 #140B35 #3A0963 #60136E #85216B #A92E5E #CB4149 #E65D2F #F78311 #FCAD12 #F5DB4B #FCFFA4}
            }
            plasma {
                return {#0D0887 #3E049C #6300A7 #8707A6 #A62098 #C03A83 #D5546E #E76F5A #F58C46 #FDAD32 #FCD225 #F0F921}
            }
            cividis {
                return {#00204D #00306F #2A406C #48526B #5E626E #727374 #878479 #9E9677 #B6A971 #D0BE67 #EAD357 #FFEA46}
            }
            rocket {
                return {#03051A #221331 #451C47 #6A1F56 #921C5B #B91657 #D92847 #ED513E #F47C56 #F6A47B #F7C9AA #FAEBDD}
            }
            mako {
                return {#0B0405 #231526 #35264C #403A75 #3D526D #366DA0 #3487A6 #35A1AB #43BBAD #6CD3AD #ADE3C0 #DEF5E5}
            }
            turbo {
                return {#30123B #4454C4 #4490FE #1FC8DE #29EFA2 #7DFF56 #C1F334 #F1CA3A #FE922A #EA4F0D #BE2102 #7A0403}
            }
            bwr {
                return {#2166AC #F7F7F7 #B2182B}
            }
            rwb {
                return {#B2182B #F7F7F7 #2166AC}
            }
            rgb {
                return {#D7191C #FFFFBF #1A9641}
            }
            default {
                return {#440154 #482173 #433E85 #38598C #2D708E #25858E #1E9B8A #2BB07F #51C56A #85D54A #C2DF23 #FDE725}
            }
        }
    }

    proc hex_to_rgb {hex} {
        set clean [string trimleft [string trim $hex] "#"]
        if {[string length $clean] != 6} {
            return {0 0 0}
        }
        if {[scan $clean "%2x%2x%2x" r g b] != 3} {
            return {0 0 0}
        }
        return [list $r $g $b]
    }

    proc heatmap_color {value min_val max_val {palette viridis}} {
        set colors [palette_hex_colors $palette]
        set color_count [llength $colors]
        if {$color_count == 0} {
            set colors [palette_hex_colors viridis]
            set color_count [llength $colors]
        }
        if {$max_val <= $min_val} {
            set t 0.5
        } else {
            set t [expr {(double($value) - double($min_val)) / (double($max_val) - double($min_val))}]
            if {$t < 0.0} {set t 0.0}
            if {$t > 1.0} {set t 1.0}
        }

        if {$color_count == 1} {
            return [lindex $colors 0]
        }

        set scaled [expr {$t * double($color_count - 1)}]
        set lower [expr {int(floor($scaled))}]
        if {$lower >= ($color_count - 1)} {
            return [lindex $colors end]
        }
        set upper [expr {$lower + 1}]
        set local [expr {$scaled - double($lower)}]
        set rgb0 [hex_to_rgb [lindex $colors $lower]]
        set rgb1 [hex_to_rgb [lindex $colors $upper]]
        set r [expr {round([lindex $rgb0 0] + (([lindex $rgb1 0] - [lindex $rgb0 0]) * $local))}]
        set g [expr {round([lindex $rgb0 1] + (([lindex $rgb1 1] - [lindex $rgb0 1]) * $local))}]
        set b [expr {round([lindex $rgb0 2] + (([lindex $rgb1 2] - [lindex $rgb0 2]) * $local))}]
        return [format "#%02x%02x%02x" $r $g $b]
    }

    proc csv_column_index {header name} {
        set index [lsearch -exact $header $name]
        if {$index < 0} {
            error "CSV is missing required column '$name'"
        }
        return $index
    }

    proc matrix_value_range {slice_columns} {
        set values {}
        foreach item $slice_columns {
            foreach value [lindex $item 1] {
                lappend values [expr {double($value)}]
            }
        }
        if {[llength $values] == 0} {
            error "No matrix values were found"
        }
        set sorted [lsort -real $values]
        return [list [lindex $sorted 0] [lindex $sorted end]]
    }

    proc infer_metric_label {csv_path} {
        set lowered [string tolower [file tail $csv_path]]
        set parent [string tolower [file tail [file dirname $csv_path]]]
        if {[string match "lddt*" $lowered] || [string match "*lddt*" $parent]} {
            return "1 - lDDT"
        }
        if {[string match "*shift*" $parent]} {
            return "Shift"
        }
        if {[string match "*_log.dcd" $lowered]} {
            return "Log RMSX"
        }
        return "RMSX"
    }

    proc option_truthy {value} {
        set lowered [string tolower [string trim $value]]
        return [expr {$lowered in {1 true yes y on}}]
    }

    proc resolve_fill_label {opts metric_label {default_label ""}} {
        set custom ""
        if {[dict exists $opts custom_fill_label]} {
            set custom [string trim [dict get $opts custom_fill_label]]
        }
        if {$custom ne ""} {
            return $custom
        }

        set fill ""
        if {[dict exists $opts fill_label]} {
            set fill [string trim [dict get $opts fill_label]]
        }
        if {$fill ne ""} {
            return $fill
        }

        if {$default_label ne ""} {
            return $default_label
        }
        return $metric_label
    }

    proc read_numeric_xy_csv {csv_path x_column y_column} {
        if {$csv_path eq "" || ![file exists $csv_path]} {
            return {}
        }
        set csv_data [read_simple_csv $csv_path]
        set header [dict get $csv_data header]
        set x_index [csv_column_index $header $x_column]
        set y_index [csv_column_index $header $y_column]
        set points {}
        foreach row [dict get $csv_data rows] {
            set x [string trim [lindex $row $x_index]]
            set y [string trim [lindex $row $y_index]]
            if {![string is double -strict $x] || ![string is double -strict $y]} {
                continue
            }
            lappend points [list [expr {double($x)}] [expr {double($y)}]]
        }
        return $points
    }

    proc read_rmsf_points_for_records {csv_path residue_records} {
        if {$csv_path eq "" || ![file exists $csv_path]} {
            return {}
        }
        set csv_data [read_simple_csv $csv_path]
        set header [dict get $csv_data header]
        set resid_index [csv_column_index $header ResidueID]
        set chain_index [lsearch -exact $header ChainID]
        set rmsf_index [csv_column_index $header RMSF]
        set by_key [dict create]
        foreach row [dict get $csv_data rows] {
            set resid [string trim [lindex $row $resid_index]]
            set chain ""
            if {$chain_index >= 0} {
                set chain [string trim [lindex $row $chain_index]]
            }
            set rmsf [string trim [lindex $row $rmsf_index]]
            if {[string is double -strict $rmsf]} {
                dict set by_key "$chain|$resid" [expr {double($rmsf)}]
                if {$chain eq ""} {
                    dict set by_key $resid [expr {double($rmsf)}]
                }
            }
        }

        set points {}
        for {set i 0} {$i < [llength $residue_records]} {incr i} {
            set resid [dict get [lindex $residue_records $i] resid]
            set chain [string trim [dict get [lindex $residue_records $i] chain]]
            set key "$chain|$resid"
            if {[dict exists $by_key $key]} {
                lappend points [list $i [dict get $by_key $key]]
            } elseif {[dict exists $by_key $resid]} {
                lappend points [list $i [dict get $by_key $resid]]
            }
        }
        return $points
    }

    proc slice_column_means {slice_columns} {
        set points {}
        for {set i 0} {$i < [llength $slice_columns]} {incr i} {
            set values [lindex [lindex $slice_columns $i] 1]
            set total 0.0
            set count 0
            foreach value $values {
                set total [expr {$total + double($value)}]
                incr count
            }
            if {$count > 0} {
                lappend points [list [expr {$i + 1}] [expr {$total / double($count)}]]
            }
        }
        return $points
    }

    proc residue_mean_metric_points {slice_columns} {
        if {[llength $slice_columns] == 0} {
            return {}
        }
        set row_count [llength [lindex [lindex $slice_columns 0] 1]]
        set points {}
        for {set row 0} {$row < $row_count} {incr row} {
            set total 0.0
            set count 0
            foreach item $slice_columns {
                set value [lindex [lindex $item 1] $row]
                if {[string is double -strict $value]} {
                    set total [expr {$total + double($value)}]
                    incr count
                }
            }
            if {$count > 0} {
                lappend points [list $row [expr {$total / double($count)}]]
            }
        }
        return $points
    }

    proc pearson_correlation {pairs} {
        set n 0
        set sum_x 0.0
        set sum_y 0.0
        set sum_xx 0.0
        set sum_yy 0.0
        set sum_xy 0.0

        foreach pair $pairs {
            set x [lindex $pair 0]
            set y [lindex $pair 1]
            if {![string is double -strict $x] || ![string is double -strict $y]} {
                continue
            }
            set x [expr {double($x)}]
            set y [expr {double($y)}]
            incr n
            set sum_x [expr {$sum_x + $x}]
            set sum_y [expr {$sum_y + $y}]
            set sum_xx [expr {$sum_xx + ($x * $x)}]
            set sum_yy [expr {$sum_yy + ($y * $y)}]
            set sum_xy [expr {$sum_xy + ($x * $y)}]
        }

        set result [dict create n $n r "" r2 ""]
        if {$n < 2} {
            return $result
        }

        set numerator [expr {($n * $sum_xy) - ($sum_x * $sum_y)}]
        set denom_x [expr {($n * $sum_xx) - ($sum_x * $sum_x)}]
        set denom_y [expr {($n * $sum_yy) - ($sum_y * $sum_y)}]
        if {$denom_x <= 0.0 || $denom_y <= 0.0} {
            return $result
        }

        set r [expr {$numerator / sqrt($denom_x * $denom_y)}]
        if {$r > 1.0} {
            set r 1.0
        } elseif {$r < -1.0} {
            set r -1.0
        }
        dict set result r $r
        dict set result r2 [expr {$r * $r}]
        return $result
    }

    proc window_check_correlations {slice_columns rmsf_points rmsd_slice_points} {
        set residue_means [dict create]
        foreach point [residue_mean_metric_points $slice_columns] {
            dict set residue_means [lindex $point 0] [lindex $point 1]
        }

        set residue_pairs {}
        foreach point $rmsf_points {
            set row [lindex $point 0]
            if {[dict exists $residue_means $row]} {
                lappend residue_pairs [list [lindex $point 1] [dict get $residue_means $row]]
            }
        }

        set rmsd_by_slice [dict create]
        foreach point $rmsd_slice_points {
            dict set rmsd_by_slice [lindex $point 0] [lindex $point 1]
        }

        set slice_pairs {}
        foreach point [slice_column_means $slice_columns] {
            set slice [lindex $point 0]
            if {[dict exists $rmsd_by_slice $slice]} {
                lappend slice_pairs [list [lindex $point 1] [dict get $rmsd_by_slice $slice]]
            }
        }

        return [dict create \
            residue [pearson_correlation $residue_pairs] \
            global [pearson_correlation $slice_pairs]]
    }

    proc format_correlation {corr} {
        set n [dict get $corr n]
        set r [dict get $corr r]
        set r2 [dict get $corr r2]
        if {$r eq "" || $r2 eq ""} {
            return "r=n/a, R^2=n/a (n=$n)"
        }
        return [format "r=%.3f, R^2=%.3f (n=%d)" $r $r2 $n]
    }

    proc binned_y_means {points bin_count} {
        set count [llength $points]
        if {$count == 0 || $bin_count <= 0} {
            return {}
        }
        set totals {}
        set counts {}
        for {set i 0} {$i < $bin_count} {incr i} {
            lappend totals 0.0
            lappend counts 0
        }
        for {set i 0} {$i < $count} {incr i} {
            set bin [expr {int(floor(double($i) * double($bin_count) / double($count)))}]
            if {$bin >= $bin_count} {
                set bin [expr {$bin_count - 1}]
            }
            lset totals $bin [expr {[lindex $totals $bin] + double([lindex [lindex $points $i] 1])}]
            lset counts $bin [expr {[lindex $counts $bin] + 1}]
        }
        set out {}
        for {set i 0} {$i < $bin_count} {incr i} {
            set n [lindex $counts $i]
            if {$n > 0} {
                lappend out [list [expr {$i + 1}] [expr {[lindex $totals $i] / double($n)}]]
            }
        }
        return $out
    }

    proc numeric_extent {values} {
        if {[llength $values] == 0} {
            return {0 1}
        }
        set sorted [lsort -real $values]
        set min_val [lindex $sorted 0]
        set max_val [lindex $sorted end]
        if {$max_val <= $min_val} {
            set pad [expr {$min_val == 0.0 ? 1.0 : abs($min_val) * 0.1}]
            set min_val [expr {$min_val - $pad}]
            set max_val [expr {$max_val + $pad}]
        }
        return [list $min_val $max_val]
    }

    proc svg_polyline_points {points x y w h x_min x_max y_min y_max} {
        set out {}
        foreach point $points {
            set px [lindex $point 0]
            set py [lindex $point 1]
            if {$x_max <= $x_min} {
                set sx [expr {$x + ($w / 2.0)}]
            } else {
                set sx [expr {$x + ((double($px) - double($x_min)) / (double($x_max) - double($x_min)) * $w)}]
            }
            if {$y_max <= $y_min} {
                set sy [expr {$y + ($h / 2.0)}]
            } else {
                set sy [expr {$y + $h - ((double($py) - double($y_min)) / (double($y_max) - double($y_min)) * $h)}]
            }
            lappend out [format "%.2f,%.2f" $sx $sy]
        }
        return [join $out " "]
    }

    proc svg_line_chart {fp x y w h points label color} {
        puts $fp [format {<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="#fbfbfc" stroke="#d8dbe2"/>} $x $y $w $h]
        puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="11" font-weight="700" fill="#333">%s</text>} $x [expr {$y - 8}] [xml_escape $label]]
        if {[llength $points] == 0} {
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="10" fill="#777">No data</text>} [expr {$x + 8}] [expr {$y + ($h / 2.0)}]]
            return
        }

        set xs {}
        set ys {}
        foreach point $points {
            lappend xs [lindex $point 0]
            lappend ys [lindex $point 1]
        }
        lassign [numeric_extent $xs] x_min x_max
        lassign [numeric_extent $ys] y_min y_max
        set line [svg_polyline_points $points $x $y $w $h $x_min $x_max $y_min $y_max]
        puts $fp [format {<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#e6e8ee" stroke-width="1"/>} $x [expr {$y + ($h / 2.0)}] [expr {$x + $w}] [expr {$y + ($h / 2.0)}]]
        puts $fp [format {<polyline points="%s" fill="none" stroke="%s" stroke-width="1.4" stroke-linejoin="round" stroke-linecap="round"/>} $line $color]
        puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="8" text-anchor="end" fill="#666">%.3g</text>} [expr {$x - 6}] [expr {$y + 9}] $y_max]
        puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="8" text-anchor="end" fill="#666">%.3g</text>} [expr {$x - 6}] [expr {$y + $h}] $y_min]
    }

    proc svg_rmsf_side_chart {fp x y w h rmsf_points row_count} {
        puts $fp [format {<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#333333" stroke-width="1"/>} $x [expr {$y + $h}] [expr {$x + $w}] [expr {$y + $h}]]
        puts $fp [format {<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#333333" stroke-width="1"/>} $x $y $x [expr {$y + $h}]]
        puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="11" font-weight="700" fill="#333">RMSF</text>} $x [expr {$y - 8}]]
        if {[llength $rmsf_points] == 0 || $row_count <= 1} {
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="10" fill="#777">No data</text>} [expr {$x + 8}] [expr {$y + 18}]]
            return
        }
        set values {}
        foreach point $rmsf_points {
            lappend values [lindex $point 1]
        }
        lassign [numeric_extent $values] min_val max_val
        set coords {}
        foreach point $rmsf_points {
            set row [lindex $point 0]
            set value [lindex $point 1]
            if {$max_val <= $min_val} {
                set sx [expr {$x + ($w / 2.0)}]
            } else {
                set sx [expr {$x + ((double($value) - double($min_val)) / (double($max_val) - double($min_val)) * $w)}]
            }
            set sy [expr {$y + (double($row) / double($row_count - 1) * $h)}]
            lappend coords [format "%.2f,%.2f" $sx $sy]
        }
        puts $fp [format {<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#e6e8ee" stroke-width="1"/>} [expr {$x + ($w / 2.0)}] $y [expr {$x + ($w / 2.0)}] [expr {$y + $h}]]
        puts $fp [format {<polyline points="%s" fill="none" stroke="#111111" stroke-width="1.4" stroke-linejoin="round" stroke-linecap="round"/>} [join $coords " "]]
        puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="8" fill="#666">%.3g</text>} $x [expr {$y + $h + 14}] $min_val]
        puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="8" text-anchor="end" fill="#666">%.3g</text>} [expr {$x + $w}] [expr {$y + $h + 14}] $max_val]
    }

    proc chain_display_label {chain} {
        set cleaned [string trim $chain]
        if {$cleaned eq ""} {
            return "Chain (blank)"
        }
        return "Chain $cleaned"
    }

    proc slice_columns_for_rows {slice_columns row_indices} {
        set out {}
        foreach item $slice_columns {
            set name [lindex $item 0]
            set values [lindex $item 1]
            set selected {}
            foreach row $row_indices {
                lappend selected [lindex $values $row]
            }
            lappend out [list $name $selected]
        }
        return $out
    }

    proc mask_metadata_for_rows {mask_metadata row_indices} {
        set out {}
        foreach row $row_indices {
            if {[llength $mask_metadata] > $row} {
                lappend out [lindex $mask_metadata $row]
            }
        }
        return $out
    }

    proc rmsf_points_for_rows {rmsf_points row_indices} {
        if {[llength $rmsf_points] == 0} {
            return {}
        }
        set by_row [dict create]
        foreach point $rmsf_points {
            dict set by_row [lindex $point 0] [lindex $point 1]
        }
        set out {}
        for {set panel_row 0} {$panel_row < [llength $row_indices]} {incr panel_row} {
            set global_row [lindex $row_indices $panel_row]
            if {[dict exists $by_row $global_row]} {
                lappend out [list $panel_row [dict get $by_row $global_row]]
            }
        }
        return $out
    }

    proc build_report_chain_panels {residue_records slice_columns mask_metadata rmsf_points} {
        set rows_by_chain [dict create]
        set chain_order {}
        for {set row 0} {$row < [llength $residue_records]} {incr row} {
            set chain [string trim [dict get [lindex $residue_records $row] chain]]
            if {![dict exists $rows_by_chain $chain]} {
                dict set rows_by_chain $chain {}
                lappend chain_order $chain
            }
            dict lappend rows_by_chain $chain $row
        }

        set panels {}
        foreach chain $chain_order {
            set row_indices [dict get $rows_by_chain $chain]
            set panel_records {}
            foreach row $row_indices {
                lappend panel_records [lindex $residue_records $row]
            }
            lappend panels [dict create \
                chain $chain \
                label [chain_display_label $chain] \
                row_indices $row_indices \
                records $panel_records \
                slice_columns [slice_columns_for_rows $slice_columns $row_indices] \
                mask_metadata [mask_metadata_for_rows $mask_metadata $row_indices] \
                rmsf_points [rmsf_points_for_rows $rmsf_points $row_indices] \
                row_count [llength $row_indices]]
        }
        return $panels
    }

    proc resolve_folder_csv {folder csv_path} {
        set output_dir [file normalize $folder]
        if {![file isdirectory $output_dir]} {
            error "RMSX folder does not exist: $output_dir"
        }
        set csv_path [string trim $csv_path]
        if {$csv_path ne ""} {
            set csv_path [file normalize $csv_path]
            if {![file exists $csv_path]} {
                error "RMSX CSV file does not exist: $csv_path"
            }
            if {[catch {
                csv_to_records_and_columns [read_simple_csv $csv_path]
            } err]} {
                error "RMSX CSV is not a matrix file: $csv_path ($err)"
            }
            return $csv_path
        }
        set candidates [::RMSXFlipbookTimeline::Values::candidate_csv_files $output_dir]
        set skipped {}
        foreach candidate $candidates {
            if {[catch {
                set csv_data [read_simple_csv $candidate]
                csv_to_records_and_columns $csv_data
            } err]} {
                lappend skipped "[file tail $candidate]: $err"
                continue
            }
            return $candidate
        }
        if {[llength $skipped] > 0} {
            error "No RMSX matrix CSV file found in $output_dir. Skipped candidates: [join $skipped {; }]"
        }
        error "No RMSX matrix CSV file found in $output_dir"
    }

    proc write_svg_mask_hatch {fp x y w h} {
        if {$w <= 0.0 || $h <= 0.0} {
            return
        }
        set inset [expr {min(0.6, max(0.0, min($w, $h) / 4.0))}]
        set x0 [expr {$x + $inset}]
        set y0 [expr {$y + $h - $inset}]
        set x1 [expr {$x + $w - $inset}]
        set y1 [expr {$y + $inset}]
        puts $fp [format {<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#f8fafc" stroke-width="1.6" opacity="0.9"/>} \
            $x0 $y0 $x1 $y1]
        puts $fp [format {<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#111827" stroke-width="0.55" opacity="0.75"/>} \
            $x0 $y0 $x1 $y1]
    }

    proc write_heatmap_svg {folder args} {
        set defaults [dict create \
            csv "" \
            output_name rmsx_heatmap.svg \
            title "RMSX Heatmap" \
            palette viridis \
            cell_width 24 \
            cell_height 9 \
            min_value "" \
            max_value "" \
            fill_label "" \
            custom_fill_label "" \
            interpolate 0]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set output_dir [file normalize $folder]
        set csv_path [resolve_folder_csv $output_dir [dict get $opts csv]]
        set csv_data [read_simple_csv $csv_path]
        set parsed [csv_to_records_and_columns $csv_data]
        set residue_records [dict get $parsed residue_records]
        set slice_columns [dict get $parsed slice_columns]
        set mask_metadata [read_mask_metadata_file [file join $output_dir masked_residues.csv]]

        if {[llength $residue_records] == 0 || [llength $slice_columns] == 0} {
            error "Cannot write heatmap for empty RMSX CSV: $csv_path"
        }

        set values {}
        foreach item $slice_columns {
            foreach value [lindex $item 1] {
                lappend values [expr {double($value)}]
            }
        }
        set min_val [lindex [lsort -real $values] 0]
        set max_val [lindex [lsort -real $values] end]
        if {[string trim [dict get $opts min_value]] ne ""} {
            set min_val [expr {double([dict get $opts min_value])}]
        }
        if {[string trim [dict get $opts max_value]] ne ""} {
            set max_val [expr {double([dict get $opts max_value])}]
        }
        set palette [dict get $opts palette]
        set metric_label [infer_metric_label $csv_path]
        set fill_label [resolve_fill_label $opts $metric_label]
        set interpolate [option_truthy [dict get $opts interpolate]]
        set shape_rendering [expr {$interpolate ? "auto" : "crispEdges"}]

        set cell_w [expr {double([dict get $opts cell_width])}]
        set cell_h [expr {double([dict get $opts cell_height])}]
        set left 92
        set top 56
        set right 36
        set bottom 72
        set rows [llength $residue_records]
        set cols [llength $slice_columns]
        set width [expr {int($left + ($cols * $cell_w) + $right)}]
        set height [expr {int($top + ($rows * $cell_h) + $bottom)}]

        set output_name [dict get $opts output_name]
        set svg_path $output_name
        if {[file pathtype $svg_path] ne "absolute"} {
            set svg_path [file join $output_dir $svg_path]
        }

        set fp [open $svg_path w]
        try {
            puts $fp [format {<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">} $width $height $width $height]
            puts $fp [format {<metadata>interpolate=%s; fill_label=%s</metadata>} [expr {$interpolate ? "true" : "false"}] [xml_escape $fill_label]]
            puts $fp {<rect width="100%" height="100%" fill="white"/>}
            puts $fp [format {<text x="16" y="24" font-family="Helvetica,Arial,sans-serif" font-size="16" font-weight="700" fill="#222">%s</text>} [xml_escape [dict get $opts title]]]
            puts $fp [format {<text x="16" y="42" font-family="Helvetica,Arial,sans-serif" font-size="11" fill="#555">%s</text>} [xml_escape [file tail $csv_path]]]

            for {set col 0} {$col < $cols} {incr col} {
                set x [expr {$left + ($col * $cell_w) + ($cell_w / 2.0)}]
                set label [lindex [lindex $slice_columns $col] 0]
                puts $fp [format {<text x="%.2f" y="50" transform="rotate(-35 %.2f 50)" font-family="Helvetica,Arial,sans-serif" font-size="8" text-anchor="end" fill="#333">%s</text>} $x $x [xml_escape $label]]
            }

            for {set row 0} {$row < $rows} {incr row} {
                set record [lindex $residue_records $row]
                set y [expr {$top + ($row * $cell_h)}]
                set masked 0
                if {[llength $mask_metadata] > $row && [dict get [lindex $mask_metadata $row] masked]} {
                    set masked 1
                }
                if {$row % 5 == 0 || $row == 0 || $row == ($rows - 1)} {
                    set label [residue_record_label $record]
                    puts $fp [format {<text x="84" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="8" text-anchor="end" dominant-baseline="middle" fill="#444">%s</text>} [expr {$y + ($cell_h / 2.0)}] [xml_escape $label]]
                }
                for {set col 0} {$col < $cols} {incr col} {
                    set value [expr {double([lindex [lindex [lindex $slice_columns $col] 1] $row])}]
                    set color [heatmap_color $value $min_val $max_val $palette]
                    set x [expr {$left + ($col * $cell_w)}]
                    set opacity [expr {$masked ? 0.35 : 1.0}]
                    puts $fp [format {<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" opacity="%.2f" shape-rendering="%s"/>} $x $y $cell_w $cell_h $color $opacity $shape_rendering]
                    if {$masked} {
                        write_svg_mask_hatch $fp $x $y $cell_w $cell_h
                    }
                }
            }

            set legend_y [expr {$top + ($rows * $cell_h) + 24}]
            set legend_x $left
            set legend_w [expr {$cols * $cell_w}]
            set legend_steps 80
            for {set i 0} {$i < $legend_steps} {incr i} {
                set frac [expr {double($i) / double($legend_steps - 1)}]
                set value [expr {$min_val + (($max_val - $min_val) * $frac)}]
                set x [expr {$legend_x + (($legend_w / double($legend_steps)) * $i)}]
                set w [expr {$legend_w / double($legend_steps)}]
                puts $fp [format {<rect x="%.2f" y="%.2f" width="%.2f" height="10" fill="%s"/>} $x $legend_y $w [heatmap_color $value $min_val $max_val $palette]]
            }
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" text-anchor="start" fill="#444">%.3g</text>} $legend_x [expr {$legend_y + 24}] $min_val]
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" text-anchor="end" fill="#444">%.3g</text>} [expr {$legend_x + $legend_w}] [expr {$legend_y + 24}] $max_val]
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" text-anchor="middle" fill="#444">%s</text>} [expr {$legend_x + ($legend_w / 2.0)}] [expr {$legend_y + 24}] [xml_escape $fill_label]]

            if {[llength $mask_metadata] > 0} {
                puts $fp [format {<text x="16" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" fill="#777">Masked rows are dimmed and hatched.</text>} [expr {$height - 16}]]
            }
            puts $fp {</svg>}
        } finally {
            catch {close $fp}
        }

        return [dict create \
            svg $svg_path \
            csv $csv_path \
            residue_count $rows \
            slice_count $cols \
            min $min_val \
            max $max_val \
            palette $palette \
            metric_label $metric_label \
            fill_label $fill_label \
            interpolate $interpolate]
    }

    proc resolve_optional_output_file {output_dir value default_name} {
        set path [string trim $value]
        if {$path eq ""} {
            set path $default_name
        }
        if {[file pathtype $path] ne "absolute"} {
            set path [file join $output_dir $path]
        }
        return [file normalize $path]
    }

    proc write_report_svg {folder args} {
        set defaults [dict create \
            csv "" \
            rmsd_csv rmsd.csv \
            rmsf_csv rmsf.csv \
            output_name rmsx_report.svg \
            title "RMSX Native Report" \
            metric_label "" \
            palette viridis \
            width 1200 \
            heatmap_cell_height 7 \
            min_value "" \
            max_value "" \
            fill_label "" \
            custom_fill_label "" \
            interpolate 0 \
            triple 0 \
            window_check 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set output_dir [file normalize $folder]
        set csv_path [resolve_folder_csv $output_dir [dict get $opts csv]]
        set csv_data [read_simple_csv $csv_path]
        set parsed [csv_to_records_and_columns $csv_data]
        set residue_records [dict get $parsed residue_records]
        set slice_columns [dict get $parsed slice_columns]
        set mask_metadata [read_mask_metadata_file [file join $output_dir masked_residues.csv]]

        if {[llength $residue_records] == 0 || [llength $slice_columns] == 0} {
            error "Cannot write report for empty matrix CSV: $csv_path"
        }

        lassign [matrix_value_range $slice_columns] min_val max_val
        if {[string trim [dict get $opts min_value]] ne ""} {
            set min_val [expr {double([dict get $opts min_value])}]
        }
        if {[string trim [dict get $opts max_value]] ne ""} {
            set max_val [expr {double([dict get $opts max_value])}]
        }

        set metric_label [string trim [dict get $opts metric_label]]
        if {$metric_label eq ""} {
            set metric_label [infer_metric_label $csv_path]
        }
        set fill_label [resolve_fill_label $opts $metric_label]
        set interpolate [option_truthy [dict get $opts interpolate]]
        set triple [option_truthy [dict get $opts triple]]
        set window_check [option_truthy [dict get $opts window_check]]
        set shape_rendering [expr {$interpolate ? "auto" : "crispEdges"}]
        if {$window_check} {
            set layout "window_check"
        } elseif {$triple} {
            set layout "triple"
        } else {
            set layout "heatmap"
        }
        set palette [dict get $opts palette]

        set rmsd_path [resolve_optional_output_file $output_dir [dict get $opts rmsd_csv] rmsd.csv]
        set rmsf_path [resolve_optional_output_file $output_dir [dict get $opts rmsf_csv] rmsf.csv]
        set rmsd_points {}
        set rmsd_slice_points {}
        set rmsf_points {}
        if {[file exists $rmsd_path]} {
            set rmsd_points [read_numeric_xy_csv $rmsd_path Frame RMSD]
            set rmsd_slice_points [binned_y_means $rmsd_points [llength $slice_columns]]
        }
        if {[file exists $rmsf_path]} {
            set rmsf_points [read_rmsf_points_for_records $rmsf_path $residue_records]
        }
        set chain_panels [build_report_chain_panels $residue_records $slice_columns $mask_metadata $rmsf_points]
        set split_by_chain [expr {[llength $chain_panels] > 1}]
        set chains {}
        foreach panel $chain_panels {
            lappend chains [dict get $panel chain]
        }
        set mean_metric_points [slice_column_means $slice_columns]
        set window_checks [window_check_correlations $slice_columns $rmsf_points $rmsd_slice_points]
        set residue_check [dict get $window_checks residue]
        set global_check [dict get $window_checks global]

        set width [expr {int([dict get $opts width])}]
        if {$width < 720} {
            set width 720
        }
        set left 94
        set right [expr {$layout eq "heatmap" ? 54 : 190}]
        set plot_w [expr {$width - $left - $right}]
        if {$plot_w < 360} {
            set plot_w 360
        }
        set top 72
        set chart_gap 28
        set rmsd_h 88
        set slice_rmsd_h 64
        set mean_h 74
        if {$layout eq "window_check"} {
            set heat_y [expr {$top + $rmsd_h + $chart_gap + $slice_rmsd_h + $chart_gap + $mean_h + 44}]
        } elseif {$layout eq "triple"} {
            set heat_y [expr {$top + $rmsd_h + $chart_gap + 44}]
        } else {
            set heat_y [expr {$top + 32}]
        }
        set cell_h [expr {double([dict get $opts heatmap_cell_height])}]
        if {$cell_h <= 0.0} {
            set cell_h 7.0
        }
        set rows [llength $residue_records]
        set cols [llength $slice_columns]
        set panel_gap [expr {$split_by_chain ? 46.0 : 0.0}]
        set heat_h 0.0
        foreach panel $chain_panels {
            if {$heat_h > 0.0} {
                set heat_h [expr {$heat_h + $panel_gap}]
            }
            set heat_h [expr {$heat_h + ([dict get $panel row_count] * $cell_h)}]
        }
        set cell_w [expr {$plot_w / double($cols)}]
        set legend_y [expr {$heat_y + $heat_h + 24}]
        set height [expr {int($legend_y + 100)}]

        set output_name [dict get $opts output_name]
        set svg_path $output_name
        if {[file pathtype $svg_path] ne "absolute"} {
            set svg_path [file join $output_dir $svg_path]
        }

        set fp [open $svg_path w]
        try {
            puts $fp [format {<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">} $width $height $width $height]
            puts $fp [format {<metadata>layout=%s; interpolate=%s; fill_label=%s</metadata>} [xml_escape $layout] [expr {$interpolate ? "true" : "false"}] [xml_escape $fill_label]]
            puts $fp {<rect width="100%" height="100%" fill="white"/>}
            puts $fp [format {<text x="20" y="28" font-family="Helvetica,Arial,sans-serif" font-size="18" font-weight="700" fill="#202124">%s</text>} [xml_escape [dict get $opts title]]]
            puts $fp [format {<text x="20" y="48" font-family="Helvetica,Arial,sans-serif" font-size="11" fill="#5f6368">%s</text>} [xml_escape [file tail $csv_path]]]

            if {$layout eq "window_check"} {
                svg_line_chart $fp $left $top $plot_w $rmsd_h $rmsd_points "RMSD" "#111111"
                svg_line_chart $fp $left [expr {$top + $rmsd_h + $chart_gap}] $plot_w $slice_rmsd_h $rmsd_slice_points "Mean RMSD Per Slice" "#7c3aed"
                svg_line_chart $fp $left [expr {$top + $rmsd_h + $chart_gap + $slice_rmsd_h + $chart_gap}] $plot_w $mean_h $mean_metric_points "Mean $metric_label Per Slice" "#b45309"
            } elseif {$layout eq "triple"} {
                svg_line_chart $fp $left $top $plot_w $rmsd_h $rmsd_points "RMSD" "#111111"
            }

            set heatmap_title "$metric_label Heatmap"
            if {$split_by_chain} {
                set heatmap_title "$metric_label Heatmap by Chain"
            }
            set title_y [expr {$heat_y - ($split_by_chain ? 38 : 10)}]
            set column_label_y [expr {$heat_y - ($split_by_chain ? 20 : 16)}]
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="11" font-weight="700" fill="#333">%s</text>} $left $title_y [xml_escape $heatmap_title]]

            for {set col 0} {$col < $cols} {incr col} {
                if {$cols <= 24 || $col == 0 || $col == ($cols - 1) || $col % 5 == 0} {
                    set x [expr {$left + ($col * $cell_w) + ($cell_w / 2.0)}]
                    set label [lindex [lindex $slice_columns $col] 0]
                    puts $fp [format {<text x="%.2f" y="%.2f" transform="rotate(-35 %.2f %.2f)" font-family="Helvetica,Arial,sans-serif" font-size="8" text-anchor="end" fill="#444">%s</text>} $x $column_label_y $x $column_label_y [xml_escape $label]]
                }
            }

            set panel_y $heat_y
            foreach panel $chain_panels {
                set panel_rows [dict get $panel row_count]
                set panel_h [expr {$panel_rows * $cell_h}]
                set panel_records [dict get $panel records]
                set panel_columns [dict get $panel slice_columns]
                set panel_masks [dict get $panel mask_metadata]

                if {$split_by_chain} {
                    puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="10" font-weight="700" fill="#333">%s (%d residues)</text>} $left [expr {$panel_y - 6}] [xml_escape [dict get $panel label]] $panel_rows]
                }
                puts $fp [format {<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="#fbfbfc" stroke="#d8dbe2"/>} $left $panel_y $plot_w $panel_h]

                for {set row 0} {$row < $panel_rows} {incr row} {
                    set record [lindex $panel_records $row]
                    set y [expr {$panel_y + ($row * $cell_h)}]
                    set masked 0
                    if {[llength $panel_masks] > $row && [dict get [lindex $panel_masks $row] masked]} {
                        set masked 1
                    }
                    if {$row % 5 == 0 || $row == 0 || $row == ($panel_rows - 1)} {
                        set label [residue_record_label $record]
                        puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="8" text-anchor="end" dominant-baseline="middle" fill="#444">%s</text>} [expr {$left - 8}] [expr {$y + ($cell_h / 2.0)}] [xml_escape $label]]
                    }
                    for {set col 0} {$col < $cols} {incr col} {
                        set value [expr {double([lindex [lindex [lindex $panel_columns $col] 1] $row])}]
                        set color [heatmap_color $value $min_val $max_val $palette]
                        set x [expr {$left + ($col * $cell_w)}]
                        set opacity [expr {$masked ? 0.42 : 1.0}]
                        puts $fp [format {<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" opacity="%.2f" shape-rendering="%s"/>} $x $y $cell_w $cell_h $color $opacity $shape_rendering]
                        if {$masked} {
                            write_svg_mask_hatch $fp $x $y $cell_w $cell_h
                        }
                    }
                }

                if {$layout ne "heatmap"} {
                    svg_rmsf_side_chart $fp [expr {$left + $plot_w + 36}] $panel_y 120 $panel_h [dict get $panel rmsf_points] $panel_rows
                }
                set panel_y [expr {$panel_y + $panel_h + $panel_gap}]
            }

            set legend_x $left
            set legend_w $plot_w
            set legend_steps 100
            for {set i 0} {$i < $legend_steps} {incr i} {
                set frac [expr {double($i) / double($legend_steps - 1)}]
                set value [expr {$min_val + (($max_val - $min_val) * $frac)}]
                set x [expr {$legend_x + (($legend_w / double($legend_steps)) * $i)}]
                set w [expr {$legend_w / double($legend_steps)}]
                puts $fp [format {<rect x="%.2f" y="%.2f" width="%.2f" height="10" fill="%s"/>} $x $legend_y $w [heatmap_color $value $min_val $max_val $palette]]
            }
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" text-anchor="start" fill="#444">%.3g</text>} $legend_x [expr {$legend_y + 24}] $min_val]
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" text-anchor="end" fill="#444">%.3g</text>} [expr {$legend_x + $legend_w}] [expr {$legend_y + 24}] $max_val]
            puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" text-anchor="middle" fill="#444">%s</text>} [expr {$legend_x + ($legend_w / 2.0)}] [expr {$legend_y + 24}] [xml_escape $fill_label]]
            if {$window_check} {
                puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="10" font-weight="700" fill="#333">Window Check</text>} $left [expr {$legend_y + 48}]]
                puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" fill="#555">RMSF vs mean %s: %s</text>} $left [expr {$legend_y + 64}] [xml_escape $metric_label] [xml_escape [format_correlation $residue_check]]]
                puts $fp [format {<text x="%.2f" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" fill="#555">Mean %s vs mean RMSD: %s</text>} $left [expr {$legend_y + 80}] [xml_escape $metric_label] [xml_escape [format_correlation $global_check]]]
            }
            if {[llength $mask_metadata] > 0} {
                puts $fp [format {<text x="20" y="%.2f" font-family="Helvetica,Arial,sans-serif" font-size="9" fill="#777">Masked rows are dimmed and hatched.</text>} [expr {$height - 14}]]
            }
            puts $fp {</svg>}
        } finally {
            catch {close $fp}
        }

        return [dict create \
            svg $svg_path \
            csv $csv_path \
            rmsd_csv $rmsd_path \
            rmsf_csv $rmsf_path \
            residue_count $rows \
            slice_count $cols \
            min $min_val \
            max $max_val \
            metric_label $metric_label \
            fill_label $fill_label \
            palette $palette \
            layout $layout \
            interpolate $interpolate \
            triple $triple \
            window_check $window_check \
            rmsd_points [llength $rmsd_points] \
            rmsf_points [llength $rmsf_points] \
            chain_panels [llength $chain_panels] \
            chains $chains \
            split_by_chain $split_by_chain \
            residue_correlation_r [dict get $residue_check r] \
            residue_correlation_r2 [dict get $residue_check r2] \
            residue_correlation_n [dict get $residue_check n] \
            global_correlation_r [dict get $global_check r] \
            global_correlation_r2 [dict get $global_check r2] \
            global_correlation_n [dict get $global_check n]]
    }

    proc whole_trajectory_rmsf {molid analysis_selection vmd_start vmd_end} {
        set sel [atomselect $molid $analysis_selection frame $vmd_start]
        try {
            if {[$sel num] == 0} {
                error "Analysis selection returned no atoms for whole-trajectory RMSF: $analysis_selection"
            }
            return [measure rmsfperresidue $sel first $vmd_start last $vmd_end step 1]
        } finally {
            catch {$sel delete}
        }
    }

    proc fitted_rmsd_rows {molid analysis_selection vmd_start vmd_end traj_start time_step time_origin} {
        set ref [atomselect $molid $analysis_selection frame $vmd_start]
        if {[$ref num] == 0} {
            catch {$ref delete}
            error "Analysis selection returned no atoms for RMSD reference: $analysis_selection"
        }

        set rows {}
        try {
            for {set vmd_frame $vmd_start} {$vmd_frame <= $vmd_end} {incr vmd_frame} {
                set traj_frame [expr {$traj_start + ($vmd_frame - $vmd_start)}]
                set sel [atomselect $molid $analysis_selection frame $vmd_frame]
                try {
                    if {[$sel num] != [$ref num]} {
                        error "RMSD selection atom count changed at trajectory frame $traj_frame"
                    }

                    set original_coords [$sel get {x y z}]
                    set transform [measure fit $sel $ref]
                    $sel move $transform
                    set rmsd [measure rmsd $sel $ref]
                    $sel set {x y z} $original_coords

                    lappend rows [dict create \
                        frame $traj_frame \
                        time [expr {$time_origin + ($traj_frame * $time_step)}] \
                        rmsd $rmsd]
                } finally {
                    catch {$sel delete}
                }
            }
        } finally {
            catch {$ref delete}
        }

        return $rows
    }

    proc resolve_slice_plan {available_frames opts} {
        set start [dict get $opts start_frame]
        set end [dict get $opts end_frame]

        if {$start < 0} {
            set start 0
        }
        if {$end < 0 || $end >= $available_frames} {
            set end [expr {$available_frames - 1}]
        }
        if {$end < $start} {
            error "Invalid frame range: start_frame ($start) is after end_frame ($end)"
        }

        set used [expr {$end - $start + 1}]
        set num_slices [dict get $opts num_slices]
        set slice_size [dict get $opts slice_size]

        if {$num_slices ne ""} {
            set num_slices [expr {int($num_slices)}]
            if {$num_slices <= 0} {
                error "num_slices must be greater than 0"
            }
            set slice_size [expr {int($used / $num_slices)}]
            if {$slice_size <= 0} {
                error "num_slices is larger than the available frame count"
            }
        } elseif {$slice_size ne ""} {
            set slice_size [expr {int($slice_size)}]
            if {$slice_size <= 0} {
                error "slice_size must be greater than 0"
            }
            set num_slices [expr {int($used / $slice_size)}]
            if {$num_slices <= 0} {
                error "slice_size is larger than the available frame count"
            }
        } else {
            error "Specify either num_slices or slice_size"
        }

        set adjusted [expr {$num_slices * $slice_size}]
        return [dict create \
            start_frame $start \
            end_frame [expr {$start + $adjusted - 1}] \
            requested_end_frame $end \
            used_frames $used \
            adjusted_frames $adjusted \
            num_slices $num_slices \
            slice_size $slice_size \
            truncated_frames [expr {$used - $adjusted}]]
    }

    proc validate_rmsx_slice_plan {plan} {
        set slice_size [dict get $plan slice_size]
        if {$slice_size >= 2} {
            return 1
        }

        set used [dict get $plan used_frames]
        set num_slices [dict get $plan num_slices]
        set max_slices [expr {int($used / 2)}]
        if {$max_slices >= 1} {
            set suggestion [format {Use -num_slices %d or fewer, or set -slice_size 2 or larger.} $max_slices]
        } else {
            set suggestion {Use a frame range with at least 2 frames, or use a non-RMSX metric that supports one-frame slices.}
        }

        error [format {RMSX requires at least 2 frames per slice because it computes per-residue RMSF within each slice. Requested %d slices across %d frames gives slice_size=%d, which would write all-zero B-factors. %s} \
            $num_slices $used $slice_size $suggestion]
    }

    proc run {topology trajectory output_dir args} {
        set defaults [dict create \
            chain "" \
            analysis_type protein \
            full_backbone 1 \
            selection "" \
            analysis_selection "" \
            start_frame 0 \
            end_frame -1 \
            frame_offset auto \
            topology_type auto \
            trajectory_type auto \
            num_slices "" \
            slice_size "" \
            csv_name "" \
            name_style native \
            csv_prefix rmsx \
            manual_length_ns "" \
            manual_length "" \
            manual_unit ns \
            rmsd_name rmsd.csv \
            rmsf_name rmsf.csv \
            summary_name rmsx_summary.csv \
            write_slices 1 \
            write_rmsd 1 \
            write_rmsf 1 \
            write_summary 1 \
            summary_n 3 \
            overwrite 0 \
            clean_previous_slices 1 \
            cleanup 1 \
            decimals 6 \
            log_transform 0 \
            mask_selection "" \
            write_mask_metadata 1 \
            allow_fully_masked 0 \
            defer_mask_clipping 0 \
            rmsd_time_step 0.04888821 \
            rmsd_time_origin 0.0 \
            progress_callback "" \
            verbose 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set opts [resolve_analysis_options $opts]

        set output_dir [file normalize $output_dir]
        file mkdir $output_dir
        emit_progress $opts [dict create \
            metric rmsx \
            stage preparing \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            message "Preparing native RMSX output"]

        set rmsd_path [file join $output_dir [dict get $opts rmsd_name]]
        set rmsf_path [file join $output_dir [dict get $opts rmsf_name]]
        set summary_path [file join $output_dir [dict get $opts summary_name]]
        if {[dict get $opts write_rmsd] && ![dict get $opts overwrite] && [file exists $rmsd_path]} {
            error "Native RMSD output already exists: $rmsd_path"
        }
        if {[dict get $opts write_rmsf] && ![dict get $opts overwrite] && [file exists $rmsf_path]} {
            error "Native RMSF output already exists: $rmsf_path"
        }
        if {[dict get $opts write_summary] && ![dict get $opts overwrite] && [file exists $summary_path]} {
            error "Native RMSX summary output already exists: $summary_path"
        }

        set deleted_previous_slices {}
        if {[dict get $opts overwrite] && [dict get $opts write_slices] && [dict get $opts clean_previous_slices]} {
            set deleted_previous_slices [clean_previous_slice_outputs $output_dir]
            if {[dict get $opts verbose] && [llength $deleted_previous_slices] > 0} {
                puts "  Removed [llength $deleted_previous_slices] previous slice PDB files from $output_dir"
            }
        }
        set mask_metadata_path [file join $output_dir masked_residues.csv]
        if {[dict get $opts overwrite] && [string trim [dict get $opts mask_selection]] eq "" && [file exists $mask_metadata_path]} {
            file delete $mask_metadata_path
        }

        set load_info [load_trajectory \
            [file normalize $topology] \
            [file normalize $trajectory] \
            -topology_type [dict get $opts topology_type] \
            -trajectory_type [dict get $opts trajectory_type]]
        set molid [dict get $load_info molid]
        hide_cleanup_molecule $molid $opts
        set frame_offset [resolve_frame_offset [dict get $opts frame_offset] $load_info]
        set total_frames [molinfo $molid get numframes]
        set available_frames [expr {$total_frames - $frame_offset}]
        if {$available_frames <= 0} {
            error "Trajectory has no analyzable frames after frame_offset=$frame_offset"
        }

        set plan [resolve_slice_plan $available_frames $opts]
        if {[catch {validate_rmsx_slice_plan $plan} validation_err]} {
            if {[dict get $opts cleanup]} {
                catch {mol delete $molid}
            }
            error $validation_err
        }
        set csv_path [file join $output_dir [resolve_csv_name $trajectory $opts $plan]]
        if {![dict get $opts overwrite] && [file exists $csv_path]} {
            error "Native RMSX output already exists: $csv_path"
        }

        set full_selection [append_chain_selection [dict get $opts selection] [dict get $opts chain]]
        set analysis_selection [append_chain_selection [dict get $opts analysis_selection] [dict get $opts chain]]
        emit_progress $opts [dict create \
            metric rmsx \
            stage started \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            molid $molid \
            start_frame [dict get $plan start_frame] \
            end_frame [dict get $plan end_frame] \
            frame_offset $frame_offset \
            topology_type [dict get $load_info topology_type] \
            trajectory_type [dict get $load_info trajectory_type] \
            slice_count [dict get $plan num_slices] \
            slice_size [dict get $plan slice_size] \
            selection $full_selection \
            analysis_selection $analysis_selection \
            message "Started native RMSX analysis"]

        if {[dict get $opts verbose]} {
            set topology_type_label [dict get $load_info topology_type]
            if {$topology_type_label eq ""} {
                set topology_type_label auto
            }
            set trajectory_type_label [dict get $load_info trajectory_type]
            if {$trajectory_type_label eq ""} {
                set trajectory_type_label auto
            }
            puts "RMSX Flipbook Timeline native analysis"
            puts "  Molecule: $molid"
            puts "  Frames: [dict get $plan start_frame] to [dict get $plan end_frame] (trajectory coordinates)"
            puts "  Frame offset in VMD: $frame_offset"
            puts "  Topology type: $topology_type_label"
            puts "  Trajectory type: $trajectory_type_label"
            puts "  Slices: [dict get $plan num_slices]"
            puts "  Slice size: [dict get $plan slice_size]"
            puts "  Selection: $full_selection"
            puts "  Analysis selection: $analysis_selection"
        }

        set residue_records {}
        set slice_columns {}
        set slice_frames {}
        set mask_metadata {}
        set masked_count 0
        set mask_clip_min ""
        set mask_clip_max ""
        set summary [dict create top {} bottom {}]
        set rmsd_rows {}
        set rmsf_values {}

        try {
            set num_slices [dict get $plan num_slices]
            set slice_size [dict get $plan slice_size]
            set start_frame [dict get $plan start_frame]

            for {set slice 1} {$slice <= $num_slices} {incr slice} {
                set traj_start [expr {$start_frame + (($slice - 1) * $slice_size)}]
                set traj_end [expr {$traj_start + $slice_size - 1}]
                set vmd_start [expr {$traj_start + $frame_offset}]
                set vmd_end [expr {$traj_end + $frame_offset}]

                set analysis_sel [atomselect $molid $analysis_selection frame $vmd_start]
                set full_sel [atomselect $molid $full_selection frame $vmd_start]

                try {
                    if {[$analysis_sel num] == 0} {
                        error "Analysis selection returned no atoms for slice $slice: $analysis_selection"
                    }
                    if {[$full_sel num] == 0} {
                        error "Structure selection returned no atoms for slice $slice: $full_selection"
                    }

                    set values [measure rmsfperresidue $analysis_sel first $vmd_start last $vmd_end step 1]
                    set values [format_values $values [dict get $opts decimals]]

                    if {$slice == 1} {
                        set residue_records [residue_records_from_selection $analysis_sel]
                        if {[llength $residue_records] != [llength $values]} {
                            error "Residue/value count mismatch: [llength $residue_records] residues, [llength $values] RMSF values"
                        }
                    } elseif {[llength $values] != [llength $residue_records]} {
                        error "Slice $slice value count changed: expected [llength $residue_records], got [llength $values]"
                    }

                    lappend slice_columns [list "slice_${slice}.dcd" $values]
                    lappend slice_frames [dict create slice $slice vmd_start $vmd_start]

                    if {[dict get $opts verbose]} {
                        puts "  Slice $slice: trajectory frames $traj_start-$traj_end"
                    }
                    emit_progress $opts [dict create \
                        metric rmsx \
                        stage slice \
                        output_dir $output_dir \
                        chain [dict get $opts chain] \
                        slice $slice \
                        slice_count $num_slices \
                        frame_start $traj_start \
                        frame_end $traj_end \
                        message "Computed RMSX slice $slice of $num_slices"]
                } finally {
                    catch {$analysis_sel delete}
                    catch {$full_sel delete}
                }
            }

            if {[dict get $opts log_transform]} {
                set slice_columns [value_columns_log_transform $slice_columns [dict get $opts decimals]]
            }

            set mask_metadata [build_mask_metadata \
                $molid \
                $full_selection \
                $residue_records \
                [dict get $opts mask_selection] \
                [expr {[dict get $plan start_frame] + $frame_offset}]]

            if {[dict get $opts defer_mask_clipping]} {
                set masked_count [count_masked_metadata $mask_metadata]
            } else {
                set mask_result [clip_masked_slice_columns \
                    $slice_columns \
                    $mask_metadata \
                    [dict get $opts allow_fully_masked]]
                set slice_columns [dict get $mask_result columns]
                set masked_count [dict get $mask_result masked_count]
                set mask_clip_min [dict get $mask_result clip_min]
                set mask_clip_max [dict get $mask_result clip_max]
            }
            set slice_columns [format_slice_columns $slice_columns [dict get $opts decimals]]

            emit_progress $opts [dict create \
                metric rmsx \
                stage writing_outputs \
                output_dir $output_dir \
                chain [dict get $opts chain] \
                csv $csv_path \
                message "Writing native RMSX CSV and summaries"]
            write_csv $csv_path $residue_records $slice_columns
            if {[dict get $opts write_mask_metadata] && [string trim [dict get $opts mask_selection]] ne ""} {
                write_mask_metadata $mask_metadata_path $mask_metadata
            }
            if {[dict get $opts write_summary]} {
                set summary [summary_rows \
                    $residue_records \
                    $slice_columns \
                    $mask_metadata \
                    [expr {int([dict get $opts summary_n])}]]
                write_summary_csv $summary_path $summary
            }

            if {[dict get $opts write_slices]} {
                emit_progress $opts [dict create \
                    metric rmsx \
                    stage writing_slices \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    slice_count [llength $slice_frames] \
                    message "Writing native RMSX slice PDBs"]
                foreach frame_record $slice_frames item $slice_columns {
                    set slice [dict get $frame_record slice]
                    set vmd_start [dict get $frame_record vmd_start]
                    set pdb_path [file join $output_dir "slice_${slice}_first_frame.pdb"]
                    if {![dict get $opts overwrite] && [file exists $pdb_path]} {
                        error "Native RMSX slice output already exists: $pdb_path"
                    }
                    set full_sel [atomselect $molid $full_selection frame $vmd_start]
                    try {
                        set beta_values [beta_values_for_selection $full_sel $residue_records [lindex $item 1]]
                        $full_sel set beta $beta_values
                        $full_sel writepdb $pdb_path
                    } finally {
                        catch {$full_sel delete}
                    }
                }
            }

            set vmd_analysis_start [expr {[dict get $plan start_frame] + $frame_offset}]
            set vmd_analysis_end [expr {[dict get $plan end_frame] + $frame_offset}]

            if {[dict get $opts write_rmsf]} {
                emit_progress $opts [dict create \
                    metric rmsx \
                    stage rmsf \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    message "Computing whole-trajectory RMSF"]
                set rmsf_values [whole_trajectory_rmsf \
                    $molid \
                    $analysis_selection \
                    $vmd_analysis_start \
                    $vmd_analysis_end]
                if {[llength $rmsf_values] != [llength $residue_records]} {
                    error "Whole-trajectory RMSF count mismatch: [llength $rmsf_values] values, [llength $residue_records] residues"
                }
                write_rmsf_csv $rmsf_path $residue_records $rmsf_values
            }

            if {[dict get $opts write_rmsd]} {
                emit_progress $opts [dict create \
                    metric rmsx \
                    stage rmsd \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    message "Computing fitted RMSD"]
                set rmsd_rows [fitted_rmsd_rows \
                    $molid \
                    $analysis_selection \
                    $vmd_analysis_start \
                    $vmd_analysis_end \
                    [dict get $plan start_frame] \
                    [dict get $opts rmsd_time_step] \
                    [dict get $opts rmsd_time_origin]]
                write_rmsd_csv $rmsd_path $rmsd_rows
            }
        } finally {
            if {[dict get $opts cleanup]} {
                catch {mol delete $molid}
            }
        }

        set result [dict create \
            output_dir $output_dir \
            csv $csv_path \
            rmsd_csv $rmsd_path \
            rmsf_csv $rmsf_path \
            summary_csv $summary_path \
            residue_count [llength $residue_records] \
            slice_count [llength $slice_columns] \
            rmsd_frame_count [llength $rmsd_rows] \
            rmsf_residue_count [llength $rmsf_values] \
            summary_top_count [llength [dict get $summary top]] \
            summary_bottom_count [llength [dict get $summary bottom]] \
            masked_residue_count $masked_count \
            mask_clip_min $mask_clip_min \
            mask_clip_max $mask_clip_max \
            log_transform [dict get $opts log_transform] \
            deleted_previous_slices [llength $deleted_previous_slices] \
            frame_offset $frame_offset \
            topology_type [dict get $load_info topology_type] \
            trajectory_type [dict get $load_info trajectory_type] \
            initial_frame_count [dict get $load_info initial_frame_count] \
            total_frame_count [dict get $load_info total_frame_count] \
            plan $plan \
            selection $full_selection \
            analysis_selection $analysis_selection]

        if {[dict get $opts verbose]} {
            puts "RMSX Flipbook Timeline native analysis complete: $csv_path"
        }
        emit_progress $opts [dict create \
            metric rmsx \
            stage complete \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            csv $csv_path \
            slice_count [llength $slice_columns] \
            residue_count [llength $residue_records] \
            message "Native RMSX analysis complete"]
        return $result
    }

    proc run_shift_map {topology trajectory output_dir args} {
        set defaults [dict create \
            chain "" \
            analysis_type protein \
            full_backbone 1 \
            selection "" \
            analysis_selection "" \
            start_frame 0 \
            end_frame -1 \
            frame_offset auto \
            topology_type auto \
            trajectory_type auto \
            num_slices "" \
            slice_size "" \
            csv_name "" \
            name_style native \
            csv_prefix rmsx \
            manual_length_ns "" \
            manual_length "" \
            manual_unit ns \
            rmsd_name rmsd.csv \
            rmsf_name rmsf.csv \
            summary_name rmsx_summary.csv \
            write_slices 1 \
            write_rmsd 1 \
            write_rmsf 1 \
            write_summary 1 \
            summary_n 3 \
            overwrite 0 \
            clean_previous_slices 1 \
            cleanup 1 \
            decimals 6 \
            log_transform 0 \
            mask_selection "" \
            write_mask_metadata 1 \
            allow_fully_masked 0 \
            defer_mask_clipping 0 \
            rmsd_time_step 0.04888821 \
            rmsd_time_origin 0.0 \
            progress_callback "" \
            verbose 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set opts [resolve_analysis_options $opts]

        set output_dir [file normalize $output_dir]
        file mkdir $output_dir
        emit_progress $opts [dict create \
            metric shift_map \
            stage preparing \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            message "Preparing native shift-map output"]

        set rmsd_path [file join $output_dir [dict get $opts rmsd_name]]
        set rmsf_path [file join $output_dir [dict get $opts rmsf_name]]
        set summary_path [file join $output_dir [dict get $opts summary_name]]
        if {[dict get $opts write_rmsd] && ![dict get $opts overwrite] && [file exists $rmsd_path]} {
            error "Native shift-map RMSD output already exists: $rmsd_path"
        }
        if {[dict get $opts write_rmsf] && ![dict get $opts overwrite] && [file exists $rmsf_path]} {
            error "Native shift-map RMSF output already exists: $rmsf_path"
        }
        if {[dict get $opts write_summary] && ![dict get $opts overwrite] && [file exists $summary_path]} {
            error "Native shift-map summary output already exists: $summary_path"
        }

        set deleted_previous_slices {}
        if {[dict get $opts overwrite] && [dict get $opts write_slices] && [dict get $opts clean_previous_slices]} {
            set deleted_previous_slices [clean_previous_slice_outputs $output_dir]
            if {[dict get $opts verbose] && [llength $deleted_previous_slices] > 0} {
                puts "  Removed [llength $deleted_previous_slices] previous slice PDB files from $output_dir"
            }
        }
        set mask_metadata_path [file join $output_dir masked_residues.csv]
        if {[dict get $opts overwrite] && [string trim [dict get $opts mask_selection]] eq "" && [file exists $mask_metadata_path]} {
            file delete $mask_metadata_path
        }

        set load_info [load_trajectory \
            [file normalize $topology] \
            [file normalize $trajectory] \
            -topology_type [dict get $opts topology_type] \
            -trajectory_type [dict get $opts trajectory_type]]
        set molid [dict get $load_info molid]
        hide_cleanup_molecule $molid $opts
        set frame_offset [resolve_frame_offset [dict get $opts frame_offset] $load_info]
        set total_frames [molinfo $molid get numframes]
        set available_frames [expr {$total_frames - $frame_offset}]
        if {$available_frames <= 0} {
            error "Trajectory has no analyzable frames after frame_offset=$frame_offset"
        }

        set plan [resolve_slice_plan $available_frames $opts]
        set csv_path [file join $output_dir [resolve_csv_name $trajectory $opts $plan]]
        if {![dict get $opts overwrite] && [file exists $csv_path]} {
            error "Native shift-map output already exists: $csv_path"
        }

        set full_selection [append_chain_selection [dict get $opts selection] [dict get $opts chain]]
        set analysis_selection [append_chain_selection [dict get $opts analysis_selection] [dict get $opts chain]]
        emit_progress $opts [dict create \
            metric shift_map \
            stage started \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            molid $molid \
            start_frame [dict get $plan start_frame] \
            end_frame [dict get $plan end_frame] \
            frame_offset $frame_offset \
            topology_type [dict get $load_info topology_type] \
            trajectory_type [dict get $load_info trajectory_type] \
            slice_count [dict get $plan num_slices] \
            slice_size [dict get $plan slice_size] \
            selection $full_selection \
            analysis_selection $analysis_selection \
            message "Started native shift-map analysis"]

        if {[dict get $opts verbose]} {
            set topology_type_label [dict get $load_info topology_type]
            if {$topology_type_label eq ""} {
                set topology_type_label auto
            }
            set trajectory_type_label [dict get $load_info trajectory_type]
            if {$trajectory_type_label eq ""} {
                set trajectory_type_label auto
            }
            puts "RMSX Flipbook Timeline native shift-map analysis"
            puts "  Molecule: $molid"
            puts "  Reference frame: [dict get $plan start_frame] (trajectory coordinates)"
            puts "  Frame offset in VMD: $frame_offset"
            puts "  Topology type: $topology_type_label"
            puts "  Trajectory type: $trajectory_type_label"
            puts "  Slices: [dict get $plan num_slices]"
            puts "  Slice size: [dict get $plan slice_size]"
            puts "  Selection: $full_selection"
            puts "  Analysis selection: $analysis_selection"
        }

        set residue_records {}
        set slice_columns {}
        set slice_frames {}
        set mask_metadata {}
        set masked_count 0
        set mask_clip_min ""
        set mask_clip_max ""
        set summary [dict create top {} bottom {}]
        set rmsd_rows {}
        set rmsf_values {}

        try {
            set num_slices [dict get $plan num_slices]
            set slice_size [dict get $plan slice_size]
            set start_frame [dict get $plan start_frame]
            set reference_vmd_frame [expr {$start_frame + $frame_offset}]

            set reference_sel [atomselect $molid $analysis_selection frame $reference_vmd_frame]
            try {
                set residue_records [residue_records_from_selection $reference_sel]
                ensure_representative_selection \
                    $reference_sel \
                    $residue_records \
                    "Native shift-map analysis"
                set reference_coords [selection_coordinate_list $reference_sel "Native shift-map reference"]
            } finally {
                catch {$reference_sel delete}
            }

            for {set slice 1} {$slice <= $num_slices} {incr slice} {
                set traj_frame [expr {$start_frame + (($slice - 1) * $slice_size)}]
                set vmd_frame [expr {$traj_frame + $frame_offset}]

                set analysis_sel [atomselect $molid $analysis_selection frame $vmd_frame]
                set full_sel [atomselect $molid $full_selection frame $vmd_frame]

                try {
                    if {[$analysis_sel num] == 0} {
                        error "Analysis selection returned no atoms for shift-map slice $slice: $analysis_selection"
                    }
                    if {[$full_sel num] == 0} {
                        error "Structure selection returned no atoms for shift-map slice $slice: $full_selection"
                    }

                    set current_records [residue_records_from_selection $analysis_sel]
                    assert_matching_records \
                        $residue_records \
                        $current_records \
                        "Native shift-map slice $slice"
                    ensure_representative_selection \
                        $analysis_sel \
                        $residue_records \
                        "Native shift-map slice $slice"
                    set current_coords [selection_coordinate_list $analysis_sel "Native shift-map slice $slice"]
                    set values [coordinate_distances \
                        $reference_coords \
                        $current_coords \
                        [dict get $opts decimals]]

                    lappend slice_columns [list "slice_${slice}.dcd" $values]
                    lappend slice_frames [dict create slice $slice vmd_start $vmd_frame]

                    if {[dict get $opts verbose]} {
                        puts "  Slice $slice: trajectory frame $traj_frame"
                    }
                    emit_progress $opts [dict create \
                        metric shift_map \
                        stage slice \
                        output_dir $output_dir \
                        chain [dict get $opts chain] \
                        slice $slice \
                        slice_count $num_slices \
                        frame_start $traj_frame \
                        frame_end $traj_frame \
                        message "Computed shift-map slice $slice of $num_slices"]
                } finally {
                    catch {$analysis_sel delete}
                    catch {$full_sel delete}
                }
            }

            if {[dict get $opts log_transform]} {
                set slice_columns [value_columns_log_transform $slice_columns [dict get $opts decimals]]
            }

            set mask_metadata [build_mask_metadata \
                $molid \
                $full_selection \
                $residue_records \
                [dict get $opts mask_selection] \
                $reference_vmd_frame]

            if {[dict get $opts defer_mask_clipping]} {
                set masked_count [count_masked_metadata $mask_metadata]
            } else {
                set mask_result [clip_masked_slice_columns \
                    $slice_columns \
                    $mask_metadata \
                    [dict get $opts allow_fully_masked]]
                set slice_columns [dict get $mask_result columns]
                set masked_count [dict get $mask_result masked_count]
                set mask_clip_min [dict get $mask_result clip_min]
                set mask_clip_max [dict get $mask_result clip_max]
            }
            set slice_columns [format_slice_columns $slice_columns [dict get $opts decimals]]

            emit_progress $opts [dict create \
                metric shift_map \
                stage writing_outputs \
                output_dir $output_dir \
                chain [dict get $opts chain] \
                csv $csv_path \
                message "Writing native shift-map CSV and summaries"]
            write_csv $csv_path $residue_records $slice_columns
            if {[dict get $opts write_mask_metadata] && [string trim [dict get $opts mask_selection]] ne ""} {
                write_mask_metadata $mask_metadata_path $mask_metadata
            }
            if {[dict get $opts write_summary]} {
                set summary [summary_rows \
                    $residue_records \
                    $slice_columns \
                    $mask_metadata \
                    [expr {int([dict get $opts summary_n])}]]
                write_summary_csv $summary_path $summary
            }

            if {[dict get $opts write_slices]} {
                emit_progress $opts [dict create \
                    metric shift_map \
                    stage writing_slices \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    slice_count [llength $slice_frames] \
                    message "Writing native shift-map slice PDBs"]
                foreach frame_record $slice_frames item $slice_columns {
                    set slice [dict get $frame_record slice]
                    set vmd_frame [dict get $frame_record vmd_start]
                    set pdb_path [file join $output_dir "slice_${slice}_first_frame.pdb"]
                    if {![dict get $opts overwrite] && [file exists $pdb_path]} {
                        error "Native shift-map slice output already exists: $pdb_path"
                    }
                    set full_sel [atomselect $molid $full_selection frame $vmd_frame]
                    try {
                        set beta_values [beta_values_for_selection $full_sel $residue_records [lindex $item 1]]
                        $full_sel set beta $beta_values
                        $full_sel writepdb $pdb_path
                    } finally {
                        catch {$full_sel delete}
                    }
                }
            }

            set vmd_analysis_start [expr {[dict get $plan start_frame] + $frame_offset}]
            set vmd_analysis_end [expr {[dict get $plan end_frame] + $frame_offset}]

            if {[dict get $opts write_rmsf]} {
                emit_progress $opts [dict create \
                    metric shift_map \
                    stage rmsf \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    message "Computing shift-map whole-trajectory RMSF"]
                set rmsf_values [whole_trajectory_rmsf \
                    $molid \
                    $analysis_selection \
                    $vmd_analysis_start \
                    $vmd_analysis_end]
                if {[llength $rmsf_values] != [llength $residue_records]} {
                    error "Shift-map whole-trajectory RMSF count mismatch: [llength $rmsf_values] values, [llength $residue_records] residues"
                }
                write_rmsf_csv $rmsf_path $residue_records $rmsf_values
            }

            if {[dict get $opts write_rmsd]} {
                emit_progress $opts [dict create \
                    metric shift_map \
                    stage rmsd \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    message "Computing shift-map fitted RMSD"]
                set rmsd_rows [fitted_rmsd_rows \
                    $molid \
                    $analysis_selection \
                    $vmd_analysis_start \
                    $vmd_analysis_end \
                    [dict get $plan start_frame] \
                    [dict get $opts rmsd_time_step] \
                    [dict get $opts rmsd_time_origin]]
                write_rmsd_csv $rmsd_path $rmsd_rows
            }
        } finally {
            if {[dict get $opts cleanup]} {
                catch {mol delete $molid}
            }
        }

        set result [dict create \
            metric shift_map \
            output_dir $output_dir \
            csv $csv_path \
            rmsd_csv $rmsd_path \
            rmsf_csv $rmsf_path \
            summary_csv $summary_path \
            residue_count [llength $residue_records] \
            slice_count [llength $slice_columns] \
            rmsd_frame_count [llength $rmsd_rows] \
            rmsf_residue_count [llength $rmsf_values] \
            summary_top_count [llength [dict get $summary top]] \
            summary_bottom_count [llength [dict get $summary bottom]] \
            masked_residue_count $masked_count \
            mask_clip_min $mask_clip_min \
            mask_clip_max $mask_clip_max \
            log_transform [dict get $opts log_transform] \
            deleted_previous_slices [llength $deleted_previous_slices] \
            frame_offset $frame_offset \
            topology_type [dict get $load_info topology_type] \
            trajectory_type [dict get $load_info trajectory_type] \
            initial_frame_count [dict get $load_info initial_frame_count] \
            total_frame_count [dict get $load_info total_frame_count] \
            plan $plan \
            selection $full_selection \
            analysis_selection $analysis_selection]

        if {[dict get $opts verbose]} {
            puts "RMSX Flipbook Timeline native shift-map analysis complete: $csv_path"
        }
        emit_progress $opts [dict create \
            metric shift_map \
            stage complete \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            csv $csv_path \
            slice_count [llength $slice_columns] \
            residue_count [llength $residue_records] \
            message "Native shift-map analysis complete"]
        return $result
    }

    proc run_lddt_map {topology trajectory output_dir args} {
        set defaults [dict create \
            chain "" \
            analysis_type protein \
            full_backbone 1 \
            selection "" \
            analysis_selection "" \
            start_frame 0 \
            end_frame -1 \
            frame_offset auto \
            topology_type auto \
            trajectory_type auto \
            num_slices "" \
            slice_size "" \
            csv_name "" \
            native_csv_name lddt_vmd_native.csv \
            name_style native \
            csv_prefix lddt \
            manual_length_ns "" \
            manual_length "" \
            manual_unit ns \
            rmsd_name rmsd.csv \
            rmsf_name rmsf.csv \
            summary_name rmsx_summary.csv \
            write_slices 1 \
            write_rmsd 1 \
            write_rmsf 1 \
            write_summary 1 \
            summary_n 3 \
            overwrite 0 \
            clean_previous_slices 1 \
            cleanup 1 \
            decimals 6 \
            log_transform 0 \
            mask_selection "" \
            write_mask_metadata 1 \
            allow_fully_masked 0 \
            defer_mask_clipping 0 \
            rmsd_time_step 0.04888821 \
            rmsd_time_origin 0.0 \
            inclusion_radius 15.0 \
            thresholds {0.5 1.0 2.0 4.0} \
            empty_neighbor_instability 0.0 \
            progress_callback "" \
            verbose 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set opts [resolve_analysis_options $opts]

        set empty_neighbor_instability [expr {double([dict get $opts empty_neighbor_instability])}]
        if {$empty_neighbor_instability < 0.0 || $empty_neighbor_instability > 1.0} {
            error "lDDT empty_neighbor_instability must be between 0 and 1"
        }
        set threshold_values [numeric_list [dict get $opts thresholds] "lDDT thresholds"]

        set output_dir [file normalize $output_dir]
        file mkdir $output_dir
        emit_progress $opts [dict create \
            metric lddt_map \
            stage preparing \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            message "Preparing native lDDT output"]

        set rmsd_path [file join $output_dir [dict get $opts rmsd_name]]
        set rmsf_path [file join $output_dir [dict get $opts rmsf_name]]
        set summary_path [file join $output_dir [dict get $opts summary_name]]
        if {[dict get $opts write_rmsd] && ![dict get $opts overwrite] && [file exists $rmsd_path]} {
            error "Native lDDT RMSD output already exists: $rmsd_path"
        }
        if {[dict get $opts write_rmsf] && ![dict get $opts overwrite] && [file exists $rmsf_path]} {
            error "Native lDDT RMSF output already exists: $rmsf_path"
        }
        if {[dict get $opts write_summary] && ![dict get $opts overwrite] && [file exists $summary_path]} {
            error "Native lDDT summary output already exists: $summary_path"
        }

        set deleted_previous_slices {}
        if {[dict get $opts overwrite] && [dict get $opts write_slices] && [dict get $opts clean_previous_slices]} {
            set deleted_previous_slices [clean_previous_slice_outputs $output_dir]
            if {[dict get $opts verbose] && [llength $deleted_previous_slices] > 0} {
                puts "  Removed [llength $deleted_previous_slices] previous slice PDB files from $output_dir"
            }
        }
        set mask_metadata_path [file join $output_dir masked_residues.csv]
        if {[dict get $opts overwrite] && [string trim [dict get $opts mask_selection]] eq "" && [file exists $mask_metadata_path]} {
            file delete $mask_metadata_path
        }

        set load_info [load_trajectory \
            [file normalize $topology] \
            [file normalize $trajectory] \
            -topology_type [dict get $opts topology_type] \
            -trajectory_type [dict get $opts trajectory_type]]
        set molid [dict get $load_info molid]
        hide_cleanup_molecule $molid $opts
        set frame_offset [resolve_frame_offset [dict get $opts frame_offset] $load_info]
        set total_frames [molinfo $molid get numframes]
        set available_frames [expr {$total_frames - $frame_offset}]
        if {$available_frames <= 0} {
            error "Trajectory has no analyzable frames after frame_offset=$frame_offset"
        }

        set plan [resolve_slice_plan $available_frames $opts]
        set csv_path [file join $output_dir [resolve_csv_name $trajectory $opts $plan]]
        if {![dict get $opts overwrite] && [file exists $csv_path]} {
            error "Native lDDT output already exists: $csv_path"
        }

        set full_selection [append_chain_selection [dict get $opts selection] [dict get $opts chain]]
        set analysis_selection [append_chain_selection [dict get $opts analysis_selection] [dict get $opts chain]]
        emit_progress $opts [dict create \
            metric lddt_map \
            stage started \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            molid $molid \
            start_frame [dict get $plan start_frame] \
            end_frame [dict get $plan end_frame] \
            frame_offset $frame_offset \
            topology_type [dict get $load_info topology_type] \
            trajectory_type [dict get $load_info trajectory_type] \
            slice_count [dict get $plan num_slices] \
            slice_size [dict get $plan slice_size] \
            selection $full_selection \
            analysis_selection $analysis_selection \
            inclusion_radius [dict get $opts inclusion_radius] \
            thresholds $threshold_values \
            message "Started native lDDT analysis"]

        if {[dict get $opts verbose]} {
            set topology_type_label [dict get $load_info topology_type]
            if {$topology_type_label eq ""} {
                set topology_type_label auto
            }
            set trajectory_type_label [dict get $load_info trajectory_type]
            if {$trajectory_type_label eq ""} {
                set trajectory_type_label auto
            }
            puts "RMSX Flipbook Timeline native lDDT map analysis"
            puts "  Molecule: $molid"
            puts "  Reference frame: [dict get $plan start_frame] (trajectory coordinates)"
            puts "  Frame offset in VMD: $frame_offset"
            puts "  Topology type: $topology_type_label"
            puts "  Trajectory type: $trajectory_type_label"
            puts "  Slices: [dict get $plan num_slices]"
            puts "  Slice size: [dict get $plan slice_size]"
            puts "  Selection: $full_selection"
            puts "  Analysis selection: $analysis_selection"
            puts "  lDDT inclusion radius: [dict get $opts inclusion_radius]"
            puts "  lDDT thresholds: [join $threshold_values {, }]"
        }

        set residue_records {}
        set slice_columns {}
        set slice_frames {}
        set mask_metadata {}
        set masked_count 0
        set mask_clip_min ""
        set mask_clip_max ""
        set summary [dict create top {} bottom {}]
        set rmsd_rows {}
        set rmsf_values {}

        try {
            set num_slices [dict get $plan num_slices]
            set slice_size [dict get $plan slice_size]
            set start_frame [dict get $plan start_frame]
            set reference_vmd_frame [expr {$start_frame + $frame_offset}]

            set reference_sel [atomselect $molid $analysis_selection frame $reference_vmd_frame]
            try {
                set residue_records [residue_records_from_selection $reference_sel]
                ensure_representative_selection \
                    $reference_sel \
                    $residue_records \
                    "Native lDDT analysis"
                set reference_coords [selection_coordinate_list $reference_sel "Native lDDT reference"]
                set reference_model [lddt_reference_model \
                    $reference_coords \
                    [dict get $opts inclusion_radius]]
            } finally {
                catch {$reference_sel delete}
            }

            for {set slice 1} {$slice <= $num_slices} {incr slice} {
                set traj_frame [expr {$start_frame + (($slice - 1) * $slice_size)}]
                set vmd_frame [expr {$traj_frame + $frame_offset}]

                set analysis_sel [atomselect $molid $analysis_selection frame $vmd_frame]
                set full_sel [atomselect $molid $full_selection frame $vmd_frame]

                try {
                    if {[$analysis_sel num] == 0} {
                        error "Analysis selection returned no atoms for lDDT slice $slice: $analysis_selection"
                    }
                    if {[$full_sel num] == 0} {
                        error "Structure selection returned no atoms for lDDT slice $slice: $full_selection"
                    }

                    set current_records [residue_records_from_selection $analysis_sel]
                    assert_matching_records \
                        $residue_records \
                        $current_records \
                        "Native lDDT slice $slice"
                    ensure_representative_selection \
                        $analysis_sel \
                        $residue_records \
                        "Native lDDT slice $slice"
                    set current_coords [selection_coordinate_list $analysis_sel "Native lDDT slice $slice"]
                    set values [lddt_instability_values \
                        $reference_model \
                        $current_coords \
                        $threshold_values \
                        $empty_neighbor_instability]

                    lappend slice_columns [list "slice_${slice}.dcd" $values]
                    lappend slice_frames [dict create slice $slice vmd_start $vmd_frame]

                    if {[dict get $opts verbose]} {
                        puts "  Slice $slice: trajectory frame $traj_frame"
                    }
                    emit_progress $opts [dict create \
                        metric lddt_map \
                        stage slice \
                        output_dir $output_dir \
                        chain [dict get $opts chain] \
                        slice $slice \
                        slice_count $num_slices \
                        frame_start $traj_frame \
                        frame_end $traj_frame \
                        message "Computed lDDT slice $slice of $num_slices"]
                } finally {
                    catch {$analysis_sel delete}
                    catch {$full_sel delete}
                }
            }

            if {[dict get $opts log_transform]} {
                set slice_columns [value_columns_log_transform $slice_columns [dict get $opts decimals]]
            }

            set mask_metadata [build_mask_metadata \
                $molid \
                $full_selection \
                $residue_records \
                [dict get $opts mask_selection] \
                $reference_vmd_frame]

            if {[dict get $opts defer_mask_clipping]} {
                set masked_count [count_masked_metadata $mask_metadata]
            } else {
                set mask_result [clip_masked_slice_columns \
                    $slice_columns \
                    $mask_metadata \
                    [dict get $opts allow_fully_masked]]
                set slice_columns [dict get $mask_result columns]
                set masked_count [dict get $mask_result masked_count]
                set mask_clip_min [dict get $mask_result clip_min]
                set mask_clip_max [dict get $mask_result clip_max]
            }
            set slice_columns [format_slice_columns $slice_columns [dict get $opts decimals]]

            emit_progress $opts [dict create \
                metric lddt_map \
                stage writing_outputs \
                output_dir $output_dir \
                chain [dict get $opts chain] \
                csv $csv_path \
                message "Writing native lDDT CSV and summaries"]
            write_csv $csv_path $residue_records $slice_columns
            if {[dict get $opts write_mask_metadata] && [string trim [dict get $opts mask_selection]] ne ""} {
                write_mask_metadata $mask_metadata_path $mask_metadata
            }
            if {[dict get $opts write_summary]} {
                set summary [summary_rows \
                    $residue_records \
                    $slice_columns \
                    $mask_metadata \
                    [expr {int([dict get $opts summary_n])}]]
                write_summary_csv $summary_path $summary
            }

            if {[dict get $opts write_slices]} {
                emit_progress $opts [dict create \
                    metric lddt_map \
                    stage writing_slices \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    slice_count [llength $slice_frames] \
                    message "Writing native lDDT slice PDBs"]
                foreach frame_record $slice_frames item $slice_columns {
                    set slice [dict get $frame_record slice]
                    set vmd_frame [dict get $frame_record vmd_start]
                    set pdb_path [file join $output_dir "slice_${slice}_first_frame.pdb"]
                    if {![dict get $opts overwrite] && [file exists $pdb_path]} {
                        error "Native lDDT slice output already exists: $pdb_path"
                    }
                    set full_sel [atomselect $molid $full_selection frame $vmd_frame]
                    try {
                        set beta_values [beta_values_for_selection $full_sel $residue_records [lindex $item 1]]
                        $full_sel set beta $beta_values
                        $full_sel writepdb $pdb_path
                    } finally {
                        catch {$full_sel delete}
                    }
                }
            }

            set vmd_analysis_start [expr {[dict get $plan start_frame] + $frame_offset}]
            set vmd_analysis_end [expr {[dict get $plan end_frame] + $frame_offset}]

            if {[dict get $opts write_rmsf]} {
                emit_progress $opts [dict create \
                    metric lddt_map \
                    stage rmsf \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    message "Computing lDDT whole-trajectory RMSF"]
                set rmsf_values [whole_trajectory_rmsf \
                    $molid \
                    $analysis_selection \
                    $vmd_analysis_start \
                    $vmd_analysis_end]
                if {[llength $rmsf_values] != [llength $residue_records]} {
                    error "lDDT whole-trajectory RMSF count mismatch: [llength $rmsf_values] values, [llength $residue_records] residues"
                }
                write_rmsf_csv $rmsf_path $residue_records $rmsf_values
            }

            if {[dict get $opts write_rmsd]} {
                emit_progress $opts [dict create \
                    metric lddt_map \
                    stage rmsd \
                    output_dir $output_dir \
                    chain [dict get $opts chain] \
                    message "Computing lDDT fitted RMSD"]
                set rmsd_rows [fitted_rmsd_rows \
                    $molid \
                    $analysis_selection \
                    $vmd_analysis_start \
                    $vmd_analysis_end \
                    [dict get $plan start_frame] \
                    [dict get $opts rmsd_time_step] \
                    [dict get $opts rmsd_time_origin]]
                write_rmsd_csv $rmsd_path $rmsd_rows
            }
        } finally {
            if {[dict get $opts cleanup]} {
                catch {mol delete $molid}
            }
        }

        set result [dict create \
            metric lddt_map \
            output_dir $output_dir \
            csv $csv_path \
            rmsd_csv $rmsd_path \
            rmsf_csv $rmsf_path \
            summary_csv $summary_path \
            residue_count [llength $residue_records] \
            slice_count [llength $slice_columns] \
            rmsd_frame_count [llength $rmsd_rows] \
            rmsf_residue_count [llength $rmsf_values] \
            summary_top_count [llength [dict get $summary top]] \
            summary_bottom_count [llength [dict get $summary bottom]] \
            masked_residue_count $masked_count \
            mask_clip_min $mask_clip_min \
            mask_clip_max $mask_clip_max \
            log_transform [dict get $opts log_transform] \
            deleted_previous_slices [llength $deleted_previous_slices] \
            frame_offset $frame_offset \
            topology_type [dict get $load_info topology_type] \
            trajectory_type [dict get $load_info trajectory_type] \
            initial_frame_count [dict get $load_info initial_frame_count] \
            total_frame_count [dict get $load_info total_frame_count] \
            plan $plan \
            selection $full_selection \
            analysis_selection $analysis_selection \
            inclusion_radius [dict get $opts inclusion_radius] \
            thresholds $threshold_values \
            empty_neighbor_instability $empty_neighbor_instability]

        if {[dict get $opts verbose]} {
            puts "RMSX Flipbook Timeline native lDDT map analysis complete: $csv_path"
        }
        emit_progress $opts [dict create \
            metric lddt_map \
            stage complete \
            output_dir $output_dir \
            chain [dict get $opts chain] \
            csv $csv_path \
            slice_count [llength $slice_columns] \
            residue_count [llength $residue_records] \
            message "Native lDDT analysis complete"]
        return $result
    }

    proc run_all_chains {topology trajectory output_dir args} {
        set defaults [dict create \
            analysis_type protein \
            full_backbone 1 \
            selection "" \
            analysis_selection "" \
            start_frame 0 \
            end_frame -1 \
            frame_offset auto \
            topology_type auto \
            trajectory_type auto \
            num_slices "" \
            slice_size "" \
            csv_name "" \
            name_style native \
            csv_prefix rmsx \
            manual_length_ns "" \
            manual_length "" \
            manual_unit ns \
            overwrite 0 \
            cleanup 1 \
            decimals 6 \
            log_transform 0 \
            mask_selection "" \
            write_mask_metadata 1 \
            allow_fully_masked 1 \
            rmsd_time_step 0.04888821 \
            rmsd_time_origin 0.0 \
            summary_n 3 \
            safe_output_dir 1 \
            progress_callback "" \
            verbose 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set opts [resolve_analysis_options $opts]

        set output_dir [file normalize $output_dir]
        emit_progress $opts [dict create \
            metric rmsx \
            stage all_chain_preparing \
            output_dir $output_dir \
            message "Preparing native all-chain RMSX output"]
        if {[dict get $opts safe_output_dir]} {
            prepare_managed_output_dir \
                $output_dir \
                -overwrite [dict get $opts overwrite] \
                -verbose [dict get $opts verbose] \
                -topology_file $topology \
                -trajectory_file $trajectory
        } else {
            file mkdir $output_dir
        }

        set chains [discover_valid_chains \
            [file normalize $topology] \
            [dict get $opts analysis_selection] \
            [dict get $opts topology_type]]
        if {[llength $chains] == 0} {
            error "No valid chains were found for native all-chain RMSX analysis"
        }
        emit_progress $opts [dict create \
            metric rmsx \
            stage all_chain_started \
            output_dir $output_dir \
            chains $chains \
            chain_count [llength $chains] \
            message "Started native all-chain RMSX analysis"]

        if {[dict get $opts verbose]} {
            puts "RMSX Flipbook Timeline native all-chain analysis"
            puts "  Chains: [join $chains {, }]"
            puts "  Output: $output_dir"
        }

        set mask_active [expr {[string trim [dict get $opts mask_selection]] ne ""}]
        set chain_dirs {}
        set csv_paths {}
        set chain_results {}

        set chain_index 0
        foreach chain $chains {
            incr chain_index
            set chain_dir [file join $output_dir "chain_${chain}_rmsx"]
            if {[dict get $opts verbose]} {
                puts "  Analyzing chain $chain into $chain_dir"
            }
            emit_progress $opts [dict create \
                metric rmsx \
                stage chain_started \
                output_dir $chain_dir \
                base_output_dir $output_dir \
                chain $chain \
                chain_index $chain_index \
                chain_count [llength $chains] \
                message "Analyzing RMSX chain $chain ($chain_index of [llength $chains])"]

            set result [run \
                $topology \
                $trajectory \
                $chain_dir \
                -chain $chain \
                -selection [dict get $opts selection] \
                -analysis_selection [dict get $opts analysis_selection] \
                -analysis_type [dict get $opts analysis_type] \
                -full_backbone [dict get $opts full_backbone] \
                -start_frame [dict get $opts start_frame] \
                -end_frame [dict get $opts end_frame] \
                -frame_offset [dict get $opts frame_offset] \
                -topology_type [dict get $opts topology_type] \
                -trajectory_type [dict get $opts trajectory_type] \
                -num_slices [dict get $opts num_slices] \
                -slice_size [dict get $opts slice_size] \
                -csv_name [dict get $opts csv_name] \
                -name_style [dict get $opts name_style] \
                -csv_prefix [dict get $opts csv_prefix] \
                -manual_length_ns [dict get $opts manual_length_ns] \
                -manual_length [dict get $opts manual_length] \
                -manual_unit [dict get $opts manual_unit] \
                -overwrite [dict get $opts overwrite] \
                -cleanup [dict get $opts cleanup] \
                -decimals [dict get $opts decimals] \
                -log_transform [dict get $opts log_transform] \
                -mask_selection [dict get $opts mask_selection] \
                -write_mask_metadata [dict get $opts write_mask_metadata] \
                -allow_fully_masked [dict get $opts allow_fully_masked] \
                -defer_mask_clipping $mask_active \
                -rmsd_time_step [dict get $opts rmsd_time_step] \
                -rmsd_time_origin [dict get $opts rmsd_time_origin] \
                -summary_n [dict get $opts summary_n] \
                -progress_callback [dict get $opts progress_callback] \
                -verbose [dict get $opts verbose]]

            lappend chain_dirs $chain_dir
            lappend csv_paths [dict get $result csv]
            lappend chain_results $result
            emit_progress $opts [dict create \
                metric rmsx \
                stage chain_complete \
                output_dir $chain_dir \
                base_output_dir $output_dir \
                chain $chain \
                chain_index $chain_index \
                chain_count [llength $chains] \
                csv [dict get $result csv] \
                message "Completed RMSX chain $chain"]
        }

        set global_clip_bounds {}
        if {$mask_active} {
            emit_progress $opts [dict create \
                metric rmsx \
                stage global_mask \
                output_dir $output_dir \
                chain_count [llength $chains] \
                message "Applying global all-chain RMSX mask clipping"]
            set global_clip_bounds [compute_global_csv_value_range $csv_paths]
            if {[dict get $opts verbose]} {
                puts "  Native all-chain mask clip range: [lindex $global_clip_bounds 0] to [lindex $global_clip_bounds 1]"
            }
            for {set i 0} {$i < [llength $csv_paths]} {incr i} {
                set csv_path [lindex $csv_paths $i]
                set chain_dir [lindex $chain_dirs $i]
                clip_csv_masked_rows $csv_path $global_clip_bounds [dict get $opts decimals]
                update_slice_pdb_bfactors_from_csv $chain_dir $csv_path
                write_summary_from_csv \
                    $csv_path \
                    [file join $chain_dir rmsx_summary.csv] \
                    [expr {int([dict get $opts summary_n])}]
            }
        }

        if {[llength $chain_dirs] > 1} {
            set combined_dir [file join $output_dir combined]
            emit_progress $opts [dict create \
                metric rmsx \
                stage combine \
                output_dir $combined_dir \
                base_output_dir $output_dir \
                chain_count [llength $chains] \
                message "Combining native RMSX chain flipbooks"]
            set combined_result [combine_pdb_files \
                $chain_dirs \
                $combined_dir \
                -overwrite [dict get $opts overwrite] \
                -verbose [dict get $opts verbose]]
        } else {
            set combined_dir [lindex $chain_dirs 0]
            set combined_result [dict create files [glob -nocomplain -directory $combined_dir "slice_*_first_frame.pdb"] deleted {}]
        }

        set combined_mask ""
        if {$mask_active} {
            set combined_mask [write_combined_mask_metadata $chain_dirs $combined_dir]
        }
        if {[llength $chain_dirs] > 1} {
            set combined_sidecars [write_combined_analysis_sidecars \
                $chain_dirs \
                $csv_paths \
                $combined_dir \
                -csv_name [file tail [lindex $csv_paths 0]] \
                -summary_n [dict get $opts summary_n] \
                -overwrite [dict get $opts overwrite]]
        } else {
            set combined_sidecars [sidecars_from_chain_result [lindex $chain_results 0]]
        }

        set global_clip_min ""
        set global_clip_max ""
        if {[llength $global_clip_bounds] == 2} {
            set global_clip_min [lindex $global_clip_bounds 0]
            set global_clip_max [lindex $global_clip_bounds 1]
        }

        set result [dict create \
            output_dir $combined_dir \
            base_output_dir $output_dir \
            chains $chains \
            chain_dirs $chain_dirs \
            csv_paths $csv_paths \
            chain_results $chain_results \
            csv [dict get $combined_sidecars csv] \
            rmsd_csv [dict get $combined_sidecars rmsd_csv] \
            rmsd_by_chain_csv [dict get $combined_sidecars rmsd_by_chain_csv] \
            rmsf_csv [dict get $combined_sidecars rmsf_csv] \
            summary_csv [dict get $combined_sidecars summary_csv] \
            combined_slice_count [llength [dict get $combined_result files]] \
            combined_csv [dict get $combined_sidecars csv] \
            combined_row_count [dict get $combined_sidecars row_count] \
            combined_mask_file $combined_mask \
            mask_clip_min $global_clip_min \
            mask_clip_max $global_clip_max \
            log_transform [dict get $opts log_transform]]
        emit_progress $opts [dict create \
            metric rmsx \
            stage all_chain_complete \
            output_dir $combined_dir \
            base_output_dir $output_dir \
            chains $chains \
            chain_count [llength $chains] \
            combined_slice_count [dict get $result combined_slice_count] \
            message "Native all-chain RMSX analysis complete"]
        return $result
    }

    proc run_all_chain_shift_map {topology trajectory output_dir args} {
        set defaults [dict create \
            analysis_type protein \
            full_backbone 1 \
            selection "" \
            analysis_selection "" \
            start_frame 0 \
            end_frame -1 \
            frame_offset auto \
            topology_type auto \
            trajectory_type auto \
            num_slices "" \
            slice_size "" \
            csv_name "" \
            name_style native \
            csv_prefix rmsx \
            manual_length_ns "" \
            manual_length "" \
            manual_unit ns \
            overwrite 0 \
            cleanup 1 \
            decimals 6 \
            log_transform 0 \
            mask_selection "" \
            write_mask_metadata 1 \
            allow_fully_masked 1 \
            rmsd_time_step 0.04888821 \
            rmsd_time_origin 0.0 \
            summary_n 3 \
            safe_output_dir 1 \
            progress_callback "" \
            verbose 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set opts [resolve_analysis_options $opts]

        set output_dir [file normalize $output_dir]
        emit_progress $opts [dict create \
            metric shift_map \
            stage all_chain_preparing \
            output_dir $output_dir \
            message "Preparing native all-chain shift-map output"]
        if {[dict get $opts safe_output_dir]} {
            prepare_managed_output_dir \
                $output_dir \
                -overwrite [dict get $opts overwrite] \
                -verbose [dict get $opts verbose] \
                -topology_file $topology \
                -trajectory_file $trajectory
        } else {
            file mkdir $output_dir
        }

        set chains [discover_valid_chains \
            [file normalize $topology] \
            [dict get $opts analysis_selection] \
            [dict get $opts topology_type]]
        if {[llength $chains] == 0} {
            error "No valid chains were found for native all-chain shift-map analysis"
        }
        emit_progress $opts [dict create \
            metric shift_map \
            stage all_chain_started \
            output_dir $output_dir \
            chains $chains \
            chain_count [llength $chains] \
            message "Started native all-chain shift-map analysis"]

        if {[dict get $opts verbose]} {
            puts "RMSX Flipbook Timeline native all-chain shift-map analysis"
            puts "  Chains: [join $chains {, }]"
            puts "  Output: $output_dir"
        }

        set mask_active [expr {[string trim [dict get $opts mask_selection]] ne ""}]
        set chain_dirs {}
        set csv_paths {}
        set chain_results {}

        set chain_index 0
        foreach chain $chains {
            incr chain_index
            set chain_dir [file join $output_dir "chain_${chain}_shiftmap"]
            if {[dict get $opts verbose]} {
                puts "  Shift-map chain $chain into $chain_dir"
            }
            emit_progress $opts [dict create \
                metric shift_map \
                stage chain_started \
                output_dir $chain_dir \
                base_output_dir $output_dir \
                chain $chain \
                chain_index $chain_index \
                chain_count [llength $chains] \
                message "Analyzing shift-map chain $chain ($chain_index of [llength $chains])"]

            set result [run_shift_map \
                $topology \
                $trajectory \
                $chain_dir \
                -chain $chain \
                -selection [dict get $opts selection] \
                -analysis_selection [dict get $opts analysis_selection] \
                -analysis_type [dict get $opts analysis_type] \
                -full_backbone [dict get $opts full_backbone] \
                -start_frame [dict get $opts start_frame] \
                -end_frame [dict get $opts end_frame] \
                -frame_offset [dict get $opts frame_offset] \
                -topology_type [dict get $opts topology_type] \
                -trajectory_type [dict get $opts trajectory_type] \
                -num_slices [dict get $opts num_slices] \
                -slice_size [dict get $opts slice_size] \
                -csv_name [dict get $opts csv_name] \
                -name_style [dict get $opts name_style] \
                -csv_prefix [dict get $opts csv_prefix] \
                -manual_length_ns [dict get $opts manual_length_ns] \
                -manual_length [dict get $opts manual_length] \
                -manual_unit [dict get $opts manual_unit] \
                -overwrite [dict get $opts overwrite] \
                -cleanup [dict get $opts cleanup] \
                -decimals [dict get $opts decimals] \
                -log_transform [dict get $opts log_transform] \
                -mask_selection [dict get $opts mask_selection] \
                -write_mask_metadata [dict get $opts write_mask_metadata] \
                -allow_fully_masked [dict get $opts allow_fully_masked] \
                -defer_mask_clipping $mask_active \
                -rmsd_time_step [dict get $opts rmsd_time_step] \
                -rmsd_time_origin [dict get $opts rmsd_time_origin] \
                -summary_n [dict get $opts summary_n] \
                -progress_callback [dict get $opts progress_callback] \
                -verbose [dict get $opts verbose]]

            lappend chain_dirs $chain_dir
            lappend csv_paths [dict get $result csv]
            lappend chain_results $result
            emit_progress $opts [dict create \
                metric shift_map \
                stage chain_complete \
                output_dir $chain_dir \
                base_output_dir $output_dir \
                chain $chain \
                chain_index $chain_index \
                chain_count [llength $chains] \
                csv [dict get $result csv] \
                message "Completed shift-map chain $chain"]
        }

        set global_clip_bounds {}
        if {$mask_active} {
            emit_progress $opts [dict create \
                metric shift_map \
                stage global_mask \
                output_dir $output_dir \
                chain_count [llength $chains] \
                message "Applying global all-chain shift-map mask clipping"]
            set global_clip_bounds [compute_global_csv_value_range $csv_paths]
            if {[dict get $opts verbose]} {
                puts "  Native all-chain shift-map mask clip range: [lindex $global_clip_bounds 0] to [lindex $global_clip_bounds 1]"
            }
            for {set i 0} {$i < [llength $csv_paths]} {incr i} {
                set csv_path [lindex $csv_paths $i]
                set chain_dir [lindex $chain_dirs $i]
                clip_csv_masked_rows $csv_path $global_clip_bounds [dict get $opts decimals]
                update_slice_pdb_bfactors_from_csv $chain_dir $csv_path
                write_summary_from_csv \
                    $csv_path \
                    [file join $chain_dir rmsx_summary.csv] \
                    [expr {int([dict get $opts summary_n])}]
            }
        }

        if {[llength $chain_dirs] > 1} {
            set combined_dir [file join $output_dir combined]
            emit_progress $opts [dict create \
                metric shift_map \
                stage combine \
                output_dir $combined_dir \
                base_output_dir $output_dir \
                chain_count [llength $chains] \
                message "Combining native shift-map chain flipbooks"]
            set combined_result [combine_pdb_files \
                $chain_dirs \
                $combined_dir \
                -overwrite [dict get $opts overwrite] \
                -verbose [dict get $opts verbose]]
        } else {
            set combined_dir [lindex $chain_dirs 0]
            set combined_result [dict create files [glob -nocomplain -directory $combined_dir "slice_*_first_frame.pdb"] deleted {}]
        }

        set combined_mask ""
        if {$mask_active} {
            set combined_mask [write_combined_mask_metadata $chain_dirs $combined_dir]
        }
        if {[llength $chain_dirs] > 1} {
            set combined_sidecars [write_combined_analysis_sidecars \
                $chain_dirs \
                $csv_paths \
                $combined_dir \
                -csv_name [file tail [lindex $csv_paths 0]] \
                -summary_n [dict get $opts summary_n] \
                -overwrite [dict get $opts overwrite]]
        } else {
            set combined_sidecars [sidecars_from_chain_result [lindex $chain_results 0]]
        }

        set global_clip_min ""
        set global_clip_max ""
        if {[llength $global_clip_bounds] == 2} {
            set global_clip_min [lindex $global_clip_bounds 0]
            set global_clip_max [lindex $global_clip_bounds 1]
        }

        set result [dict create \
            metric shift_map \
            output_dir $combined_dir \
            base_output_dir $output_dir \
            chains $chains \
            chain_dirs $chain_dirs \
            csv_paths $csv_paths \
            chain_results $chain_results \
            csv [dict get $combined_sidecars csv] \
            rmsd_csv [dict get $combined_sidecars rmsd_csv] \
            rmsd_by_chain_csv [dict get $combined_sidecars rmsd_by_chain_csv] \
            rmsf_csv [dict get $combined_sidecars rmsf_csv] \
            summary_csv [dict get $combined_sidecars summary_csv] \
            combined_slice_count [llength [dict get $combined_result files]] \
            combined_csv [dict get $combined_sidecars csv] \
            combined_row_count [dict get $combined_sidecars row_count] \
            combined_mask_file $combined_mask \
            mask_clip_min $global_clip_min \
            mask_clip_max $global_clip_max \
            log_transform [dict get $opts log_transform]]
        emit_progress $opts [dict create \
            metric shift_map \
            stage all_chain_complete \
            output_dir $combined_dir \
            base_output_dir $output_dir \
            chains $chains \
            chain_count [llength $chains] \
            combined_slice_count [dict get $result combined_slice_count] \
            message "Native all-chain shift-map analysis complete"]
        return $result
    }

    proc run_all_chain_lddt_map {topology trajectory output_dir args} {
        set defaults [dict create \
            analysis_type protein \
            full_backbone 1 \
            selection "" \
            analysis_selection "" \
            start_frame 0 \
            end_frame -1 \
            frame_offset auto \
            topology_type auto \
            trajectory_type auto \
            num_slices "" \
            slice_size "" \
            csv_name "" \
            native_csv_name lddt_vmd_native.csv \
            name_style native \
            csv_prefix lddt \
            manual_length_ns "" \
            manual_length "" \
            manual_unit ns \
            overwrite 0 \
            cleanup 1 \
            decimals 6 \
            log_transform 0 \
            mask_selection "" \
            write_mask_metadata 1 \
            allow_fully_masked 1 \
            rmsd_time_step 0.04888821 \
            rmsd_time_origin 0.0 \
            summary_n 3 \
            inclusion_radius 15.0 \
            thresholds {0.5 1.0 2.0 4.0} \
            empty_neighbor_instability 0.0 \
            safe_output_dir 1 \
            progress_callback "" \
            verbose 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set opts [resolve_analysis_options $opts]

        set output_dir [file normalize $output_dir]
        emit_progress $opts [dict create \
            metric lddt_map \
            stage all_chain_preparing \
            output_dir $output_dir \
            message "Preparing native all-chain lDDT output"]
        if {[dict get $opts safe_output_dir]} {
            prepare_managed_output_dir \
                $output_dir \
                -overwrite [dict get $opts overwrite] \
                -verbose [dict get $opts verbose] \
                -topology_file $topology \
                -trajectory_file $trajectory
        } else {
            file mkdir $output_dir
        }

        set chains [discover_valid_chains \
            [file normalize $topology] \
            [dict get $opts analysis_selection] \
            [dict get $opts topology_type]]
        if {[llength $chains] == 0} {
            error "No valid chains were found for native all-chain lDDT map analysis"
        }
        emit_progress $opts [dict create \
            metric lddt_map \
            stage all_chain_started \
            output_dir $output_dir \
            chains $chains \
            chain_count [llength $chains] \
            message "Started native all-chain lDDT analysis"]

        if {[dict get $opts verbose]} {
            puts "RMSX Flipbook Timeline native all-chain lDDT map analysis"
            puts "  Chains: [join $chains {, }]"
            puts "  Output: $output_dir"
        }

        set mask_active [expr {[string trim [dict get $opts mask_selection]] ne ""}]
        set chain_dirs {}
        set csv_paths {}
        set chain_results {}

        set chain_index 0
        foreach chain $chains {
            incr chain_index
            set chain_dir [file join $output_dir "chain_${chain}_lddtmap"]
            if {[dict get $opts verbose]} {
                puts "  lDDT chain $chain into $chain_dir"
            }
            emit_progress $opts [dict create \
                metric lddt_map \
                stage chain_started \
                output_dir $chain_dir \
                base_output_dir $output_dir \
                chain $chain \
                chain_index $chain_index \
                chain_count [llength $chains] \
                message "Analyzing lDDT chain $chain ($chain_index of [llength $chains])"]

            set result [run_lddt_map \
                $topology \
                $trajectory \
                $chain_dir \
                -chain $chain \
                -selection [dict get $opts selection] \
                -analysis_selection [dict get $opts analysis_selection] \
                -analysis_type [dict get $opts analysis_type] \
                -full_backbone [dict get $opts full_backbone] \
                -start_frame [dict get $opts start_frame] \
                -end_frame [dict get $opts end_frame] \
                -frame_offset [dict get $opts frame_offset] \
                -topology_type [dict get $opts topology_type] \
                -trajectory_type [dict get $opts trajectory_type] \
                -num_slices [dict get $opts num_slices] \
                -slice_size [dict get $opts slice_size] \
                -csv_name [dict get $opts csv_name] \
                -native_csv_name [dict get $opts native_csv_name] \
                -name_style [dict get $opts name_style] \
                -csv_prefix [dict get $opts csv_prefix] \
                -manual_length_ns [dict get $opts manual_length_ns] \
                -manual_length [dict get $opts manual_length] \
                -manual_unit [dict get $opts manual_unit] \
                -overwrite [dict get $opts overwrite] \
                -cleanup [dict get $opts cleanup] \
                -decimals [dict get $opts decimals] \
                -log_transform [dict get $opts log_transform] \
                -mask_selection [dict get $opts mask_selection] \
                -write_mask_metadata [dict get $opts write_mask_metadata] \
                -allow_fully_masked [dict get $opts allow_fully_masked] \
                -defer_mask_clipping $mask_active \
                -rmsd_time_step [dict get $opts rmsd_time_step] \
                -rmsd_time_origin [dict get $opts rmsd_time_origin] \
                -summary_n [dict get $opts summary_n] \
                -inclusion_radius [dict get $opts inclusion_radius] \
                -thresholds [dict get $opts thresholds] \
                -empty_neighbor_instability [dict get $opts empty_neighbor_instability] \
                -progress_callback [dict get $opts progress_callback] \
                -verbose [dict get $opts verbose]]

            lappend chain_dirs $chain_dir
            lappend csv_paths [dict get $result csv]
            lappend chain_results $result
            emit_progress $opts [dict create \
                metric lddt_map \
                stage chain_complete \
                output_dir $chain_dir \
                base_output_dir $output_dir \
                chain $chain \
                chain_index $chain_index \
                chain_count [llength $chains] \
                csv [dict get $result csv] \
                message "Completed lDDT chain $chain"]
        }

        set global_clip_bounds {}
        if {$mask_active} {
            emit_progress $opts [dict create \
                metric lddt_map \
                stage global_mask \
                output_dir $output_dir \
                chain_count [llength $chains] \
                message "Applying global all-chain lDDT mask clipping"]
            set global_clip_bounds [compute_global_csv_value_range $csv_paths]
            if {[dict get $opts verbose]} {
                puts "  Native all-chain lDDT mask clip range: [lindex $global_clip_bounds 0] to [lindex $global_clip_bounds 1]"
            }
            for {set i 0} {$i < [llength $csv_paths]} {incr i} {
                set csv_path [lindex $csv_paths $i]
                set chain_dir [lindex $chain_dirs $i]
                clip_csv_masked_rows $csv_path $global_clip_bounds [dict get $opts decimals]
                update_slice_pdb_bfactors_from_csv $chain_dir $csv_path
                write_summary_from_csv \
                    $csv_path \
                    [file join $chain_dir rmsx_summary.csv] \
                    [expr {int([dict get $opts summary_n])}]
            }
        }

        if {[llength $chain_dirs] > 1} {
            set combined_dir [file join $output_dir combined]
            emit_progress $opts [dict create \
                metric lddt_map \
                stage combine \
                output_dir $combined_dir \
                base_output_dir $output_dir \
                chain_count [llength $chains] \
                message "Combining native lDDT chain flipbooks"]
            set combined_result [combine_pdb_files \
                $chain_dirs \
                $combined_dir \
                -overwrite [dict get $opts overwrite] \
                -verbose [dict get $opts verbose]]
        } else {
            set combined_dir [lindex $chain_dirs 0]
            set combined_result [dict create files [glob -nocomplain -directory $combined_dir "slice_*_first_frame.pdb"] deleted {}]
        }

        set combined_mask ""
        if {$mask_active} {
            set combined_mask [write_combined_mask_metadata $chain_dirs $combined_dir]
        }
        if {[llength $chain_dirs] > 1} {
            set combined_sidecars [write_combined_analysis_sidecars \
                $chain_dirs \
                $csv_paths \
                $combined_dir \
                -csv_name [file tail [lindex $csv_paths 0]] \
                -summary_n [dict get $opts summary_n] \
                -overwrite [dict get $opts overwrite]]
        } else {
            set combined_sidecars [sidecars_from_chain_result [lindex $chain_results 0]]
        }

        set global_clip_min ""
        set global_clip_max ""
        if {[llength $global_clip_bounds] == 2} {
            set global_clip_min [lindex $global_clip_bounds 0]
            set global_clip_max [lindex $global_clip_bounds 1]
        }

        set result [dict create \
            metric lddt_map \
            output_dir $combined_dir \
            base_output_dir $output_dir \
            chains $chains \
            chain_dirs $chain_dirs \
            csv_paths $csv_paths \
            chain_results $chain_results \
            csv [dict get $combined_sidecars csv] \
            rmsd_csv [dict get $combined_sidecars rmsd_csv] \
            rmsd_by_chain_csv [dict get $combined_sidecars rmsd_by_chain_csv] \
            rmsf_csv [dict get $combined_sidecars rmsf_csv] \
            summary_csv [dict get $combined_sidecars summary_csv] \
            combined_slice_count [llength [dict get $combined_result files]] \
            combined_csv [dict get $combined_sidecars csv] \
            combined_row_count [dict get $combined_sidecars row_count] \
            combined_mask_file $combined_mask \
            mask_clip_min $global_clip_min \
            mask_clip_max $global_clip_max \
            log_transform [dict get $opts log_transform] \
            inclusion_radius [dict get $opts inclusion_radius] \
            thresholds [numeric_list [dict get $opts thresholds] "lDDT thresholds"] \
            empty_neighbor_instability [dict get $opts empty_neighbor_instability]]
        emit_progress $opts [dict create \
            metric lddt_map \
            stage all_chain_complete \
            output_dir $combined_dir \
            base_output_dir $output_dir \
            chains $chains \
            chain_count [llength $chains] \
            combined_slice_count [dict get $result combined_slice_count] \
            message "Native all-chain lDDT analysis complete"]
        return $result
    }
}
