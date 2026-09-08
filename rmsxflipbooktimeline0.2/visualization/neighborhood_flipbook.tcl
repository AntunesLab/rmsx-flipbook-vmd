################################################################################
# Timeline Neighborhood Flipbook
################################################################################

namespace eval ::RMSXFlipbookTimeline::NeighborhoodFlipbook {
    variable snapshot_molids {}
    variable snapshot_files {}
    variable drawn_state {}
    variable active_flipbook_state {}
    variable modulation_env_state {}
    variable last_status {}
    variable last_request_key {}

    proc default_status {{message ""}} {
        return [dict create \
            enabled 0 \
            created 0 \
            molids {} \
            files {} \
            frames {} \
            center_frame "" \
            matched_columns 0 \
            message $message]
    }

    proc status {} {
        variable last_status
        if {$last_status eq {}} {
            set last_status [default_status "Timeline neighborhood is idle."]
        }
        return $last_status
    }

    proc loaded_molid {molid} {
        return [expr {$molid ne "" && [info commands molinfo] ne "" && [lsearch -exact [molinfo list] $molid] != -1}]
    }

    proc mol_drawn_state {molid} {
        if {![loaded_molid $molid]} {
            return 0
        }
        set drawn 1
        catch {set drawn [molinfo $molid get drawn]}
        return [expr {$drawn ? 1 : 0}]
    }

    proc restore_drawn_state {} {
        variable drawn_state
        if {$drawn_state eq {} || [info commands molinfo] eq ""} {
            set drawn_state {}
            return
        }
        dict for {molid drawn} $drawn_state {
            if {![loaded_molid $molid]} {
                continue
            }
            if {$drawn} {
                catch {mol on $molid}
            } else {
                catch {mol off $molid}
            }
        }
        set drawn_state {}
    }

    proc focus_scene {} {
        variable drawn_state
        set drawn_state {}
        if {[info commands molinfo] eq ""} {
            return
        }
        foreach molid [molinfo list] {
            dict set drawn_state $molid [mol_drawn_state $molid]
            catch {mol off $molid}
        }
    }

    proc capture_modulation_env {} {
        global env
        set out [dict create]
        foreach name {VMDMODULATERIBBON VMDMODULATENEWTUBE VMDMODULATENEWCARTOON} {
            if {[info exists env($name)]} {
                dict set out $name [list 1 $env($name)]
            } else {
                dict set out $name [list 0 ""]
            }
        }
        return $out
    }

    proc disable_geometry_modulation {} {
        global env
        foreach name {VMDMODULATERIBBON VMDMODULATENEWTUBE VMDMODULATENEWCARTOON} {
            catch {unset env($name)}
        }
    }

    proc restore_modulation_env {} {
        variable modulation_env_state
        global env
        if {$modulation_env_state eq {}} {
            return
        }
        dict for {name item} $modulation_env_state {
            lassign $item existed value
            if {$existed} {
                set env($name) $value
            } else {
                catch {unset env($name)}
            }
        }
        set modulation_env_state {}
    }

    proc focus_on_snapshots {molids} {
        if {[info commands molinfo] eq ""} {
            return
        }
        foreach molid [molinfo list] {
            if {[lsearch -exact $molids $molid] != -1} {
                catch {mol on $molid}
            } else {
                catch {mol off $molid}
            }
        }
        if {[llength $molids] > 0} {
            set center_index [expr {int(([llength $molids] - 1) / 2)}]
            set center_molid [lindex $molids $center_index]
            if {[loaded_molid $center_molid]} {
                catch {mol top $center_molid}
            }
        }
        catch {display update ui}
    }

    proc normalize_nonnegative_integer {value label} {
        set text [string trim $value]
        if {![string is integer -strict $text] || int($text) < 0} {
            error "$label must be a non-negative integer"
        }
        return [expr {int($text)}]
    }

    proc normalize_positive_integer {value label} {
        set text [string trim $value]
        if {![string is integer -strict $text] || int($text) < 1} {
            error "$label must be a positive integer"
        }
        return [expr {int($text)}]
    }

    proc capture_flipbook_state {} {
        set out [dict create]
        foreach key {
            molids slice_files spacing spacing_mode layout_offsets source_folder
            value_source value_file raw_min raw_max norm_min norm_max
            initial_view_matrices
        } {
            dict set out $key [::RMSXFlipbookTimeline::state_get $key ""]
        }
        return $out
    }

