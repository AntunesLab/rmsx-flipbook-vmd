################################################################################
# VMD-live Timeline analysis backend
################################################################################

namespace eval ::RMSXFlipbookTimeline::TimelineAnalysis {
    proc snapshot_vmd_state {} {
        if {[info commands molinfo] eq ""} {
            return {}
        }
        set top ""
        catch {set top [molinfo top]}
        set frames [dict create]
        foreach molid [molinfo list] {
            if {![catch {molinfo $molid get frame} frame]} {
                dict set frames $molid $frame
            }
        }
        return [dict create top $top frames $frames]
    }

    proc restore_vmd_state {snapshot} {
        if {$snapshot eq {} || [info commands molinfo] eq ""} {
            return
        }
        if {[dict exists $snapshot frames]} {
            dict for {molid frame} [dict get $snapshot frames] {
                if {[lsearch -exact [molinfo list] $molid] != -1} {
                    catch {molinfo $molid set frame $frame}
                }
            }
        }
        if {[dict exists $snapshot top]} {
            set top [dict get $snapshot top]
            if {$top ne "" && [lsearch -exact [molinfo list] $top] != -1} {
                catch {mol top $top}
            }
        }
    }

    proc key_atom_selection {selection} {
        set base [string trim $selection]
        if {$base eq ""} {
            set base all
        }
        return "($base) and ((protein and name CA) or (nucleic and (name \"C3'\" or name \"C3*\")) or name BAS)"
    }

    proc frame_range {molid first_frame last_frame} {
        if {[lsearch -exact [molinfo list] $molid] == -1} {
            error "Molecule is not loaded: $molid"
        }
        set total [molinfo $molid get numframes]
        if {$total <= 0} {
            error "Molecule $molid has no frames"
        }
        set first [expr {int($first_frame)}]
        set last [expr {int($last_frame)}]
        if {$last < 0} {
            set last [expr {$total - 1}]
        }
        if {$first < 0 || $first >= $total} {
            error "First frame $first is outside molecule frame range 0-[expr {$total - 1}]"
        }
        if {$last < $first || $last >= $total} {
            error "Last frame $last is outside requested/available range $first-[expr {$total - 1}]"
        }
        return [list $first $last]
    }

    proc frame_columns {molid first last} {
        set columns {}
        for {set frame $first} {$frame <= $last} {incr frame} {
            lappend columns [dict create \
                index [llength $columns] \
                frame $frame \
                label $frame \
                target_type frame \
                molid $molid]
        }
        return $columns
    }

    proc residue_rows {molid selection frame} {
        set sel [atomselect $molid [key_atom_selection $selection] frame $frame]
        try {
            if {[$sel num] == 0} {
                error "Selection returned no Timeline key atoms: $selection"
            }
            set rows {}
            foreach atom [$sel get {index residue resid resname chain segid}] {
                lassign $atom atom_index residue resid resname chain segid
                set chain [string trim $chain]
                set segid [string trim $segid]
                set display_chain $chain
                if {$display_chain eq "" || $display_chain eq "X"} {
                    set display_chain $segid
                }
                set label [string trim "$display_chain:$resid $resname" ":"]
                lappend rows [dict create \
                    index [llength $rows] \
                    atom_index $atom_index \
                    residue $residue \
                    resid $resid \
                    resname $resname \
                    chain $display_chain \
                    segid $segid \
                    label $label \
                    selection "same residue as index $atom_index" \
                    row_mode residue]
            }
            return $rows
        } finally {
            catch {$sel delete}
        }
    }

    proc make_dataset {molid title value_label unit rows columns values row_mode} {
        return [::RMSXFlipbookTimeline::Matrix::create \
            title $title \
            value_label $value_label \
            unit $unit \
            source_type live_trajectory \
            row_mode $row_mode \
            column_mode frame \
            molid $molid \
            rows $rows \
            columns $columns \
            values $values \
            provenance [dict create calculator $value_label molid $molid]]
    }

    proc secondary_structure_categories {} {
        return [list \
            [dict create value H label "H alpha helix" color "#d95f02"] \
            [dict create value G label "G 3-10 helix" color "#e7298a"] \
            [dict create value I label "I pi helix" color "#e31a1c"] \
            [dict create value E label "E beta strand" color "#1b9e77"] \
            [dict create value B label "B beta bridge" color "#a6d854"] \
            [dict create value T label "T turn" color "#7570b3"] \
            [dict create value C label "C coil" color "#f0f0f0"]]
    }

    proc binary_categories {{present_label present} {absent_label absent}} {
        return [list \
            [dict create value 0 label "0 $absent_label" color "#f3f4f6"] \
            [dict create value 1 label "1 $present_label" color "#2563eb"]]
    }

    proc scalar_mean {values} {
        set total 0.0
        set count 0
        foreach value $values {
            if {[::RMSXFlipbookTimeline::Matrix::is_numeric $value]} {
                set total [expr {$total + double($value)}]
                incr count
            }
        }
        if {$count == 0} {
            return 0.0
        }
        return [expr {$total / double($count)}]
    }

    proc as_bool {value} {
        set clean [string tolower [string trim $value]]
        return [expr {$clean in {1 true yes y on}}]
    }

    proc selection_list {value label} {
        if {[catch {set count [llength $value]}]} {
            error "$label must be a Tcl list of VMD selection strings"
        }
        if {$count == 0} {
            error "$label must contain at least one VMD selection string"
        }
        return $value
    }

