################################################################################
# RMSX Flipbook Timeline Tk GUI
################################################################################

namespace eval ::RMSXFlipbookTimeline::GUI {
    variable top ".rmsxflipbooktimeline"
    variable folder ""
    variable quality "Balanced"
    variable palette "viridis"
    variable rep "NewTube"
    variable res "32"
    variable thick "0.30"
    variable spacing "auto"
    variable color_min "0.0"
    variable color_max "10.0"
    variable apply_mask "1"
    variable mask_opacity "0.30"
    variable native_topology ""
    variable native_trajectory ""
    variable native_output ""
    variable native_chain "7"
    variable native_slices "9"
    variable native_slice_size ""
    variable native_start "0"
    variable native_end "-1"
    variable native_time_step "0.04888821"
    variable native_metric "RMSX"
    variable native_analysis_type "protein"
    variable native_log_transform "0"
    variable native_mask_selection ""
    variable mouse_mode "coords"
    variable mouse_sensitivity "2.0"
    variable mouse_burst_count "240"
    variable mouse_burst_axis "y"
    variable mouse_burst_angle "0.75"
    variable metric_values {
        RMSX Shift-Map lDDT
        displacement displacement_velocity rmsd rmsf sasa native_contacts
        secondary_structure phi delta_phi psi delta_psi
        hbonds salt_bridges inter_selection_contacts cross_correlation
        x y z user user2 user3 user4 user_field residue_function
        selection_empty test_free_selection rmsd_tool
    }
    variable timeline_molid "top"
    variable timeline_selection "protein"
    variable timeline_metric "RMSX"
    variable timeline_first "0"
    variable timeline_last "-1"
    variable timeline_scale_mode "fit"
    variable timeline_scale_min ""
    variable timeline_scale_max ""
    variable timeline_threshold_min ""
    variable timeline_threshold_max ""
    variable timeline_filter_min "0.0"
    variable timeline_filter_max "1.0"
    variable timeline_filter_first "0"
    variable timeline_filter_last "-1"
    variable timeline_filter_frames "1"
    variable timeline_user_field "user2"
    variable timeline_residue_function ""
    variable timeline_residue_function_label "user residue function"
    variable timeline_residue_function_unit ""
    variable timeline_residue_function_context "protein or nucleic"
    variable timeline_cc_map_file ""
    variable timeline_cc_vol_id "auto"
    variable timeline_cc_map_res "5.0"
    variable timeline_cc_spacing ""
    variable timeline_cc_threshold ""
    variable timeline_cc_use_spacing "0"
    variable timeline_cc_use_threshold "0"
    variable timeline_cc_method "segments"
    variable timeline_cc_selection_list "{protein}"
    variable timeline_inter_method "residues_to_selection"
    variable timeline_inter_dist "4.0"
    variable timeline_inter_from_selection "protein"
    variable timeline_inter_to_selection "protein"
    variable timeline_inter_selection_list "{protein} {protein}"
    variable timeline_tml_file ""
    variable timeline_collection_dir ""
    variable timeline_export_file ""
    variable timeline_collection {}
    variable timeline_collection_index "0"
    variable show_display_advanced "0"
    variable show_native_advanced "0"
    variable show_view_advanced "0"
    variable show_output_advanced "0"
    variable status_widget ""
    variable close_pending 0

    proc set_status {message {append 0}} {
        variable status_widget

        if {$status_widget ne "" && [winfo exists $status_widget]} {
            $status_widget configure -state normal
            if {!$append} {
                $status_widget delete 1.0 end
            }
            $status_widget insert end "$message\n"
            $status_widget see end
            $status_widget configure -state disabled
        }
        puts $message
    }

    proc native_progress {event} {
        set message [expr {[dict exists $event message] ? [dict get $event message] : [dict get $event stage]}]
        if {[dict exists $event slice] && [dict exists $event slice_count]} {
            append message " ([dict get $event slice]/[dict get $event slice_count])"
        } elseif {[dict exists $event chain] && [dict exists $event chain_index] && [dict exists $event chain_count]} {
            append message " ([dict get $event chain_index]/[dict get $event chain_count])"
        }
        set_status $message 1
        return [::RMSXFlipbookTimeline::Operation::checkpoint $event]
    }

    proc format_result {result} {
        set lines {}
        if {[dict exists $result files]} {
            lappend lines "Loaded [dict get $result molecules] molecules from [dict get $result files] slice files."
        } else {
            lappend lines "Applied settings to [dict get $result molecules] loaded molecules."
        }
        if {[dict exists $result raw_min]} {
            lappend lines [format "RMSX range: %.3f to %.3f" [dict get $result raw_min] [dict get $result raw_max]]
        }
        if {[dict exists $result value_source] && [dict get $result value_source] ne ""} {
            set source_line "Value source: [dict get $result value_source]"
            if {[dict exists $result value_file] && [dict get $result value_file] ne ""} {
                append source_line " ([file tail [dict get $result value_file]])"
            }
            lappend lines $source_line
        }
        if {[dict exists $result masked_residues] && [dict get $result masked_residues] > 0} {
            lappend lines "Masked residues: [dict get $result masked_residues]"
        }
        if {[dict exists $result spacing_mode]} {
            lappend lines [format "Spacing: %.2f A (%s)" [dict get $result spacing] [dict get $result spacing_mode]]
        } elseif {[dict exists $result spacing]} {
            lappend lines [format "Spacing: %.2f A" [dict get $result spacing]]
        }
        if {[dict exists $result manifest] && [dict get $result manifest] ne ""} {
            lappend lines "Manifest: [dict get $result manifest]"
        }
        return [join $lines "\n"]
    }

    proc quality_settings {name} {
        switch -- $name {
            Fast {
                return [dict create rep NewTube res 16 thick 0.22]
            }
            Balanced {
                return [dict create rep NewTube res 32 thick 0.30]
            }
            Screenshot {
                return [dict create rep NewTube res 80 thick 0.30]
            }
            default {
                return [dict create]
            }
        }
    }

    proc apply_quality {} {
        variable quality
        variable rep
        variable res
        variable thick

        set settings [quality_settings $quality]
        foreach key {rep res thick} {
            if {[dict exists $settings $key]} {
                set $key [dict get $settings $key]
            }
        }
    }

    proc validate_double {label value {min ""} {max ""}} {
        if {![string is double -strict $value]} {
            error "$label must be a number"
        }

        set number [expr {double($value)}]
        if {$min ne "" && $number < $min} {
            error "$label must be at least $min"
        }
        if {$max ne "" && $number > $max} {
            error "$label must be no greater than $max"
        }
        return $number
    }

    proc validate_int {label value {min ""} {max ""}} {
        if {![string is integer -strict $value]} {
            error "$label must be an integer"
        }

        set number [expr {int($value)}]
        if {$min ne "" && $number < $min} {
            error "$label must be at least $min"
        }
        if {$max ne "" && $number > $max} {
            error "$label must be no greater than $max"
        }
        return $number
    }

    proc collect_options {} {
        variable quality
        variable palette
        variable rep
        variable res
        variable thick
        variable spacing
        variable color_min
        variable color_max
        variable apply_mask
        variable mask_opacity

        set res_value [validate_int "Resolution" $res 4 160]
        set thick_value [validate_double "Thickness" $thick 0.01 5.0]
        set color_min_value [validate_double "Color minimum" $color_min]
        set color_max_value [validate_double "Color maximum" $color_max]
        if {$color_max_value <= $color_min_value} {
            error "Color maximum must be greater than color minimum"
        }
        set opacity_value [validate_double "Mask opacity" $mask_opacity 0.0 1.0]

        set spacing_clean [string trim $spacing]
        if {$spacing_clean eq "" || [string tolower $spacing_clean] eq "auto"} {
            set spacing_value auto
        } else {
            set spacing_value [validate_double "Spacing" $spacing_clean 0.01]
        }

        return [dict create \
            quality $quality \
            palette $palette \
            rep $rep \
            res $res_value \
            thick $thick_value \
            spacing $spacing_value \
            color_min $color_min_value \
            color_max $color_max_value \
            apply_mask $apply_mask \
            mask_opacity $opacity_value]
    }

