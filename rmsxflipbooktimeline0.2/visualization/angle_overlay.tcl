################################################################################
# Phi/psi region matrix and flipbook overlay helpers
################################################################################

namespace eval ::RMSXFlipbookTimeline::AngleOverlay {
    variable overlay_items {}

    proc clear {} {
        variable overlay_items
        foreach item $overlay_items {
            set molid [lindex $item 0]
            set graphics_id [lindex $item 1]
            if {[info commands molinfo] ne "" && [lsearch -exact [molinfo list] $molid] != -1} {
                catch {graphics $molid delete $graphics_id}
            }
        }
        set overlay_items {}
        return 1
    }

    proc ramachandran_categories {} {
        return [list \
            [dict create value alpha label "alpha-like" color "#d95f02" vmd_color 3] \
            [dict create value beta label "beta/PPII-like" color "#1b9e77" vmd_color 7] \
            [dict create value left label "left-handed" color "#7570b3" vmd_color 11] \
            [dict create value other label "other/outlier" color "#9ca3af" vmd_color 2] \
            [dict create value unknown label "unknown" color "#e5e7eb" vmd_color 6]]
    }

    proc category_vmd_color {value} {
        foreach category [ramachandran_categories] {
            if {[dict get $category value] eq $value} {
                return [dict get $category vmd_color]
            }
        }
        return 2
    }

    proc valid_angle {value} {
        if {![::RMSXFlipbookTimeline::Matrix::is_numeric $value]} {
            return 0
        }
        if {[catch {expr {double($value) != double($value)}} is_nan] || $is_nan} {
            return 0
        }
        return 1
    }

    proc normalize_angle {value} {
        set angle [expr {double($value)}]
        set wrapped [expr {fmod($angle + 180.0, 360.0)}]
        if {$wrapped < 0.0} {
            set wrapped [expr {$wrapped + 360.0}]
        }
        return [expr {$wrapped - 180.0}]
    }

    proc angle_between {value low high} {
        return [expr {$value >= $low && $value <= $high}]
    }

    proc classify {phi psi} {
        if {![valid_angle $phi] || ![valid_angle $psi]} {
            return unknown
        }
        set phi [normalize_angle $phi]
        set psi [normalize_angle $psi]

        if {[angle_between $phi -100.0 -30.0] && [angle_between $psi -90.0 20.0]} {
            return alpha
        }
        if {[angle_between $phi -180.0 -40.0] && ([angle_between $psi 80.0 180.0] || [angle_between $psi -180.0 -140.0])} {
            return beta
        }
        if {[angle_between $phi 30.0 100.0] && [angle_between $psi -20.0 120.0]} {
            return left
        }
        return other
    }

    proc row_text {row key} {
        if {[dict exists $row $key]} {
            return [string trim [dict get $row $key]]
        }
        return ""
    }

    proc row_chain {row} {
        set chain [row_text $row chain]
        if {$chain eq "" || $chain eq "X"} {
            set segid [row_text $row segid]
            if {$segid ne ""} {
                return $segid
            }
        }
        return $chain
    }

    proc same_context {left right} {
        set left_chain [row_chain $left]
        set right_chain [row_chain $right]
        if {$left_chain ne "" && $right_chain ne "" && $left_chain ne $right_chain} {
            return 0
        }
        set left_segid [row_text $left segid]
        set right_segid [row_text $right segid]
        if {$left_segid ne "" && $right_segid ne "" && $left_segid ne $right_segid} {
            return 0
        }
        return 1
    }

    proc transition_label {left right} {
        set chain [row_chain $left]
        if {$chain eq ""} {
            set chain [row_chain $right]
        }
        set left_resid [row_text $left resid]
        set right_resid [row_text $right resid]
        if {$left_resid eq ""} {
            set left_resid [row_text $left residue]
        }
        if {$right_resid eq ""} {
            set right_resid [row_text $right residue]
        }
        set label "$left_resid-$right_resid"
        if {$chain ne ""} {
            return "$chain:$label"
        }
        return $label
    }

    proc transition_selection {left right} {
        set atom_indices {}
        foreach row [list $left $right] {
            if {[dict exists $row atom_index] && [string trim [dict get $row atom_index]] ne ""} {
                lappend atom_indices [dict get $row atom_index]
            }
        }
        if {[llength $atom_indices] > 0} {
            return "same residue as (index [join $atom_indices { }])"
        }
        set selections {}
        foreach row [list $left $right] {
            set selection [::RMSXFlipbookTimeline::Matrix::row_selection $row]
            if {$selection ne ""} {
                lappend selections "($selection)"
            }
        }
        return [join $selections " or "]
    }

