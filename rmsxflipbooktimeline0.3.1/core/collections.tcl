# Saved Timeline collections. Preparation and identity matching have no Tk dependency.
namespace eval ::RMSXFlipbookTimeline::Collections {
    variable items {}
    variable current_index -1
    variable directory ""
    variable plot_options {}
    variable controls {}
    variable selected_label ""
    variable status_command ""

    proc value {record key {default ""}} {
        if {[dict exists $record $key]} {return [dict get $record $key]}
        return $default
    }
    proc datasets {} {variable items; return $items}
    proc index {} {variable current_index; return $current_index}
    proc labels {} {
        variable items
        set labels {}
        foreach dataset $items {
            set path ""
            if {[dict exists $dataset provenance file]} {set path [file tail [dict get $dataset provenance file]]}
            lappend labels "[expr {[llength $labels]+1}]. [dict get $dataset title] ($path)"
        }
        return $labels
    }
    proc set_status_command {command} {variable status_command; set status_command $command}
    proc status {message} {
        variable status_command
        if {$status_command ne ""} {uplevel #0 [list {*}$status_command $message]}
    }
    proc source_identity {dataset} {
        set identity {}
        set molid [value $dataset molid]
        if {$molid ne ""} {dict set identity molid $molid}
        # Compare actual source metadata across the supported record shapes.
        # Output folders and run IDs identify analyses, not input trajectories.
        foreach path {{} provenance {provenance method} {provenance method parameters}} {
            if {$path eq {}} {set record $dataset} elseif {[dict exists $dataset {*}$path]} {set record [dict get $dataset {*}$path]} else {continue}
            set id [value $record source_identity]
            if {$id ne ""} {dict set identity source_identity $id}
            foreach {field key} {topology topology topology_file topology trajectory trajectory trajectory_file trajectory} {
                set source [value $record $field]
                if {$source ne ""} {dict set identity $key [file normalize $source]}
            }
            set paths [value $record source_paths]
            if {[llength $paths] == 2} {
                dict set identity topology [file normalize [lindex $paths 0]]
                dict set identity trajectory [file normalize [lindex $paths 1]]
            } elseif {[llength $paths]} {
                dict set identity source_paths [lmap source $paths {file normalize $source}]
            }
            set name [value $record mol_name]
            # The plugin's historical MOL_NAME often contains a session-local
            # integer ID. That is not portable source identity after import.
            if {$name ne "" && ![string is integer -strict $name]} {dict set identity mol_name $name}
        }
        return $identity
    }
    proc source_compatible {a b} {
        set left [source_identity $a]; set right [source_identity $b]
        set evidence 0
        dict for {key item} $left {
            if {![dict exists $right $key]} {continue}
            if {$item ne [dict get $right $key]} {return 0}
            set evidence 1
        }
        return $evidence
    }
    proc row_matches {a b} {
        if {[dict exists $a resid] && [dict exists $b resid]} {
            set full_a [::RMSXFlipbookTimeline::ResidueIdentity::full $a]
            set full_b [::RMSXFlipbookTimeline::ResidueIdentity::full $b]
            if {$full_a && $full_b} {
                return [expr {[::RMSXFlipbookTimeline::ResidueIdentity::key $a] eq [::RMSXFlipbookTimeline::ResidueIdentity::key $b]}]
            }
            if {$full_a} {return [::RMSXFlipbookTimeline::ResidueIdentity::matches $b $a]}
            return [::RMSXFlipbookTimeline::ResidueIdentity::matches $a $b]
        }
        # Free selections have no residue key. Require the exact selection text;
        # labels and row positions are deliberately insufficient.
        set selection [string trim [value $a selection]]
        return [expr {$selection ne "" && $selection eq [string trim [value $b selection]]}]
    }
    proc interval {column} {
        if {[dict exists $column frame_start] && [dict exists $column frame_end]} {
            set first [dict get $column frame_start]; set last [dict get $column frame_end]
        } elseif {[dict exists $column frame]} {
            set first [dict get $column frame]; set last $first
        } else {return {}}
        if {![string is integer -strict $first] || ![string is integer -strict $last] || $first < 0 || $last < $first} {return {}}
        return [list $first $last]
    }
    proc matching_column {old columns} {
        set range [interval $old]
        if {$range eq {}} {return -1}
        set exact {}; set containing {}
        set anchor ""
        foreach key {frame representative_frame} {
            if {[dict exists $old $key] && [string is integer -strict [dict get $old $key]]} {set anchor [dict get $old $key]; break}
        }
        if {$anchor eq "" && [lindex $range 0] == [lindex $range 1]} {set anchor [lindex $range 0]}
        set i 0
        foreach column $columns {
            set candidate [interval $column]
            if {$candidate eq $range} {lappend exact $i}
            if {$candidate ne {} && $anchor ne "" && $anchor >= [lindex $candidate 0] && $anchor <= [lindex $candidate 1]} {lappend containing $i}
            incr i
        }
        if {[llength $exact] == 1} {return [lindex $exact 0]}
        if {[llength $exact] > 1} {return -1}
        if {[llength $containing] == 1} {return [lindex $containing 0]}
        return -1
    }
    proc map_selection {old_dataset new_dataset coordinate} {
        set clear [dict create coordinate {} status cleared reason "Selection cleared: no matching residue and frame."]
        if {[llength $coordinate] != 2 || $old_dataset eq {}} {
            return [dict replace $clear status none reason "No previous selection."]
        }
        lassign $coordinate row col
        if {![string is integer -strict $row] || ![string is integer -strict $col] || $row < 0 || $col < 0 ||
            $row >= [llength [dict get $old_dataset rows]] || $col >= [llength [dict get $old_dataset columns]]} {return $clear}
        if {![source_compatible $old_dataset $new_dataset]} {
            return [dict replace $clear reason "Selection cleared: source identity is different or cannot be established."]
        }
        set old_row [lindex [dict get $old_dataset rows] $row]
        set matches {}; set i 0
        foreach candidate [dict get $new_dataset rows] {
            if {[row_matches $old_row $candidate]} {lappend matches $i}
            incr i
        }
        if {[llength $matches] != 1} {
            return [dict replace $clear reason "Selection cleared: residue identity is absent or ambiguous."]
        }
        set new_row [lindex $matches 0]
        # Legacy matches must be unique in BOTH directions, including when the
        # destination contains only one of several ambiguous source rows.
        set reverse 0
        foreach candidate [dict get $old_dataset rows] {
            if {[row_matches $candidate [lindex [dict get $new_dataset rows] $new_row]]} {incr reverse}
        }
        if {$reverse != 1} {return [dict replace $clear reason "Selection cleared: legacy residue identity is ambiguous."]}
        set new_col [matching_column [lindex [dict get $old_dataset columns] $col] [dict get $new_dataset columns]]
        if {$new_col < 0} {return [dict replace $clear reason "Selection cleared: no unique matching frame or window."]}
        return [dict create coordinate [list $new_row $new_col] status preserved reason "Residue and frame selection preserved."]
    }
    proc prepare_dataset {dataset molid actual_rows} {
        set dataset [::RMSXFlipbookTimeline::Matrix::validate $dataset]
        if {![llength [dict get $dataset rows]] || ![llength [dict get $dataset columns]]} {error "Collection dataset is empty: [dict get $dataset title]"}
        dict set dataset molid $molid
        set frame_count ""
        if {$molid ne ""} {
            set frame_count [molinfo $molid get numframes]
            if {![string is integer -strict $frame_count] || $frame_count <= 0} {error "Collection source molecule has no frames: $molid"}
        }
        set rows {}
        foreach row [dict get $dataset rows] {
            # Serialized integer molecule IDs and residue indices are not
            # portable and must never select a coincidentally reused VMD ID.
            foreach key {source_molid residue atom_index} {catch {dict unset row $key}}
            if {$molid ne "" && [dict exists $row resid]} {
                set actual [::RMSXFlipbookTimeline::ResidueIdentity::resolve $row $actual_rows]
                foreach key {identity_schema resid chain segid insertion ordinal residue source_molid} {dict set row $key [dict get $actual $key]}
                dict set row selection [::RMSXFlipbookTimeline::ResidueIdentity::selection $row $molid]
            } elseif {$molid ne ""} {
                set text [string trim [value $row selection]]
                if {$text eq ""} {error "Collection row has no selection to bind: [value $row label]"}
                set selected [atomselect $molid $text]
                try {
                    if {[$selected num] == 0} {error "Collection row selection is empty on molecule $molid: $text"}
                } finally {$selected delete}
            }
            lappend rows $row
        }
        dict set dataset rows $rows
        set columns {}
        foreach column [dict get $dataset columns] {
            foreach key {molid slice_molid} {catch {dict unset column $key}}
            if {$molid ne ""} {
                if {[interval $column] eq {}} {error "Collection column has no valid source frame metadata: [value $column label]"}
                foreach key {frame representative_frame frame_start frame_end} {
                    if {![dict exists $column $key]} {continue}
                    set frame [dict get $column $key]
                    if {![string is integer -strict $frame] || $frame < 0 || $frame >= $frame_count} {
                        error "Collection $key $frame is outside molecule $molid frame range 0-[expr {$frame_count-1}]"
                    }
                }
            }
            if {$molid ne "" && [value $column target_type frame] eq "frame"} {dict set column molid $molid}
            lappend columns $column
        }
        dict set dataset columns $columns
        return $dataset
    }
    proc previous_selection {} {
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current eq {} || ![dict exists $current dataset]} {return [list {} {}]}
        set coordinate [value $current selected_cell]
        if {$coordinate eq {} && [info commands ::RMSXFlipbookTimeline::TimelinePlot::selected_record] ne ""} {
            set selected [::RMSXFlipbookTimeline::TimelinePlot::selected_record]
            if {[dict exists $selected row] && [dict exists $selected column] &&
                [::RMSXFlipbookTimeline::TimelinePlot::current_dataset] eq [dict get $current dataset]} {
                set coordinate [list [dict get $selected row] [dict get $selected column]]
            }
        }
        return [list [dict get $current dataset] $coordinate]
    }
    proc activate {dataset options} {
        lassign [previous_selection] previous coordinate
        set mapped [map_selection $previous $dataset $coordinate]
        # TimelinePlot::show validates/draws a hidden candidate before publishing.
        # Nothing in collection state changes until this succeeds.
        set result [::RMSXFlipbookTimeline::show_timeline_dataset $dataset {*}$options]
        set coordinate [dict get $mapped coordinate]
        if {$coordinate ne {}} {
            set canvas $::RMSXFlipbookTimeline::TimelinePlot::canvas
            if {[catch {
                if {$canvas ne "" && [info commands winfo] ne "" && [winfo exists $canvas]} {
                    ::RMSXFlipbookTimeline::Navigation::choose $canvas $coordinate
                } else {::RMSXFlipbookTimeline::TimelinePlot::select_cell {*}$coordinate}
            } message]} {
                set coordinate {}
                catch {::RMSXFlipbookTimeline::TimelinePlot::clear_structure_highlight}
                catch {::RMSXFlipbookTimeline::TimelinePlot::clear_canvas_highlight}
                set ::RMSXFlipbookTimeline::TimelinePlot::selected_record {}
                set mapped [dict create coordinate {} status cleared reason "Dataset loaded; selection unavailable: $message"]
            }
        }
        ::RMSXFlipbookTimeline::Results::update [dict create selected_cell $coordinate]
        dict set result selected_cell $coordinate
        dict set result selection_status [dict get $mapped status]
        dict set result selection_message [dict get $mapped reason]
        return $result
    }
    proc load {path {molid ""} args} {
        variable items; variable current_index; variable directory; variable plot_options
        if {[::RMSXFlipbookTimeline::Operation::running]} {error "Wait for the current operation before loading a collection"}
        set path [file normalize $path]
        if {![file isdirectory $path]} {error "Collection directory does not exist: $path"}
        set actual_rows {}
        if {$molid ne ""} {
            if {[info commands molinfo] eq ""} {error "Binding a collection requires VMD"}
            if {$molid eq "top"} {set molid [molinfo top]}
            if {[lsearch -exact [molinfo list] $molid] < 0} {error "Molecule is not loaded: $molid"}
            set selection [atomselect $molid all]
            try {set actual_rows [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $selection]} finally {$selection delete}
        }
        set candidate {}
        foreach dataset [::RMSXFlipbookTimeline::TimelineIO::load_collection $path molid $molid] {
            lappend candidate [prepare_dataset $dataset $molid $actual_rows]
        }
        if {![llength $candidate]} {error "No .tml files found in $path"}
        set result [activate [lindex $candidate 0] $args]
        set items $candidate; set current_index 0; set directory $path; set plot_options $args
        ::RMSXFlipbookTimeline::state_set timeline_collection_dir $path
        ::RMSXFlipbookTimeline::state_set timeline_collection_index 0
        dict set result collection_index 0
        refresh_controls
        return $result
    }
    proc select {position args} {
        variable items; variable current_index; variable plot_options
        if {[::RMSXFlipbookTimeline::Operation::running]} {error "Wait for the current operation before switching datasets"}
        if {![string is integer -strict $position] || $position < 0 || $position >= [llength $items]} {error "Collection dataset index is outside 0-[expr {[llength $items]-1}]"}
        if {[llength $args]} {set options $args} else {set options $plot_options}
        set result [activate [lindex $items $position] $options]
        set current_index $position; set plot_options $options
        ::RMSXFlipbookTimeline::state_set timeline_collection_index $position
        dict set result collection_index $position
        refresh_controls
        return $result
    }
    proc refresh_controls {} {
        variable controls; variable current_index; variable selected_label
        set names [labels]
        set selected_label [lindex $names $current_index]
        if {[info commands winfo] eq ""} {return}
        set remaining {}
        foreach parent $controls {
            if {![winfo exists $parent]} {continue}
            lappend remaining $parent
            $parent.dataset configure -values $names
            $parent.dataset configure -state [expr {[llength $names] ? "readonly" : "disabled"}]
            $parent.prev configure -state [expr {$current_index > 0 ? "normal" : "disabled"}]
            $parent.next configure -state [expr {$current_index >= 0 && $current_index < [llength $names]-1 ? "normal" : "disabled"}]
        }
        set controls $remaining
    }
    proc choose_control {position} {
        if {[catch {select $position} result]} {refresh_controls; status "Dataset switch failed: $result"; return}
        status "Dataset [expr {$position+1}] of [llength [datasets]]. [dict get $result selection_message]"
    }
    proc step {delta} {choose_control [expr {[index]+$delta}]}
    proc choose_label {} {variable selected_label; choose_control [lsearch -exact [labels] $selected_label]}
    proc build_controls {parent} {
        variable controls
        ttk::frame $parent
        ttk::label $parent.label -text "Saved data"
        ttk::combobox $parent.dataset -textvariable ::RMSXFlipbookTimeline::Collections::selected_label -state readonly -width 24
        ttk::button $parent.prev -text "Prev" -command {::RMSXFlipbookTimeline::Collections::step -1}
        ttk::button $parent.next -text "Next" -command {::RMSXFlipbookTimeline::Collections::step 1}
        grid $parent.label -row 0 -column 0 -sticky w -padx {0 4}
        grid $parent.dataset -row 0 -column 1 -sticky ew
        grid $parent.prev -row 0 -column 2 -padx {4 0}
        grid $parent.next -row 0 -column 3 -padx {4 0}
        grid columnconfigure $parent 1 -weight 1
        bind $parent.dataset <<ComboboxSelected>> ::RMSXFlipbookTimeline::Collections::choose_label
        lappend controls $parent
        refresh_controls
        return $parent
    }
}