    proc sync_controls_from_state {} {
        variable folder
        variable quality
        variable palette
        variable rep
        variable res
        variable thick
        variable spacing
        variable color_min
        variable color_max
        variable apply_mask
        variable mask_opacity
        variable native_topology
        variable native_trajectory
        variable native_output
        variable native_chain
        variable native_slices
        variable native_slice_size
        variable native_start
        variable native_end
        variable native_time_step
        variable native_metric
        variable native_analysis_type
        variable native_mask_selection
        variable mouse_mode
        variable mouse_sensitivity
        variable timeline_molid
        variable timeline_selection
        variable timeline_metric
        variable timeline_first
        variable timeline_last
        variable timeline_scale_mode
        variable timeline_scale_min
        variable timeline_scale_max
        variable timeline_threshold_min
        variable timeline_threshold_max
        variable timeline_filter_min
        variable timeline_filter_max
        variable timeline_filter_first
        variable timeline_filter_last
        variable timeline_filter_frames
        variable timeline_user_field
        variable timeline_residue_function
        variable timeline_residue_function_label
        variable timeline_residue_function_unit
        variable timeline_residue_function_context
        variable timeline_cc_map_file
        variable timeline_cc_vol_id
        variable timeline_cc_map_res
        variable timeline_cc_spacing
        variable timeline_cc_threshold
        variable timeline_cc_use_spacing
        variable timeline_cc_use_threshold
        variable timeline_cc_method
        variable timeline_cc_selection_list
        variable timeline_inter_method
        variable timeline_inter_dist
        variable timeline_inter_from_selection
        variable timeline_inter_to_selection
        variable timeline_inter_selection_list
        variable timeline_tml_file
        variable timeline_collection_dir
        variable timeline_collection_index

        set existing_folder [::RMSXFlipbookTimeline::state_get source_folder ""]
        if {$existing_folder ne ""} {
            set folder $existing_folder
        }

        set existing_topology [::RMSXFlipbookTimeline::state_get native_topology ""]
        if {$existing_topology ne ""} {
            set native_topology $existing_topology
        }

        set existing_trajectory [::RMSXFlipbookTimeline::state_get native_trajectory ""]
        if {$existing_trajectory ne ""} {
            set native_trajectory $existing_trajectory
        }

        set existing_output [::RMSXFlipbookTimeline::state_get native_output ""]
        if {$existing_output ne ""} {
            set native_output $existing_output
        }

        set existing_chain [::RMSXFlipbookTimeline::state_get native_chain ""]
        if {$existing_chain ne ""} {
            set native_chain $existing_chain
        }

        set existing_slices [::RMSXFlipbookTimeline::state_get native_slices ""]
        if {$existing_slices ne ""} {
            set native_slices $existing_slices
        }

        set existing_slice_size [::RMSXFlipbookTimeline::state_get native_slice_size ""]
        if {$existing_slice_size ne ""} {
            set native_slice_size $existing_slice_size
        }

        set existing_start [::RMSXFlipbookTimeline::state_get native_start ""]
        if {$existing_start ne ""} {
            set native_start $existing_start
        }

        set existing_end [::RMSXFlipbookTimeline::state_get native_end ""]
        if {$existing_end ne ""} {
            set native_end $existing_end
        }

        set existing_time_step [::RMSXFlipbookTimeline::state_get native_time_step ""]
        if {$existing_time_step ne ""} {
            set native_time_step $existing_time_step
        }

        set existing_metric [::RMSXFlipbookTimeline::state_get native_metric ""]
        if {$existing_metric ne ""} {
            set native_metric $existing_metric
        }

        set existing_analysis_type [::RMSXFlipbookTimeline::state_get native_analysis_type ""]
        if {$existing_analysis_type ne ""} {
            set native_analysis_type $existing_analysis_type
        }

        set existing_mask_selection [::RMSXFlipbookTimeline::state_get native_mask_selection ""]
        if {$existing_mask_selection ne ""} {
            set native_mask_selection $existing_mask_selection
        }

        set quality [::RMSXFlipbookTimeline::state_get quality $quality]
        set palette [::RMSXFlipbookTimeline::state_get palette $palette]
        set rep [::RMSXFlipbookTimeline::state_get rep $rep]
        set res [::RMSXFlipbookTimeline::state_get res $res]
        set thick [::RMSXFlipbookTimeline::state_get thick $thick]
        set color_min [::RMSXFlipbookTimeline::state_get color_min $color_min]
        set color_max [::RMSXFlipbookTimeline::state_get color_max $color_max]
        set apply_mask [::RMSXFlipbookTimeline::state_get apply_mask $apply_mask]
        set mask_opacity [::RMSXFlipbookTimeline::state_get mask_opacity $mask_opacity]

        if {[::RMSXFlipbookTimeline::state_get spacing_mode auto] eq "auto"} {
            set spacing auto
        } else {
            set spacing [::RMSXFlipbookTimeline::state_get spacing $spacing]
        }

        set mouse_mode [::RMSXFlipbookTimeline::state_get mouse_rotation_mode $mouse_mode]
        set mouse_sensitivity [::RMSXFlipbookTimeline::state_get mouse_rotation_sensitivity $mouse_sensitivity]
        set timeline_molid [::RMSXFlipbookTimeline::state_get timeline_molid $timeline_molid]
        set timeline_selection [::RMSXFlipbookTimeline::state_get timeline_selection $timeline_selection]
        set existing_timeline_metric [::RMSXFlipbookTimeline::state_get timeline_metric ""]
        if {$existing_timeline_metric ne ""} {
            set timeline_metric $existing_timeline_metric
        } elseif {$existing_metric ne ""} {
            set timeline_metric $existing_metric
        }
        set native_metric $timeline_metric
        set timeline_first [::RMSXFlipbookTimeline::state_get timeline_first $timeline_first]
        set timeline_last [::RMSXFlipbookTimeline::state_get timeline_last $timeline_last]
        set timeline_scale_mode [::RMSXFlipbookTimeline::state_get timeline_scale_mode $timeline_scale_mode]
        set timeline_scale_min [::RMSXFlipbookTimeline::state_get timeline_scale_min $timeline_scale_min]
        set timeline_scale_max [::RMSXFlipbookTimeline::state_get timeline_scale_max $timeline_scale_max]
        set timeline_threshold_min [::RMSXFlipbookTimeline::state_get timeline_threshold_min $timeline_threshold_min]
        set timeline_threshold_max [::RMSXFlipbookTimeline::state_get timeline_threshold_max $timeline_threshold_max]
        set timeline_filter_min [::RMSXFlipbookTimeline::state_get timeline_filter_min $timeline_filter_min]
        set timeline_filter_max [::RMSXFlipbookTimeline::state_get timeline_filter_max $timeline_filter_max]
        set timeline_filter_first [::RMSXFlipbookTimeline::state_get timeline_filter_first $timeline_filter_first]
        set timeline_filter_last [::RMSXFlipbookTimeline::state_get timeline_filter_last $timeline_filter_last]
        set timeline_filter_frames [::RMSXFlipbookTimeline::state_get timeline_filter_frames $timeline_filter_frames]
        set timeline_user_field [::RMSXFlipbookTimeline::state_get timeline_user_field $timeline_user_field]
        set timeline_residue_function [::RMSXFlipbookTimeline::state_get timeline_residue_function $timeline_residue_function]
        set timeline_residue_function_label [::RMSXFlipbookTimeline::state_get timeline_residue_function_label $timeline_residue_function_label]
        set timeline_residue_function_unit [::RMSXFlipbookTimeline::state_get timeline_residue_function_unit $timeline_residue_function_unit]
        set timeline_residue_function_context [::RMSXFlipbookTimeline::state_get timeline_residue_function_context $timeline_residue_function_context]
        set timeline_cc_map_file [::RMSXFlipbookTimeline::state_get timeline_cc_map_file $timeline_cc_map_file]
        set timeline_cc_vol_id [::RMSXFlipbookTimeline::state_get timeline_cc_vol_id $timeline_cc_vol_id]
        set timeline_cc_map_res [::RMSXFlipbookTimeline::state_get timeline_cc_map_res $timeline_cc_map_res]
        set timeline_cc_spacing [::RMSXFlipbookTimeline::state_get timeline_cc_spacing $timeline_cc_spacing]
        set timeline_cc_threshold [::RMSXFlipbookTimeline::state_get timeline_cc_threshold $timeline_cc_threshold]
        set timeline_cc_use_spacing [::RMSXFlipbookTimeline::state_get timeline_cc_use_spacing $timeline_cc_use_spacing]
        set timeline_cc_use_threshold [::RMSXFlipbookTimeline::state_get timeline_cc_use_threshold $timeline_cc_use_threshold]
        set timeline_cc_method [::RMSXFlipbookTimeline::state_get timeline_cc_method $timeline_cc_method]
        set timeline_cc_selection_list [::RMSXFlipbookTimeline::state_get timeline_cc_selection_list $timeline_cc_selection_list]
        set timeline_inter_method [::RMSXFlipbookTimeline::state_get timeline_inter_method $timeline_inter_method]
        set timeline_inter_dist [::RMSXFlipbookTimeline::state_get timeline_inter_dist $timeline_inter_dist]
        set timeline_inter_from_selection [::RMSXFlipbookTimeline::state_get timeline_inter_from_selection $timeline_inter_from_selection]
        set timeline_inter_to_selection [::RMSXFlipbookTimeline::state_get timeline_inter_to_selection $timeline_inter_to_selection]
        set timeline_inter_selection_list [::RMSXFlipbookTimeline::state_get timeline_inter_selection_list $timeline_inter_selection_list]
        set timeline_tml_file [::RMSXFlipbookTimeline::state_get timeline_tml_file $timeline_tml_file]
        set timeline_collection_dir [::RMSXFlipbookTimeline::state_get timeline_collection_dir $timeline_collection_dir]
        set timeline_collection_index [::RMSXFlipbookTimeline::state_get timeline_collection_index $timeline_collection_index]
    }

    proc browse_folder {} {
        variable folder
        variable top

        set start $folder
        if {$start eq "" || ![file isdirectory $start]} {
            set current [::RMSXFlipbookTimeline::state_get source_folder ""]
            if {$current ne "" && [file isdirectory $current]} {
                set start $current
            } else {
                set start [pwd]
            }
        }

        set picked [tk_chooseDirectory -parent $top -initialdir $start -mustexist true]
        if {$picked ne ""} {
            set folder [file normalize $picked]
        }
    }

    proc browse_native_topology {} {
        variable native_topology
        variable top

        set start [file dirname $native_topology]
        if {$native_topology eq "" || ![file isdirectory $start]} {
            set start [pwd]
        }

        set picked [tk_getOpenFile \
            -parent $top \
            -initialdir $start \
            -filetypes {{"PDB files" {.pdb}} {"All files" {*}}}]
        if {$picked ne ""} {
            set native_topology [file normalize $picked]
        }
    }

    proc browse_native_trajectory {} {
        variable native_trajectory
        variable top

        set start [file dirname $native_trajectory]
        if {$native_trajectory eq "" || ![file isdirectory $start]} {
            set start [pwd]
        }

        set picked [tk_getOpenFile \
            -parent $top \
            -initialdir $start \
            -filetypes {{"DCD files" {.dcd}} {"All files" {*}}}]
        if {$picked ne ""} {
            set native_trajectory [file normalize $picked]
        }
    }

    proc browse_native_output {} {
        variable native_output
        variable top

        set start $native_output
        if {$start eq "" || ![file isdirectory $start]} {
            set start [pwd]
        }

        set picked [tk_chooseDirectory -parent $top -initialdir $start -mustexist false]
        if {$picked ne ""} {
            set native_output [file normalize $picked]
        }
    }

    proc browse_timeline_tml {} {
        variable timeline_tml_file
        variable top

        set start [file dirname $timeline_tml_file]
        if {$timeline_tml_file eq "" || ![file isdirectory $start]} {
            set start [pwd]
        }

        set picked [tk_getOpenFile \
            -parent $top \
            -initialdir $start \
            -filetypes {{"Timeline files" {.tml .TML}} {"All files" {*}}}]
        if {$picked ne ""} {
            set timeline_tml_file [file normalize $picked]
            ::RMSXFlipbookTimeline::state_set timeline_tml_file $timeline_tml_file
        }
    }

    proc browse_timeline_collection {} {
        variable timeline_collection_dir
        variable top

        set start $timeline_collection_dir
        if {$start eq "" || ![file isdirectory $start]} {
            set start [pwd]
        }

        set picked [tk_chooseDirectory -parent $top -initialdir $start -mustexist true]
        if {$picked ne ""} {
            set timeline_collection_dir [file normalize $picked]
            ::RMSXFlipbookTimeline::state_set timeline_collection_dir $timeline_collection_dir
        }
    }

    proc browse_timeline_cc_map {} {
        variable timeline_cc_map_file
        variable top

        set start [file dirname $timeline_cc_map_file]
        if {$timeline_cc_map_file eq "" || ![file isdirectory $start]} {
            set start [pwd]
        }

        set picked [tk_getOpenFile \
            -parent $top \
            -initialdir $start \
            -filetypes {{"Density maps" {.dx .map .mrc .ccp4 .situs}} {"All files" {*}}}]
        if {$picked ne ""} {
            set timeline_cc_map_file [file normalize $picked]
            ::RMSXFlipbookTimeline::state_set timeline_cc_map_file $timeline_cc_map_file
        }
    }