    proc transition_row {left right index} {
        set chain [row_chain $left]
        if {$chain eq ""} {
            set chain [row_chain $right]
        }
        set segid [row_text $left segid]
        if {$segid eq ""} {
            set segid [row_text $right segid]
        }
        set from_resid [row_text $left resid]
        set to_resid [row_text $right resid]
        set out [dict create \
            index $index \
            row_mode residue_transition \
            label [transition_label $left $right] \
            selection [transition_selection $left $right] \
            from_resid $from_resid \
            to_resid $to_resid \
            chain $chain \
            segid $segid]
        foreach {prefix row} [list from $left to $right] {
            foreach key {atom_index residue resid resname chain segid} {
                if {[dict exists $row $key]} {
                    dict set out ${prefix}_${key} [dict get $row $key]
                }
            }
        }
        return $out
    }

    proc build_dataset_from_phi_psi {phi_dataset psi_dataset args} {
        set phi_dataset [::RMSXFlipbookTimeline::Matrix::validate $phi_dataset]
        set psi_dataset [::RMSXFlipbookTimeline::Matrix::validate $psi_dataset]
        set defaults [dict create title "Phi/Psi Regions"]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set phi_rows [dict get $phi_dataset rows]
        set psi_rows [dict get $psi_dataset rows]
        set columns [dict get $phi_dataset columns]
        if {[llength $columns] != [llength [dict get $psi_dataset columns]]} {
            error "Phi and psi datasets have different column counts"
        }
        if {[llength $phi_rows] != [llength $psi_rows]} {
            error "Phi and psi datasets have different row counts"
        }

        set rows {}
        set row_pairs {}
        for {set row 0} {$row < [expr {[llength $phi_rows] - 1}]} {incr row} {
            set left [lindex $psi_rows $row]
            set right [lindex $phi_rows [expr {$row + 1}]]
            if {![same_context $left $right]} {
                continue
            }
            lappend rows [transition_row $left $right [llength $rows]]
            lappend row_pairs [list $row [expr {$row + 1}]]
        }
        if {[llength $rows] == 0} {
            error "No adjacent residue pairs were found for phi/psi region overlay"
        }

        set phi_values [dict get $phi_dataset values]
        set psi_values [dict get $psi_dataset values]
        set values {}
        for {set col 0} {$col < [llength $columns]} {incr col} {
            set phi_col [lindex $phi_values $col]
            set psi_col [lindex $psi_values $col]
            set col_values {}
            foreach pair $row_pairs {
                lassign $pair psi_row phi_row
                lappend col_values [classify [lindex $phi_col $phi_row] [lindex $psi_col $psi_row]]
            }
            lappend values $col_values
        }

        set provenance [dict create calculator phi_psi_regions]
        foreach source {molid column_mode} {
            if {[dict exists $phi_dataset $source]} {
                dict set provenance $source [dict get $phi_dataset $source]
            }
        }
        set source_molid ""
        if {[dict exists $phi_dataset molid]} {
            set source_molid [dict get $phi_dataset molid]
        }
        return [::RMSXFlipbookTimeline::Matrix::create \
            title [dict get $opts title] \
            value_label "phi/psi region" \
            unit "" \
            source_type ramachandran_regions \
            row_mode residue_transition \
            column_mode [dict get $phi_dataset column_mode] \
            value_kind categorical \
            categories [ramachandran_categories] \
            molid $source_molid \
            rows $rows \
            columns $columns \
            values $values \
            provenance $provenance \
            min 0 \
            max 1]
    }

    proc build_dataset {molid args} {
        set defaults [dict create \
            selection protein \
            first_frame 0 \
            last_frame -1 \
            column_mode slices \
            slicing_mode slices \
            slices "" \
            slice_size "" \
            slice_aggregation circular_mean \
            slice_representative middle]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set live_args [list \
            selection [dict get $opts selection] \
            first_frame [dict get $opts first_frame] \
            last_frame [dict get $opts last_frame]]
        set phi [::RMSXFlipbookTimeline::TimelineAnalysis::calculate $molid phi {*}$live_args]
        set psi [::RMSXFlipbookTimeline::TimelineAnalysis::calculate $molid psi {*}$live_args]
        set mode [string tolower [string trim [dict get $opts column_mode]]]
        if {$mode in {slice slices}} {
            set slices [dict get $opts slices]
            if {[string trim $slices] eq ""} {
                set molids [::RMSXFlipbookTimeline::state_get molids {}]
                if {[llength $molids] > 0} {
                    set slices [llength $molids]
                } else {
                    set slices [::RMSXFlipbookTimeline::state_get native_slices 9]
                }
            }
            set aggregate_args [list \
                slicing_mode [dict get $opts slicing_mode] \
                slices $slices \
                slice_size [dict get $opts slice_size] \
                aggregation [dict get $opts slice_aggregation] \
                representative [dict get $opts slice_representative]]
            set phi [::RMSXFlipbookTimeline::Matrix::aggregate_to_slices $phi {*}$aggregate_args]
            set psi [::RMSXFlipbookTimeline::Matrix::aggregate_to_slices $psi {*}$aggregate_args]
        }
        return [build_dataset_from_phi_psi $phi $psi]
    }