    proc require_mdff_cc {} {
        if {[catch {package require mdff} err]} {
            error "Timeline cross-correlation requires VMD's mdff package: $err"
        }
        if {[llength [info commands mdffi]] != 0} {
            return mdffi
        }
        if {[llength [info commands mdff]] != 0} {
            return mdff
        }
        error "Timeline cross-correlation requires mdffi or mdff ccc from VMD's mdff package"
    }

    proc resolve_cc_volume {molid opts} {
        set vol_id [string trim [dict get $opts cc_vol_id]]
        set num_volumes [molinfo $molid get numvolumedata]
        if {$vol_id ne "" && [string tolower $vol_id] ne "auto"} {
            set vol_id [expr {int($vol_id)}]
            if {$num_volumes <= 0} {
                error "Cross-correlation volume id $vol_id was requested, but molecule $molid has no volumetric data"
            }
            if {$vol_id < 0 || $vol_id >= $num_volumes} {
                error "Cross-correlation volume id $vol_id is outside available volume range 0-[expr {$num_volumes - 1}]"
            }
            return $vol_id
        }

        set map_file [string trim [dict get $opts cc_map_file]]
        if {$map_file ne ""} {
            if {![file exists $map_file]} {
                error "Cross-correlation map file does not exist: $map_file"
            }
            catch {mol top $molid}
            if {[catch {mol addfile $map_file} err]} {
                error "Could not load cross-correlation map file '$map_file': $err"
            }
            set num_volumes [molinfo $molid get numvolumedata]
            if {$num_volumes <= 0} {
                error "Cross-correlation map file loaded no volumetric data: $map_file"
            }
            return [expr {$num_volumes - 1}]
        }

        if {$num_volumes > 0} {
            return [expr {$num_volumes - 1}]
        }
        error "Timeline cross-correlation needs cc_map_file or a molecule with preloaded volumetric data"
    }

    proc resolve_cc_map_file {opts} {
        set map_file [string trim [dict get $opts cc_map_file]]
        if {$map_file eq ""} {
            error "Timeline cross-correlation needs cc_map_file when mdffi is unavailable"
        }
        if {![file exists $map_file]} {
            error "Cross-correlation map file does not exist: $map_file"
        }
        return $map_file
    }

    proc cc_value {backend molid target sel opts} {
        set map_res [expr {double([dict get $opts cc_map_res])}]
        if {$backend eq "mdffi"} {
            set cmd [list mdffi cc $sel -res $map_res -mol $molid -vol $target]
            set threshold_option -thresholddensity
        } else {
            set cmd [list mdff ccc $sel -i $target -res $map_res]
            set threshold_option -threshold
        }
        if {[as_bool [dict get $opts cc_use_threshold]]} {
            set threshold [string trim [dict get $opts cc_threshold]]
            if {$threshold eq ""} {
                error "Cross-correlation threshold is enabled but cc_threshold is empty"
            }
            lappend cmd $threshold_option [expr {double($threshold)}]
        }
        if {[as_bool [dict get $opts cc_use_spacing]]} {
            set spacing [string trim [dict get $opts cc_spacing]]
            if {$spacing eq ""} {
                error "Cross-correlation spacing is enabled but cc_spacing is empty"
            }
            lappend cmd -spacing [expr {double($spacing)}]
        }
        set value [{*}$cmd]
        if {![string is double -strict $value] || [catch {expr {double($value) != double($value)}} is_nan] || $is_nan} {
            return -1.0
        }
        return $value
    }

    proc cc_segment_groups {rows structures} {
        set groups {}
        set current {}
        set current_key {}
        for {set index 0} {$index < [llength $rows]} {incr index} {
            set row [lindex $rows $index]
            set structure [lindex $structures $index]
            set chain [expr {[dict exists $row chain] ? [dict get $row chain] : ""}]
            set segid [expr {[dict exists $row segid] ? [dict get $row segid] : ""}]
            set key [list $structure $chain $segid]
            if {$current ne {} && $key ne $current_key} {
                lappend groups $current
                set current {}
            }
            if {$current eq {}} {
                set current_key $key
            }
            lappend current $index
        }
        if {$current ne {}} {
            lappend groups $current
        }
        return $groups
    }

    proc cc_group_selection {rows group} {
        set atom_indices {}
        foreach row_index $group {
            set row [lindex $rows $row_index]
            lappend atom_indices [dict get $row atom_index]
        }
        return "same residue as (index [join $atom_indices { }])"
    }