    proc choose_timeline_export_file {kind} {
        variable timeline_export_file
        variable top

        switch -- $kind {
            tml {
                set title "Export Timeline TML"
                set extension ".tml"
                set filetypes {{"Timeline files" {.tml}} {"All files" {*}}}
            }
            png {
                set title "Export Timeline PNG"
                set extension ".png"
                set filetypes {{"PNG images" {.png}} {"All files" {*}}}
            }
            default {
                set title "Export Timeline SVG"
                set extension ".svg"
                set filetypes {{"SVG images" {.svg}} {"All files" {*}}}
            }
        }

        set start [file dirname $timeline_export_file]
        if {$timeline_export_file eq "" || ![file isdirectory $start]} {
            set start [file normalize [file join [pwd] outputs]]
        }
        set initial [file tail $timeline_export_file]
        if {$initial eq ""} {
            set initial "timeline$extension"
        }

        set picked [tk_getSaveFile \
            -parent $top \
            -title $title \
            -initialdir $start \
            -initialfile $initial \
            -defaultextension $extension \
            -filetypes $filetypes]
        if {$picked ne ""} {
            set timeline_export_file [file normalize $picked]
            ::RMSXFlipbookTimeline::state_set timeline_export_file $timeline_export_file
        }
        return $timeline_export_file
    }

    proc load_selected_folder {} {
        variable folder

        if {$folder eq ""} {
            set_status "Choose an RMSX output folder first."
            return
        }
        if {![file isdirectory $folder]} {
            set_status "Folder does not exist: $folder"
            return
        }

        if {[catch {collect_options} options]} {
            set_status $options
            return
        }

        set_status "Loading RMSX flipbook folder...\n$folder"
        update idletasks

        if {[catch {
            ::RMSXFlipbookTimeline::load_folder $folder {*}$options write_manifest 1
        } result]} {
            set_status "Load failed:\n$result"
            return
        }

        set lines [list [format_result $result]]
        if {[catch {enable_mouse_rotation 1} mouse_result]} {
            lappend lines "Mouse rotation not enabled: $mouse_result"
        } else {
            lappend lines "Mouse rotation enabled: [format_mouse_status $mouse_result]"
        }
        set_status [join $lines "\n"]
    }

    proc apply_current_settings {} {
        if {[catch {collect_options} options]} {
            set_status $options
            return
        }

        if {[catch {
            ::RMSXFlipbookTimeline::apply_settings {*}$options write_manifest 1
        } result]} {
            set_status "Apply failed:\n$result"
            return
        }

        set_status [format_result $result]
    }

    proc reset_scene {} {
        if {[::RMSXFlipbookTimeline::Operation::running]} { set_status "Stop the active operation first."; return }
        ::RMSXFlipbookTimeline::reset 1
        set_status "RMSX Flipbook Timeline scene cleared."
    }

    proc reset_view {} {
        ::RMSXFlipbookTimeline::reset_view
        set_status "View reset."
    }

    proc close_window {} {
        variable top
        variable close_pending
        if {[::RMSXFlipbookTimeline::Operation::running]} {
            set close_pending 1
            ::RMSXFlipbookTimeline::Operation::request_cancel
            return
        }
        set close_pending 0
        if {[catch {::RMSXFlipbookTimeline::cleanup_side_effects 0 {window input}} result]} {
            set_status "Cleanup warning while closing:\n$result"
        }
        if {[winfo exists $top]} {
            wm withdraw $top
        }
        return 1
    }

    proc format_mouse_status {status} {
        return [::RMSXFlipbookTimeline::mouse_rotation_format_status $status]
    }

    proc toggle_mouse_rotation {} {
        variable mouse_mode
        variable mouse_sensitivity

        set status [::RMSXFlipbookTimeline::mouse_rotation_status]
        if {[dict get $status enabled]} {
            set result [::RMSXFlipbookTimeline::uninstall_mouse_rotation]
            set_status "Mouse rotation disabled."
        } else {
            if {[catch {enable_mouse_rotation 1} result]} {
                set_status "Mouse rotation failed:\n$result"
                return
            }
            set_status "Mouse rotation enabled.\n[format_mouse_status $result]"
        }
        puts $result
    }

    proc enable_mouse_rotation {{reset_stats 1}} {
        variable mouse_mode
        variable mouse_sensitivity

        set sensitivity [validate_double "Mouse sensitivity" $mouse_sensitivity 0.01]
        set result [::RMSXFlipbookTimeline::install_mouse_rotation $mouse_mode $sensitivity]
        if {$reset_stats} {
            set result [::RMSXFlipbookTimeline::mouse_rotation_reset_stats]
        }
        set mouse_mode [dict get $result mode]
        set mouse_sensitivity [format "%.2f" [dict get $result sensitivity]]
        return $result
    }

    proc show_mouse_status {} {
        if {[catch {::RMSXFlipbookTimeline::mouse_rotation_status} result]} {
            set_status "Mouse rotation status failed:\n$result"
            return
        }
        set_status "Mouse rotation:\n[format_mouse_status $result]"
    }

    proc reset_mouse_stats {} {
        if {[catch {::RMSXFlipbookTimeline::mouse_rotation_reset_stats} result]} {
            set_status "Mouse rotation stats reset failed:\n$result"
            return
        }
        set_status "Mouse rotation stats reset.\n[format_mouse_status $result]"
    }

    proc run_mouse_burst {} {
        variable mouse_mode
        variable mouse_sensitivity
        variable mouse_burst_count
        variable mouse_burst_axis
        variable mouse_burst_angle

        if {[catch {
            set count [validate_int "Burst count" $mouse_burst_count 1]
            set axis [string tolower [string trim $mouse_burst_axis]]
            if {$axis ni {x y z}} {
                error "Burst axis must be x, y, or z"
            }
            set angle [validate_double "Burst angle" $mouse_burst_angle]
            set sensitivity [validate_double "Mouse sensitivity" $mouse_sensitivity 0.01]
            set status [::RMSXFlipbookTimeline::mouse_rotation_status]
            if {![dict get $status enabled]} {
                ::RMSXFlipbookTimeline::install_mouse_rotation $mouse_mode $sensitivity
            } else {
                ::RMSXFlipbookTimeline::mouse_rotation_set_sensitivity $sensitivity
            }
            ::RMSXFlipbookTimeline::mouse_rotation_burst $count $axis $angle
        } result]} {
            set_status "Mouse burst failed:\n$result"
            return
        }

        set mouse_mode [dict get $result mode]
        set mouse_sensitivity [format "%.2f" [dict get $result sensitivity]]
        set_status [format "Mouse burst complete: %d x %s %.3f\nTotal %.3f ms, loop avg %.3f ms\n%s" \
            [dict get $result burst_count] \
            [dict get $result burst_axis] \
            [dict get $result burst_angle] \
            [dict get $result burst_total_ms] \
            [dict get $result burst_loop_avg_ms] \
            [format_mouse_status $result]]
    }

    proc nudge_spacing {delta} {
        variable spacing
        if {[catch {::RMSXFlipbookTimeline::adjust_spacing $delta} result]} {
            set_status "Spacing adjustment failed:\n$result"
            return
        }
        set spacing [format "%.2f" [dict get $result spacing]]
        set_status [format "Spacing: %.2f A" [dict get $result spacing]]
    }

    proc nudge_thickness {delta} {
        variable thick
        if {[catch {::RMSXFlipbookTimeline::adjust_thickness $delta} result]} {
            set_status "Thickness adjustment failed:\n$result"
            return
        }
        set thick [format "%.2f" [dict get $result thick]]
        set_status [format "Thickness: %.2f" [dict get $result thick]]
    }

    proc update_advanced_visibility {} {
        variable top
        variable show_display_advanced
        variable show_native_advanced
        variable show_view_advanced
        variable show_output_advanced

        if {![winfo exists $top]} {
            return
        }

        set controls $top.controls
        if {[winfo exists $controls.res_label]} {
            if {$show_display_advanced} {
                grid $controls.res_label -row 4 -column 0 -sticky w -padx {0 8} -pady 4
                grid $controls.res_entry -row 4 -column 1 -sticky ew -pady 4
                grid $controls.color_min_label -row 4 -column 2 -sticky e -padx {16 8} -pady 4
                grid $controls.color_min_entry -row 4 -column 3 -sticky ew -pady 4
                grid $controls.color_max_label -row 4 -column 4 -sticky e -padx {16 8} -pady 4
                grid $controls.color_max_entry -row 4 -column 5 -sticky ew -pady 4
                grid $controls.opacity_label -row 5 -column 0 -sticky w -padx {0 8} -pady 4
                grid $controls.opacity_entry -row 5 -column 1 -sticky ew -pady 4
            } else {
                foreach widget {
                    res_label res_entry color_min_label color_min_entry
                    color_max_label color_max_entry opacity_label opacity_entry
                } {
                    catch {grid remove $controls.$widget}
                }
            }
        }

        set native $top.native
        if {[winfo exists $native.slice_size_label]} {
            if {$show_native_advanced} {
                grid $native.slice_size_label -row 6 -column 0 -sticky w -padx {0 8} -pady 3
                grid $native.slice_size_entry -row 6 -column 1 -sticky ew -pady 3
                grid $native.type_label -row 6 -column 2 -sticky e -padx {16 8} -pady 3
                grid $native.type_combo -row 6 -column 3 -sticky ew -pady 3
                grid $native.time_step_label -row 6 -column 4 -sticky e -padx {16 8} -pady 3
                grid $native.time_step_entry -row 6 -column 5 -columnspan 4 -sticky ew -pady 3
                grid $native.log_check -row 7 -column 1 -columnspan 2 -sticky w -pady 3
            } else {
                foreach widget {
                    slice_size_label slice_size_entry type_label type_combo
                    time_step_label time_step_entry log_check
                } {
                    catch {grid remove $native.$widget}
                }
            }
        }

        if {[winfo exists $top.view]} {
            if {$show_view_advanced} {
                grid $top.view -row 3 -column 0 -sticky ew -padx 10 -pady {0 8}
            } else {
                catch {grid remove $top.view}
            }
        }

        set actions $top.actions
        if {[winfo exists $actions.repair]} {
            if {$show_output_advanced} {
                grid $actions.repair -row 3 -column 0 -sticky ew -padx {0 8} -pady {8 0}
                grid $actions.heatmap -row 3 -column 1 -sticky ew -padx {0 8} -pady {8 0}
                grid $actions.report -row 3 -column 2 -sticky ew -padx {0 8} -pady {8 0}
                grid $actions.render -row 3 -column 3 -sticky ew -padx {0 8} -pady {8 0}
                grid $actions.manifest -row 3 -column 4 -sticky ew -padx {0 8} -pady {8 0}
                grid $actions.load_manifest -row 3 -column 5 -sticky ew -pady {8 0}
            } else {
                foreach widget {
                    repair heatmap report render manifest load_manifest
                } {
                    catch {grid remove $actions.$widget}
                }
            }
        }
    }

    proc require_selected_folder {} {
        variable folder

        if {$folder eq ""} {
            error "Choose an RMSX output folder first."
        }
        if {![file isdirectory $folder]} {
            error "Folder does not exist: $folder"
        }
        return $folder
    }