    proc selection_for_anchor {row prefix} {
        set index_key ${prefix}_atom_index
        if {[dict exists $row $index_key] && [string trim [dict get $row $index_key]] ne ""} {
            return "index [dict get $row $index_key]"
        }
        set resid_key ${prefix}_resid
        set resid ""
        if {[dict exists $row $resid_key]} {
            set resid [string trim [dict get $row $resid_key]]
        }
        if {$resid eq ""} {
            return ""
        }
        set clauses [list "resid $resid" "name CA"]
        set chain_key ${prefix}_chain
        set segid_key ${prefix}_segid
        set chain ""
        set segid ""
        if {[dict exists $row $chain_key]} {
            set chain [string trim [dict get $row $chain_key]]
        }
        if {[dict exists $row $segid_key]} {
            set segid [string trim [dict get $row $segid_key]]
        }
        if {$chain ne ""} {
            lappend clauses "(chain $chain or segid $chain)"
        } elseif {$segid ne ""} {
            lappend clauses "segid $segid"
        }
        return [join $clauses " and "]
    }

    proc anchor_coord {molid row prefix} {
        set selection [selection_for_anchor $row $prefix]
        if {$selection eq ""} {
            return ""
        }
        set sel [atomselect $molid $selection]
        try {
            if {[$sel num] == 0} {
                return ""
            }
            return [lindex [$sel get {x y z}] 0]
        } finally {
            catch {$sel delete}
        }
    }

    proc draw_dataset {dataset args} {
        variable overlay_items
        set defaults [dict create molids {} radius 0.35 resolution 12 clear_existing 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set molids [dict get $opts molids]
        if {[llength $molids] == 0} {
            set molids [::RMSXFlipbookTimeline::state_get molids {}]
        }
        if {[llength $molids] == 0} {
            error "Load a flipbook folder before applying the phi/psi overlay"
        }
        if {[info commands graphics] eq "" || [info commands atomselect] eq ""} {
            error "Phi/psi overlay drawing requires VMD graphics and atom selection commands"
        }
        if {[dict get $opts clear_existing]} {
            clear
        }
        set columns [dict get $dataset columns]
        set rows [dict get $dataset rows]
        set values [dict get $dataset values]
        set drawn 0
        set max_columns [expr {min([llength $columns], [llength $molids])}]
        for {set col 0} {$col < $max_columns} {incr col} {
            set slice_molid [lindex $molids $col]
            if {[info commands molinfo] ne "" && [lsearch -exact [molinfo list] $slice_molid] == -1} {
                continue
            }
            set col_values [lindex $values $col]
            for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
                set row [lindex $rows $row_index]
                set from_coord [anchor_coord $slice_molid $row from]
                set to_coord [anchor_coord $slice_molid $row to]
                if {$from_coord eq "" || $to_coord eq ""} {
                    continue
                }
                set category [lindex $col_values $row_index]
                catch {graphics $slice_molid color [category_vmd_color $category]}
                if {![catch {
                    graphics $slice_molid cylinder $from_coord $to_coord \
                        radius [dict get $opts radius] \
                        resolution [dict get $opts resolution] \
                        filled yes
                } graphics_id]} {
                    lappend overlay_items [list $slice_molid $graphics_id]
                    incr drawn
                }
            }
        }
        return [dict create drawn $drawn graphics [llength $overlay_items] molids [llength $molids]]
    }

    proc apply {molid args} {
        set defaults [dict create \
            selection protein \
            first_frame 0 \
            last_frame -1 \
            slicing_mode slices \
            slices "" \
            slice_size "" \
            slice_aggregation circular_mean \
            slice_representative middle \
            radius 0.35 \
            resolution 12 \
            draw 1 \
            show_matrix 1 \
            clear_existing 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set dataset [build_dataset $molid \
            selection [dict get $opts selection] \
            first_frame [dict get $opts first_frame] \
            last_frame [dict get $opts last_frame] \
            column_mode slices \
            slicing_mode [dict get $opts slicing_mode] \
            slices [dict get $opts slices] \
            slice_size [dict get $opts slice_size] \
            slice_aggregation [dict get $opts slice_aggregation] \
            slice_representative [dict get $opts slice_representative]]
        set draw_result [dict create drawn 0 graphics 0 molids 0]
        if {[dict get $opts draw]} {
            set draw_result [draw_dataset $dataset \
                radius [dict get $opts radius] \
                resolution [dict get $opts resolution] \
                clear_existing [dict get $opts clear_existing]]
        }
        if {[dict get $opts show_matrix]} {
            ::RMSXFlipbookTimeline::TimelinePlot::show $dataset
        }
        return [dict create dataset $dataset overlay $draw_result]
    }
}