    proc activate_mini_flipbook {molids files spacing offsets {value_result {}}} {
        variable active_flipbook_state
        if {$active_flipbook_state eq {}} {
            set active_flipbook_state [capture_flipbook_state]
        }
        ::RMSXFlipbookTimeline::state_set molids $molids
        ::RMSXFlipbookTimeline::state_set slice_files $files
        ::RMSXFlipbookTimeline::state_set source_folder "Timeline matrix-colored mini-flipbook"
        ::RMSXFlipbookTimeline::state_set spacing $spacing
        ::RMSXFlipbookTimeline::state_set spacing_mode auto
        ::RMSXFlipbookTimeline::state_set layout_offsets $offsets
        ::RMSXFlipbookTimeline::state_set value_source "timeline_neighborhood"
        ::RMSXFlipbookTimeline::state_set value_file ""
        foreach key {raw_min raw_max norm_min norm_max} {
            if {$value_result ne {} && [dict exists $value_result $key]} {
                ::RMSXFlipbookTimeline::state_set $key [dict get $value_result $key]
            }
        }
        ::RMSXFlipbookTimeline::Style::store_initial_view_matrices $molids
        if {[::RMSXFlipbookTimeline::truthy [::RMSXFlipbookTimeline::state_get dashboard_auto_mouse_rotation 1]]} {
            catch {
                ::RMSXFlipbookTimeline::install_mouse_rotation \
                    coords \
                    [::RMSXFlipbookTimeline::state_get mouse_rotation_sensitivity 2.0]
            }
        } else {
            catch {mouse mode rotate}
        }
    }

    proc restore_flipbook_state {} {
        variable active_flipbook_state
        if {$active_flipbook_state eq {}} {
            return
        }
        dict for {key value} $active_flipbook_state {
            ::RMSXFlipbookTimeline::state_set $key $value
        }
        set active_flipbook_state {}
    }

    proc frame_plan {total_frames center_frame window step} {
        set total [normalize_positive_integer $total_frames "Total frames"]
        set center [expr {int($center_frame)}]
        set window [normalize_nonnegative_integer $window "Neighborhood window"]
        set step [normalize_positive_integer $step "Neighborhood step"]
        if {$center < 0} {
            set center 0
        }
        if {$center >= $total} {
            set center [expr {$total - 1}]
        }

        set frames {}
        for {set offset [expr {0 - $window}]} {$offset <= $window} {incr offset} {
            set frame [expr {$center + ($offset * $step)}]
            if {$frame < 0 || $frame >= $total} {
                continue
            }
            if {[lsearch -exact $frames $frame] == -1} {
                lappend frames $frame
            }
        }
        if {[llength $frames] == 0} {
            set frames [list $center]
        }
        return $frames
    }

    proc column_frame {column} {
        if {[dict exists $column frame]} {
            return [expr {int([dict get $column frame])}]
        }
        if {[dict exists $column representative_frame]} {
            return [expr {int([dict get $column representative_frame])}]
        }
        if {[dict exists $column index]} {
            return [expr {int([dict get $column index])}]
        }
        return 0
    }

    proc column_index_for_frame {dataset frame} {
        set columns [dict get $dataset columns]
        for {set i 0} {$i < [llength $columns]} {incr i} {
            set column [lindex $columns $i]
            if {[dict exists $column frame] && int([dict get $column frame]) == int($frame)} {
                return $i
            }
        }
        for {set i 0} {$i < [llength $columns]} {incr i} {
            set column [lindex $columns $i]
            if {[dict exists $column representative_frame] && int([dict get $column representative_frame]) == int($frame)} {
                return $i
            }
        }
        return -1
    }