    proc checkpoint {opts index total unit} {
        if {![dict exists $opts progress_callback] || [dict get $opts progress_callback] eq ""} { return }
        set event [dict create stage calculating completed $index total $total unit $unit message "Calculating Timeline: $unit $index of $total"]
        set answer [uplevel #0 [list {*}[dict get $opts progress_callback] $event]]
        if {[string tolower [string trim $answer]] in {cancel cancelled stop abort}} {
            return -code error -errorcode {RMSXFLIPBOOK CANCELLED} "Timeline calculation cancelled"
        }
    }

    proc calculate_property {molid property label unit opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set selection [dict get $opts selection]
        set rows [residue_rows $molid $selection $first]
        set columns [frame_columns $molid $first $last]
        set sel [atomselect $molid [key_atom_selection $selection]]
        set values {}
        try {
            foreach column $columns {
                checkpoint $opts [expr {[dict get $column frame] - $first}] [llength $columns] frame
                set frame [dict get $column frame]
                $sel frame $frame
                lappend values [$sel get $property]
            }
        } finally {
            catch {$sel delete}
        }
        return [make_dataset $molid $label $label $unit $rows $columns $values residue]
    }

    proc calculate_delta_property {molid property label unit opts {is_angle 0}} {
        set dataset [calculate_property $molid $property $label $unit $opts]
        set values [dict get $dataset values]
        set reference [lindex $values 0]
        set delta_columns {}
        foreach column_values $values {
            set out {}
            foreach value $column_values ref $reference {
                if {$is_angle} {
                    lappend out [expr {fmod(900.0 + double($value) - double($ref), 360.0) - 180.0}]
                } else {
                    lappend out [expr {double($value) - double($ref)}]
                }
            }
            lappend delta_columns $out
        }
        dict set dataset values $delta_columns
        dict set dataset value_label $label
        dict set dataset unit $unit
        dict set dataset value_kind diverging
        lassign [::RMSXFlipbookTimeline::Matrix::value_range $delta_columns] min_val max_val
        dict set dataset min $min_val
        dict set dataset max $max_val
        return $dataset
    }

    proc user_property {property} {
        set clean [string tolower [string trim $property]]
        set valid {user user2 user3 user4}
        if {[lsearch -exact $valid $clean] == -1} {
            error "Timeline user-field metric must be one of: [join $valid {, }]"
        }
        return $clean
    }

    proc calculate_user_field {molid opts} {
        set property [user_property [dict get $opts user_field]]
        return [calculate_property $molid $property $property "" $opts]
    }

    proc calculate_residue_function {molid opts} {
        set command [string trim [dict get $opts residue_function]]
        if {$command eq ""} {
            error "Timeline residue_function metric needs a residue_function option naming a Tcl proc"
        }
        if {[llength $command] != 1 || [llength [info commands $command]] == 0} {
            error "Timeline residue_function proc is not defined: $command"
        }

        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set selection [dict get $opts selection]
        set rows [residue_rows $molid $selection $first]
        set columns [frame_columns $molid $first $last]
        set label [string trim [dict get $opts residue_function_label]]
        if {$label eq ""} {
            set label [namespace tail $command]
        }
        set unit [dict get $opts residue_function_unit]
        set context_text [dict get $opts residue_function_context_selection]
        if {[string trim $context_text] eq ""} {
            set context_text "protein or nucleic"
        }

        set values [lrepeat [llength $columns] {}]
        set context_sel [atomselect $molid $context_text]
        try {
            for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            checkpoint $opts $row_index [llength $rows] residue
                set row [lindex $rows $row_index]
                set atom_index [dict get $row atom_index]
                set key_sel [atomselect $molid "index $atom_index"]
                set residue_sel [atomselect $molid [::RMSXFlipbookTimeline::Matrix::row_selection $row]]
                try {
                    for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                        set frame [dict get [lindex $columns $col] frame]
                        $key_sel frame $frame
                        $residue_sel frame $frame
                        $context_sel frame $frame
                        set value [{*}[list $command $key_sel $residue_sel $context_sel]]
                        set col_values [lindex $values $col]
                        lappend col_values $value
                        lset values $col $col_values
                    }
                } finally {
                    catch {$key_sel delete}
                    catch {$residue_sel delete}
                }
            }
        } finally {
            catch {$context_sel delete}
        }
        return [make_dataset $molid $label $label $unit $rows $columns $values residue]
    }

    proc calculate_displacement {molid opts {velocity 0}} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set selection [dict get $opts selection]
        set rows [residue_rows $molid $selection $first]
        set columns [frame_columns $molid $first $last]
        set sel [atomselect $molid [key_atom_selection $selection]]
        set values {}
        set reference {}
        try {
            foreach column $columns {
                checkpoint $opts [expr {[dict get $column frame] - $first}] [llength $columns] frame
                set frame [dict get $column frame]
                $sel frame $frame
                set coords [$sel get {x y z}]
                if {$reference eq {}} {
                    set reference $coords
                    lappend values [lrepeat [llength $coords] 0.0]
                    continue
                }
                set column_values {}
                foreach coord $coords ref $reference {
                    lappend column_values [veclength [vecsub $coord $ref]]
                }
                lappend values $column_values
                if {$velocity} {
                    set reference $coords
                }
            }
        } finally {
            catch {$sel delete}
        }
        if {$velocity} {
            return [make_dataset $molid "Displacement Velocity" "dispVel" "A/frame" $rows $columns $values residue]
        }
        return [make_dataset $molid "Displacement" "displacement" "A" $rows $columns $values residue]
    }

    proc calculate_rmsd {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set rows [residue_rows $molid [dict get $opts selection] $first]
        set columns [frame_columns $molid $first $last]
        set values [lrepeat [llength $columns] {}]
        for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            checkpoint $opts $row_index [llength $rows] residue
            set row [lindex $rows $row_index]
            set selection [::RMSXFlipbookTimeline::Matrix::row_selection $row]
            set ref_sel [atomselect $molid $selection frame $first]
            set cur_sel [atomselect $molid $selection]
            try {
                for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                    $cur_sel frame [dict get [lindex $columns $col] frame]
                    set col_values [lindex $values $col]
                    lappend col_values [measure rmsd $ref_sel $cur_sel]
                    lset values $col $col_values
                }
            } finally {
                catch {$ref_sel delete}
                catch {$cur_sel delete}
            }
        }
        return [make_dataset $molid RMSD RMSD A $rows $columns $values residue]
    }

    proc calculate_rmsf {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set rows [residue_rows $molid [dict get $opts selection] $first]
        set columns [frame_columns $molid $first $last]
        set window [expr {max(1, int([dict get $opts rmsf_window]))}]
        set step [expr {max(1, int([dict get $opts rmsf_step]))}]
        set half [expr {max(1, int($window / 2.0))}]
        set values [lrepeat [llength $columns] {}]
        for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            checkpoint $opts $row_index [llength $rows] residue
            set row [lindex $rows $row_index]
            set sel [atomselect $molid [::RMSXFlipbookTimeline::Matrix::row_selection $row]]
            try {
                for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                    set frame [dict get [lindex $columns $col] frame]
                    set first_window [expr {max($first, $frame - $half)}]
                    set last_window [expr {min($last, $frame + $half)}]
                    set col_values [lindex $values $col]
                    lappend col_values [scalar_mean [measure rmsf $sel first $first_window last $last_window step $step]]
                    lset values $col $col_values
                }
            } finally {
                catch {$sel delete}
            }
        }
        return [make_dataset $molid RMSF RMSF A $rows $columns $values residue]
    }

    proc calculate_sasa {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set rows [residue_rows $molid [dict get $opts selection] $first]
        set columns [frame_columns $molid $first $last]
        set radius [expr {double([dict get $opts sasa_radius])}]
        set values [lrepeat [llength $columns] {}]
        for {set row_index 0} {$row_index < [llength $rows]} {incr row_index} {
            checkpoint $opts $row_index [llength $rows] residue
            set row [lindex $rows $row_index]
            set sel [atomselect $molid [::RMSXFlipbookTimeline::Matrix::row_selection $row]]
            try {
                for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                    $sel frame [dict get [lindex $columns $col] frame]
                    set col_values [lindex $values $col]
                    lappend col_values [measure sasa $radius $sel]
                    lset values $col $col_values
                }
            } finally {
                catch {$sel delete}
            }
        }
        return [make_dataset $molid SASA SASA "A^2" $rows $columns $values residue]
    }

    proc calculate_secondary_structure {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set selection [dict get $opts selection]
        set rows [residue_rows $molid $selection $first]
        set columns [frame_columns $molid $first $last]
        set sel [atomselect $molid [key_atom_selection $selection]]
        set values {}
        try {
            foreach column $columns {
                checkpoint $opts [expr {[dict get $column frame] - $first}] [llength $columns] frame
                set frame [dict get $column frame]
                animate goto $frame
                catch {mol ssrecalc $molid}
                $sel frame $frame
                lappend values [$sel get structure]
            }
        } finally {
            catch {$sel delete}
        }
        set dataset [make_dataset $molid "Secondary Structure" struct "" $rows $columns $values residue]
        dict set dataset value_kind categorical
        dict set dataset categories [secondary_structure_categories]
        dict set dataset min 0
        dict set dataset max 1
        return $dataset
    }

    proc append_binary_interaction {rows_var values_by_key_var key label selection frame frame_index} {
        upvar 1 $rows_var rows $values_by_key_var values_by_key
        if {![dict exists $values_by_key $key]} {
            set row_index [llength $rows]
            lappend rows [dict create \
                index $row_index \
                label $label \
                selection $selection \
                row_mode free_selection]
            dict set values_by_key $key [dict create row_index $row_index frames {}]
        }
        set item [dict get $values_by_key $key]
        dict set item frames $frame_index 1
        dict set values_by_key $key $item
    }

    proc build_binary_dataset {molid title columns rows values_by_key} {
        set values {}
        for {set col 0} {$col < [llength $columns]} {incr col} {
            lappend values [lrepeat [llength $rows] 0]
        }
        dict for {_ item} $values_by_key {
            set row_index [dict get $item row_index]
            dict for {frame_index _value} [dict get $item frames] {
                set col_values [lindex $values $frame_index]
                lset col_values $row_index 1
                lset values $frame_index $col_values
            }
        }
        set dataset [make_dataset $molid $title $title "" $rows $columns $values free_selection]
        dict set dataset value_kind binary
        dict set dataset categories [binary_categories active inactive]
        dict set dataset min 0
        dict set dataset max 1
        return $dataset
    }

    proc normalize_contact_method {method} {
        set method [string tolower [string map {" " "_" "-" "_"} [string trim $method]]]
        switch -- $method {
            "" -
            auto -
            residues -
            residue -
            residues_to_selection -
            residue_to_selection -
            per_residue {
                return residues_to_selection
            }
            pair -
            pairs -
            selection_pairs {
                return pairs
            }
            all -
            all_pairs -
            selection_matrix -
            selections {
                return all
            }
            default {
                error "Unknown inter-selection contact method '$method'; use residues_to_selection, pairs, or all"
            }
        }
    }

    proc auto_contact_selection {text fallback} {
        set clean [string trim $text]
        if {$clean eq "" || [string tolower $clean] eq "auto"} {
            return $fallback
        }
        return $clean
    }

    proc append_inter_contact_spec {specs_var label sel1_text sel2_text row_selection row_mode args} {
        upvar 1 $specs_var specs
        set spec [dict create \
            label $label \
            sel1 $sel1_text \
            sel2 $sel2_text \
            selection $row_selection \
            row_mode $row_mode]
        foreach {key value} $args {
            dict set spec $key $value
        }
        lappend specs $spec
    }

    proc calculate_hbonds {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        set sel1_text [dict get $opts hbond_sel1]
        if {[string trim $sel1_text] eq ""} {
            set sel1_text "([dict get $opts selection]) and (protein or nucleic)"
        }
        set sel1 [atomselect $molid $sel1_text]
        set sel2 ""
        if {[string trim [dict get $opts hbond_sel2]] ne ""} {
            set sel2 [atomselect $molid [dict get $opts hbond_sel2]]
        }
        set rows {}
        set values_by_key [dict create]
        try {
            for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                set frame [dict get [lindex $columns $col] frame]
                $sel1 frame $frame
                if {$sel2 ne ""} {
                    $sel2 frame $frame
                    set measured [measure hbonds [dict get $opts hbond_dist] [dict get $opts hbond_angle] $sel1 $sel2]
                } else {
                    set measured [measure hbonds [dict get $opts hbond_dist] [dict get $opts hbond_angle] $sel1]
                }
                foreach {donors acceptors hydrogens} $measured {}
                foreach donor $donors acceptor $acceptors hydrogen $hydrogens {
                    set key "$donor|$acceptor|$hydrogen"
                    append_binary_interaction rows values_by_key $key "H-bond $donor-$acceptor-$hydrogen" "index $donor $acceptor $hydrogen" $frame $col
                }
            }
        } finally {
            catch {$sel1 delete}
            if {$sel2 ne ""} {
                catch {$sel2 delete}
            }
        }
        return [build_binary_dataset $molid H-bond $columns $rows $values_by_key]
    }

    proc calculate_salt_bridges {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        set base [dict get $opts selection]
        set acidic [atomselect $molid "($base) and (protein and acidic and oxygen and not backbone)"]
        set basic [atomselect $molid "($base) and (protein and basic and nitrogen and not backbone)"]
        set rows {}
        set values_by_key [dict create]
        try {
            for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                set frame [dict get [lindex $columns $col] frame]
                $acidic frame $frame
                $basic frame $frame
                foreach {oxygens nitrogens} [measure contacts [dict get $opts salt_dist] $acidic $basic] {}
                foreach oxygen $oxygens nitrogen $nitrogens {
                    set key "$oxygen|$nitrogen"
                    append_binary_interaction rows values_by_key $key "Salt $oxygen-$nitrogen" "same residue as (index $oxygen $nitrogen)" $frame $col
                }
            }
        } finally {
            catch {$acidic delete}
            catch {$basic delete}
        }
        return [build_binary_dataset $molid "salt bridge" $columns $rows $values_by_key]
    }

    proc calculate_inter_selection_contacts {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        set dist [dict get $opts inter_dist]
        set method [normalize_contact_method [dict get $opts inter_method]]
        set rows {}
        set values {}
        foreach _ $columns {
            lappend values {}
        }

        set pair_specs {}
        if {$method eq "residues_to_selection"} {
            set from_text [auto_contact_selection [dict get $opts inter_from_selection] [dict get $opts selection]]
            set to_text [auto_contact_selection [dict get $opts inter_to_selection] $from_text]
            set from_sel [atomselect $molid "($from_text) and [key_atom_selection all]" frame $first]
            try {
                if {[$from_sel num] == 0} {
                    error "Inter-selection contact From selection returned no residue/key atoms: $from_text"
                }
                foreach atom [$from_sel get {index residue resid resname chain segid}] {
                    lassign $atom atom_index residue resid resname chain segid
                    set chain [string trim $chain]
                    set segid [string trim $segid]
                    set display_chain $chain
                    if {$display_chain eq "" || $display_chain eq "X"} {
                        set display_chain $segid
                    }
                    set label [string trim "$display_chain:$resid $resname -> $to_text" ":"]
                    set row_selection "same residue as index $atom_index"
                    set row_target_selection "($to_text) and not ($row_selection)"
                    append_inter_contact_spec pair_specs \
                        $label \
                        $row_selection \
                        $row_target_selection \
                        $row_selection \
                        residue_contact \
                        atom_index $atom_index \
                        residue $residue \
                        resid $resid \
                        resname $resname \
                        chain $display_chain \
                        segid $segid \
                        target_selection $to_text
                }
            } finally {
                catch {$from_sel delete}
            }
        } else {
            set selections [dict get $opts inter_selection_list]
            if {[llength $selections] < 2} {
                error "Inter-selection contact list must contain at least two VMD selection strings"
            }
            if {$method eq "pairs"} {
                for {set i 0} {$i < [llength $selections]} {incr i 2} {
                    if {$i + 1 >= [llength $selections]} {
                        error "Inter-selection pairs mode requires an even number of selections"
                    }
                    set sel1_text [lindex $selections $i]
                    set sel2_text [lindex $selections [expr {$i + 1}]]
                    append_inter_contact_spec pair_specs \
                        "$sel1_text == $sel2_text" \
                        $sel1_text \
                        $sel2_text \
                        "($sel1_text) or ($sel2_text)" \
                        free_selection
                }
            } else {
                for {set i 0} {$i < [llength $selections]} {incr i} {
                    for {set j 0} {$j < $i} {incr j} {
                        set sel1_text [lindex $selections $i]
                        set sel2_text [lindex $selections $j]
                        append_inter_contact_spec pair_specs \
                            "$sel1_text == $sel2_text" \
                            $sel1_text \
                            $sel2_text \
                            "($sel1_text) or ($sel2_text)" \
                            free_selection
                    }
                }
            }
        }

        if {[llength $pair_specs] == 0} {
            error "Inter-selection contacts produced no row definitions"
        }

        foreach spec $pair_specs {
            set label [dict get $spec label]
            set sel1_text [dict get $spec sel1]
            set sel2_text [dict get $spec sel2]
            set row_index [llength $rows]
            set row [dict create \
                index $row_index \
                label $label \
                selection [dict get $spec selection] \
                row_mode [dict get $spec row_mode]]
            foreach key {atom_index residue resid resname chain segid target_selection} {
                if {[dict exists $spec $key]} {
                    dict set row $key [dict get $spec $key]
                }
            }
            lappend rows $row
            set sel1 [atomselect $molid $sel1_text]
            set sel2 [atomselect $molid $sel2_text]
            try {
                if {[$sel1 num] == 0} {
                    error "Inter-selection contact row selection returned no atoms: $sel1_text"
                }
                if {[$sel2 num] == 0} {
                    error "Inter-selection contact target selection returned no atoms: $sel2_text"
                }
                for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                    set frame [dict get [lindex $columns $col] frame]
                    $sel1 frame $frame
                    $sel2 frame $frame
                    set count [llength [lindex [measure contacts $dist $sel1 $sel2] 0]]
                    set col_values [lindex $values $col]
                    lappend col_values $count
                    lset values $col $col_values
                }
            } finally {
                catch {$sel1 delete}
                catch {$sel2 delete}
            }
        }
        set row_mode [expr {$method eq "residues_to_selection" ? "residue_contact" : "free_selection"}]
        return [make_dataset $molid "Inter-selection Contacts" "contact count" "contacts" $rows $columns $values $row_mode]
    }

    proc calculate_native_contacts {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        set ref_frame [expr {int([dict get $opts native_ref_frame])}]
        set total_frames [molinfo $molid get numframes]
        if {$ref_frame < 0 || $ref_frame >= $total_frames} {
            error "Native-contact reference frame $ref_frame is outside molecule frame range 0-[expr {$total_frames - 1}]"
        }
        set cutoff [dict get $opts native_dist]
        set to_sel [atomselect $molid "([dict get $opts native_to_selection]) and [key_atom_selection all]"]
        set rows {}
        set values {}
        foreach _ $columns {
            lappend values {}
        }
        try {
            foreach from_text [dict get $opts native_from_selection_list] {
                set row_index [llength $rows]
                lappend rows [dict create index $row_index label $from_text selection $from_text row_mode free_selection]
                set from_sel [atomselect $molid "($from_text) and [key_atom_selection all]"]
                try {
                    $from_sel frame $ref_frame
                    $to_sel frame $ref_frame
                    set from_atoms [$from_sel get index]
                    array unset ref_contacts
                    foreach atom $from_atoms {
                        set ref_contacts($atom) {}
                    }
                    foreach {from_result to_result} [measure contacts $cutoff $from_sel $to_sel] {}
                    foreach f $from_result t $to_result {
                        lappend ref_contacts($f) $t
                    }
                    set ref_total 0
                    foreach atom $from_atoms {
                        incr ref_total [llength $ref_contacts($atom)]
                    }
                    if {$ref_total <= 0} {
                        set ref_total 1
                    }
                    for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                        set frame [dict get [lindex $columns $col] frame]
                        $from_sel frame $frame
                        $to_sel frame $frame
                        array unset current_contacts
                        foreach atom $from_atoms {
                            set current_contacts($atom) {}
                        }
                        foreach {from_result to_result} [measure contacts $cutoff $from_sel $to_sel] {}
                        foreach f $from_result t $to_result {
                            lappend current_contacts($f) $t
                        }
                        set preserved 0
                        foreach atom $from_atoms {
                            foreach target $ref_contacts($atom) {
                                if {[lsearch -exact $current_contacts($atom) $target] != -1} {
                                    incr preserved
                                }
                            }
                        }
                        set col_values [lindex $values $col]
                        lappend col_values [expr {$preserved / double($ref_total)}]
                        lset values $col $col_values
                    }
                } finally {
                    catch {$from_sel delete}
                }
            }
        } finally {
            catch {$to_sel delete}
        }
        set dataset [make_dataset $molid "native contacts" "native contacts" "" $rows $columns $values free_selection]
        dict set dataset value_kind fraction
        dict set dataset min 0
        dict set dataset max 1
        return $dataset
    }

    proc calculate_selection_empty {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        set rows [list [dict create \
            index 0 \
            label "-" \
            selection none \
            row_mode free_selection]]
        set values {}
        foreach _ $columns {
            lappend values {0}
        }
        return [make_dataset $molid "Selection Empty" "--" "" $rows $columns $values free_selection]
    }

    proc calculate_test_free_selection {molid opts} {
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        set row_specs {
            {"res 23 / res 28" "resid 23 28"}
            {"res 1-5 / res 70-80" "resid 1 to 5 70 to 80"}
            {"resid 60 61 62" "resid 60 61 62"}
            {"resid 70 to 75" "resid 70 to 75"}
            {"some in 20's and 60's" "resid 20 to 25 28 67"}
            {"favorites" "resid 50 51 52 61 62"}
            {"res 9 / res 20" "resid 9 20"}
        }
        set rows {}
        foreach spec $row_specs {
            lassign $spec label selection
            lappend rows [dict create \
                index [llength $rows] \
                label $label \
                selection $selection \
                row_mode free_selection]
        }

        set values {}
        foreach _ $columns {
            lappend values [lrepeat [llength $rows] 0]
        }

        set assignments {
            {0 5 100}
            {0 23 -100}
            {0 24 -100}
            {0 25 -100}
            {0 26 -100}
            {1 2 -100}
            {1 3 -100}
            {1 4 70}
            {1 5 90}
            {1 6 110}
            {1 17 -50}
            {1 50 150}
            {2 27 -50}
            {2 40 150}
            {2 41 150}
            {2 42 150}
            {2 43 150}
            {3 17 -10}
            {3 45 70}
            {3 46 80}
            {3 80 100}
            {5 27 -40}
            {5 38 150}
            {5 39 150}
            {5 40 150}
            {6 12 -130}
            {6 13 -100}
            {6 14 170}
            {6 15 90}
            {6 16 110}
            {6 17 -140}
            {6 30 150}
        }

        for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
            set frame [dict get [lindex $columns $col] frame]
            foreach assignment $assignments {
                lassign $assignment row_index assignment_frame value
                if {$frame == $assignment_frame} {
                    set col_values [lindex $values $col]
                    lset col_values $row_index $value
                    lset values $col $col_values
                }
            }
        }

        return [make_dataset $molid "Free Selection Test" "free-sel. test" "" $rows $columns $values free_selection]
    }

    proc calculate_rmsd_tool {molid opts} {
        if {[llength [info commands ::rmsdtool]] == 0} {
            catch {package require rmsdtool}
        }
        if {[llength [info commands ::rmsdtool]] == 0} {
            error "VMD RMSD Tool command is unavailable: ::rmsdtool"
        }
        if {[catch {::rmsdtool} err]} {
            error "VMD RMSD Tool launch failed: $err"
        }

        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        set values {}
        foreach _ $columns {
            lappend values {}
        }
        return [::RMSXFlipbookTimeline::Matrix::create \
            title "RMSD Tool" \
            value_label rmsdtool \
            unit "" \
            source_type external_tool \
            row_mode free_selection \
            column_mode frame \
            molid $molid \
            rows {} \
            columns $columns \
            values $values \
            provenance [dict create calculator rmsd_tool launched 1 molid $molid]]
    }

    proc calculate_cross_correlation {molid opts} {
        set backend [require_mdff_cc]
        lassign [frame_range $molid [dict get $opts first_frame] [dict get $opts last_frame]] first last
        set columns [frame_columns $molid $first $last]
        if {$backend eq "mdffi"} {
            set cc_target [resolve_cc_volume $molid $opts]
        } else {
            set cc_target [resolve_cc_map_file $opts]
        }
        set method [string tolower [string map {" " "_" "-" "_"} [string trim [dict get $opts cc_method]]]]

        if {$method in {selection selections free free_selection custom}} {
            set rows {}
            set values {}
            foreach _ $columns {
                lappend values {}
            }
            foreach sel_text [selection_list [dict get $opts cc_selection_list] "cc_selection_list"] {
                set row_index [llength $rows]
                lappend rows [dict create \
                    index $row_index \
                    label $sel_text \
                    selection $sel_text \
                    row_mode free_selection]
                set sel [atomselect $molid $sel_text]
                try {
                    if {[$sel num] == 0} {
                        error "Cross-correlation selection returned no atoms: $sel_text"
                    }
                    for {set col 0} {$col < [llength $columns]} {incr col} {
                    checkpoint $opts $col [llength $columns] frame
                        set frame [dict get [lindex $columns $col] frame]
                        $sel frame $frame
                        set col_values [lindex $values $col]
                        lappend col_values [cc_value $backend $molid $cc_target $sel $opts]
                        lset values $col $col_values
                    }
                } finally {
                    catch {$sel delete}
                }
            }
            set dataset [make_dataset $molid "Cross-correlation" "cross-corr." "" $rows $columns $values free_selection]
            dict set dataset value_kind correlation
            dict set dataset min -1
            dict set dataset max 1
            return $dataset
        }

        if {$method ni {segments secondary_structure secondary_struct residue residues}} {
            error "Unknown cross-correlation method '$method'; use segments or selections"
        }

        set selection [dict get $opts selection]
        set rows [residue_rows $molid $selection $first]
        set key_sel [atomselect $molid [key_atom_selection $selection]]
        set values {}
        try {
            foreach column $columns {
                checkpoint $opts [expr {[dict get $column frame] - $first}] [llength $columns] frame
                set frame [dict get $column frame]
                animate goto $frame
                catch {mol ssrecalc $molid}
                $key_sel frame $frame
                set structures [$key_sel get structure]
                set col_values [lrepeat [llength $rows] -1.0]
                foreach group [cc_segment_groups $rows $structures] {
                    set group_sel [atomselect $molid [cc_group_selection $rows $group] frame $frame]
                    try {
                        if {[$group_sel num] == 0} {
                            continue
                        }
                        set value [cc_value $backend $molid $cc_target $group_sel $opts]
                    } finally {
                        catch {$group_sel delete}
                    }
                    foreach row_index $group {
                        lset col_values $row_index $value
                    }
                }
                lappend values $col_values
            }
        } finally {
            catch {$key_sel delete}
        }
        set dataset [make_dataset $molid "Cross-correlation" "cross-corr." "" $rows $columns $values residue]
        dict set dataset value_kind correlation
        dict set dataset min -1
        dict set dataset max 1
        return $dataset
    }

    proc calculate {molid metric args} {
        set defaults [dict create \
            selection all \
            progress_callback "" \
            first_frame 0 \
            last_frame -1 \
            rmsf_window 5 \
            rmsf_step 1 \
            sasa_radius 1.4 \
            hbond_dist 3.0 \
            hbond_angle 20 \
            hbond_sel1 "" \
            hbond_sel2 "" \
            salt_dist 3.2 \
            inter_method residues_to_selection \
            inter_dist 4.0 \
            inter_selection_list {{protein} {protein}} \
            inter_from_selection "" \
            inter_to_selection "protein" \
            native_dist 8.0 \
            native_ref_frame 0 \
            native_from_selection_list {{protein}} \
            native_to_selection protein \
            user_field user \
            residue_function "" \
            residue_function_label "user residue function" \
            residue_function_unit "" \
            residue_function_context_selection "protein or nucleic" \
            cc_map_file "" \
            cc_vol_id auto \
            cc_map_res 5.0 \
            cc_spacing "" \
            cc_threshold "" \
            cc_use_spacing 0 \
            cc_use_threshold 0 \
            cc_method segments \
            cc_selection_list {{protein}}]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set key [string tolower [string map {" " "_" "-" "_"} [string trim $metric]]]
        if {$molid eq "top"} { set molid [molinfo top] }
        if {[lsearch -exact [molinfo list] $molid] < 0} { error "Source molecule is no longer loaded: $molid" }
        set snapshot [snapshot_vmd_state]
        try {
            checkpoint $opts 0 1 preparation
            switch -- $key {
            x -
            data_x -
            x_position {
                return [calculate_property $molid x "x" A $opts]
            }
            y -
            data_y -
            y_position {
                return [calculate_property $molid y "y" A $opts]
            }
            z -
            data_z -
            z_position {
                return [calculate_property $molid z "z" A $opts]
            }
            user {
                return [calculate_property $molid user "user" "" $opts]
            }
            user2 {
                return [calculate_property $molid user2 "user2" "" $opts]
            }
            user3 {
                return [calculate_property $molid user3 "user3" "" $opts]
            }
            user4 {
                return [calculate_property $molid user4 "user4" "" $opts]
            }
            user_field -
            show_user_field -
            data_user {
                return [calculate_user_field $molid $opts]
            }
            residue_function -
            any_res_func -
            user_defined -
            user_defined_per_res -
            user_defined_per_residue {
                return [calculate_residue_function $molid $opts]
            }
            displacement -
            disp {
                return [calculate_displacement $molid $opts 0]
            }
            displacement_velocity -
            disp_velocity -
            dispvel {
                return [calculate_displacement $molid $opts 1]
            }
            rmsd {
                return [calculate_rmsd $molid $opts]
            }
            rmsf {
                return [calculate_rmsf $molid $opts]
            }
            sasa {
                return [calculate_sasa $molid $opts]
            }
            secondary_structure -
            sec_struct -
            structure -
            struct {
                return [calculate_secondary_structure $molid $opts]
            }
            phi {
                return [calculate_property $molid phi "phi" deg $opts]
            }
            delta_phi {
                return [calculate_delta_property $molid phi "delta-phi" deg $opts 1]
            }
            psi {
                return [calculate_property $molid psi "psi" deg $opts]
            }
            delta_psi {
                return [calculate_delta_property $molid psi "delta-psi" deg $opts 1]
            }
            hbonds -
            hbond -
            h_bonds {
                return [calculate_hbonds $molid $opts]
            }
            salt_bridges -
            salt_bridge {
                return [calculate_salt_bridges $molid $opts]
            }
            inter_selection_contacts -
            inter_sel_contacts -
            contacts {
                return [calculate_inter_selection_contacts $molid $opts]
            }
            native_contacts {
                return [calculate_native_contacts $molid $opts]
            }
            selection_empty -
            sel_empty -
            empty_selection -
            calc_sel_empty {
                return [calculate_selection_empty $molid $opts]
            }
            test_free_selection -
            test_free_sel -
            free_selection_test -
            calc_test_free_sel {
                return [calculate_test_free_selection $molid $opts]
            }
            rmsd_tool -
            rmsdtool -
            vmd_rmsd_tool {
                return [calculate_rmsd_tool $molid $opts]
            }
            cross_correlation -
            cross_corr -
            crosscorr -
            ccss -
            cc {
                return [calculate_cross_correlation $molid $opts]
            }
                default {
                    error "Unknown Timeline metric '$metric'"
                }
            }
        } finally {
            restore_vmd_state $snapshot
        }
    }
}