    proc repair_selected_folder {} {
        if {[catch {require_selected_folder} selected_folder]} {
            set_status $selected_folder
            return
        }

        set_status "Repairing slice PDB B-factors...\n$selected_folder"
        update idletasks

        if {[catch {
            ::RMSXFlipbookTimeline::repair_folder_bfactors $selected_folder
        } result]} {
            set_status "B-factor repair failed:\n$result"
            return
        }

        set lines [list "B-factor repair complete."]
        lappend lines "CSV: [dict get $result csv]"
        lappend lines "Updated PDBs: [dict get $result updated_count]"
        set_status [join $lines "\n"]
    }

    proc write_heatmap_for_selected_folder {} {
        if {[catch {require_selected_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        if {[catch {collect_options} options]} {
            set_status $options
            return
        }

        set_status "Writing RMSX heatmap SVG...\n$selected_folder"
        update idletasks

        if {[catch {
            ::RMSXFlipbookTimeline::write_heatmap_svg \
                $selected_folder \
                -palette [dict get $options palette]
        } result]} {
            set_status "Heatmap export failed:\n$result"
            return
        }

        set lines [list "Heatmap SVG written."]
        lappend lines "SVG: [dict get $result svg]"
        lappend lines "CSV: [dict get $result csv]"
        lappend lines "Palette: [dict get $result palette]"
        lappend lines "Residues: [dict get $result residue_count]"
        lappend lines "Slices: [dict get $result slice_count]"
        lappend lines [format "Range: %.3f to %.3f" [dict get $result min] [dict get $result max]]
        set_status [join $lines "\n"]
    }

    proc show_plot_window_for_selected_folder {} {
        if {[catch {require_selected_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        if {[catch {collect_options} options]} {
            set_status $options
            return
        }

        set_status "Opening 2D plot window...\n$selected_folder"
        update idletasks

        if {[catch {
            ::RMSXFlipbookTimeline::show_plot_window \
                folder $selected_folder \
                palette [dict get $options palette]
        } result]} {
            set_status "Plot window failed:\n$result"
            return
        }

        set lines [list "2D plot window opened."]
        lappend lines "Cells: [dict get $result cells]"
        lappend lines "Slice points: [dict get $result summary_points]"
        lappend lines "Residues: [dict get $result rows]"
        lappend lines "Slices: [dict get $result columns]"
        lappend lines "Palette: [dict get $result palette]"
        lappend lines "Click cells or slice points in the plot. Structure picks map back while the plot is open."
        set_status [join $lines "\n"]
    }

    proc show_viewer_plot_for_selected_folder {} {
        return [show_plot_window_for_selected_folder]
    }

    proc write_report_for_selected_folder {} {
        if {[catch {require_selected_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        if {[catch {collect_options} options]} {
            set_status $options
            return
        }

        set_status "Writing native report SVG...\n$selected_folder"
        update idletasks

        if {[catch {
            ::RMSXFlipbookTimeline::write_report_svg \
                $selected_folder \
                -palette [dict get $options palette]
        } result]} {
            set_status "Report export failed:\n$result"
            return
        }

        set lines [list "Report SVG written."]
        lappend lines "SVG: [dict get $result svg]"
        lappend lines "CSV: [dict get $result csv]"
        lappend lines "Metric: [dict get $result metric_label]"
        lappend lines "Palette: [dict get $result palette]"
        lappend lines "Residues: [dict get $result residue_count]"
        lappend lines "Slices: [dict get $result slice_count]"
        lappend lines [format "Range: %.3f to %.3f" [dict get $result min] [dict get $result max]]
        set_status [join $lines "\n"]
    }

    proc render_loaded_scene {} {
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $molids] == 0} {
            set_status "Load a flipbook folder before rendering."
            return
        }
        if {[catch {collect_options} options]} {
            set_status $options
            return
        }

        set_status "Rendering loaded flipbook scene with VMD TachyonInternal..."
        update idletasks

        if {[catch {
            ::RMSXFlipbookTimeline::apply_settings {*}$options
            ::RMSXFlipbookTimeline::render_flipbook_image \
                -method TachyonInternal \
                -width 2000 \
                -height 1000 \
                -view_preset rmsx
        } result]} {
            set_status "Render failed:\n$result"
            return
        }

        set lines [list "Rendered flipbook scene."]
        lappend lines "Image: [dict get $result image]"
        lappend lines "Method: [dict get $result method]"
        lappend lines "Bytes: [dict get $result bytes]"
        set_status [join $lines "\n"]
    }

    proc timeline_resolve_molid {} {
        variable timeline_molid

        set value [string trim $timeline_molid]
        if {$value eq "" || [string tolower $value] eq "top"} {
            if {[info commands molinfo] eq "" || [molinfo num] <= 0} {
                error "Load a trajectory molecule first, or enter a molecule id."
            }
            set molid [molinfo top]
        } elseif {[string is integer -strict $value]} {
            set molid [expr {int($value)}]
        } else {
            error "Timeline molecule must be 'top' or a numeric molecule id."
        }

        if {[info commands molinfo] ne "" && [lsearch -exact [molinfo list] $molid] == -1} {
            error "Molecule is not loaded: $molid"
        }
        ::RMSXFlipbookTimeline::state_set timeline_molid $value
        return $molid
    }

    proc timeline_plot_options {} {
        variable palette
        variable timeline_scale_mode
        variable timeline_scale_min
        variable timeline_scale_max
        variable timeline_threshold_min
        variable timeline_threshold_max

        set opts [list palette $palette scale_mode $timeline_scale_mode]
        set scale_min_clean [string trim $timeline_scale_min]
        set scale_max_clean [string trim $timeline_scale_max]
        if {$scale_min_clean ne "" || $scale_max_clean ne ""} {
            if {$scale_min_clean eq "" || $scale_max_clean eq ""} {
                error "Timeline color scale needs both minimum and maximum values."
            }
            set scale_min_value [validate_double "Timeline color scale minimum" $scale_min_clean]
            set scale_max_value [validate_double "Timeline color scale maximum" $scale_max_clean]
            if {$scale_max_value <= $scale_min_value} {
                error "Timeline color scale maximum must be greater than minimum"
            }
            lappend opts scale_min $scale_min_value scale_max $scale_max_value
        }
        set min_clean [string trim $timeline_threshold_min]
        set max_clean [string trim $timeline_threshold_max]
        if {$min_clean ne "" || $max_clean ne ""} {
            if {$min_clean eq "" || $max_clean eq ""} {
                error "Timeline threshold needs both minimum and maximum values."
            }
            lappend opts threshold_min [validate_double "Timeline threshold minimum" $min_clean]
            lappend opts threshold_max [validate_double "Timeline threshold maximum" $max_clean]
        }
        ::RMSXFlipbookTimeline::state_set timeline_scale_mode $timeline_scale_mode
        ::RMSXFlipbookTimeline::state_set timeline_scale_min $timeline_scale_min
        ::RMSXFlipbookTimeline::state_set timeline_scale_max $timeline_scale_max
        ::RMSXFlipbookTimeline::state_set timeline_threshold_min $timeline_threshold_min
        ::RMSXFlipbookTimeline::state_set timeline_threshold_max $timeline_threshold_max
        return $opts
    }

    proc timeline_live_options {} {
        variable timeline_selection
        variable timeline_user_field
        variable timeline_residue_function
        variable timeline_residue_function_label
        variable timeline_residue_function_unit
        variable timeline_residue_function_context
        variable timeline_cc_map_file
        variable timeline_cc_vol_id
        variable timeline_cc_map_res
        variable timeline_cc_spacing
        variable timeline_cc_threshold
        variable timeline_cc_use_spacing
        variable timeline_cc_use_threshold
        variable timeline_cc_method
        variable timeline_cc_selection_list
        variable timeline_inter_method
        variable timeline_inter_dist
        variable timeline_inter_from_selection
        variable timeline_inter_to_selection
        variable timeline_inter_selection_list
        variable timeline_first
        variable timeline_last

        set opts [list \
            selection $timeline_selection \
            first_frame [validate_int "Timeline first frame" $timeline_first 0] \
            last_frame [validate_int "Timeline last frame" $timeline_last -1] \
            user_field $timeline_user_field \
            residue_function [string trim $timeline_residue_function] \
            residue_function_label [string trim $timeline_residue_function_label] \
            residue_function_unit [string trim $timeline_residue_function_unit] \
            residue_function_context_selection [string trim $timeline_residue_function_context] \
            cc_map_file [string trim $timeline_cc_map_file] \
            cc_vol_id [string trim $timeline_cc_vol_id] \
            cc_map_res [validate_double "Timeline cross-correlation map resolution" $timeline_cc_map_res] \
            cc_spacing [string trim $timeline_cc_spacing] \
            cc_threshold [string trim $timeline_cc_threshold] \
            cc_use_spacing $timeline_cc_use_spacing \
            cc_use_threshold $timeline_cc_use_threshold \
            cc_method [string trim $timeline_cc_method] \
            cc_selection_list [string trim $timeline_cc_selection_list] \
            inter_method [string trim $timeline_inter_method] \
            inter_dist [validate_double "Timeline inter-selection contact cutoff" $timeline_inter_dist] \
            inter_from_selection [string trim $timeline_inter_from_selection] \
            inter_to_selection [string trim $timeline_inter_to_selection] \
            inter_selection_list [string trim $timeline_inter_selection_list]]

        ::RMSXFlipbookTimeline::state_set timeline_user_field $timeline_user_field
        ::RMSXFlipbookTimeline::state_set timeline_residue_function [string trim $timeline_residue_function]
        ::RMSXFlipbookTimeline::state_set timeline_residue_function_label [string trim $timeline_residue_function_label]
        ::RMSXFlipbookTimeline::state_set timeline_residue_function_unit [string trim $timeline_residue_function_unit]
        ::RMSXFlipbookTimeline::state_set timeline_residue_function_context [string trim $timeline_residue_function_context]
        ::RMSXFlipbookTimeline::state_set timeline_cc_map_file [string trim $timeline_cc_map_file]
        ::RMSXFlipbookTimeline::state_set timeline_cc_vol_id [string trim $timeline_cc_vol_id]
        ::RMSXFlipbookTimeline::state_set timeline_cc_map_res [string trim $timeline_cc_map_res]
        ::RMSXFlipbookTimeline::state_set timeline_cc_spacing [string trim $timeline_cc_spacing]
        ::RMSXFlipbookTimeline::state_set timeline_cc_threshold [string trim $timeline_cc_threshold]
        ::RMSXFlipbookTimeline::state_set timeline_cc_use_spacing $timeline_cc_use_spacing
        ::RMSXFlipbookTimeline::state_set timeline_cc_use_threshold $timeline_cc_use_threshold
        ::RMSXFlipbookTimeline::state_set timeline_cc_method [string trim $timeline_cc_method]
        ::RMSXFlipbookTimeline::state_set timeline_cc_selection_list [string trim $timeline_cc_selection_list]
        ::RMSXFlipbookTimeline::state_set timeline_inter_method [string trim $timeline_inter_method]
        ::RMSXFlipbookTimeline::state_set timeline_inter_dist [string trim $timeline_inter_dist]
        ::RMSXFlipbookTimeline::state_set timeline_inter_from_selection [string trim $timeline_inter_from_selection]
        ::RMSXFlipbookTimeline::state_set timeline_inter_to_selection [string trim $timeline_inter_to_selection]
        ::RMSXFlipbookTimeline::state_set timeline_inter_selection_list [string trim $timeline_inter_selection_list]
        return $opts
    }

    proc format_timeline_result {headline result} {
        set lines [list $headline]
        lappend lines "Rows: [dict get $result rows]"
        lappend lines "Columns: [dict get $result columns]"
        if {[dict exists $result min] && [dict exists $result max]} {
            lappend lines [format "Range: %.4g to %.4g" [dict get $result min] [dict get $result max]]
        }
        if {[dict exists $result dataset]} {
            set dataset [dict get $result dataset]
            if {[dict exists $dataset title]} {
                lappend lines "Dataset: [dict get $dataset title]"
            }
            if {[dict exists $dataset value_label]} {
                lappend lines "Value: [dict get $dataset value_label]"
            }
        }
        return [join $lines "\n"]
    }

    proc show_live_timeline_matrix {} {
        variable native_metric
        variable timeline_metric

        if {[metric_is_native_flipbook $timeline_metric]} {
            set_status "Use Run Native for $timeline_metric; live Timeline metrics use the same dropdown for the other methods."
            return
        }

        if {[catch {
            set molid [timeline_resolve_molid]
            set plot_opts [timeline_plot_options]
            set live_opts [timeline_live_options]
            set native_metric $timeline_metric
            ::RMSXFlipbookTimeline::state_set native_metric $native_metric
            ::RMSXFlipbookTimeline::state_set timeline_metric $timeline_metric
            set result [::RMSXFlipbookTimeline::show_live_timeline \
                $molid \
                $timeline_metric \
                {*}$live_opts \
                {*}$plot_opts]
        } err]} {
            set_status "Timeline live plot failed:\n$err"
            return
        }

        set_status [format_timeline_result "Timeline live plot opened." $result]
    }

    proc load_timeline_tml_file {} {
        variable timeline_tml_file

        if {$timeline_tml_file eq ""} {
            browse_timeline_tml
        }
        if {$timeline_tml_file eq ""} {
            return
        }
        if {![file exists $timeline_tml_file]} {
            set_status "Timeline file does not exist:\n$timeline_tml_file"
            return
        }

        if {[catch {
            set plot_opts [timeline_plot_options]
            set result [::RMSXFlipbookTimeline::show_timeline_tml $timeline_tml_file {*}$plot_opts]
        } err]} {
            set_status "Timeline TML load failed:\n$err"
            return
        }

        set_status [format_timeline_result "Timeline TML loaded." $result]
    }

    proc load_timeline_rmsx_folder {} {
        if {[catch {require_selected_folder} selected_folder]} {
            set_status $selected_folder
            return
        }

        if {[catch {
            set plot_opts [timeline_plot_options]
            set result [::RMSXFlipbookTimeline::show_timeline_rmsx_folder $selected_folder {*}$plot_opts]
        } err]} {
            set_status "Timeline RMSX folder load failed:\n$err"
            return
        }

        set_status [format_timeline_result "Timeline RMSX folder loaded." $result]
    }

    proc load_timeline_collection_dir {} {
        variable timeline_collection_dir
        variable timeline_collection
        variable timeline_collection_index

        if {$timeline_collection_dir eq ""} {
            browse_timeline_collection
        }
        if {$timeline_collection_dir eq ""} {
            return
        }
        if {![file isdirectory $timeline_collection_dir]} {
            set_status "Timeline collection folder does not exist:\n$timeline_collection_dir"
            return
        }

        if {[catch {
            set timeline_collection [::RMSXFlipbookTimeline::load_timeline_collection $timeline_collection_dir]
            if {[llength $timeline_collection] == 0} {
                error "No .tml files found in $timeline_collection_dir"
            }
            set timeline_collection_index 0
            ::RMSXFlipbookTimeline::state_set timeline_collection_index $timeline_collection_index
            set result [show_timeline_collection_index $timeline_collection_index]
        } err]} {
            set_status "Timeline collection load failed:\n$err"
            return
        }

        return $result
    }

    proc show_timeline_collection_index {index_delta {relative 0}} {
        variable timeline_collection
        variable timeline_collection_dir
        variable timeline_collection_index

        set total [llength $timeline_collection]
        if {$total == 0} {
            error "Load a Timeline collection first."
        }

        if {$relative} {
            set index [expr {int($timeline_collection_index) + int($index_delta)}]
        } else {
            set index [expr {int($index_delta)}]
        }
        set index [expr {(($index % $total) + $total) % $total}]
        set timeline_collection_index $index
        ::RMSXFlipbookTimeline::state_set timeline_collection_index $timeline_collection_index

        set plot_opts [timeline_plot_options]
        set dataset [lindex $timeline_collection $index]
        set result [::RMSXFlipbookTimeline::show_timeline_dataset $dataset {*}$plot_opts]

        set lines [list [format_timeline_result "Timeline collection dataset opened." $result]]
        lappend lines "Dataset: [expr {$index + 1}] of $total"
        if {$timeline_collection_dir ne ""} {
            lappend lines "Folder: $timeline_collection_dir"
        }
        set_status [join $lines "\n"]
        return $result
    }

    proc previous_timeline_collection_dataset {} {
        if {[catch {show_timeline_collection_index -1 1} err]} {
            set_status "Timeline collection navigation failed:\n$err"
        }
    }

    proc next_timeline_collection_dataset {} {
        if {[catch {show_timeline_collection_index 1 1} err]} {
            set_status "Timeline collection navigation failed:\n$err"
        }
    }

    proc filter_timeline_matrix {} {
        variable timeline_filter_min
        variable timeline_filter_max
        variable timeline_filter_first
        variable timeline_filter_last
        variable timeline_filter_frames

        if {[catch {
            set min_value [validate_double "Timeline filter minimum" $timeline_filter_min]
            set max_value [validate_double "Timeline filter maximum" $timeline_filter_max]
            set first [validate_int "Timeline filter first frame" $timeline_filter_first 0]
            set last [validate_int "Timeline filter last frame" $timeline_filter_last -1]
            set frames [validate_int "Timeline passing frames" $timeline_filter_frames 1]
            set plot_opts [timeline_plot_options]
            set result [::RMSXFlipbookTimeline::filter_timeline_current \
                $min_value \
                $max_value \
                $first \
                $last \
                $frames \
                {*}$plot_opts]
        } err]} {
            set_status "Timeline filter failed:\n$err"
            return
        }

        set_status [format_timeline_result "Timeline filter applied." $result]
    }

    proc copy_timeline_user_field {} {
        variable timeline_user_field

        if {[catch {
            ::RMSXFlipbookTimeline::state_set timeline_user_field $timeline_user_field
            set result [::RMSXFlipbookTimeline::copy_timeline_to_user $timeline_user_field]
        } err]} {
            set_status "Timeline copy-to-user failed:\n$err"
            return
        }

        set_status [format "Copied Timeline values to %s.\nRows: %d\nColumns: %d" \
            [dict get $result field] \
            [dict get $result rows] \
            [dict get $result columns]]
    }

    proc export_timeline_matrix {kind} {
        variable timeline_export_file

        set filename [choose_timeline_export_file $kind]
        if {$filename eq ""} {
            return
        }

        if {[catch {
            switch -- $kind {
                tml {
                    set written [::RMSXFlipbookTimeline::write_current_timeline_tml $filename]
                    set label "Timeline TML exported."
                }
                png {
                    set plot_opts [timeline_plot_options]
                    set written [::RMSXFlipbookTimeline::write_current_timeline_png $filename {*}$plot_opts]
                    set label "Timeline PNG exported."
                }
                default {
                    set plot_opts [timeline_plot_options]
                    set written [::RMSXFlipbookTimeline::write_current_timeline_svg $filename {*}$plot_opts]
                    set label "Timeline SVG exported."
                }
            }
        } err]} {
            set_status "Timeline export failed:\n$err"
            return
        }

        set timeline_export_file $written
        ::RMSXFlipbookTimeline::state_set timeline_export_file $timeline_export_file
        set_status "$label\n$written"
    }

    proc metric_key {metric} {
        return [string tolower [string map {" " "_" "-" "_"} [string trim $metric]]]
    }

    proc metric_is_native_flipbook {metric} {
        set key [metric_key $metric]
        return [expr {$key in {rmsx shift shiftmap shift_map lddt lddt_map 1_lddt 1___lddt}}]
    }

    proc native_timeline_selection {} {
        variable timeline_selection
        variable native_analysis_type

        set selection [string trim $timeline_selection]
        if {$selection ne ""} {
            return $selection
        }
        switch -- [string tolower [string trim $native_analysis_type]] {
            dna -
            rna {
                return nucleic
            }
            generic {
                return all
            }
            default {
                return protein
            }
        }
    }

    proc run_native_timeline_metric {metric start_value end_value} {
        variable native_topology
        variable native_trajectory
        variable timeline_molid
        variable timeline_metric
        variable timeline_selection
        variable timeline_first
        variable timeline_last

        if {[info commands mol] eq ""} {
            set_status "Timeline metric '$metric' needs VMD molecule commands."
            return
        }

        if {[catch {
            set molid [mol new $native_topology waitfor all]
            mol addfile $native_trajectory waitfor all molid $molid
        } err]} {
            set_status "Could not load topology/trajectory for Timeline metric '$metric':\n$err"
            return
        }

        set timeline_molid $molid
        set timeline_metric $metric
        set timeline_selection [native_timeline_selection]
        set timeline_first $start_value
        set timeline_last $end_value
        ::RMSXFlipbookTimeline::state_set timeline_molid $timeline_molid
        ::RMSXFlipbookTimeline::state_set timeline_metric $timeline_metric
        ::RMSXFlipbookTimeline::state_set timeline_selection $timeline_selection
        ::RMSXFlipbookTimeline::state_set timeline_first $timeline_first
        ::RMSXFlipbookTimeline::state_set timeline_last $timeline_last

        if {[catch {
            set plot_opts [timeline_plot_options]
            set live_opts [timeline_live_options]
            set result [::RMSXFlipbookTimeline::show_live_timeline \
                $molid \
                $metric \
                {*}$live_opts \
                {*}$plot_opts]
        } err]} {
            set_status "Timeline metric '$metric' failed:\n$err"
            return
        }

        set_status [format_timeline_result "Timeline metric '$metric' opened from Native Analysis files." $result]
    }

    proc run_native_analysis {} {
        if {[::RMSXFlipbookTimeline::Operation::running]} { set_status "An operation is already running."; return }
        if {[info commands ::RMSXFlipbookTimeline::Dashboard::run_native_metric] eq ""} {
            source [file join [::RMSXFlipbookTimeline::package_root] gui dashboard_window.tcl]
        }
        foreach name {native_topology native_trajectory native_output native_chain native_slices native_slice_size native_start native_end native_time_step native_metric native_analysis_type native_log_transform native_mask_selection timeline_molid timeline_selection} {
            if {[info exists ::RMSXFlipbookTimeline::GUI::$name]} {
                set ::RMSXFlipbookTimeline::Dashboard::$name [set ::RMSXFlipbookTimeline::GUI::$name]
            }
        }
        set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode [expr {[string trim $::RMSXFlipbookTimeline::GUI::native_slice_size] ne "" ? "slice_size" : "slices"}]
        if {[catch {::RMSXFlipbookTimeline::Dashboard::run_native_metric} result]} { set_status "Run failed: $result"; return }
        set_status "Run complete."
        return $result
    }

    proc open_manifest {} {
        set manifest [::RMSXFlipbookTimeline::state_get manifest_path ""]
        if {$manifest eq "" || ![file exists $manifest]} {
            set_status "No manifest has been written yet."
            return
        }

        set fp [open $manifest r]
        set payload [read $fp]
        close $fp
        set_status $payload
    }

    proc load_manifest_file {} {
        variable folder
        variable top

        set start $folder
        if {$start eq "" || ![file isdirectory $start]} {
            set current [::RMSXFlipbookTimeline::state_get source_folder ""]
            if {$current ne "" && [file isdirectory $current]} {
                set start $current
            } else {
                set start [pwd]
            }
        }

        set picked [tk_getOpenFile \
            -parent $top \
            -initialdir $start \
            -title "Load RMSX Flipbook Timeline Manifest" \
            -filetypes {{"RMSX manifests" {.tcldict}} {"All files" {*}}}]
        if {$picked eq ""} {
            return
        }

        set_status "Loading RMSX flipbook manifest...\n$picked"
        update idletasks

        if {[catch {
            ::RMSXFlipbookTimeline::load_manifest $picked
        } result]} {
            set_status "Manifest load failed:\n$result"
            return
        }

        sync_controls_from_state
        set lines [list [format_result $result]]
        lappend lines "Loaded manifest: [dict get $result manifest_loaded]"
        if {[catch {enable_mouse_rotation 1} mouse_result]} {
            lappend lines "Mouse rotation not enabled: $mouse_result"
        } else {
            lappend lines "Mouse rotation enabled: [format_mouse_status $mouse_result]"
        }
        set_status [join $lines "\n"]
    }

    proc build {} {
        variable top
        variable status_widget
        variable metric_values

        if {[winfo exists $top]} {
            wm deiconify $top
            raise $top
            return $top
        }

        sync_controls_from_state

        toplevel $top
        wm title $top "RMSX Flipbook Timeline"
        wm minsize $top 1080 640

        grid columnconfigure $top 0 -weight 1
        grid rowconfigure $top 5 -weight 1

        set controls [ttk::frame $top.controls -padding 10]
        grid $controls -row 0 -column 0 -sticky ew
        foreach col {1 3 5} {
            grid columnconfigure $controls $col -weight 1
        }

        ttk::label $controls.folder_label -text "Folder"
        ttk::entry $controls.folder_entry -textvariable ::RMSXFlipbookTimeline::GUI::folder
        ttk::button $controls.folder_browse -text "Browse" -command ::RMSXFlipbookTimeline::GUI::browse_folder

        grid $controls.folder_label -row 0 -column 0 -sticky w -padx {0 8} -pady 4
        grid $controls.folder_entry -row 0 -column 1 -columnspan 4 -sticky ew -pady 4
        grid $controls.folder_browse -row 0 -column 5 -sticky ew -padx {8 0} -pady 4

        ttk::label $controls.quality_label -text "Quality"
        ttk::combobox $controls.quality_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::quality \
            -values {Fast Balanced Screenshot Custom} \
            -state readonly \
            -width 12
        bind $controls.quality_combo <<ComboboxSelected>> {::RMSXFlipbookTimeline::GUI::apply_quality}

        ttk::label $controls.palette_label -text "Palette"
        ttk::combobox $controls.palette_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::palette \
            -values {viridis magma inferno plasma cividis turbo BWR RWB RGB} \
            -state readonly \
            -width 12

        ttk::label $controls.rep_label -text "Style"
        ttk::combobox $controls.rep_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::rep \
            -values {NewTube NewCartoon Tube Licorice Lines} \
            -state readonly \
            -width 12

        grid $controls.quality_label -row 1 -column 0 -sticky w -padx {0 8} -pady 4
        grid $controls.quality_combo -row 1 -column 1 -sticky ew -pady 4
        grid $controls.palette_label -row 1 -column 2 -sticky e -padx {16 8} -pady 4
        grid $controls.palette_combo -row 1 -column 3 -sticky ew -pady 4
        grid $controls.rep_label -row 1 -column 4 -sticky e -padx {16 8} -pady 4
        grid $controls.rep_combo -row 1 -column 5 -sticky ew -pady 4

        ttk::label $controls.res_label -text "Resolution"
        ttk::entry $controls.res_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::res \
            -width 8
        ttk::label $controls.thick_label -text "Thickness"
        ttk::entry $controls.thick_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::thick \
            -width 8
        ttk::label $controls.spacing_label -text "Spacing"
        ttk::entry $controls.spacing_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::spacing \
            -width 10
        ttk::checkbutton $controls.display_advanced_check \
            -text "Advanced Display" \
            -variable ::RMSXFlipbookTimeline::GUI::show_display_advanced \
            -command ::RMSXFlipbookTimeline::GUI::update_advanced_visibility

        grid $controls.thick_label -row 2 -column 0 -sticky w -padx {0 8} -pady 4
        grid $controls.thick_entry -row 2 -column 1 -sticky ew -pady 4
        grid $controls.spacing_label -row 2 -column 2 -sticky e -padx {16 8} -pady 4
        grid $controls.spacing_entry -row 2 -column 3 -sticky ew -pady 4

        ttk::label $controls.color_min_label -text "Color Min"
        ttk::entry $controls.color_min_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::color_min \
            -width 8
        ttk::label $controls.color_max_label -text "Color Max"
        ttk::entry $controls.color_max_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::color_max \
            -width 8
        ttk::label $controls.opacity_label -text "Mask Opacity"
        ttk::entry $controls.opacity_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::mask_opacity \
            -width 8

        ttk::checkbutton $controls.mask_check \
            -text "Apply Mask" \
            -variable ::RMSXFlipbookTimeline::GUI::apply_mask
        grid $controls.mask_check -row 2 -column 4 -sticky w -padx {16 8} -pady 4
        grid $controls.display_advanced_check -row 2 -column 5 -sticky w -pady 4

        ttk::label $controls.metric_label -text "Metric"
        ttk::combobox $controls.metric_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_metric \
            -values $metric_values \
            -state readonly \
            -width 22
        grid $controls.metric_label -row 3 -column 0 -sticky w -padx {0 8} -pady 4
        grid $controls.metric_combo -row 3 -column 1 -columnspan 5 -sticky ew -pady 4

        set native [ttk::labelframe $top.native -text "Native Analysis" -padding 10]
        grid $native -row 1 -column 0 -sticky ew -padx 10 -pady {0 8}
        foreach col {1 3 5 7} {
            grid columnconfigure $native $col -weight 1
        }

        ttk::label $native.topology_label -text "Topology"
        ttk::entry $native.topology_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_topology
        ttk::button $native.topology_browse -text "Browse" -command ::RMSXFlipbookTimeline::GUI::browse_native_topology

        grid $native.topology_label -row 0 -column 0 -sticky w -padx {0 8} -pady 3
        grid $native.topology_entry -row 0 -column 1 -columnspan 4 -sticky ew -pady 3
        grid $native.topology_browse -row 0 -column 5 -sticky ew -padx {8 0} -pady 3

        ttk::label $native.trajectory_label -text "Trajectory"
        ttk::entry $native.trajectory_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_trajectory
        ttk::button $native.trajectory_browse -text "Browse" -command ::RMSXFlipbookTimeline::GUI::browse_native_trajectory

        grid $native.trajectory_label -row 1 -column 0 -sticky w -padx {0 8} -pady 3
        grid $native.trajectory_entry -row 1 -column 1 -columnspan 4 -sticky ew -pady 3
        grid $native.trajectory_browse -row 1 -column 5 -sticky ew -padx {8 0} -pady 3

        ttk::label $native.output_label -text "Output"
        ttk::entry $native.output_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_output
        ttk::button $native.output_browse -text "Browse" -command ::RMSXFlipbookTimeline::GUI::browse_native_output

        grid $native.output_label -row 2 -column 0 -sticky w -padx {0 8} -pady 3
        grid $native.output_entry -row 2 -column 1 -columnspan 4 -sticky ew -pady 3
        grid $native.output_browse -row 2 -column 5 -sticky ew -padx {8 0} -pady 3

        ttk::label $native.chain_label -text "Chain"
        ttk::entry $native.chain_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_chain -width 8
        ttk::label $native.slices_label -text "Slices"
        ttk::entry $native.slices_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_slices -width 8
        ttk::label $native.slice_size_label -text "Slice Size"
        ttk::entry $native.slice_size_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_slice_size -width 8
        ttk::label $native.frames_label -text "Frames"
        ttk::entry $native.start_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_start -width 8
        ttk::entry $native.end_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_end -width 8
        ttk::label $native.type_label -text "Type"
        ttk::combobox $native.type_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::native_analysis_type \
            -values {protein dna rna generic} \
            -width 10 \
            -state readonly
        ttk::label $native.time_step_label -text "Time Step"
        ttk::entry $native.time_step_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_time_step -width 10
        ttk::checkbutton $native.log_check \
            -text "Log Transform" \
            -variable ::RMSXFlipbookTimeline::GUI::native_log_transform
        ttk::label $native.mask_label -text "Mask"
        ttk::entry $native.mask_entry -textvariable ::RMSXFlipbookTimeline::GUI::native_mask_selection
        ttk::checkbutton $native.advanced_check \
            -text "Advanced Native" \
            -variable ::RMSXFlipbookTimeline::GUI::show_native_advanced \
            -command ::RMSXFlipbookTimeline::GUI::update_advanced_visibility

        grid $native.chain_label -row 3 -column 0 -sticky w -padx {0 8} -pady 3
        grid $native.chain_entry -row 3 -column 1 -sticky ew -pady 3
        grid $native.slices_label -row 3 -column 2 -sticky e -padx {16 8} -pady 3
        grid $native.slices_entry -row 3 -column 3 -sticky ew -pady 3
        grid $native.frames_label -row 3 -column 4 -sticky e -padx {16 8} -pady 3
        grid $native.start_entry -row 3 -column 5 -sticky ew -pady 3
        grid $native.end_entry -row 3 -column 6 -sticky ew -padx {8 0} -pady 3
        grid $native.mask_label -row 4 -column 0 -sticky w -padx {0 8} -pady 3
        grid $native.mask_entry -row 4 -column 1 -columnspan 8 -sticky ew -pady 3
        grid $native.advanced_check -row 5 -column 1 -columnspan 2 -sticky w -pady 3

        set timeline [ttk::labelframe $top.timeline -text "Timeline Matrix" -padding 10]
        grid $timeline -row 2 -column 0 -sticky ew -padx 10 -pady {0 8}
        foreach col {1 3 5 7} {
            grid columnconfigure $timeline $col -weight 1
        }
        foreach col {9 10 11 12} {
            grid columnconfigure $timeline $col -weight 1
        }

        ttk::label $timeline.molid_label -text "Molecule"
        ttk::entry $timeline.molid_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_molid \
            -width 8
        ttk::label $timeline.selection_label -text "Selection"
        ttk::entry $timeline.selection_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_selection
        ttk::label $timeline.frames_label -text "Frames"
        ttk::entry $timeline.first_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_first \
            -width 8
        ttk::entry $timeline.last_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_last \
            -width 8
        ttk::button $timeline.live -text "Live Plot" -command ::RMSXFlipbookTimeline::GUI::show_live_timeline_matrix

        grid $timeline.molid_label -row 0 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.molid_entry -row 0 -column 1 -sticky ew -pady 3
        grid $timeline.selection_label -row 0 -column 2 -sticky e -padx {16 8} -pady 3
        grid $timeline.selection_entry -row 0 -column 3 -columnspan 2 -sticky ew -pady 3
        grid $timeline.frames_label -row 0 -column 5 -sticky e -padx {16 8} -pady 3
        grid $timeline.first_entry -row 0 -column 6 -sticky ew -pady 3
        grid $timeline.last_entry -row 0 -column 7 -sticky ew -padx {8 0} -pady 3
        grid $timeline.live -row 0 -column 8 -sticky ew -padx {16 0} -pady 3

        ttk::label $timeline.tml_label -text "TML"
        ttk::entry $timeline.tml_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_tml_file
        ttk::button $timeline.tml_browse -text "Browse" -command ::RMSXFlipbookTimeline::GUI::browse_timeline_tml
        ttk::button $timeline.tml_load -text "Load TML" -command ::RMSXFlipbookTimeline::GUI::load_timeline_tml_file
        ttk::label $timeline.collection_label -text "Collection"
        ttk::entry $timeline.collection_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_collection_dir
        ttk::button $timeline.collection_browse -text "Browse" -command ::RMSXFlipbookTimeline::GUI::browse_timeline_collection
        ttk::button $timeline.collection_load -text "Load Collection" -command ::RMSXFlipbookTimeline::GUI::load_timeline_collection_dir
        ttk::button $timeline.collection_prev -text "Prev Data" -command ::RMSXFlipbookTimeline::GUI::previous_timeline_collection_dataset
        ttk::button $timeline.collection_next -text "Next Data" -command ::RMSXFlipbookTimeline::GUI::next_timeline_collection_dataset

        grid $timeline.tml_label -row 1 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.tml_entry -row 1 -column 1 -columnspan 3 -sticky ew -pady 3
        grid $timeline.tml_browse -row 1 -column 4 -sticky ew -padx {8 0} -pady 3
        grid $timeline.tml_load -row 1 -column 5 -sticky ew -padx {8 0} -pady 3
        grid $timeline.collection_label -row 1 -column 6 -sticky e -padx {16 8} -pady 3
        grid $timeline.collection_entry -row 1 -column 7 -columnspan 2 -sticky ew -pady 3
        grid $timeline.collection_browse -row 1 -column 9 -sticky ew -padx {8 0} -pady 3
        grid $timeline.collection_load -row 1 -column 10 -sticky ew -padx {8 0} -pady 3
        grid $timeline.collection_prev -row 1 -column 11 -sticky ew -padx {8 0} -pady 3
        grid $timeline.collection_next -row 1 -column 12 -sticky ew -padx {8 0} -pady 3

        ttk::label $timeline.scale_label -text "Scale"
        ttk::combobox $timeline.scale_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_scale_mode \
            -values {fit every_residue} \
            -state readonly \
            -width 12
        ttk::entry $timeline.scale_min_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_scale_min \
            -width 8
        ttk::entry $timeline.scale_max_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_scale_max \
            -width 8
        ttk::label $timeline.threshold_label -text "Threshold"
        ttk::entry $timeline.threshold_min_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_threshold_min \
            -width 8
        ttk::entry $timeline.threshold_max_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_threshold_max \
            -width 8
        ttk::label $timeline.filter_label -text "Filter"
        ttk::entry $timeline.filter_min_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_filter_min \
            -width 8
        ttk::entry $timeline.filter_max_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_filter_max \
            -width 8
        ttk::entry $timeline.filter_first_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_filter_first \
            -width 8
        ttk::entry $timeline.filter_last_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_filter_last \
            -width 8
        ttk::entry $timeline.filter_frames_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_filter_frames \
            -width 8
        ttk::button $timeline.filter_apply -text "Apply Filter" -command ::RMSXFlipbookTimeline::GUI::filter_timeline_matrix

        grid $timeline.scale_label -row 2 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.scale_combo -row 2 -column 1 -sticky ew -pady 3
        grid $timeline.scale_min_entry -row 2 -column 2 -sticky ew -padx {8 0} -pady 3
        grid $timeline.scale_max_entry -row 2 -column 3 -sticky ew -padx {8 0} -pady 3
        grid $timeline.threshold_label -row 2 -column 4 -sticky e -padx {16 8} -pady 3
        grid $timeline.threshold_min_entry -row 2 -column 5 -sticky ew -pady 3
        grid $timeline.threshold_max_entry -row 2 -column 6 -sticky ew -padx {8 0} -pady 3
        grid $timeline.filter_label -row 2 -column 7 -sticky e -padx {16 8} -pady 3
        grid $timeline.filter_min_entry -row 2 -column 8 -sticky ew -pady 3
        grid $timeline.filter_max_entry -row 2 -column 9 -sticky ew -padx {8 0} -pady 3
        grid $timeline.filter_first_entry -row 2 -column 10 -sticky ew -padx {8 0} -pady 3
        grid $timeline.filter_last_entry -row 2 -column 11 -sticky ew -padx {8 0} -pady 3
        grid $timeline.filter_frames_entry -row 2 -column 12 -sticky ew -padx {8 0} -pady 3
        grid $timeline.filter_apply -row 3 -column 11 -columnspan 2 -sticky ew -padx {8 0} -pady 3

        ttk::label $timeline.user_label -text "User Field"
        ttk::combobox $timeline.user_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_user_field \
            -values {user user2 user3 user4} \
            -state readonly \
            -width 8
        ttk::button $timeline.copy_user -text "Copy" -command ::RMSXFlipbookTimeline::GUI::copy_timeline_user_field
        ttk::button $timeline.export_tml -text "Export TML" -command {::RMSXFlipbookTimeline::GUI::export_timeline_matrix tml}
        ttk::button $timeline.export_svg -text "Export SVG" -command {::RMSXFlipbookTimeline::GUI::export_timeline_matrix svg}
        ttk::button $timeline.export_png -text "Export PNG" -command {::RMSXFlipbookTimeline::GUI::export_timeline_matrix png}
        ttk::button $timeline.rmsx_folder -text "Load RMSX Folder" -command ::RMSXFlipbookTimeline::GUI::load_timeline_rmsx_folder

        grid $timeline.user_label -row 3 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.user_combo -row 3 -column 1 -sticky ew -pady 3
        grid $timeline.copy_user -row 3 -column 2 -sticky ew -padx {16 8} -pady 3
        grid $timeline.export_tml -row 3 -column 3 -sticky ew -padx {0 8} -pady 3
        grid $timeline.export_svg -row 3 -column 4 -sticky ew -padx {0 8} -pady 3
        grid $timeline.export_png -row 3 -column 5 -sticky ew -padx {0 8} -pady 3
        grid $timeline.rmsx_folder -row 3 -column 6 -columnspan 2 -sticky ew -padx {16 8} -pady 3

        ttk::label $timeline.resfunc_label -text "Residue Proc"
        ttk::entry $timeline.resfunc_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_residue_function
        ttk::label $timeline.resfunc_context_label -text "Context"
        ttk::entry $timeline.resfunc_context_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_residue_function_context
        ttk::label $timeline.resfunc_value_label -text "Label"
        ttk::entry $timeline.resfunc_value_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_residue_function_label
        ttk::label $timeline.resfunc_unit_label -text "Unit"
        ttk::entry $timeline.resfunc_unit_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_residue_function_unit \
            -width 8

        grid $timeline.resfunc_label -row 4 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.resfunc_entry -row 4 -column 1 -columnspan 3 -sticky ew -pady 3
        grid $timeline.resfunc_context_label -row 4 -column 4 -sticky e -padx {16 8} -pady 3
        grid $timeline.resfunc_context_entry -row 4 -column 5 -columnspan 3 -sticky ew -pady 3
        grid $timeline.resfunc_value_label -row 4 -column 8 -sticky e -padx {16 8} -pady 3
        grid $timeline.resfunc_value_entry -row 4 -column 9 -columnspan 2 -sticky ew -pady 3
        grid $timeline.resfunc_unit_label -row 4 -column 11 -sticky e -padx {16 8} -pady 3
        grid $timeline.resfunc_unit_entry -row 4 -column 12 -sticky ew -pady 3

        ttk::label $timeline.cc_map_label -text "CC Map"
        ttk::entry $timeline.cc_map_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_cc_map_file
        ttk::button $timeline.cc_map_browse -text "Browse" -command ::RMSXFlipbookTimeline::GUI::browse_timeline_cc_map
        ttk::label $timeline.cc_vol_label -text "Vol"
        ttk::entry $timeline.cc_vol_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_cc_vol_id \
            -width 8
        ttk::label $timeline.cc_res_label -text "Res"
        ttk::entry $timeline.cc_res_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_cc_map_res \
            -width 8
        ttk::label $timeline.cc_method_label -text "Method"
        ttk::combobox $timeline.cc_method_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_cc_method \
            -values {segments selections} \
            -state readonly \
            -width 10
        ttk::checkbutton $timeline.cc_spacing_check \
            -text "Spacing" \
            -variable ::RMSXFlipbookTimeline::GUI::timeline_cc_use_spacing
        ttk::entry $timeline.cc_spacing_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_cc_spacing \
            -width 8
        ttk::checkbutton $timeline.cc_threshold_check \
            -text "Threshold" \
            -variable ::RMSXFlipbookTimeline::GUI::timeline_cc_use_threshold
        ttk::entry $timeline.cc_threshold_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_cc_threshold \
            -width 8

        grid $timeline.cc_map_label -row 5 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.cc_map_entry -row 5 -column 1 -columnspan 3 -sticky ew -pady 3
        grid $timeline.cc_map_browse -row 5 -column 4 -sticky ew -padx {8 0} -pady 3
        grid $timeline.cc_vol_label -row 5 -column 5 -sticky e -padx {16 8} -pady 3
        grid $timeline.cc_vol_entry -row 5 -column 6 -sticky ew -pady 3
        grid $timeline.cc_res_label -row 5 -column 7 -sticky e -padx {16 8} -pady 3
        grid $timeline.cc_res_entry -row 5 -column 8 -sticky ew -pady 3
        grid $timeline.cc_method_label -row 5 -column 9 -sticky e -padx {16 8} -pady 3
        grid $timeline.cc_method_combo -row 5 -column 10 -sticky ew -pady 3
        grid $timeline.cc_spacing_check -row 5 -column 11 -sticky e -padx {16 4} -pady 3
        grid $timeline.cc_spacing_entry -row 5 -column 12 -sticky ew -pady 3
        grid $timeline.cc_threshold_check -row 6 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.cc_threshold_entry -row 6 -column 1 -sticky ew -pady 3

        ttk::label $timeline.cc_selection_label -text "CC Selections"
        ttk::entry $timeline.cc_selection_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_cc_selection_list

        grid $timeline.cc_selection_label -row 6 -column 2 -sticky e -padx {16 8} -pady 3
        grid $timeline.cc_selection_entry -row 6 -column 3 -columnspan 10 -sticky ew -pady 3

        ttk::label $timeline.inter_method_label -text "Contact Method"
        ttk::combobox $timeline.inter_method_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_inter_method \
            -values {residues_to_selection pairs all} \
            -state readonly \
            -width 18
        ttk::label $timeline.inter_dist_label -text "Cutoff"
        ttk::entry $timeline.inter_dist_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_inter_dist \
            -width 8
        ttk::label $timeline.inter_from_label -text "From"
        ttk::entry $timeline.inter_from_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_inter_from_selection
        ttk::label $timeline.inter_to_label -text "To"
        ttk::entry $timeline.inter_to_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_inter_to_selection
        ttk::label $timeline.inter_list_label -text "Contact List"
        ttk::entry $timeline.inter_list_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::timeline_inter_selection_list

        grid $timeline.inter_method_label -row 7 -column 0 -sticky w -padx {0 8} -pady 3
        grid $timeline.inter_method_combo -row 7 -column 1 -sticky ew -pady 3
        grid $timeline.inter_dist_label -row 7 -column 2 -sticky e -padx {16 8} -pady 3
        grid $timeline.inter_dist_entry -row 7 -column 3 -sticky ew -pady 3
        grid $timeline.inter_from_label -row 7 -column 4 -sticky e -padx {16 8} -pady 3
        grid $timeline.inter_from_entry -row 7 -column 5 -columnspan 2 -sticky ew -pady 3
        grid $timeline.inter_to_label -row 7 -column 7 -sticky e -padx {16 8} -pady 3
        grid $timeline.inter_to_entry -row 7 -column 8 -columnspan 2 -sticky ew -pady 3
        grid $timeline.inter_list_label -row 7 -column 10 -sticky e -padx {16 8} -pady 3
        grid $timeline.inter_list_entry -row 7 -column 11 -columnspan 2 -sticky ew -pady 3

        set view [ttk::labelframe $top.view -text "Advanced View Controls" -padding 10]
        grid $view -row 3 -column 0 -sticky ew -padx 10 -pady {0 8}
        foreach col {1 3 5 7} {
            grid columnconfigure $view $col -weight 1
        }

        ttk::label $view.mode_label -text "Mouse"
        ttk::combobox $view.mode_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::mouse_mode \
            -values {coords display} \
            -state readonly \
            -width 8
        ttk::label $view.sensitivity_label -text "Sensitivity"
        ttk::entry $view.sensitivity_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::mouse_sensitivity \
            -width 8
        ttk::button $view.mouse_toggle -text "Mouse On/Off" -command ::RMSXFlipbookTimeline::GUI::toggle_mouse_rotation
        ttk::button $view.mouse_status -text "Status" -command ::RMSXFlipbookTimeline::GUI::show_mouse_status
        ttk::button $view.mouse_reset -text "Reset Stats" -command ::RMSXFlipbookTimeline::GUI::reset_mouse_stats

        grid $view.mode_label -row 0 -column 0 -sticky w -padx {0 8} -pady 3
        grid $view.mode_combo -row 0 -column 1 -sticky ew -pady 3
        grid $view.sensitivity_label -row 0 -column 2 -sticky e -padx {16 8} -pady 3
        grid $view.sensitivity_entry -row 0 -column 3 -sticky ew -pady 3
        grid $view.mouse_toggle -row 0 -column 4 -sticky ew -padx {16 8} -pady 3
        grid $view.mouse_status -row 0 -column 5 -sticky ew -padx {0 8} -pady 3
        grid $view.mouse_reset -row 0 -column 6 -sticky ew -pady 3

        ttk::label $view.burst_count_label -text "Burst"
        ttk::entry $view.burst_count_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::mouse_burst_count \
            -width 8
        ttk::combobox $view.burst_axis_combo \
            -textvariable ::RMSXFlipbookTimeline::GUI::mouse_burst_axis \
            -values {x y z} \
            -state readonly \
            -width 4
        ttk::entry $view.burst_angle_entry \
            -textvariable ::RMSXFlipbookTimeline::GUI::mouse_burst_angle \
            -width 8
        ttk::button $view.burst_run -text "Run Burst" -command ::RMSXFlipbookTimeline::GUI::run_mouse_burst

        grid $view.burst_count_label -row 1 -column 0 -sticky w -padx {0 8} -pady 3
        grid $view.burst_count_entry -row 1 -column 1 -sticky ew -pady 3
        grid $view.burst_axis_combo -row 1 -column 2 -sticky ew -padx {16 8} -pady 3
        grid $view.burst_angle_entry -row 1 -column 3 -sticky ew -pady 3
        grid $view.burst_run -row 1 -column 4 -sticky ew -padx {16 8} -pady 3

        set actions [ttk::frame $top.actions -padding {10 0 10 8}]
        grid $actions -row 4 -column 0 -sticky ew
        foreach col {0 1 2 3 4 5} {
            grid columnconfigure $actions $col -weight 1
        }

        ttk::button $actions.load -text "Load" -command ::RMSXFlipbookTimeline::GUI::load_selected_folder
        ttk::button $actions.native -text "Run Native" -command ::RMSXFlipbookTimeline::GUI::run_native_analysis
        ttk::button $actions.apply -text "Apply" -command ::RMSXFlipbookTimeline::GUI::apply_current_settings
        ttk::button $actions.repair -text "Repair B-Factors" -command ::RMSXFlipbookTimeline::GUI::repair_selected_folder
        ttk::button $actions.viewer_plot -text "Plot Window" -command ::RMSXFlipbookTimeline::GUI::show_plot_window_for_selected_folder
        ttk::button $actions.heatmap -text "Heatmap SVG" -command ::RMSXFlipbookTimeline::GUI::write_heatmap_for_selected_folder
        ttk::button $actions.report -text "Report SVG" -command ::RMSXFlipbookTimeline::GUI::write_report_for_selected_folder
        ttk::button $actions.render -text "Render TGA" -command ::RMSXFlipbookTimeline::GUI::render_loaded_scene
        ttk::button $actions.view -text "Reset View" -command ::RMSXFlipbookTimeline::GUI::reset_view
        ttk::button $actions.load_manifest -text "Load Manifest" -command ::RMSXFlipbookTimeline::GUI::load_manifest_file
        ttk::button $actions.manifest -text "Manifest" -command ::RMSXFlipbookTimeline::GUI::open_manifest
        ttk::button $actions.reset -text "Clear" -command ::RMSXFlipbookTimeline::GUI::reset_scene
        ttk::label $actions.quick_label -text "View Adjust"
        ttk::button $actions.spacing_minus -text "Spacing −" -width 12 -command {::RMSXFlipbookTimeline::GUI::nudge_spacing -2.0}
        ttk::button $actions.spacing_plus -text "Spacing +" -width 12 -command {::RMSXFlipbookTimeline::GUI::nudge_spacing 2.0}
        ttk::button $actions.thinner -text "Thinner" -command {::RMSXFlipbookTimeline::GUI::nudge_thickness -0.05}
        ttk::button $actions.thicker -text "Thicker" -command {::RMSXFlipbookTimeline::GUI::nudge_thickness 0.05}
        ttk::checkbutton $actions.view_advanced_check \
            -text "Advanced View" \
            -variable ::RMSXFlipbookTimeline::GUI::show_view_advanced \
            -command ::RMSXFlipbookTimeline::GUI::update_advanced_visibility
        ttk::checkbutton $actions.output_advanced_check \
            -text "Advanced Outputs" \
            -variable ::RMSXFlipbookTimeline::GUI::show_output_advanced \
            -command ::RMSXFlipbookTimeline::GUI::update_advanced_visibility

        grid $actions.load -row 0 -column 0 -sticky ew -padx {0 8}
        grid $actions.native -row 0 -column 1 -sticky ew -padx {0 8}
        grid $actions.apply -row 0 -column 2 -sticky ew -padx {0 8}
        grid $actions.viewer_plot -row 0 -column 3 -sticky ew -padx {0 8}
        grid $actions.view -row 0 -column 4 -sticky ew -padx {0 8}
        grid $actions.reset -row 0 -column 5 -sticky ew
        grid $actions.quick_label -row 1 -column 0 -sticky w -pady {8 0}
        grid $actions.spacing_minus -row 1 -column 1 -sticky ew -padx {0 8} -pady {8 0}
        grid $actions.spacing_plus -row 1 -column 2 -sticky ew -padx {0 8} -pady {8 0}
        grid $actions.thinner -row 1 -column 3 -sticky ew -padx {0 8} -pady {8 0}
        grid $actions.thicker -row 1 -column 4 -sticky ew -padx {0 8} -pady {8 0}
        grid $actions.view_advanced_check -row 2 -column 0 -columnspan 2 -sticky w -pady {8 0}
        grid $actions.output_advanced_check -row 2 -column 2 -columnspan 2 -sticky w -padx {0 8} -pady {8 0}

        set status_frame [ttk::frame $top.status_frame -padding {10 0 10 10}]
        grid $status_frame -row 5 -column 0 -sticky nsew
        grid columnconfigure $status_frame 0 -weight 1
        grid rowconfigure $status_frame 0 -weight 1

        set status_widget [text $status_frame.status \
            -height 9 \
            -wrap word \
            -state disabled \
            -font TkFixedFont]
        set yscroll [ttk::scrollbar $status_frame.yscroll -orient vertical -command "$status_widget yview"]
        $status_widget configure -yscrollcommand "$yscroll set"

        grid $status_widget -row 0 -column 0 -sticky nsew
        grid $yscroll -row 0 -column 1 -sticky ns

        wm protocol $top WM_DELETE_WINDOW ::RMSXFlipbookTimeline::GUI::close_window
        update_advanced_visibility
        set_status "Ready."

        return $top
    }

    proc show {} {
        return [build]
    }
}