    proc cell_color_for_frame {dataset row_index selected_column frame palette min_val max_val} {
        set column_index [column_index_for_frame $dataset $frame]
        set matched 1
        if {$column_index < 0} {
            set column_index $selected_column
            set matched 0
        }
        set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row_index $column_index]
        set color [::RMSXFlipbookTimeline::TimelinePlot::cell_color $value $min_val $max_val $palette $dataset]
        return [dict create \
            column $column_index \
            value $value \
            color $color \
            matched $matched]
    }

    proc hex_to_rgb01 {hex} {
        set clean [string trimleft [string trim $hex] "#"]
        if {[string length $clean] != 6} {
            return {0.5 0.5 0.5}
        }
        scan $clean "%2x%2x%2x" r g b
        return [list [expr {$r / 255.0}] [expr {$g / 255.0}] [expr {$b / 255.0}]]
    }

    proc nearest_color_id {hex} {
        lassign [hex_to_rgb01 $hex] r g b
        set palette {
            {0 0.00 0.00 1.00}
            {1 1.00 0.00 0.00}
            {2 0.50 0.50 0.50}
            {3 1.00 0.50 0.00}
            {4 1.00 1.00 0.00}
            {5 0.50 0.35 0.20}
            {6 0.60 0.60 0.60}
            {7 0.00 1.00 0.00}
            {8 1.00 1.00 1.00}
            {9 1.00 0.60 0.60}
            {10 0.00 1.00 1.00}
            {11 0.65 0.00 0.65}
            {12 0.50 1.00 0.00}
            {13 0.90 0.40 0.70}
            {14 0.50 0.30 0.00}
            {15 0.50 0.75 1.00}
            {16 0.00 0.00 0.00}
        }
        set best_id 2
        set best_dist 999.0
        foreach entry $palette {
            lassign $entry id pr pg pb
            set dist [expr {pow($r - $pr, 2) + pow($g - $pg, 2) + pow($b - $pb, 2)}]
            if {$dist < $best_dist} {
                set best_dist $dist
                set best_id $id
            }
        }
        return $best_id
    }

    proc temp_pdb_path {} {
        set pattern [file join [::RMSXFlipbookTimeline::state_get basedir [pwd]] "neighborhood_snapshot_XXXXXX.pdb"]
        if {[info exists ::env(TMPDIR)] && [string trim $::env(TMPDIR)] ne ""} {
            set pattern [file join $::env(TMPDIR) "rmsx_timeline_neighborhood_XXXXXX.pdb"]
        }
        set fp [file tempfile path $pattern]
        close $fp
        return $path
    }

    proc row_identity_selection {row fallback} {
        if {![dict exists $row resid]} {
            return $fallback
        }
        set resid [string trim [dict get $row resid]]
        if {$resid eq ""} {
            return $fallback
        }
        set clauses [list "resid $resid"]
        set chain [expr {[dict exists $row chain] ? [string trim [dict get $row chain]] : ""}]
        set segid [expr {[dict exists $row segid] ? [string trim [dict get $row segid]] : ""}]
        if {$chain ne "" && $segid ne "" && $chain ne $segid} {
            lappend clauses "(chain $chain or segid $chain or segid $segid)"
        } elseif {$chain ne ""} {
            lappend clauses "(chain $chain or segid $chain)"
        } elseif {$segid ne ""} {
            lappend clauses "segid $segid"
        }
        return [join $clauses " and "]
    }

    proc selection_count {molid frame selection} {
        if {[string trim $selection] eq ""} {
            return 0
        }
        if {[catch {
            set sel [atomselect $molid $selection frame $frame]
            try {
                set count [$sel num]
            } finally {
                catch {$sel delete}
            }
        }]} {
            return 0
        }
        return $count
    }

    proc snapshot_selection {dataset source_molid frame selected_row_index} {
        set key_indices {}
        set row_selections {}
        if {$dataset ne {} && [dict exists $dataset rows]} {
            foreach row [dict get $dataset rows] {
                if {[dict exists $row atom_index]} {
                    lappend key_indices [dict get $row atom_index]
                    continue
                }
                set row_selection [row_identity_selection $row [::RMSXFlipbookTimeline::Matrix::row_selection $row]]
                if {[string trim $row_selection] ne "" && [selection_count $source_molid $frame $row_selection] > 0} {
                    lappend row_selections "($row_selection)"
                }
            }
        }
        set selections {}
        if {[llength $key_indices] > 0} {
            lappend selections "same residue as (index [join $key_indices { }])"
        }
        if {[llength $row_selections] > 0} {
            lappend selections [join $row_selections " or "]
        }

        if {$dataset ne {} && [dict exists $dataset rows]} {
            set rows [dict get $dataset rows]
            if {$selected_row_index >= 0 && $selected_row_index < [llength $rows]} {
                set selected_row [lindex $rows $selected_row_index]
                set base [row_identity_selection $selected_row [::RMSXFlipbookTimeline::Matrix::row_selection $selected_row]]
                set sidechain "($base) and not backbone and not hydrogen"
                if {[selection_count $source_molid $frame $sidechain] > 0} {
                    lappend selections $sidechain
                } elseif {[selection_count $source_molid $frame $base] > 0} {
                    lappend selections $base
                }
            }
        }

        if {[llength $selections] > 0} {
            set selection [join $selections " or "]
            if {[selection_count $source_molid $frame $selection] > 0} {
                return $selection
            }
        }
        set key_selection [::RMSXFlipbookTimeline::TimelineAnalysis::key_atom_selection all]
        if {[selection_count $source_molid $frame $key_selection] > 0} {
            return $key_selection
        }
        return all
    }

    proc write_snapshot_pdb {source_molid frame dataset selected_row_index} {
        set path [temp_pdb_path]
        set selection [snapshot_selection $dataset $source_molid $frame $selected_row_index]
        set sel [atomselect $source_molid $selection frame $frame]
        try {
            if {[$sel num] <= 0} {
                error "Source molecule has no atoms at frame $frame"
            }
            $sel writepdb $path
        } finally {
            catch {$sel delete}
        }
        return $path
    }

    proc safe_selection_has_atoms {molid selection} {
        if {[string trim $selection] eq ""} {
            return 0
        }
        if {[catch {
            set sel [atomselect $molid $selection]
            try {
                set count [$sel num]
            } finally {
                catch {$sel delete}
            }
        }]} {
            return 0
        }
        return [expr {$count > 0}]
    }

    proc row_selection_has_atoms {molid selection} {
        return [safe_selection_has_atoms $molid $selection]
    }

    proc set_atom_field_value {molid selection fields value} {
        if {[string trim $selection] eq ""} {
            return 0
        }
        if {[catch {
            set sel [atomselect $molid $selection]
            try {
                set count [$sel num]
                if {$count <= 0} {
                    return 0
                }
                set values [lrepeat $count $value]
                foreach field $fields {
                    catch {$sel set $field $values}
                }
            } finally {
                catch {$sel delete}
            }
        }]} {
            return 0
        }
        return 1
    }

    proc initialize_user_fields {molid norm raw} {
        set user_scale [::RMSXFlipbookTimeline::state_get user_scale 1.0]
        set user_offset [::RMSXFlipbookTimeline::state_get user_offset 2.0]
        set thickness [::RMSXFlipbookTimeline::Values::clamp [expr {$user_scale * double($norm) + double($user_offset)}] 0.0 10.0]
        set_atom_field_value $molid all {user} $thickness
        set_atom_field_value $molid all {user2} $norm
        set_atom_field_value $molid all {user3 user4} $raw
        return 1
    }

    proc normalize_matrix_window {dataset column_indices {scale_min ""} {scale_max ""}} {
        set raw_values {}
        set raw_columns {}
        set row_count [llength [dict get $dataset rows]]
        foreach column_index $column_indices {
            set raw_column {}
            for {set row_index 0} {$row_index < $row_count} {incr row_index} {
                set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row_index $column_index]
                if {[::RMSXFlipbookTimeline::Matrix::is_numeric $value]} {
                    set numeric [expr {double($value)}]
                    lappend raw_column $numeric
                    lappend raw_values $numeric
                } else {
                    lappend raw_column ""
                }
            }
            lappend raw_columns $raw_column
        }
        if {[llength $raw_values] == 0} {
            return {}
        }

        set use_scale [expr { \
            [::RMSXFlipbookTimeline::Matrix::is_numeric $scale_min] \
            && [::RMSXFlipbookTimeline::Matrix::is_numeric $scale_max] \
            && double($scale_max) > double($scale_min)}]
        if {$use_scale} {
            set raw_min [expr {double($scale_min)}]
            set raw_max [expr {double($scale_max)}]
            set range [expr {$raw_max - $raw_min}]
            set normalized_values {}
            foreach raw $raw_values {
                lappend normalized_values [::RMSXFlipbookTimeline::Values::clamp [expr {((double($raw) - $raw_min) / $range) * 10.0}] 0.0 10.0]
            }
            set result [dict create \
                raw_min $raw_min \
                raw_max $raw_max \
                norm_min [::RMSXFlipbookTimeline::Values::list_min $normalized_values] \
                norm_max [::RMSXFlipbookTimeline::Values::list_max $normalized_values] \
                values $normalized_values]
        } else {
            set result [::RMSXFlipbookTimeline::Values::normalize_values $raw_values]
            set normalized_values [dict get $result values]
        }
        set cursor 0
        set normalized_columns {}
        foreach raw_column $raw_columns {
            set normalized_column {}
            foreach raw $raw_column {
                if {$raw eq ""} {
                    lappend normalized_column ""
                } else {
                    lappend normalized_column [lindex $normalized_values $cursor]
                    incr cursor
                }
            }
            lappend normalized_columns $normalized_column
        }
        dict set result columns $normalized_columns
        dict set result raw_columns $raw_columns
        dict set result record_count [llength $raw_values]
        return $result
    }

    proc assign_matrix_values {dataset molid column_index norm_column raw_column} {
        initialize_user_fields $molid 0.0 0.0
        set rows [dict get $dataset rows]
        set user_scale [::RMSXFlipbookTimeline::state_get user_scale 1.0]
        set user_offset [::RMSXFlipbookTimeline::state_get user_offset 2.0]
        set assigned 0
        for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            set norm [lindex $norm_column $row_index]
            set raw [lindex $raw_column $row_index]
            if {$norm eq "" || $raw eq ""} {
                continue
            }
            set row [lindex $rows $row_index]
            set selection [row_identity_selection $row [::RMSXFlipbookTimeline::Matrix::row_selection $row]]
            set thickness [::RMSXFlipbookTimeline::Values::clamp [expr {$user_scale * double($norm) + double($user_offset)}] 0.0 10.0]
            set ok 0
            if {[set_atom_field_value $molid $selection {user} $thickness]} {
                set ok 1
            }
            set_atom_field_value $molid $selection {user2} $norm
            set_atom_field_value $molid $selection {user3 user4} $raw
            if {$ok} {
                incr assigned
            }
        }
        return $assigned
    }

    proc matrix_column_for_frame {dataset selected_column frame} {
        set column_index [column_index_for_frame $dataset $frame]
        set matched 1
        if {$column_index < 0} {
            set column_index $selected_column
            set matched 0
        }
        return [dict create column $column_index matched $matched]
    }

    proc palette_for_dataset {dataset requested_palette} {
        set kind [::RMSXFlipbookTimeline::TimelinePlot::dataset_value_kind $dataset]
        if {$kind eq "diverging" || $kind eq "correlation"} {
            return BWR
        }
        return $requested_palette
    }

    proc compact_auto_spacing {molids} {
        set spacing [::RMSXFlipbookTimeline::Layout::auto_spacing $molids]
        set scale [::RMSXFlipbookTimeline::state_get timeline_neighborhood_spacing_scale 0.72]
        if {![string is double -strict $scale] || double($scale) <= 0.0} {
            set scale 0.72
        }
        set compact [expr {$spacing * double($scale)}]
        if {$compact < 8.0} {
            set compact 8.0
        }
        return $compact
    }

    proc apply_continuous_matrix_style {molids dataset palette min_val max_val} {
        if {[llength $molids] == 0} {
            return
        }
        return [::RMSXFlipbookTimeline::Style::apply \
            $molids \
            rep [::RMSXFlipbookTimeline::state_get rep NewTube] \
            thick [::RMSXFlipbookTimeline::state_get thick 0.30] \
            res [::RMSXFlipbookTimeline::state_get res 32] \
            aspect [::RMSXFlipbookTimeline::state_get aspect 1.00] \
            spline [::RMSXFlipbookTimeline::state_get spline 0] \
            color_method User2 \
            color_min $min_val \
            color_max $max_val \
            palette [palette_for_dataset $dataset $palette]]
    }

    proc category_selection_for_column {dataset column_index category_value} {
        set rows [dict get $dataset rows]
        set selections {}
        for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row_index $column_index]
            if {![::RMSXFlipbookTimeline::TimelinePlot::category_matches $category_value $value]} {
                continue
            }
            set row [lindex $rows $row_index]
            set selection [row_identity_selection $row [::RMSXFlipbookTimeline::Matrix::row_selection $row]]
            if {[string trim $selection] ne ""} {
                lappend selections "($selection)"
            }
        }
        return [join $selections " or "]
    }

    proc add_base_context_rep {molid} {
        set selection [chain_context_selection $molid]
        mol representation {*}[::RMSXFlipbookTimeline::Style::representation_args \
            NewTube \
            [neighborhood_tube_thickness base] \
            [::RMSXFlipbookTimeline::state_get res 32] \
            [::RMSXFlipbookTimeline::state_get aspect 1.00] \
            [::RMSXFlipbookTimeline::state_get spline 0]]
        mol selection $selection
        mol color ColorID 6
        mol material Opaque
        mol addrep $molid
    }

    proc neighborhood_tube_thickness {{role category}} {
        set base [::RMSXFlipbookTimeline::state_get thick 0.30]
        if {![string is double -strict $base]} {
            set base 0.30
        }
        set base [expr {double($base)}]
        switch -- $role {
            base {
                return [expr {max($base, 0.36)}]
            }
            highlight {
                return [expr {max($base + 0.08, 0.44)}]
            }
            default {
                return [expr {max($base + 0.12, 0.48)}]
            }
        }
    }

    proc selection_with_atoms {molid candidates} {
        foreach selection $candidates {
            if {[safe_selection_has_atoms $molid $selection]} {
                return $selection
            }
        }
        return all
    }

    proc chain_context_selection {molid} {
        return [selection_with_atoms $molid [list \
            {(protein or nucleic) and backbone} \
            {backbone} \
            {name CA or name P} \
            {all}]]
    }

    proc matrix_row_display_selection {molid selection} {
        set clean [string trim $selection]
        if {$clean eq ""} {
            return ""
        }
        return [selection_with_atoms $molid [list \
            "(($clean) and ((protein or nucleic) and backbone))" \
            "(($clean) and backbone)" \
            "(($clean) and (name CA or name P))" \
            $clean]]
    }

    proc add_category_rep {molid selection color_id} {
        set display_selection [matrix_row_display_selection $molid $selection]
        if {$display_selection eq "" || ![safe_selection_has_atoms $molid $display_selection]} {
            return 0
        }
        mol representation {*}[::RMSXFlipbookTimeline::Style::representation_args \
            NewTube \
            [neighborhood_tube_thickness category] \
            [::RMSXFlipbookTimeline::state_get res 32] \
            [::RMSXFlipbookTimeline::state_get aspect 1.00] \
            [::RMSXFlipbookTimeline::state_get spline 0]]
        mol selection $display_selection
        mol color ColorID $color_id
        mol material Opaque
        mol addrep $molid
        return 1
    }

    proc apply_categorical_matrix_style {dataset molids column_indices} {
        set categories [::RMSXFlipbookTimeline::TimelinePlot::dataset_categories $dataset]
        set colored 0
        foreach molid $molids column_index $column_indices {
            ::RMSXFlipbookTimeline::Style::delete_all_reps $molid
            add_base_context_rep $molid
            foreach category $categories {
                set selection [category_selection_for_column $dataset $column_index [dict get $category value]]
                if {$selection eq ""} {
                    continue
                }
                if {[add_category_rep $molid $selection [nearest_color_id [dict get $category color]]]} {
                    incr colored
                }
            }
        }
        return $colored
    }

    proc apply_snapshot_highlight {molid selection color_id is_center} {
        if {![loaded_molid $molid]} {
            return 0
        }
        if {$selection eq "" || ![row_selection_has_atoms $molid $selection]} {
            return 0
        }
        set sidechain "($selection) and not backbone and not hydrogen"
        if {[row_selection_has_atoms $molid $sidechain]} {
            if {$is_center} {
                mol representation Licorice 0.42 14 14
            } else {
                mol representation Licorice 0.32 12 12
            }
            mol selection $sidechain
            mol color ColorID $color_id
            mol material Opaque
            mol addrep $molid
            return 1
        }

        if {$is_center} {
            mol representation VDW 1.05 16
        } else {
            mol representation VDW 0.82 12
        }
        mol selection $selection
        mol color ColorID $color_id
        mol material Opaque
        mol addrep $molid
        return 1
    }

    proc clear {} {
        variable snapshot_molids
        variable snapshot_files
        variable last_status
        variable last_request_key
        restore_drawn_state
        if {[info commands molinfo] ne ""} {
            foreach molid $snapshot_molids {
                if {[loaded_molid $molid]} {
                    catch {mol delete $molid}
                }
            }
        }
        foreach path $snapshot_files {
            if {[file exists $path]} {
                catch {file delete -force $path}
            }
        }
        set snapshot_molids {}
        set snapshot_files {}
        set last_request_key {}
        restore_flipbook_state
        restore_modulation_env
        set last_status [default_status "Timeline neighborhood cleared."]
        return $last_status
    }

    proc snapshot_molecules_loaded {} {
        variable snapshot_molids
        if {[llength $snapshot_molids] == 0} {
            return 0
        }
        foreach molid $snapshot_molids {
            if {![loaded_molid $molid]} {
                return 0
            }
        }
        return 1
    }

    proc source_molid_for_record {dataset record} {
        if {![dict exists $record column]} {
            return ""
        }
        set columns [dict get $dataset columns]
        set col [expr {int([dict get $record column])}]
        if {$col < 0 || $col >= [llength $columns]} {
            return ""
        }
        set column [lindex $columns $col]
        return [::RMSXFlipbookTimeline::Matrix::target_molid_for_column $dataset $column]
    }

    proc with_quiet_console {script} {
        set previous [::RMSXFlipbookTimeline::state_get quiet_console 0]
        ::RMSXFlipbookTimeline::state_set quiet_console 1
        try {
            return [uplevel 1 $script]
        } finally {
            ::RMSXFlipbookTimeline::state_set quiet_console $previous
        }
    }

    proc show_for_selection {dataset record args} {
        variable snapshot_molids
        variable snapshot_files
        variable modulation_env_state
        variable last_status
        variable last_request_key

        set defaults [dict create \
            window [::RMSXFlipbookTimeline::state_get timeline_neighborhood_window 4] \
            step [::RMSXFlipbookTimeline::state_get timeline_neighborhood_step 1] \
            palette [::RMSXFlipbookTimeline::state_get palette viridis] \
            color_mode [::RMSXFlipbookTimeline::state_get timeline_neighborhood_color_mode matrix] \
            scale_min "" \
            scale_max ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        if {$dataset eq {} || $record eq {} || ![dict exists $record row] || ![dict exists $record column]} {
            set last_status [default_status "Timeline neighborhood needs a selected matrix cell."]
            return $last_status
        }
        if {[info commands molinfo] eq "" || [info commands atomselect] eq ""} {
            set last_status [default_status "Timeline neighborhood needs a live VMD trajectory molecule."]
            return $last_status
        }

        set row_index [expr {int([dict get $record row])}]
        set col_index [expr {int([dict get $record column])}]
        set rows [dict get $dataset rows]
        set columns [dict get $dataset columns]
        if {$row_index < 0 || $row_index >= [llength $rows] || $col_index < 0 || $col_index >= [llength $columns]} {
            set last_status [default_status "Timeline neighborhood selection is outside the dataset."]
            return $last_status
        }

        set source_molid [source_molid_for_record $dataset $record]
        if {![loaded_molid $source_molid]} {
            set last_status [default_status "Timeline neighborhood needs a loaded trajectory-backed dataset."]
            return $last_status
        }
        set total_frames [molinfo $source_molid get numframes]
        if {$total_frames <= 1} {
            set last_status [default_status "Timeline neighborhood needs a source molecule with multiple frames."]
            return $last_status
        }

        set row [lindex $rows $row_index]
        set row_selection [::RMSXFlipbookTimeline::Matrix::row_selection $row]
        if {[string trim $row_selection] eq ""} {
            set last_status [default_status "Selected Timeline row has no usable VMD selection."]
            return $last_status
        }

        set center_column [lindex $columns $col_index]
        set center_frame [column_frame $center_column]
        set window [normalize_nonnegative_integer [dict get $opts window] "Neighborhood window"]
        set step [normalize_positive_integer [dict get $opts step] "Neighborhood step"]
        set frames [frame_plan $total_frames $center_frame $window $step]
        set row_highlight_selection [row_identity_selection $row $row_selection]

        set scale_min [string trim [dict get $opts scale_min]]
        set scale_max [string trim [dict get $opts scale_max]]
        if {$scale_min eq "" || $scale_max eq ""} {
            set scale_min [dict get $dataset min]
            set scale_max [dict get $dataset max]
        }
        if {![::RMSXFlipbookTimeline::Matrix::is_numeric $scale_min] || ![::RMSXFlipbookTimeline::Matrix::is_numeric $scale_max]} {
            set scale_min 0.0
            set scale_max 1.0
        }
        if {$scale_max <= $scale_min} {
            set scale_max [expr {$scale_min + 1.0}]
        }
        set palette [dict get $opts palette]
        set color_mode [string tolower [string trim [dict get $opts color_mode]]]
        if {$color_mode eq ""} {
            set color_mode matrix
        }
        set request_key [list \
            source_molid $source_molid \
            row $row_index \
            column $col_index \
            center_frame $center_frame \
            frames $frames \
            palette $palette \
            color_mode $color_mode \
            scale_min $scale_min \
            scale_max $scale_max]
        if {$request_key eq $last_request_key && [snapshot_molecules_loaded]} {
            return $last_status
        }
        set categories [::RMSXFlipbookTimeline::TimelinePlot::dataset_categories $dataset]
        set categorical [expr {[llength $categories] > 0}]
        set frame_columns {}
        set matched_columns 0
        foreach frame $frames {
            set column_info [matrix_column_for_frame $dataset $col_index $frame]
            lappend frame_columns [dict get $column_info column]
            if {[dict get $column_info matched]} {
                incr matched_columns
            }
        }
        set value_result {}
        if {!$categorical} {
            set value_result [normalize_matrix_window $dataset $frame_columns $scale_min $scale_max]
            if {$value_result eq {}} {
                set last_status [default_status "Timeline neighborhood needs numeric matrix values for Flipbook coloring."]
                return $last_status
            }
        }

        clear
        focus_scene
        set modulation_env_state [capture_modulation_env]
        set snapshot [::RMSXFlipbookTimeline::TimelineAnalysis::snapshot_vmd_state]
        set created_molids {}
        set created_files {}
        set colored_rows 0
        set colored_category_reps 0
        set highlighted 0
        if {[catch {
            set norm_columns {}
            set raw_columns {}
            if {!$categorical} {
                set norm_columns [dict get $value_result columns]
                set raw_columns [dict get $value_result raw_columns]
            }
            set frame_i 0
            foreach frame $frames {
                set frame_column [lindex $frame_columns $frame_i]
                set path [write_snapshot_pdb $source_molid $frame $dataset $row_index]
                lappend created_files $path
                mol new $path type pdb waitfor all
                set snapshot_molid [molinfo top]
                catch {mol rename $snapshot_molid [format "Timeline frame %s" $frame]}
                if {!$categorical} {
                    incr colored_rows [assign_matrix_values \
                        $dataset \
                        $snapshot_molid \
                        $frame_column \
                        [lindex $norm_columns $frame_i] \
                        [lindex $raw_columns $frame_i]]
                }
                lappend created_molids $snapshot_molid
                incr frame_i
            }
            with_quiet_console {
                if {$categorical} {
                    disable_geometry_modulation
                    set colored_category_reps [apply_categorical_matrix_style $dataset $created_molids $frame_columns]
                } else {
                    apply_continuous_matrix_style $created_molids $dataset $palette 0.0 10.0
                }
            }
            foreach snapshot_molid $created_molids frame $frames {
                if {[apply_snapshot_highlight $snapshot_molid $row_highlight_selection 4 [expr {$frame == $center_frame}]]} {
                    incr highlighted
                }
            }
            set spacing 8.0
            set offsets {}
            if {[llength $created_molids] > 0 && [info commands ::RMSXFlipbookTimeline::Layout::set_grid_spacing] ne ""} {
                set spacing [compact_auto_spacing $created_molids]
                set offsets [with_quiet_console {
                    ::RMSXFlipbookTimeline::Layout::set_grid_spacing $created_molids $spacing
                }]
            }
            with_quiet_console {
                activate_mini_flipbook $created_molids $created_files $spacing $offsets $value_result
            }
        } err opts_dict]} {
            set snapshot_molids $created_molids
            set snapshot_files $created_files
            catch {clear}
            ::RMSXFlipbookTimeline::TimelineAnalysis::restore_vmd_state $snapshot
            set last_status [default_status "Timeline neighborhood failed: $err"]
            return $last_status
        }
        ::RMSXFlipbookTimeline::TimelineAnalysis::restore_vmd_state $snapshot

        set snapshot_molids $created_molids
        set snapshot_files $created_files
        focus_on_snapshots $snapshot_molids
        set mode_note ""
        if {$matched_columns < [llength $frames]} {
            set mode_note "; using the selected/representative matrix column where exact frame columns are unavailable"
        }
        set color_note "normal Flipbook User/User2 scaling"
        if {$categorical} {
            set color_note "categorical matrix colors"
        }
        set full_atoms 0
        if {[llength $created_molids] > 0 && [loaded_molid [lindex $created_molids 0]]} {
            set full_atoms [molinfo [lindex $created_molids 0] get numatoms]
        }
        set message [format "%d-frame Timeline mini-Flipbook: frames %s; full residue structures for %d matrix rows (%d atoms), colored by %s%s." [llength $frames] [join $frames ", "] [llength $rows] $full_atoms $color_note $mode_note]
        if {$highlighted == 0} {
            append message " Row selection did not match atoms in the snapshot PDBs."
        }
        set last_status [dict create \
            enabled 1 \
            created [llength $created_molids] \
            molids $created_molids \
            files $created_files \
            frames $frames \
            center_frame $center_frame \
            row $row_index \
            column $col_index \
            source_molid $source_molid \
            matched_columns $matched_columns \
            frame_columns $frame_columns \
            highlighted $highlighted \
            color_mode $color_mode \
            color_style [expr {$categorical ? "categorical" : "continuous"}] \
            colored_rows $colored_rows \
            colored_category_reps $colored_category_reps \
            context_atoms $full_atoms \
            message $message]
        set last_request_key $request_key
        return $last_status
    }

    proc show_current {args} {
        set dataset [::RMSXFlipbookTimeline::TimelinePlot::current_dataset]
        set record [::RMSXFlipbookTimeline::TimelinePlot::selected_record]
        set defaults [dict create row "" column ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        if {[string trim [dict get $opts row]] ne "" && [string trim [dict get $opts column]] ne ""} {
            set record [dict create \
                row [expr {int([dict get $opts row])}] \
                column [expr {int([dict get $opts column])}]]
            dict unset opts row
            dict unset opts column
            return [show_for_selection $dataset $record {*}$opts]
        }
        dict unset opts row
        dict unset opts column
        return [show_for_selection $dataset $record {*}$opts]
    }
}
