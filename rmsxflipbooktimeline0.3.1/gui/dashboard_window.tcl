################################################################################
# RMSX Flipbook Timeline release dashboard GUI
################################################################################

namespace eval ::RMSXFlipbookTimeline::Dashboard {
    variable top ".rmsxflipbooktimeline_dashboard"
    variable dashboard_min_width 600
    variable dashboard_default_height 800
    variable status_widget ""
    variable dataset_list_widget ""
    variable metric_combo_widget ""
    variable native_metric_combo_widget ""
    variable timeline_metric_combo_widget ""
    variable embedded_heatmap_canvas ""
    variable embedded_heatmap_status_var "Heatmap will appear here after Run."
    variable embedded_heatmap_dataset {}
    variable embedded_heatmap_palette "viridis"
    variable embedded_heatmap_selected_record {}
    variable embedded_heatmap_mode ""
    variable embedded_heatmap_redraw_after ""
    variable embedded_heatmap_last_width 0
    variable embedded_record_by_tag
    variable native_show_context_plots "1"
    variable palette "viridis"
    variable citation_note "Beruldsen, F., de Freitas, M.V. & Antunes, D.A. High resolution mapping of protein motions in time and space with RMSX and Flipbook. Scientific Reports (2026).\nhttps://doi.org/10.1038/s41598-026-39869-7"
    variable citation_footer_note "Cite: Beruldsen et al., Sci. Rep. (2026)\ndoi:10.1038/s41598-026-39869-7"
    variable help_url "https://github.com/AntunesLab/rmsx"
    variable source_type "new_analysis"
    variable metric_group "Primary"
    variable native_metric "RMSX"
    variable timeline_metric "displacement"
    variable folder ""
    variable native_topology ""
    variable native_trajectory ""
    variable native_output ""
    variable saved_result {}
    variable pending_native_view {}
    variable native_view_serial 0
    variable native_chain "all"
    variable native_chain_groups {}
    variable native_chain_groups_topology ""
    variable native_slices "9"
    variable native_slice_size ""
    variable native_slicing_mode "slices"
    variable native_total_frames "auto"
    variable native_detected_total_frames ""
    variable native_frame_count_key ""
    variable native_frame_count_after ""
    variable native_frame_count_running "0"
    variable native_frame_count_attempt_key ""
    variable native_start "0"
    variable native_end "-1"
    variable native_time_step ""
    variable native_total_time_ns "auto"
    variable native_detected_time_step_ps ""
    variable native_detected_total_time_ns ""
    variable native_time_estimate_source ""
    variable native_analysis_type "protein"
    variable native_log_transform "0"
    variable native_mask_selection ""
    variable timeline_molid "top"
    variable timeline_file_molid ""
    variable timeline_file_topology ""
    variable timeline_file_trajectory ""
    variable timeline_selection "protein"
    variable timeline_scale_mode "fit"
    variable timeline_column_mode "frames"
    variable timeline_slice_aggregation "auto"
    variable timeline_slice_representative "first"
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
    variable timeline_native_dist "8.0"
    variable timeline_native_ref_frame "0"
    variable timeline_native_from_selection_list "{protein}"
    variable timeline_native_to_selection "protein"
    variable timeline_inter_method "residues_to_selection"
    variable timeline_inter_dist "4.0"
    variable timeline_inter_from_selection "protein"
    variable timeline_inter_to_selection "protein"
    variable timeline_inter_selection_list "{protein} {protein}"
    variable timeline_tml_file ""
    variable timeline_collection_dir ""
    variable timeline_collection {}
    variable timeline_collection_index "0"
    variable show_advanced "0"
    variable dataset_items {}
    variable dataset_summary_var "Loaded: none"
    variable output_display_var ""
    variable displayed_flipbook_path ""
    variable easy_auto_scrolled_after_run "0"
    variable mouse_mode "coords"
    variable mouse_sensitivity "2.0"
    variable mouse_burst_count "240"
    variable mouse_burst_axis "y"
    variable mouse_burst_angle "0.75"
    variable auto_mouse_rotation "1"
    variable render_transparent_png "0"
    array set embedded_record_by_tag {}

    proc experimental_enabled {} {
        if {[info commands ::RMSXFlipbookTimeline::experimental_enabled] ne ""} {
            return [::RMSXFlipbookTimeline::experimental_enabled]
        }
        return 0
    }

    proc metric_metadata {} {
        set records [list \
            [dict create key RMSX label RMSX group Primary route native panel native description "RMSX flipbook slices"] \
            [dict create key Shift-Map label "Shift-Map" group Primary route native panel native description "Shift-map flipbook slices"] \
            [dict create key lDDT label 1-lDDT group Primary route native panel native description "1-lDDT flipbook slices"] \
            [dict create key rmsd label RMSD group Primary route timeline panel timeline description "Per-residue RMSD over frames"] \
            [dict create key rmsf label RMSF group Primary route timeline panel timeline description "Sliding-window residue fluctuation"] \
            [dict create key displacement label "Displacement" group Primary route timeline panel timeline description "Distance from reference frame"] \
            [dict create key secondary_structure label "SS" group Primary route timeline panel structure description "DSSP-style structure categories"] \
            [dict create key native_contacts label "Native contacts" group Primary route timeline panel contacts description "Fraction of native contacts retained"] \
            [dict create key displacement_velocity label "Step displacement" group Motion route timeline panel timeline description "Frame-to-frame displacement"] \
            [dict create key sasa label SASA group Structure route timeline panel timeline description "Solvent accessible surface area"] \
            [dict create key phi label phi group Structure route timeline panel angles description "Backbone phi angle"] \
            [dict create key delta_phi label "Δphi" group Structure route timeline panel angles description "Delta phi from first frame"] \
            [dict create key psi label psi group Structure route timeline panel angles description "Backbone psi angle"] \
            [dict create key delta_psi label "Δpsi" group Structure route timeline panel angles description "Delta psi from first frame"] \
            [dict create key hbonds label "H-bonds" group Contacts route timeline panel contacts description "Hydrogen-bond event matrix"] \
            [dict create key salt_bridges label "Salt bridges" group Contacts route timeline panel contacts description "Salt-bridge event matrix"] \
            [dict create key inter_selection_contacts label "Contacts" group Contacts route timeline panel contacts description "Contacts between selections"]]
        if {[experimental_enabled]} {
            foreach record [list \
                [dict create key cross_correlation label cross_correlation group Contacts route timeline panel cross_correlation description "Map/trajectory cross-correlation"] \
                [dict create key x label x group Fields route timeline panel timeline description "Residue/key atom X coordinate"] \
                [dict create key y label y group Fields route timeline panel timeline description "Residue/key atom Y coordinate"] \
                [dict create key z label z group Fields route timeline panel timeline description "Residue/key atom Z coordinate"] \
                [dict create key user label user group Fields route timeline panel fields description "VMD user field"] \
                [dict create key user2 label user2 group Fields route timeline panel fields description "VMD user2 field"] \
                [dict create key user3 label user3 group Fields route timeline panel fields description "VMD user3 field"] \
                [dict create key user4 label user4 group Fields route timeline panel fields description "VMD user4 field"] \
                [dict create key user_field label user_field group Fields route timeline panel fields description "Choose one VMD user field"] \
                [dict create key residue_function label residue_function group Advanced route timeline panel residue_function description "User Tcl residue function"] \
                [dict create key selection_empty label selection_empty group Advanced route timeline panel advanced description "Timeline compatibility empty selection"] \
                [dict create key test_free_selection label test_free_selection group Advanced route timeline panel advanced description "Timeline compatibility free-selection test"] \
                [dict create key rmsd_tool label rmsd_tool group Advanced route external panel advanced description "Launch VMD RMSD Tool"]] {
                lappend records $record
            }
        }
        return $records
    }

    proc metric_groups {} {
        set groups {}
        foreach record [metric_metadata] {
            set group [dict get $record group]
            if {[lsearch -exact $groups $group] < 0} {
                lappend groups $group
            }
        }
        return $groups
    }

    proc metric_key {metric} {
        set key [string tolower [string map {" " "_" "-" "_"} [string trim $metric]]]
        set aliases [dict create ss secondary_structure h_bonds hbonds contacts inter_selection_contacts step_displacement displacement_velocity Δphi delta_phi Δpsi delta_psi δphi delta_phi δpsi delta_psi 1_lddt lddt]
        if {[dict exists $aliases $key]} { return [dict get $aliases $key] }
        return $key
    }

    proc metric_record {metric} {
        set target [metric_key $metric]
        foreach record [metric_metadata] {
            if {[metric_key [dict get $record key]] eq $target || [metric_key [dict get $record label]] eq $target} {
                return $record
            }
        }
        return [dict create key $metric label $metric group Advanced route timeline panel timeline description "Timeline metric"]
    }

    proc metric_values_for_group {group} {
        set values {}
        foreach record [metric_metadata] {
            if {[dict get $record group] eq $group} {
                lappend values [dict get $record key]
            }
        }
        return $values
    }

    proc metric_values {} {
        set values {}
        foreach record [metric_metadata] {
            lappend values [dict get $record key]
        }
        return $values
    }

    proc palette_values {} {
        return {viridis magma inferno plasma cividis rocket mako turbo BWR RWB RGB}
    }

    proc normalize_palette {value} {
        set clean [string trim $value]
        if {$clean eq ""} {
            return viridis
        }
        foreach palette [palette_values] {
            if {[string tolower $palette] eq [string tolower $clean]} {
                return $palette
            }
        }
        return viridis
    }

    proc metric_values_for_route {route} {
        set values {}
        foreach record [metric_metadata] {
            if {[dict get $record route] eq $route} {
                lappend values [dict get $record key]
            }
        }
        return $values
    }

    proc native_metric_values {} {
        return {RMSX Shift-Map 1-lDDT}
    }

    proc timeline_metric_values {} {
        set values {}
        foreach record [metric_metadata] {
            set route [dict get $record route]
            if {$route eq "timeline" || $route eq "external"} {
                lappend values [dict get $record label]
            }
        }
        return $values
    }

    proc metric_route {metric} {
        return [dict get [metric_record $metric] route]
    }

    proc metric_panel {metric} {
        return [dict get [metric_record $metric] panel]
    }

    proc metric_description {metric} {
        return [dict get [metric_record $metric] description]
    }

    proc current_metric_values {} {
        set values [metric_values]
        if {[llength $values] == 0} {
            return [list RMSX]
        }
        return $values
    }

    proc ensure_native_metric {} {
        variable native_metric
        if {[metric_route $native_metric] ne "native"} {
            set native_metric RMSX
        }
        return $native_metric
    }

    proc ensure_timeline_metric {} {
        variable timeline_metric
        set record [metric_record $timeline_metric]
        if {[dict get $record route] eq "native"} { set record [metric_record displacement] }
        set timeline_metric [dict get $record label]
        return $timeline_metric
    }

    proc set_status {message {append 0}} {
        variable status_widget
        variable status_text
        variable detail_log
        set status_text [lindex [split $message "\n"] 0]
        append detail_log "[clock format [clock seconds] -format %H:%M:%S]  $message\n"
        set lines [split $detail_log "\n"]
        if {[llength $lines] > 600} { set detail_log [join [lrange $lines end-599 end] "\n"] }
        if {[info commands winfo] ne "" && $status_widget ne "" && [winfo exists $status_widget]} {
            $status_widget configure -state normal
            $status_widget delete 1.0 end
            $status_widget insert end $detail_log
            $status_widget see end
            $status_widget configure -state disabled
        }
        puts $message
    }

    proc validate_int {label value min_value} {
        set clean [string trim $value]
        if {![string is integer -strict $clean]} {
            error "$label must be an integer"
        }
        set out [expr {int($clean)}]
        if {$out < $min_value} {
            error "$label must be >= $min_value"
        }
        return $out
    }

    proc validate_double {label value min_value} {
        set clean [string trim $value]
        if {![string is double -strict $clean]} {
            error "$label must be numeric"
        }
        set out [expr {double($clean)}]
        if {$out < $min_value} {
            error "$label must be >= $min_value"
        }
        return $out
    }

    proc format_compact_double {value {decimals 6}} {
        set text [format "%.${decimals}f" [expr {double($value)}]]
        regsub {0+$} $text {} text
        regsub {\.$} $text {} text
        if {$text eq "-0"} {
            set text "0"
        }
        return $text
    }

    proc format_time_step_display_ps {value} {
        set step [expr {double($value)}]
        if {$step == 0.0} {
            return "0"
        }
        if {abs($step) < 0.001} {
            return [format_compact_double $step 6]
        }
        if {abs($step) < 0.01} {
            return [format_compact_double $step 5]
        }
        return [format_compact_double $step 3]
    }

    proc format_total_time_display_ns {value} {
        if {[info commands ::RMSXFlipbookTimeline::NativeAnalysis::format_simulation_length_ns] ne ""} {
            return [::RMSXFlipbookTimeline::NativeAnalysis::format_simulation_length_ns $value]
        }
        set ns [expr {double($value)}]
        if {$ns == 0.0} {
            return "0.000"
        }
        if {$ns < 0.001} {
            return [format "%.6f" $ns]
        }
        if {$ns < 0.01} {
            return [format "%.5f" $ns]
        }
        return [format "%.3f" $ns]
    }

    proc normalize_time_unit_to_ps {value unit {default_unit ps}} {
        set clean_unit [string tolower [string trim $unit]]
        if {$clean_unit eq ""} {
            set clean_unit [string tolower [string trim $default_unit]]
        }
        set numeric [expr {double($value)}]
        switch -glob -- $clean_unit {
            fs* -
            femtosecond* {
                return [expr {$numeric / 1000.0}]
            }
            ns* -
            nanosecond* {
                return [expr {$numeric * 1000.0}]
            }
            us* -
            microsecond* {
                return [expr {$numeric * 1000000.0}]
            }
            ms* -
            millisecond* {
                return [expr {$numeric * 1000000000.0}]
            }
            default {
                return $numeric
            }
        }
    }

    proc native_total_time_override_ns_value {} {
        variable native_total_time_ns
        set text [string trim $native_total_time_ns]
        if {$text eq "" || [string tolower $text] eq "auto"} {
            return ""
        }
        if {![string is double -strict $text] || double($text) < 0.0} {
            error "Total time override must be auto or a non-negative number of ns"
        }
        return [expr {double($text)}]
    }

    proc time_step_from_total_ns {total_ns frames} {
        if {$frames <= 1} {
            return 0.0
        }
        return [expr {(double($total_ns) * 1000.0) / double($frames - 1)}]
    }

    proc effective_time_step_ps_for_run {} {
        variable native_time_step
        variable native_detected_time_step_ps
        set override_ns [native_total_time_override_ns_value]
        if {$override_ns ne ""} {
            set frame_info [dashboard_frame_count]
            if {![dict get $frame_info known]} {
                error "Total time override needs a known frame range: [dict get $frame_info reason]"
            }
            set step [time_step_from_total_ns $override_ns [dict get $frame_info frames]]
            set native_time_step [format_time_step_display_ps $step]
            return $step
        }
        set displayed [string trim $native_time_step]
        if {$displayed eq ""} { return "" }
        if {[string is double -strict [string trim $native_detected_time_step_ps]]} {
            set detected [expr {double($native_detected_time_step_ps)}]
            set detected_displays [list \
                [format_time_step_display_ps $detected] \
                [format_compact_double $detected 6] \
                [format_compact_double $detected 9]]
            if {[lsearch -exact $detected_displays $displayed] >= 0} {
                return $detected
            }
        }
        return [validate_double "Time step" $native_time_step 0.0]
    }

    proc metadata_candidate_files {trajectory} {
        set path [string trim $trajectory]
        if {$path eq "" || ![file exists $path]} {
            return {}
        }
        set dir [file dirname [file normalize $path]]
        set root [file rootname [file tail $path]]
        set candidates {}
        foreach ext {log out xsc xst mdp txt json yaml yml meta metadata} {
            foreach pattern [list "${root}*.${ext}" "*.${ext}"] {
                foreach item [glob -nocomplain -directory $dir $pattern] {
                    if {[file isfile $item] && [lsearch -exact $candidates $item] < 0} {
                        lappend candidates $item
                    }
                }
            }
        }
        return [lsort -dictionary $candidates]
    }

    proc read_metadata_snippet {filename} {
        if {![file exists $filename] || ![file isfile $filename]} {
            return ""
        }
        if {[file size $filename] > 5242880} {
            return ""
        }
        set fp [open $filename r]
        try {
            return [read $fp 524288]
        } finally {
            catch {close $fp}
        }
    }

    proc parse_time_step_ps_from_text {text} {
        set direct_patterns {
            {(?in)(?:frame|trajectory|traj)[ _-]*(?:step|dt|interval|spacing)[[:space:]]*[:=]?[[:space:]]*([0-9.+\-eE]+)[[:space:]]*(fs|femtoseconds?|ps|picoseconds?|ns|nanoseconds?)?}
            {(?in)time[ _-]*per[ _-]*frame[[:space:]]*[:=]?[[:space:]]*([0-9.+\-eE]+)[[:space:]]*(fs|femtoseconds?|ps|picoseconds?|ns|nanoseconds?)?}
        }
        foreach pattern $direct_patterns {
            if {[regexp $pattern $text _ value unit]} {
                if {[string is double -strict $value]} {
                    return [normalize_time_unit_to_ps $value $unit ps]
                }
            }
        }

        set dt ""
        set dt_unit ""
        if {[regexp {(?in)(?:^|[^a-z])(dt|time[ _-]*step|timestep)[[:space:]]*[:=]?[[:space:]]*([0-9.+\-eE]+)[[:space:]]*(fs|femtoseconds?|ps|picoseconds?|ns|nanoseconds?)?} $text _ _ value unit]} {
            if {[string is double -strict $value]} {
                set dt $value
                set dt_unit $unit
            }
        }

        set freq ""
        if {[regexp {(?in)(?:dcdfreq|dcd[ _-]*frequency|nstxout(?:[-_a-z]*)?|xstfreq|traj(?:ectory)?[ _-]*(?:freq|frequency|stride|period)|save[ _-]*(?:freq|frequency|stride|period))[[:space:]]*[:=]?[[:space:]]*([0-9]+)} $text _ value]} {
            set freq $value
        }

        if {$dt ne "" && $freq ne ""} {
            return [expr {[normalize_time_unit_to_ps $dt $dt_unit ps] * int($freq)}]
        }
        return ""
    }

    proc parse_total_time_ns_from_text {text} {
        set patterns {
            {(?in)(?:total|simulation|trajectory|elapsed)[ _-]*(?:time|length|duration)[[:space:]]*[:=]?[[:space:]]*([0-9.+\-eE]+)[[:space:]]*(fs|femtoseconds?|ps|picoseconds?|ns|nanoseconds?)?}
            {(?in)(?:run|production)[ _-]*(?:time|length|duration)[[:space:]]*[:=]?[[:space:]]*([0-9.+\-eE]+)[[:space:]]*(fs|femtoseconds?|ps|picoseconds?|ns|nanoseconds?)?}
        }
        foreach pattern $patterns {
            if {[regexp $pattern $text _ value unit]} {
                if {[string is double -strict $value]} {
                    return [expr {[normalize_time_unit_to_ps $value $unit ns] / 1000.0}]
                }
            }
        }
        return ""
    }

    proc metadata_time_estimate {trajectory frames} {
        foreach filename [metadata_candidate_files $trajectory] {
            set text [read_metadata_snippet $filename]
            if {$text eq ""} {
                continue
            }
            set step [parse_time_step_ps_from_text $text]
            if {$step ne "" && $step >= 0.0} {
                return [dict create step_ps $step source "metadata [file tail $filename]"]
            }
            set total_ns [parse_total_time_ns_from_text $text]
            if {$total_ns ne "" && $frames > 1} {
                return [dict create step_ps [time_step_from_total_ns $total_ns $frames] total_ns $total_ns source "metadata [file tail $filename]"]
            }
        }
        return {}
    }

    proc molinfo_time_estimate {molid frames} {
        if {[info commands molinfo] eq "" || $molid eq "" || $frames <= 1} {
            return {}
        }
        foreach field {timesteps times timeframes} {
            if {[catch {set values [molinfo $molid get $field]}]} {
                continue
            }
            if {[llength $values] >= 2} {
                set first [lindex $values 0]
                set last [lindex $values [expr {min([llength $values], $frames) - 1}]]
                if {[string is double -strict $first] && [string is double -strict $last] && double($last) > double($first)} {
                    return [dict create \
                        step_ps [expr {(double($last) - double($first)) / double(min([llength $values], $frames) - 1)}] \
                        total_ns [expr {(double($last) - double($first)) / 1000.0}] \
                        source "VMD $field"]
                }
            }
        }
        foreach field {timestep time_step dt} {
            if {[catch {set value [molinfo $molid get $field]}]} {
                continue
            }
            if {[string is double -strict $value] && double($value) > 0.0} {
                return [dict create step_ps [expr {double($value)}] source "VMD $field"]
            }
        }
        return {}
    }

    proc update_time_estimate_from_loaded_trajectory {molid frames trajectory} {
        variable native_time_step
        variable native_total_time_ns
        variable native_detected_time_step_ps
        variable native_detected_total_time_ns
        variable native_time_estimate_source

        set estimate [molinfo_time_estimate $molid $frames]
        if {[llength $estimate] == 0} {
            set estimate [metadata_time_estimate $trajectory $frames]
        }
        if {[llength $estimate] == 0} {
            set native_time_estimate_source ""
            set native_detected_time_step_ps ""
            set native_detected_total_time_ns ""
            return {}
        }

        set step [dict get $estimate step_ps]
        set native_detected_time_step_ps [format_compact_double $step 9]
        if {[dict exists $estimate total_ns]} {
            set native_detected_total_time_ns [format_total_time_display_ns [dict get $estimate total_ns]]
        } elseif {$frames > 1} {
            set native_detected_total_time_ns [format_total_time_display_ns [expr {(($frames - 1) * double($step)) / 1000.0}]]
        } else {
            set native_detected_total_time_ns "0.000"
        }
        set native_time_estimate_source [dict get $estimate source]
        if {[string trim $native_total_time_ns] eq "" || [string tolower [string trim $native_total_time_ns]] eq "auto"} {
            set native_time_step [format_time_step_display_ps $step]
            ::RMSXFlipbookTimeline::state_set native_time_step $native_time_step
        }
        ::RMSXFlipbookTimeline::state_set native_detected_time_step_ps $native_detected_time_step_ps
        ::RMSXFlipbookTimeline::state_set native_detected_total_time_ns $native_detected_total_time_ns
        ::RMSXFlipbookTimeline::state_set native_time_estimate_source $native_time_estimate_source
        return $estimate
    }

    proc sync_from_state {} {
        variable folder
        variable native_topology
        variable native_trajectory
        variable native_output
        variable native_chain
        variable native_slices
        variable native_slice_size
        variable native_slicing_mode
        variable native_total_frames
        variable native_start
        variable native_end
        variable native_time_step
        variable native_total_time_ns
        variable native_detected_time_step_ps
        variable native_detected_total_time_ns
        variable native_time_estimate_source
        variable native_analysis_type
        variable native_log_transform
        variable native_mask_selection
        variable palette
        variable timeline_molid
        variable timeline_selection
        variable timeline_column_mode
        variable timeline_slice_aggregation
        variable timeline_slice_representative
        variable native_metric
        variable timeline_metric
        variable metric_group
        variable timeline_native_dist
        variable timeline_native_ref_frame
        variable timeline_native_from_selection_list
        variable timeline_native_to_selection
        variable timeline_inter_method
        variable timeline_inter_dist
        variable timeline_inter_from_selection
        variable timeline_inter_to_selection
        variable timeline_inter_selection_list
        variable mouse_mode
        variable mouse_sensitivity
        variable auto_mouse_rotation
        variable render_transparent_png
        variable native_frame_count_key

        set folder [::RMSXFlipbookTimeline::state_get source_folder $folder]
        set native_topology [::RMSXFlipbookTimeline::state_get native_topology $native_topology]
        set native_trajectory [::RMSXFlipbookTimeline::state_get native_trajectory $native_trajectory]
        set native_output [::RMSXFlipbookTimeline::state_get native_output $native_output]
        set native_chain [::RMSXFlipbookTimeline::state_get native_chain $native_chain]
        set native_slices [::RMSXFlipbookTimeline::state_get native_slices $native_slices]
        set native_slice_size [::RMSXFlipbookTimeline::state_get native_slice_size $native_slice_size]
        set native_slicing_mode [::RMSXFlipbookTimeline::state_get native_slicing_mode $native_slicing_mode]
        set native_total_frames [::RMSXFlipbookTimeline::state_get native_total_frames $native_total_frames]
        set native_start [::RMSXFlipbookTimeline::state_get native_start $native_start]
        set native_end [::RMSXFlipbookTimeline::state_get native_end $native_end]
        set native_time_step [::RMSXFlipbookTimeline::state_get native_time_step $native_time_step]
        set native_total_time_ns [::RMSXFlipbookTimeline::state_get native_total_time_ns $native_total_time_ns]
        set native_detected_time_step_ps [::RMSXFlipbookTimeline::state_get native_detected_time_step_ps $native_detected_time_step_ps]
        set native_detected_total_time_ns [::RMSXFlipbookTimeline::state_get native_detected_total_time_ns $native_detected_total_time_ns]
        set native_time_estimate_source [::RMSXFlipbookTimeline::state_get native_time_estimate_source $native_time_estimate_source]
        if {$native_slicing_mode eq ""} {
            if {[string trim $native_slice_size] ne ""} {
                set native_slicing_mode "slice_size"
            } else {
                set native_slicing_mode "slices"
            }
        }
        set native_analysis_type [::RMSXFlipbookTimeline::state_get native_analysis_type $native_analysis_type]
        set native_log_transform [::RMSXFlipbookTimeline::state_get native_log_transform $native_log_transform]
        set native_mask_selection [::RMSXFlipbookTimeline::state_get native_mask_selection $native_mask_selection]
        set palette [normalize_palette [::RMSXFlipbookTimeline::state_get palette $palette]]
        set timeline_molid [::RMSXFlipbookTimeline::state_get timeline_molid $timeline_molid]
        set timeline_selection [::RMSXFlipbookTimeline::state_get timeline_selection $timeline_selection]
        set timeline_column_mode [::RMSXFlipbookTimeline::state_get timeline_column_mode $timeline_column_mode]
        set timeline_slice_aggregation [::RMSXFlipbookTimeline::state_get timeline_slice_aggregation $timeline_slice_aggregation]
        set timeline_slice_representative [::RMSXFlipbookTimeline::state_get timeline_slice_representative $timeline_slice_representative]
        set timeline_native_dist [::RMSXFlipbookTimeline::state_get timeline_native_dist $timeline_native_dist]
        set timeline_native_ref_frame [::RMSXFlipbookTimeline::state_get timeline_native_ref_frame $timeline_native_ref_frame]
        set timeline_native_from_selection_list [::RMSXFlipbookTimeline::state_get timeline_native_from_selection_list $timeline_native_from_selection_list]
        set timeline_native_to_selection [::RMSXFlipbookTimeline::state_get timeline_native_to_selection $timeline_native_to_selection]
        set timeline_inter_method [::RMSXFlipbookTimeline::state_get timeline_inter_method $timeline_inter_method]
        set timeline_inter_dist [::RMSXFlipbookTimeline::state_get timeline_inter_dist $timeline_inter_dist]
        set timeline_inter_from_selection [::RMSXFlipbookTimeline::state_get timeline_inter_from_selection $timeline_inter_from_selection]
        set timeline_inter_to_selection [::RMSXFlipbookTimeline::state_get timeline_inter_to_selection $timeline_inter_to_selection]
        set timeline_inter_selection_list [::RMSXFlipbookTimeline::state_get timeline_inter_selection_list $timeline_inter_selection_list]

        set existing_native_metric [::RMSXFlipbookTimeline::state_get native_metric ""]
        if {$existing_native_metric ne "" && [metric_route $existing_native_metric] eq "native"} {
            set native_metric $existing_native_metric
        }
        set existing_timeline_metric [::RMSXFlipbookTimeline::state_get timeline_metric ""]
        if {$existing_timeline_metric ne ""} {
            if {[metric_route $existing_timeline_metric] eq "native"} {
                set native_metric $existing_timeline_metric
            } else {
                set timeline_metric $existing_timeline_metric
            }
        }
        ensure_native_metric
        ensure_timeline_metric
        set metric_group [dict get [metric_record $timeline_metric] group]
        set mouse_mode [::RMSXFlipbookTimeline::state_get mouse_rotation_mode $mouse_mode]
        set mouse_sensitivity [::RMSXFlipbookTimeline::state_get mouse_rotation_sensitivity $mouse_sensitivity]
        set auto_mouse_rotation "1"
        set render_transparent_png [::RMSXFlipbookTimeline::state_get render_transparent_png $render_transparent_png]
        set native_frame_count_key [current_native_frame_count_key]
    }

    proc persist_common_state {} {
        variable folder
        variable native_topology
        variable native_trajectory
        variable native_output
        variable native_chain
        variable native_slices
        variable native_slice_size
        variable native_slicing_mode
        variable native_total_frames
        variable native_start
        variable native_end
        variable native_time_step
        variable native_total_time_ns
        variable native_detected_time_step_ps
        variable native_detected_total_time_ns
        variable native_time_estimate_source
        variable native_analysis_type
        variable native_log_transform
        variable native_mask_selection
        variable palette
        variable timeline_molid
        variable timeline_selection
        variable timeline_column_mode
        variable timeline_slice_aggregation
        variable timeline_slice_representative
        variable native_metric
        variable timeline_metric
        variable timeline_native_dist
        variable timeline_native_ref_frame
        variable timeline_native_from_selection_list
        variable timeline_native_to_selection
        variable timeline_inter_method
        variable timeline_inter_dist
        variable timeline_inter_from_selection
        variable timeline_inter_to_selection
        variable timeline_inter_selection_list
        variable mouse_mode
        variable mouse_sensitivity
        variable auto_mouse_rotation
        variable render_transparent_png

        ::RMSXFlipbookTimeline::state_set source_folder $folder
        ::RMSXFlipbookTimeline::state_set native_topology $native_topology
        ::RMSXFlipbookTimeline::state_set native_trajectory $native_trajectory
        ::RMSXFlipbookTimeline::state_set native_output $native_output
        ::RMSXFlipbookTimeline::state_set native_chain $native_chain
        ::RMSXFlipbookTimeline::state_set native_slices $native_slices
        ::RMSXFlipbookTimeline::state_set native_slice_size $native_slice_size
        ::RMSXFlipbookTimeline::state_set native_slicing_mode $native_slicing_mode
        ::RMSXFlipbookTimeline::state_set native_total_frames $native_total_frames
        ::RMSXFlipbookTimeline::state_set native_start $native_start
        ::RMSXFlipbookTimeline::state_set native_end $native_end
        ::RMSXFlipbookTimeline::state_set native_time_step $native_time_step
        ::RMSXFlipbookTimeline::state_set native_total_time_ns $native_total_time_ns
        ::RMSXFlipbookTimeline::state_set native_detected_time_step_ps $native_detected_time_step_ps
        ::RMSXFlipbookTimeline::state_set native_detected_total_time_ns $native_detected_total_time_ns
        ::RMSXFlipbookTimeline::state_set native_time_estimate_source $native_time_estimate_source
        ::RMSXFlipbookTimeline::state_set native_analysis_type $native_analysis_type
        ::RMSXFlipbookTimeline::state_set native_log_transform $native_log_transform
        ::RMSXFlipbookTimeline::state_set native_mask_selection $native_mask_selection
        ::RMSXFlipbookTimeline::state_set palette [normalize_palette $palette]
        ::RMSXFlipbookTimeline::state_set timeline_molid $timeline_molid
        ::RMSXFlipbookTimeline::state_set timeline_selection $timeline_selection
        ::RMSXFlipbookTimeline::state_set timeline_column_mode $timeline_column_mode
        ::RMSXFlipbookTimeline::state_set timeline_slice_aggregation $timeline_slice_aggregation
        ::RMSXFlipbookTimeline::state_set timeline_slice_representative $timeline_slice_representative
        ::RMSXFlipbookTimeline::state_set timeline_native_dist $timeline_native_dist
        ::RMSXFlipbookTimeline::state_set timeline_native_ref_frame $timeline_native_ref_frame
        ::RMSXFlipbookTimeline::state_set timeline_native_from_selection_list $timeline_native_from_selection_list
        ::RMSXFlipbookTimeline::state_set timeline_native_to_selection $timeline_native_to_selection
        ::RMSXFlipbookTimeline::state_set timeline_inter_method $timeline_inter_method
        ::RMSXFlipbookTimeline::state_set timeline_inter_dist $timeline_inter_dist
        ::RMSXFlipbookTimeline::state_set timeline_inter_from_selection $timeline_inter_from_selection
        ::RMSXFlipbookTimeline::state_set timeline_inter_to_selection $timeline_inter_to_selection
        ::RMSXFlipbookTimeline::state_set timeline_inter_selection_list $timeline_inter_selection_list
        ::RMSXFlipbookTimeline::state_set timeline_metric $timeline_metric
        ::RMSXFlipbookTimeline::state_set native_metric $native_metric
        ::RMSXFlipbookTimeline::state_set mouse_rotation_mode $mouse_mode
        ::RMSXFlipbookTimeline::state_set mouse_rotation_sensitivity $mouse_sensitivity
        ::RMSXFlipbookTimeline::state_set dashboard_auto_mouse_rotation 1
        ::RMSXFlipbookTimeline::state_set render_transparent_png $render_transparent_png
    }

    proc add_dataset_item {label kind detail} {
        variable dataset_items
        variable dataset_list_widget
        variable dataset_summary_var
        variable displayed_flipbook_path
        set item [dict create label $label kind $kind detail $detail]
        set dataset_items [list $item]
        set clean_detail [string trim $detail]
        if {$clean_detail eq ""} {
            set dataset_summary_var "Loaded: $label ($kind)"
        } else {
            set dataset_summary_var "Loaded: $label ($kind) - $clean_detail"
        }
        if {$kind eq "flipbook"} {
            set displayed_flipbook_path $clean_detail
            refresh_output_display_indicator
        }
        if {$dataset_list_widget ne "" && [info commands winfo] ne "" && [winfo exists $dataset_list_widget]} {
            set widget_class [winfo class $dataset_list_widget]
            if {$widget_class eq "Treeview"} {
                set iid "dataset_[llength $dataset_items]"
                $dataset_list_widget insert {} end -id $iid -text $label -values [list $kind $detail]
                catch {$dataset_list_widget selection set $iid}
                catch {$dataset_list_widget see $iid}
            } else {
                $dataset_list_widget insert end "$label  ($kind)"
            }
        }
        return $item
    }

    proc normalize_dashboard_path {path} {
        set clean [string trim $path]
        if {$clean eq ""} {
            return ""
        }
        if {[catch {file normalize $clean} normalized]} {
            return [string trimright $clean "/"]
        }
        return [string trimright $normalized "/"]
    }

    proc output_paths_match {current displayed} {
        if {$current eq "" || $displayed eq ""} {
            return 0
        }
        if {$current eq $displayed} {
            return 1
        }
        set combined [normalize_dashboard_path [file join $current combined]]
        if {$combined ne "" && $combined eq $displayed} {
            return 1
        }
        if {[file tail $displayed] eq "combined" && [normalize_dashboard_path [file dirname $displayed]] eq $current} {
            return 1
        }
        return 0
    }

    proc easy_content_root {} {
        variable top
        set content $top.tabs.easy.content
        if {[info commands winfo] ne "" && [winfo exists $content]} {
            return $content
        }
        return $top.tabs.easy
    }

    proc easy_child {name} {
        return "[easy_content_root].$name"
    }

    proc refresh_output_display_indicator {} {
        variable output_display_var
        set output_display_var ""
    }

    proc molid_is_loaded {molid} {
        if {[info commands molinfo] eq "" || ![string is integer -strict $molid]} {
            return 0
        }
        if {[catch {molinfo list} molids]} {
            return 0
        }
        return [expr {[lsearch -exact $molids [expr {int($molid)}]] >= 0}]
    }

    proc file_backed_timeline_molid {} {
        variable native_topology
        variable native_trajectory
        variable native_total_frames
        variable native_detected_total_frames
        variable timeline_molid
        variable timeline_file_molid
        variable timeline_file_topology
        variable timeline_file_trajectory

        if {$native_topology eq "" || ![file exists $native_topology]} {
            error "Choose a topology PDB before running this Timeline metric."
        }
        if {$native_trajectory eq "" || ![file exists $native_trajectory]} {
            error "Choose a trajectory DCD before running this Timeline metric."
        }
        if {[info commands mol] eq "" || [info commands molinfo] eq ""} {
            error "Timeline metrics from PDB/DCD need VMD molecule commands."
        }

        set top_norm [file normalize $native_topology]
        set traj_norm [file normalize $native_trajectory]
        if {[molid_is_loaded $timeline_file_molid] \
            && $timeline_file_topology eq $top_norm \
            && $timeline_file_trajectory eq $traj_norm} {
            set timeline_molid $timeline_file_molid
            ::RMSXFlipbookTimeline::state_set timeline_molid $timeline_molid
            return $timeline_file_molid
        }

        if {[molid_is_loaded $timeline_file_molid]} {
            catch {mol delete $timeline_file_molid}
        }

        if {[info commands ::RMSXFlipbookTimeline::NativeAnalysis::load_trajectory] ne ""} {
            set load_info [::RMSXFlipbookTimeline::NativeAnalysis::load_trajectory $top_norm $traj_norm]
            set molid [dict get $load_info molid]
            set frames [dict get $load_info total_frame_count]
        } else {
            set molid [mol new $top_norm waitfor all]
            mol addfile $traj_norm waitfor all molid $molid
            set frames [molinfo $molid get numframes]
        }

        set timeline_file_molid $molid
        set timeline_file_topology $top_norm
        set timeline_file_trajectory $traj_norm
        set timeline_molid $molid
        ::RMSXFlipbookTimeline::state_set timeline_molid $timeline_molid
        if {[string is integer -strict $frames] && int($frames) > 1} {
            set native_detected_total_frames [expr {int($frames)}]
            if {[string trim $native_total_frames] eq "" || [string tolower [string trim $native_total_frames]] eq "auto"} {
                set native_total_frames $native_detected_total_frames
                ::RMSXFlipbookTimeline::state_set native_total_frames $native_total_frames
            }
        }
        return $molid
    }

    proc dashboard_molid {} {
        variable timeline_molid
        set requested [string trim $timeline_molid]
        if {[info commands molinfo] eq ""} { error "VMD molecule commands are unavailable" }
        if {$requested eq "" || $requested eq "top" || $requested eq "Top"} {
            set requested [molinfo top]
        } elseif {[regexp {^([0-9]+):} $requested -> id]} { set requested $id }
        if {![string is integer -strict $requested] || [lsearch -exact [molinfo list] $requested] < 0} {
            error "Choose a loaded molecule for Timeline."
        }
        return $requested
    }

    proc timeline_plot_options {} {
        variable timeline_scale_mode
        variable timeline_scale_min
        variable timeline_scale_max
        variable timeline_threshold_min
        variable timeline_threshold_max
        set opts [list scale_mode $timeline_scale_mode]
        if {[string trim $timeline_scale_min] ne "" || [string trim $timeline_scale_max] ne ""} {
            lappend opts scale_min $timeline_scale_min scale_max $timeline_scale_max
        }
        if {[string trim $timeline_threshold_min] ne "" && [string trim $timeline_threshold_max] ne ""} {
            lappend opts threshold_min $timeline_threshold_min threshold_max $timeline_threshold_max
        }
        return $opts
    }

    proc clear_embedded_heatmap {{message ""}} {
        variable embedded_heatmap_canvas
        variable embedded_heatmap_status_var
        variable embedded_heatmap_dataset
        variable embedded_heatmap_selected_record
        variable embedded_heatmap_mode
        variable embedded_record_by_tag
        set embedded_heatmap_dataset {}
        set embedded_heatmap_selected_record {}
        set embedded_heatmap_mode ""
        catch {array unset embedded_record_by_tag}
        array set embedded_record_by_tag {}
        if {$message eq ""} {
            set message "Heatmap will appear here after Run."
        }
        set embedded_heatmap_status_var $message
        if {$embedded_heatmap_canvas ne "" && [info commands winfo] ne "" && [winfo exists $embedded_heatmap_canvas]} {
            $embedded_heatmap_canvas delete all
            $embedded_heatmap_canvas configure -height 320
            set w [expr {max(360, [winfo width $embedded_heatmap_canvas])}]
            set h [expr {max(220, [winfo height $embedded_heatmap_canvas])}]
            $embedded_heatmap_canvas configure -scrollregion [list 0 0 $w $h]
            $embedded_heatmap_canvas create text [expr {$w / 2.0}] [expr {$h / 2.0}] \
                -anchor center \
                -font TkDefaultFont \
                -fill "#666666" \
                -text $message
        }
    }

    proc set_embedded_heatmap_canvas_height {height} {
        variable embedded_heatmap_canvas
        if {$embedded_heatmap_canvas eq "" || [info commands winfo] eq "" || ![winfo exists $embedded_heatmap_canvas]} {
            return
        }
        set requested [expr {int(ceil(double($height)))}]
        if {$requested < 320} {
            set requested 320
        }
        $embedded_heatmap_canvas configure -height $requested
    }

    proc resize_label_wrap {widget width {min_width 160} {pad 8}} {
        if {[info commands winfo] eq "" || ![winfo exists $widget]} {
            return
        }
        set wrap [expr {max($min_width, int($width) - int($pad))}]
        catch {$widget configure -wraplength $wrap}
    }

    proc redraw_embedded_heatmap_after_resize {} {
        variable embedded_heatmap_redraw_after
        variable embedded_heatmap_mode
        variable embedded_heatmap_dataset
        variable folder
        set embedded_heatmap_redraw_after ""
        if {$embedded_heatmap_mode eq "timeline" && $embedded_heatmap_dataset ne {}} {
            catch {draw_embedded_heatmap $embedded_heatmap_dataset}
            return
        }
        if {$embedded_heatmap_mode eq "native" && [string trim $folder] ne "" && [file isdirectory $folder]} {
            catch {render_native_heatmap}
        }
    }

    proc schedule_embedded_heatmap_resize_redraw {width} {
        variable embedded_heatmap_mode
        variable embedded_heatmap_last_width
        variable embedded_heatmap_redraw_after
        if {$embedded_heatmap_mode eq "" || $width < 120} {
            return
        }
        if {abs(int($width) - int($embedded_heatmap_last_width)) < 10} {
            return
        }
        set embedded_heatmap_last_width [expr {int($width)}]
        if {$embedded_heatmap_redraw_after ne ""} {
            catch {after cancel $embedded_heatmap_redraw_after}
        }
        set embedded_heatmap_redraw_after [after 140 ::RMSXFlipbookTimeline::Dashboard::redraw_embedded_heatmap_after_resize]
    }

    proc embedded_heatmap_width {} {
        variable embedded_heatmap_canvas
        set width 560
        if {$embedded_heatmap_canvas ne "" && [info commands winfo] ne "" && [winfo exists $embedded_heatmap_canvas]} {
            catch {set width [expr {[winfo width $embedded_heatmap_canvas] - 28}]}
        }
        if {$width < 360} {
            set width 360
        }
        return $width
    }

    proc embedded_heatmap_layout_options {width} {
        set defaults [dict create scale_mode fit threshold_min "" threshold_max "" scale_min "" scale_max ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}[timeline_plot_options]]
        return [list \
            width $width \
            scale_mode [dict get $opts scale_mode] \
            threshold_min [dict get $opts threshold_min] \
            threshold_max [dict get $opts threshold_max] \
            scale_min [dict get $opts scale_min] \
            scale_max [dict get $opts scale_max]]
    }

    proc draw_embedded_heatmap_selection {record} {
        variable embedded_heatmap_canvas
        variable embedded_heatmap_selected_record
        if {$embedded_heatmap_canvas eq "" || [info commands winfo] eq "" || ![winfo exists $embedded_heatmap_canvas]} {
            return
        }
        catch {$embedded_heatmap_canvas delete embedded_selection}
        set embedded_heatmap_selected_record $record
        if {$record eq {}} {
            return
        }
        set x0 [dict get $record x0]
        set y0 [dict get $record y0]
        set x1 [dict get $record x1]
        set y1 [dict get $record y1]
        set cx [dict get $record center_x]
        set cy [dict get $record center_y]
        $embedded_heatmap_canvas create rectangle $x0 $y0 $x1 $y1 \
            -outline "#facc15" \
            -width 3 \
            -tags embedded_selection
        $embedded_heatmap_canvas create line $x0 $cy $x1 $cy \
            -fill "#facc15" \
            -width 2 \
            -tags embedded_selection
        $embedded_heatmap_canvas create line $cx $y0 $cx $y1 \
            -fill "#facc15" \
            -width 2 \
            -tags embedded_selection
    }

    proc embedded_record_from_current {} {
        variable embedded_heatmap_canvas
        variable embedded_record_by_tag
        if {$embedded_heatmap_canvas eq "" || [info commands winfo] eq "" || ![winfo exists $embedded_heatmap_canvas]} {
            return {}
        }
        set current [$embedded_heatmap_canvas find withtag current]
        if {[llength $current] == 0} {
            return {}
        }
        foreach tag [$embedded_heatmap_canvas gettags [lindex $current 0]] {
            if {[info exists embedded_record_by_tag($tag)]} {
                return $embedded_record_by_tag($tag)
            }
        }
        return {}
    }

    proc embedded_heatmap_status_for_record {record} {
        variable embedded_heatmap_dataset
        if {$record eq {} || $embedded_heatmap_dataset eq {}} {
            return ""
        }
        set row [lindex [dict get $embedded_heatmap_dataset rows] [dict get $record row]]
        set column [lindex [dict get $embedded_heatmap_dataset columns] [dict get $record column]]
        set value [::RMSXFlipbookTimeline::Matrix::cell_value $embedded_heatmap_dataset [dict get $record row] [dict get $record column]]
        set target_label "slice"
        if {[dict exists $column target_type] && [dict get $column target_type] ne ""} {
            set target_label [dict get $column target_type]
        }
        return [format {%s, %s %s, value %s} \
            [::RMSXFlipbookTimeline::Matrix::row_label $row] \
            $target_label \
            [::RMSXFlipbookTimeline::Matrix::column_label $column] \
            $value]
    }

    proc embedded_heatmap_hover_current {} {
        variable embedded_heatmap_status_var
        set record [embedded_record_from_current]
        if {$record eq {}} {
            return
        }
        set embedded_heatmap_status_var [embedded_heatmap_status_for_record $record]
    }

    proc embedded_heatmap_pick_current {} {
        variable embedded_heatmap_status_var
        set record [embedded_record_from_current]
        if {$record eq {}} {
            return
        }
        draw_embedded_heatmap_selection $record
        if {[catch {
            ::RMSXFlipbookTimeline::TimelinePlot::select_cell [dict get $record row] [dict get $record column]
        } result]} {
            set embedded_heatmap_status_var "Selection failed: $result"
            return
        }
        if {[catch {dict get $result message} message]} {
            set message [embedded_heatmap_status_for_record $record]
        }
        set embedded_heatmap_status_var $message
        return $result
    }

    proc draw_embedded_heatmap {dataset} {
        variable embedded_heatmap_canvas
        variable embedded_heatmap_status_var
        variable embedded_heatmap_dataset
        variable embedded_heatmap_palette
        variable embedded_heatmap_selected_record
        variable embedded_heatmap_mode
        variable embedded_heatmap_last_width
        variable embedded_record_by_tag
        if {$embedded_heatmap_canvas eq "" || [info commands winfo] eq "" || ![winfo exists $embedded_heatmap_canvas]} {
            set embedded_heatmap_dataset $dataset
            set embedded_heatmap_mode "timeline"
            return
        }
        set dataset [::RMSXFlipbookTimeline::Matrix::validate $dataset]
        set embedded_heatmap_dataset $dataset
        set embedded_heatmap_mode "timeline"
        set embedded_heatmap_last_width [winfo width $embedded_heatmap_canvas]
        set embedded_heatmap_selected_record {}
        catch {array unset embedded_record_by_tag}
        array set embedded_record_by_tag {}

        set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        set embedded_heatmap_palette $palette
        set width [embedded_heatmap_width]
        set layout [::RMSXFlipbookTimeline::TimelinePlot::build_layout $dataset {*}[embedded_heatmap_layout_options $width]]
        set records [dict get $layout records]
        set_embedded_heatmap_canvas_height [dict get $layout canvas_height]
        foreach record $records {
            set embedded_record_by_tag([dict get $record tag]) $record
        }
        catch {::RMSXFlipbookTimeline::TimelinePlot::install_record_map $records}
        lassign [::RMSXFlipbookTimeline::TimelinePlot::color_scale_range $dataset $layout] min_val max_val

        $embedded_heatmap_canvas delete all
        $embedded_heatmap_canvas configure -scrollregion [list 0 0 [dict get $layout canvas_width] [dict get $layout canvas_height]]
        set left [dict get $layout left]
        set heat_top [dict get $layout heat_top]
        set heat_bottom [dict get $layout heat_bottom]
        set plot_w [dict get $layout plot_width]

        $embedded_heatmap_canvas create text $left 24 \
            -anchor w \
            -font TkHeadingFont \
            -fill "#222222" \
            -text [dict get $dataset title]
        $embedded_heatmap_canvas create text [expr {$left + $plot_w}] 24 \
            -anchor e \
            -font TkDefaultFont \
            -fill "#555555" \
            -text [dict get $dataset value_label]

        foreach record $records {
            set row [dict get $record row]
            set col [dict get $record column]
            set tag [dict get $record tag]
            set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row $col]
            $embedded_heatmap_canvas create rectangle \
                [dict get $record x0] [dict get $record y0] \
                [dict get $record x1] [dict get $record y1] \
                -outline "" \
                -fill [::RMSXFlipbookTimeline::TimelinePlot::cell_color $value $min_val $max_val $palette $dataset] \
                -tags [list pickable embedded_pickable embedded_heat_cell $tag]
            if {[::RMSXFlipbookTimeline::Matrix::row_masked $dataset $row]} {
                ::RMSXFlipbookTimeline::TimelinePlot::draw_mask_hatch \
                    $embedded_heatmap_canvas \
                    $record \
                    [list embedded_pickable embedded_heat_cell $tag]
            }
        }
        $embedded_heatmap_canvas create rectangle $left $heat_top [expr {$left + $plot_w}] $heat_bottom -outline "#333333"

        set rows [dict get $dataset rows]
        set row_step [expr {max(1, int(ceil([llength $rows] / 14.0)))}]
        for {set row 0} {$row < [llength $rows]} {incr row $row_step} {
            set y [expr {$heat_top + ($row * [dict get $layout cell_height]) + ([dict get $layout cell_height] / 2.0)}]
            $embedded_heatmap_canvas create text [expr {$left - 8}] $y \
                -anchor e \
                -font TkDefaultFont \
                -fill "#444444" \
                -text [::RMSXFlipbookTimeline::Matrix::row_label [lindex $rows $row]]
        }

        set columns [dict get $dataset columns]
        set col_step [expr {max(1, int(ceil([llength $columns] / 10.0)))}]
        for {set col 0} {$col < [llength $columns]} {incr col $col_step} {
            set x [expr {$left + ($col * [dict get $layout cell_width]) + ([dict get $layout cell_width] / 2.0)}]
            $embedded_heatmap_canvas create text $x [expr {$heat_bottom + 8}] \
                -anchor n \
                -font TkDefaultFont \
                -fill "#444444" \
                -text [::RMSXFlipbookTimeline::Matrix::column_label [lindex $columns $col]]
        }

        ::RMSXFlipbookTimeline::TimelinePlot::draw_legend \
            $embedded_heatmap_canvas \
            $left \
            [expr {$heat_bottom + 38}] \
            $plot_w \
            12 \
            $min_val \
            $max_val \
            $palette \
            [dict get $dataset value_label] \
            $dataset
        ::RMSXFlipbookTimeline::Navigation::attach $embedded_heatmap_canvas $records [list ::RMSXFlipbookTimeline::Dashboard::select_embedded_timeline $embedded_heatmap_canvas $dataset] [list ::RMSXFlipbookTimeline::TimelinePlot::clear_on_canvas $embedded_heatmap_canvas]
        $embedded_heatmap_canvas bind embedded_pickable <Motion> {::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_hover_current}
        mount_heatmap_tools $embedded_heatmap_canvas $dataset

        set embedded_heatmap_status_var [format {%s: %d residues x %d slices} \
            [dict get $dataset title] \
            [dict get $dataset row_count] \
            [dict get $dataset column_count]]
        return [dict create layout $layout rows [dict get $dataset row_count] columns [dict get $dataset column_count]]
    }

    proc embedded_native_plot_args {folder csv_path width {record __current__}} {
        variable timeline_scale_min
        variable timeline_scale_max
        variable native_show_context_plots
        set show_context [expr {$native_show_context_plots ? 1 : 0}]
        set args [list \
            folder $folder \
            width $width \
            palette [::RMSXFlipbookTimeline::state_get palette viridis] \
            pick 1 \
            top_margin 26 \
            bottom_margin 62 \
            heatmap_min_height 178 \
            heatmap_max_height 224 \
            chain_heatmap_min_height 154 \
            chain_heatmap_max_height 205 \
            chart_gap 6 \
            rmsd_height 70 \
            rmsf_width 70 \
            side_gap 18 \
            left_margin 122 \
            min_plot_width 250 \
            rmsf_right_padding 30 \
            show_title 0 \
            show_heat_title 0 \
            show_rmsd_chart $show_context \
            show_rmsf_chart $show_context \
            show_slice_rmsd_chart 0 \
            show_summary_chart 0]
        foreach item [native_plot_time_axis_args $record] {
            lappend args $item
        }
        if {[string trim $csv_path] ne ""} {
            lappend args csv $csv_path
        }
        set min_text [string trim $timeline_scale_min]
        set max_text [string trim $timeline_scale_max]
        if {$min_text ne "" && $max_text ne ""} {
            lappend args min_value $min_text max_value $max_text
        }
        return $args
    }

    proc native_plot_time_axis_args {{current __current__}} {
        if {$current eq "__current__"} {set current [::RMSXFlipbookTimeline::Results::get]}
        set args {}
        if {$current eq {}} { return $args }
        if {[dict exists $current time_step_ps] && [dict get $current time_step_ps] ne ""} {
            lappend args time_step_ps [dict get $current time_step_ps]
        }
        if {[dict exists $current native_result plan]} {
            set plan [dict get $current native_result plan]
            if {[dict exists $plan adjusted_frames]} { lappend args total_frames [dict get $plan adjusted_frames] } elseif {[dict exists $plan used_frames]} { lappend args total_frames [dict get $plan used_frames] }
            if {[dict exists $plan start_frame]} { lappend args first_frame [dict get $plan start_frame] }
        }
        return $args
    }

    proc embedded_native_plot_pick_current {} {
        variable embedded_heatmap_status_var
        if {[catch {::RMSXFlipbookTimeline::PlotWindow::pick_current} result]} {
            set embedded_heatmap_status_var "Selection failed: $result"
            return
        }
        if {[catch {dict get $result message} message] == 0} {
            set embedded_heatmap_status_var $message
        }
        return $result
    }

    proc embedded_native_plot_hover_current {} {
        variable embedded_heatmap_status_var
        catch {::RMSXFlipbookTimeline::PlotWindow::hover_current}
        set message [set ::RMSXFlipbookTimeline::PlotWindow::status_var]
        if {$message ne ""} {
            set embedded_heatmap_status_var $message
        }
    }

    proc draw_embedded_native_plot {folder csv_path metric} {
        variable embedded_heatmap_canvas
        variable embedded_heatmap_status_var
        variable embedded_heatmap_mode
        variable embedded_heatmap_last_width
        catch {::RMSXFlipbookTimeline::PlotWindow::clear 0}
        set embedded_heatmap_mode "native"
        if {$embedded_heatmap_canvas ne "" && [info commands winfo] ne "" && [winfo exists $embedded_heatmap_canvas]} {
            set embedded_heatmap_last_width [winfo width $embedded_heatmap_canvas]
        }
        set width [embedded_heatmap_width]
        set prepared [::RMSXFlipbookTimeline::PlotWindow::prepare {*}[embedded_native_plot_args $folder $csv_path $width]]
        set result [::RMSXFlipbookTimeline::PlotWindow::result_from_prepared $prepared 0 1]
        set_embedded_heatmap_canvas_height [dict get [dict get $prepared layout] canvas_height]
        if {$embedded_heatmap_canvas ne "" && [info commands winfo] ne "" && [winfo exists $embedded_heatmap_canvas]} {
            set result [::RMSXFlipbookTimeline::PlotWindow::draw_prepared $embedded_heatmap_canvas $prepared]
            $embedded_heatmap_canvas configure -scrollregion [list 0 0 \
                [dict get [dict get $prepared layout] canvas_width] \
                [dict get [dict get $prepared layout] canvas_height]]
            ::RMSXFlipbookTimeline::Navigation::attach $embedded_heatmap_canvas [dict get [dict get $prepared layout] records] [list ::RMSXFlipbookTimeline::Dashboard::select_embedded_native $embedded_heatmap_canvas] [list ::RMSXFlipbookTimeline::PlotWindow::clear_on_canvas $embedded_heatmap_canvas]
            ::RMSXFlipbookTimeline::PlotWindow::context_attach $embedded_heatmap_canvas $prepared
            $embedded_heatmap_canvas bind pickable <Motion> {::RMSXFlipbookTimeline::Dashboard::embedded_native_plot_hover_current}
            $embedded_heatmap_canvas bind pickable <Leave> {}
            mount_heatmap_tools $embedded_heatmap_canvas [::RMSXFlipbookTimeline::PlotWindow::exploration_dataset $prepared]
        }
        if {[dict get $result flanking_plots]} {
            set embedded_heatmap_status_var [format {%s plot: %d residues x %d slices, RMSD %d points, RMSF %d residues.} \
                [dict get $result metric_label] \
                [dict get $result rows] \
                [dict get $result columns] \
                [dict get $result rmsd_points] \
                [dict get $result rmsf_points]]
        } else {
            set embedded_heatmap_status_var [format {%s heatmap: %d residues x %d slices. Add rmsd.csv/rmsf.csv to show flanking context.} \
                [dict get $result metric_label] \
                [dict get $result rows] \
                [dict get $result columns]]
        }
        catch {::RMSXFlipbookTimeline::PlotWindow::install_pick_trace}
        return $result
    }

    proc timeline_live_options {} {
        variable timeline_selection
        variable timeline_column_mode
        variable timeline_slice_aggregation
        variable timeline_slice_representative
        variable native_slicing_mode
        variable native_slices
        variable native_slice_size
        variable native_start
        variable native_end
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
        variable timeline_native_dist
        variable timeline_native_ref_frame
        variable timeline_native_from_selection_list
        variable timeline_native_to_selection
        variable timeline_inter_method
        variable timeline_inter_dist
        variable timeline_inter_from_selection
        variable timeline_inter_to_selection
        variable timeline_inter_selection_list

        set first [validate_int "First frame" $native_start 0]
        set last [validate_int "Last frame" $native_end -1]
        set opts [list selection $timeline_selection first_frame $first last_frame $last progress_callback ::RMSXFlipbookTimeline::Operation::checkpoint]
        lappend opts \
            column_mode $timeline_column_mode \
            slicing_mode $native_slicing_mode \
            slices $native_slices \
            slice_size $native_slice_size \
            slice_aggregation $timeline_slice_aggregation \
            slice_representative $timeline_slice_representative
        lappend opts user_field $timeline_user_field
        lappend opts \
            native_dist $timeline_native_dist \
            native_ref_frame $timeline_native_ref_frame \
            native_from_selection_list $timeline_native_from_selection_list \
            native_to_selection $timeline_native_to_selection
        lappend opts \
            inter_method $timeline_inter_method \
            inter_dist $timeline_inter_dist \
            inter_from_selection $timeline_inter_from_selection \
            inter_to_selection $timeline_inter_to_selection \
            inter_selection_list $timeline_inter_selection_list
        if {[string trim $timeline_residue_function] ne ""} {
            lappend opts \
                residue_function $timeline_residue_function \
                residue_function_label $timeline_residue_function_label \
                residue_function_unit $timeline_residue_function_unit \
                residue_function_context_selection $timeline_residue_function_context
        }
        lappend opts \
            cc_map_file $timeline_cc_map_file \
            cc_vol_id $timeline_cc_vol_id \
            cc_map_res $timeline_cc_map_res \
            cc_spacing $timeline_cc_spacing \
            cc_threshold $timeline_cc_threshold \
            cc_use_spacing $timeline_cc_use_spacing \
            cc_use_threshold $timeline_cc_use_threshold \
            cc_method $timeline_cc_method \
            cc_selection_list $timeline_cc_selection_list
        return $opts
    }

    proc run_native_metric {} {
        return [perform_operation run_native_metric ::RMSXFlipbookTimeline::Dashboard::_run_native_metric]
    }

    proc _run_native_metric {} {
        variable native_topology
        variable native_trajectory
        variable native_output
        variable native_chain
        variable native_slices
        variable native_slice_size
        variable native_slicing_mode
        variable native_start
        variable native_end
        variable native_time_step
        variable native_total_time_ns
        variable native_total_frames
        variable native_detected_total_frames
        variable native_analysis_type
        variable native_log_transform
        variable native_mask_selection
        variable native_metric
        variable timeline_metric
        variable folder

        persist_common_state
        if {$native_topology eq "" || ![file exists $native_topology]} {
            error "Choose a topology PDB first."
        }
        if {$native_trajectory eq "" || ![file exists $native_trajectory]} {
            error "Choose a trajectory DCD first."
        }
        if {$native_output eq ""} {
            error "Choose an output folder first."
        }

        set start_value [validate_int "Start frame" $native_start 0]
        set end_value [validate_int "End frame" $native_end -1]
        set time_step_value [effective_time_step_ps_for_run]
        set time_known [expr {$time_step_value ne ""}]
        set calculator_time_step [expr {$time_known ? $time_step_value : 1.0}]
        set manual_length_ns [native_total_time_override_ns_value]
        set slices_value [validate_int "Slices" $native_slices 1]
        set use_slice_size [expr {$native_slicing_mode eq "slice_size"}]
        set slice_size_value ""
        if {$use_slice_size} {
            if {[string trim $native_slice_size] eq ""} {
                error "Frames per slice must be set when that slicing mode is active."
            }
            set slice_size_value [validate_int "Slice size" $native_slice_size 1]
        }

        ensure_native_metric
        set key [metric_key $native_metric]
        set single_proc ::RMSXFlipbookTimeline::run_native_analysis
        set all_proc ::RMSXFlipbookTimeline::run_native_all_chain_analysis
        set label "RMSX"
        if {$key in {shift shiftmap shift_map}} {
            set single_proc ::RMSXFlipbookTimeline::run_native_shift_map
            set all_proc ::RMSXFlipbookTimeline::run_native_all_chain_shift_map
            set label "Shift-Map"
        } elseif {$key in {lddt lddt_map 1_lddt 1___lddt}} {
            set single_proc ::RMSXFlipbookTimeline::run_native_lddt_map
            set all_proc ::RMSXFlipbookTimeline::run_native_all_chain_lddt_map
            set label "lDDT"
        }

        if {$use_slice_size} {
            set slicing_args [list -slice_size $slice_size_value]
        } else {
            set slicing_args [list -num_slices $slices_value]
        }

        set run_output [unique_run_path $native_output $native_metric]
        set chain_mode [string tolower [string trim $native_chain]]
        if {$chain_mode in {all * auto}} {
            set command [list $all_proc $native_topology $native_trajectory $run_output]
        } else {
            set command [list $single_proc $native_topology $native_trajectory $run_output -chain [selected_chain_group]]
        }
        lappend command {*}$slicing_args \
            -start_frame $start_value \
            -end_frame $end_value \
            -overwrite 0 \
            -progress_callback ::RMSXFlipbookTimeline::Operation::checkpoint \
            -cleanup 1 \
            -analysis_type $native_analysis_type \
            -rmsd_time_step $calculator_time_step \
            -time_known $time_known \
            -manual_length_ns $manual_length_ns \
            -log_transform $native_log_transform \
            -mask_selection $native_mask_selection \
            -verbose 0

        set_status "Running $label analysis..."
        set result [uplevel #0 $command]
        set detected_total [result_total_frame_count $result]
        if {$detected_total ne ""} {
            set native_detected_total_frames $detected_total
            set native_total_frames $detected_total
            ::RMSXFlipbookTimeline::state_set native_total_frames $native_total_frames
        }
        if {[dict exists $result output_dir]} {
            set folder [dict get $result output_dir]
        } else {
            set folder $run_output
        }
        set resolved_plan [result_frame_plan $result]
        set result_first $start_value
        set result_last $end_value
        if {[dict exists $resolved_plan start_frame]} { set result_first [dict get $resolved_plan start_frame] }
        if {[dict exists $resolved_plan end_frame]} { set result_last [dict get $resolved_plan end_frame] }
        variable saved_result
        set saved_result [dict create folder $folder metric $native_metric label $native_metric source_paths [list $native_topology $native_trajectory] chain $native_chain selection [result_analysis_selection $result] frame_first $result_first frame_last $result_last native_result $result time_known $time_known time_step_ps $time_step_value view_options [timeline_plot_options]]
        refresh_export_controls
        ::RMSXFlipbookTimeline::Operation::checkpoint [dict create stage loading message "Analysis saved; loading result…"]
        if {[catch {load_folder_with_view $folder $saved_result} load_error load_options]} {
            return -code error -errorcode {RMSXFLIPBOOK PARTIAL} "Analysis saved to $folder; display failed: $load_error. Use Retry view."
        }
        set saved_result {}
        focus_flipbook_scene
        add_dataset_item $label flipbook $folder
        set_status [format "%s complete: %s" $label $folder]
        refresh_dashboard
        maybe_scroll_easy_to_heatmap_after_run
        return $result
    }

    proc result_analysis_selection {result} {
        if {[dict exists $result analysis_selection]} {return [dict get $result analysis_selection]}
        set selections {}
        if {[dict exists $result chain_results]} {
            foreach child [dict get $result chain_results] {
                set selection [result_analysis_selection $child]
                if {$selection ne "" && [lsearch -exact $selections "($selection)"] < 0} {lappend selections "($selection)"}
            }
        }
        return [join $selections " or "]
    }

    proc result_frame_plan {result} {
        if {[dict exists $result plan]} { return [dict get $result plan] }
        if {[dict exists $result chain_results]} {
            foreach child [dict get $result chain_results] {
                set plan [result_frame_plan $child]
                if {$plan ne {}} { return $plan }
            }
        }
        return {}
    }

    proc result_total_frame_count {result} {
        if {[catch {dict size $result}]} {
            return ""
        }
        if {[dict exists $result total_frame_count]} {
            set total [dict get $result total_frame_count]
            set offset 0
            if {[dict exists $result frame_offset]} {set offset [dict get $result frame_offset]}
            if {[string is integer -strict $total] && [string is integer -strict $offset] &&
                $offset >= 0 && $total > $offset} {
                return [expr {int($total) - int($offset)}]
            }
        }
        if {[dict exists $result chain_results]} {
            foreach chain_result [dict get $result chain_results] {
                set total [result_total_frame_count $chain_result]
                if {$total ne ""} {
                    return $total
                }
            }
        }
        return ""
    }

    proc run_live_metric {} {
        return [perform_operation run_live_metric ::RMSXFlipbookTimeline::Dashboard::_run_live_metric]
    }

    proc _run_live_metric {} {
        variable timeline_metric
        variable timeline_column_mode
        variable timeline_slice_aggregation
        ensure_timeline_metric
        persist_common_state
        set molid [dashboard_molid]
        set result [::RMSXFlipbookTimeline::show_live_timeline \
            $molid \
            [dict get [metric_record $timeline_metric] key] \
            {*}[timeline_live_options] \
            {*}[timeline_plot_options]]
        if {[dict exists $result dataset]} {
            set dataset [dict get $result dataset]
            set metadata [dict create label $timeline_metric source_molid $molid selection $::RMSXFlipbookTimeline::Dashboard::timeline_selection view_options [timeline_plot_options] palette $::RMSXFlipbookTimeline::Dashboard::palette]
            set columns [dict get $dataset columns]
            if {[llength $columns]} {
                set first [lindex $columns 0]; set last [lindex $columns end]
                foreach {column key out} [list $first frame frame_first $last frame frame_last] {
                    if {[dict exists $column $key]} {dict set metadata $out [dict get $column $key]}
                }
                if {[dict exists $first frame_start]} {dict set metadata frame_first [dict get $first frame_start]}
                if {[dict exists $last frame_end]} {dict set metadata frame_last [dict get $last frame_end]}
            }
            ::RMSXFlipbookTimeline::Results::update $metadata
        }
        set detail "live molecule $molid"
        set mode_label "frames"
        if {[string tolower [string trim $timeline_column_mode]] in {slice slices}} {
            set mode_label "slices"
            append detail " aggregated by $timeline_slice_aggregation"
        }
        add_dataset_item "$timeline_metric ($mode_label)" matrix $detail
        set_status "Timeline $mode_label matrix opened for $timeline_metric."
        return $result
    }

    proc format_mouse_status {status} {
        return [::RMSXFlipbookTimeline::mouse_rotation_format_status $status]
    }

    proc enable_mouse_rotation {{reset_stats 1} {mode_override ""}} {
        variable mouse_mode
        variable mouse_sensitivity

        if {$mode_override ne ""} {
            set mouse_mode $mode_override
        }
        set sensitivity [validate_double "Mouse sensitivity" $mouse_sensitivity 0.01]
        set result [::RMSXFlipbookTimeline::install_mouse_rotation $mouse_mode $sensitivity]
        if {$reset_stats} {
            set result [::RMSXFlipbookTimeline::mouse_rotation_reset_stats]
        }
        set mouse_mode [dict get $result mode]
        set mouse_sensitivity [format "%.2f" [dict get $result sensitivity]]
        persist_common_state
        return $result
    }

    proc auto_enable_mouse_rotation_status {} {
        variable auto_mouse_rotation

        if {!$auto_mouse_rotation} {
            return ""
        }
        if {[catch {enable_mouse_rotation 1 coords} result]} {
            return "Per-slice drag not enabled: $result"
        }
        return "Per-slice drag enabled: [format_mouse_status $result]"
    }

    proc ensure_default_mouse_rotation {} {
        variable auto_mouse_rotation
        variable mouse_mode
        if {!$auto_mouse_rotation} {
            return ""
        }
        set result_molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $result_molids] == 0} {
            return ""
        }
        set mouse_mode coords
        if {[catch {enable_mouse_rotation 1 coords} result]} {
            set_status "Per-slice rotation could not be enabled: $result"
            return ""
        }
        return $result
    }

    proc focus_flipbook_scene {} {
        if {[info commands mol] eq "" || [info commands molinfo] eq ""} {
            return
        }
        set result_molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $result_molids] == 0} {
            return
        }
        # Reviewer examples may be opened inside an existing working session.
        set preserve_unrelated [expr {[info exists ::RMSXFlipbookTimeline::Reviewer::active] && $::RMSXFlipbookTimeline::Reviewer::active}]
        foreach molid [molinfo list] {
            if {[lsearch -exact $result_molids $molid] >= 0} {
                catch {mol on $molid}
            } elseif {!$preserve_unrelated} {
                catch {mol off $molid}
            }
        }
        set center_index [expr {int(([llength $result_molids] - 1) / 2)}]
        set center_molid [lindex $result_molids $center_index]
        if {[lsearch -exact [molinfo list] $center_molid] != -1} {
            catch {mol top $center_molid}
        }
        catch {display update}
    }

    proc toggle_mouse_rotation {} {
        if {[catch {::RMSXFlipbookTimeline::mouse_rotation_status} status]} {
            set_status "Per-slice drag status failed:\n$status"
            return
        }
        if {[dict get $status enabled]} {
            if {[catch {::RMSXFlipbookTimeline::uninstall_mouse_rotation} result]} {
                set_status "Per-slice drag disable failed:\n$result"
                return
            }
            set_status "Per-slice drag disabled."
            return $result
        }
        if {[catch {enable_mouse_rotation 1 coords} result]} {
            set_status "Per-slice drag failed:\n$result"
            return
        }
        set_status "Per-slice drag enabled.\n[format_mouse_status $result]"
        return $result
    }

    proc show_mouse_status {} {
        if {[catch {::RMSXFlipbookTimeline::mouse_rotation_status} result]} {
            set_status "Per-slice drag status failed:\n$result"
            return
        }
        set_status "Per-slice drag:\n[format_mouse_status $result]"
        return $result
    }

    proc reset_mouse_stats {} {
        if {[catch {::RMSXFlipbookTimeline::mouse_rotation_reset_stats} result]} {
            set_status "Per-slice drag stats reset failed:\n$result"
            return
        }
        set_status "Per-slice drag stats reset.\n[format_mouse_status $result]"
        return $result
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
        persist_common_state
        set_status [format "Mouse burst complete: %d x %s %.3f\nTotal %.3f ms, loop avg %.3f ms\n%s" \
            [dict get $result burst_count] \
            [dict get $result burst_axis] \
            [dict get $result burst_angle] \
            [dict get $result burst_total_ms] \
            [dict get $result burst_loop_avg_ms] \
            [format_mouse_status $result]]
        return $result
    }

    proc nudge_spacing {delta} {
        if {[catch {::RMSXFlipbookTimeline::adjust_spacing $delta} result]} {
            set_status "Spacing adjustment failed:\n$result"
            return
        }
        set_status [format "Spacing: %.2f A" [dict get $result spacing]]
        return $result
    }

    proc nudge_thickness {delta} {
        if {[catch {::RMSXFlipbookTimeline::adjust_thickness $delta} result]} {
            set_status "Thickness adjustment failed:\n$result"
            return
        }
        set_status [format "Thickness: %.2f" [dict get $result thick]]
        return $result
    }

    proc reset_view {} {
        if {[catch {::RMSXFlipbookTimeline::reset_view} result]} {
            set_status "View reset failed:\n$result"
            return
        }
        set_status "View reset."
        return $result
    }

    proc clear_scene {} {
        variable displayed_flipbook_path
        variable easy_auto_scrolled_after_run
        if {[::RMSXFlipbookTimeline::Operation::running]} { return }
        if {[info commands tk_messageBox] ne ""} {
            if {[tk_messageBox -parent $::RMSXFlipbookTimeline::Dashboard::top -type okcancel -icon question -title "Remove flipbook" -message "Remove the loaded plugin molecules and current result? Files on disk are kept."] ne "ok"} { return }
        }
        ::RMSXFlipbookTimeline::reset 1
        ::RMSXFlipbookTimeline::Results::clear
        set displayed_flipbook_path ""
        set easy_auto_scrolled_after_run 0
        clear_embedded_heatmap
        refresh_dashboard
        set_status "Loaded flipbook removed. Files kept."
    }

    proc close_window {} {
        variable top
        variable close_pending
        if {[::RMSXFlipbookTimeline::Operation::running]} {
            set close_pending 1
            ::RMSXFlipbookTimeline::Operation::request_cancel
            return
        }
        hide_tooltip
        stop_scene_refresh
        foreach name {native_frame_count_after embedded_heatmap_redraw_after} {
            upvar 0 ::RMSXFlipbookTimeline::Dashboard::$name pending
            if {$pending ne ""} { after cancel $pending; set pending "" }
        }
        catch {::RMSXFlipbookTimeline::cleanup_side_effects 0 {window input}}
        if {[winfo exists $top]} { wm withdraw $top }
        set close_pending 0
    }

    proc apply_ramachandran_overlay {} {
        persist_common_state
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $molids] == 0} {
            set_status "Load a flipbook folder before applying the phi/psi snapshot overlay."
            return
        }
        if {[catch {
            set molid [dashboard_molid]
            ::RMSXFlipbookTimeline::apply_ramachandran_overlay \
                $molid \
                {*}[timeline_live_options]
        } result]} {
            set_status "Phi/psi overlay failed:\n$result"
            return
        }
        set overlay [dict get $result overlay]
        add_dataset_item "Phi/Psi Regions" overlay "[dict get $overlay drawn] snapshot segments"
        set_status "Applied phi/psi region overlay and opened the matching matrix."
        return $result
    }

    proc clear_ramachandran_overlay {} {
        if {[catch {::RMSXFlipbookTimeline::clear_angle_overlay} result]} {
            set_status "Clear phi/psi overlay failed:\n$result"
            return
        }
        set_status "Cleared phi/psi overlay."
        return $result
    }

    proc run_analysis {} {
        variable native_metric
        variable timeline_metric
        persist_common_state
        set route [metric_route $timeline_metric]
        if {$route eq "native"} {
            set native_metric $timeline_metric
            if {[catch {run_native_metric} result]} {
                set_status "Run failed:\n$result"
                return
            }
        } elseif {$route eq "external"} {
            set_status "This metric opens a separate VMD tool. Use Classic controls for external tool launch."
            return
        } else {
            if {[catch {run_live_metric} result]} {
                set_status "Timeline metric failed:\n$result"
                return
            }
        }
        refresh_dashboard
        return $result
    }

    proc load_existing_folder {} {
        return [perform_operation load_existing_folder ::RMSXFlipbookTimeline::Dashboard::_load_existing_folder]
    }

    proc _load_existing_folder {} {
        variable folder
        if {$folder eq "" || ![file isdirectory $folder]} { error "Choose an existing result folder first." }
        variable saved_result
        set saved_result [dict create folder $folder]
        if {[catch {load_folder_with_view $folder {}} message options]} {
            refresh_export_controls
            return -options $options $message
        }
        set saved_result {}
        set result [::RMSXFlipbookTimeline::Results::get]
        focus_flipbook_scene
        add_dataset_item "Flipbook" flipbook $folder
        set_status "Loaded [file tail $folder]."
        refresh_dashboard
        return $result
    }

    proc native_metric_chain_suffix {metric} {
        set key [metric_key $metric]
        if {$key in {shift shiftmap shift_map}} {
            return shiftmap
        }
        if {$key in {lddt lddt_map 1_lddt 1___lddt}} {
            return lddtmap
        }
        return rmsx
    }

    proc native_metric_csv_patterns {metric} {
        set key [metric_key $metric]
        if {$key in {lddt lddt_map 1_lddt 1___lddt}} {
            return {lddt_vmd_native.csv lddt*.csv}
        }
        if {$key in {shift shiftmap shift_map}} {
            return {rmsx_vmd_native.csv rmsx*.csv shift*.csv}
        }
        return {rmsx_vmd_native.csv rmsx*.csv}
    }

    proc native_metric_csv_candidate_ok {path} {
        set name [string tolower [file tail $path]]
        if {$name in {rmsd.csv rmsf.csv masked_residues.csv}} {
            return 0
        }
        if {[string match "*summary*.csv" $name]} {
            return 0
        }
        if {[string match "*_plot_*" $name]} {
            return 0
        }
        return 1
    }

    proc native_metric_matrix_dirs {root metric} {
        variable native_chain

        set suffix [native_metric_chain_suffix $metric]
        set dirs [list $root]

        set chain_text [string trim $native_chain]
        set chain_mode [string tolower $chain_text]
        if {$chain_text ne "" && $chain_mode ni {all * auto}} {
            lappend dirs [file join $root "chain_${chain_text}_${suffix}"]
        }

        lappend dirs [file join $root combined]
        foreach path [lsort [glob -nocomplain -directory $root -types d "chain_*_${suffix}"]] {
            lappend dirs $path
        }

        set unique {}
        foreach dir $dirs {
            set dir [file normalize $dir]
            if {[lsearch -exact $unique $dir] < 0} {
                lappend unique $dir
            }
        }
        return $unique
    }

    proc native_metric_matrix_csv {folder metric} {
        set root [file normalize $folder]
        foreach dir [native_metric_matrix_dirs $root $metric] {
            if {![file isdirectory $dir]} {
                continue
            }
            foreach pattern [native_metric_csv_patterns $metric] {
                foreach path [lsort [glob -nocomplain -directory $dir $pattern]] {
                    if {[file isfile $path] && [native_metric_csv_candidate_ok $path]} {
                        return [file normalize $path]
                    }
                }
            }
        }
        return ""
    }

    proc render_native_heatmap {{metric ""}} {
        set current [::RMSXFlipbookTimeline::Results::get]
        set plot_folder [current_native_folder]
        if {[dict exists $current metric] && [dict get $current metric] ne ""} { set metric [dict get $current metric] }
        if {$metric eq ""} { set metric RMSX }
        set csv_path ""
        if {[dict exists $current csv]} { set csv_path [dict get $current csv] }
        if {$csv_path eq ""} { set csv_path [native_metric_matrix_csv $plot_folder $metric] }
        if {$csv_path ne ""} { set plot_folder [file dirname $csv_path] }
        set result [draw_embedded_native_plot $plot_folder $csv_path $metric]
        return [dict create metric $metric detail $plot_folder result $result]
    }

    proc view_matrix {} {
        if {[catch {render_native_heatmap} info]} {
            set_status "Matrix view failed:\n$info"
            return
        }
        set matrix_metric [dict get $info metric]
        set detail [dict get $info detail]
        add_dataset_item "$matrix_metric Matrix" matrix $detail
        set_status "Displayed $matrix_metric heatmap in the RMSX / Flipbook panel."
        return [dict get $info result]
    }

    proc current_native_folder {} {
        set result [::RMSXFlipbookTimeline::Results::get]
        if {$result eq {} || ![dict exists $result folder] || [dict get $result folder] eq ""} {
            error "Load or run a flipbook first."
        }
        set selected [dict get $result folder]
        if {![file isdirectory $selected]} { error "Result folder is unavailable: $selected" }
        return [file normalize $selected]
    }

    proc choose_render_file {} {
        variable top
        set base [::RMSXFlipbookTimeline::state_get source_folder ""]
        if {$base eq "" || ![file isdirectory $base]} {
            set base [pwd]
        }
        set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        set initial [format "rmsx_%s.png" [string tolower [string trim $palette]]]
        if {[info commands tk_getSaveFile] eq ""} {
            return [file normalize [file join $base $initial]]
        }
        set picked [tk_getSaveFile \
            -parent $top \
            -initialdir $base \
            -initialfile $initial \
            -title "Save RMSX Flipbook Image" \
            -defaultextension ".png" \
            -filetypes {{"PNG images" {.png}} {"TGA images" {.tga}} {"JPEG images" {.jpg .jpeg}} {"All files" {*}}}]
        if {$picked eq ""} {
            return ""
        }
        return [file normalize $picked]
    }

    proc save_flipbook_image {} {
        variable render_transparent_png
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $molids] == 0} {
            set_status "Load or run a flipbook before saving an image."
            return
        }
        set filename [choose_render_file]
        if {$filename eq ""} {
            return
        }
        set_status "Saving flipbook image...\n$filename"
        update idletasks
        if {[catch {
            ::RMSXFlipbookTimeline::render_flipbook_image \
                -output_name $filename \
                -method TachyonInternal \
                -width 2000 \
                -height 1000 \
                -view_preset rmsx \
                -transparent_background $render_transparent_png \
                -overwrite 1
        } result]} {
            set_status "Image export failed:\n$result"
            return
        }
        add_dataset_item "Saved Image" image [dict get $result image]
        set transparent_note ""
        if {[dict exists $result transparent_background] && [dict get $result transparent_background]} {
            set transparent_note "\nTransparent background: yes"
        }
        set_status [format "Saved flipbook image.\n%s\nFormat: %s\nBytes: %s%s" \
            [dict get $result image] \
            [dict get $result format] \
            [dict get $result bytes] \
            $transparent_note]
        return $result
    }

    proc repair_native_bfactors {} {
        if {[catch {current_native_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        set_status "Repairing slice PDB B-factors...\n$selected_folder"
        update idletasks
        if {[catch {::RMSXFlipbookTimeline::repair_folder_bfactors $selected_folder} result]} {
            set_status "B-factor repair failed:\n$result"
            return
        }
        set_status [format "B-factor repair complete.\nCSV: %s\nUpdated PDBs: %s" \
            [dict get $result csv] \
            [dict get $result updated_count]]
        return $result
    }

    proc export_native_heatmap_svg {} {
        if {[catch {current_native_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        set_status "Writing heatmap SVG...\n$selected_folder"
        update idletasks
        if {[catch {::RMSXFlipbookTimeline::write_heatmap_svg $selected_folder -palette $palette} result]} {
            set_status "Heatmap SVG export failed:\n$result"
            return
        }
        set_status [format "Heatmap SVG written.\nSVG: %s\nCSV: %s" \
            [dict get $result svg] \
            [dict get $result csv]]
        return $result
    }

    proc export_native_report_svg {} {
        if {[catch {current_native_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        set_status "Writing report SVG...\n$selected_folder"
        update idletasks
        if {[catch {::RMSXFlipbookTimeline::write_report_svg $selected_folder -palette $palette} result]} {
            set_status "Report SVG export failed:\n$result"
            return
        }
        set_status [format "Report SVG written.\nSVG: %s\nCSV: %s" \
            [dict get $result svg] \
            [dict get $result csv]]
        return $result
    }

    proc export_multimodel_pdb {} {
        if {[catch {current_native_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        set_status "Writing multi-model flipbook PDB...\n$selected_folder"
        update idletasks
        if {[catch {::RMSXFlipbookTimeline::write_multimodel_pdb $selected_folder} result]} {
            set_status "Multi-model PDB export failed:\n$result"
            return
        }
        set_status [format "Multi-model PDB written.\nPDB: %s\nModels: %s" \
            [dict get $result pdb] \
            [dict get $result models]]
        return $result
    }

    proc open_full_plot_window {} {
        if {[catch {current_native_folder} selected_folder]} {
            set_status $selected_folder
            return
        }
        set matrix_metric [ensure_native_metric]
        set plot_folder $selected_folder
        set csv_path [native_metric_matrix_csv $selected_folder $matrix_metric]
        if {$csv_path ne ""} {
            set plot_folder [file dirname $csv_path]
        }
        set width [expr {max(880, [embedded_heatmap_width])}]
        set plot_args [embedded_native_plot_args $plot_folder $csv_path $width]
        set_status "Opening full plot window...\n$plot_folder"
        update idletasks
        if {[catch {::RMSXFlipbookTimeline::show_plot_window {*}$plot_args} result]} {
            set_status "Full plot window failed:\n$result"
            return
        }
        set_status [format "Full plot window opened.\nResidues: %s\nSlices: %s" \
            [dict get $result rows] \
            [dict get $result columns]]
        return $result
    }

    proc refresh_native_heatmap_view {} {
        if {[catch {render_native_heatmap} result]} {
            set_status $result
        }
    }

    proc show_manifest {} {
        set manifest [::RMSXFlipbookTimeline::state_get manifest_path ""]
        if {$manifest eq "" || ![file exists $manifest]} {
            set_status "No manifest has been written yet."
            return
        }
        set fp [open $manifest r]
        set payload [read $fp]
        close $fp
        set_status $payload
        return $manifest
    }

    proc load_manifest_file {} {
        variable top
        variable folder
        set start [string trim $folder]
        if {$start eq "" || ![file isdirectory $start]} {
            set start [::RMSXFlipbookTimeline::state_get source_folder ""]
        }
        if {$start eq "" || ![file isdirectory $start]} {
            set start [pwd]
        }
        if {[info commands tk_getOpenFile] eq ""} {
            set_status "Manifest loading needs Tk file selection in this dashboard."
            return
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
        if {[catch {::RMSXFlipbookTimeline::load_manifest $picked} result]} {
            set_status "Manifest load failed:\n$result"
            return
        }
        sync_from_state
        focus_flipbook_scene
        ensure_default_mouse_rotation
        catch {render_native_heatmap}
        add_dataset_item "Manifest" manifest $picked
        refresh_dashboard
        set_status [format "Loaded manifest.\n%s" [dict get $result manifest_loaded]]
        return $result
    }

    proc install_dashboard_hotkeys {} {
        if {[catch {::RMSXFlipbookTimeline::install_hotkeys} result]} {
            set_status "Hotkey install failed:\n$result"
            return
        }
        set_status "Installed RMSX Flipbook hotkeys."
        return $result
    }

    proc load_tml {} {
        variable timeline_tml_file
        if {$timeline_tml_file eq "" || ![file exists $timeline_tml_file]} {
            set_status "Choose a TML file first."
            return
        }
        if {[catch {::RMSXFlipbookTimeline::show_timeline_tml $timeline_tml_file {*}[timeline_plot_options]} result]} {
            set_status "TML load failed:\n$result"
            return
        }
        add_dataset_item "TML Dataset" matrix $timeline_tml_file
        set_status "Loaded TML dataset.\n$timeline_tml_file"
        return $result
    }

    proc load_collection {} {
        variable timeline_collection_dir
        variable timeline_collection
        variable timeline_collection_index
        if {[string trim $timeline_collection_dir] eq ""} {set_status "Choose a collection directory first."; return}
        ::RMSXFlipbookTimeline::Collections::set_status_command ::RMSXFlipbookTimeline::Dashboard::set_status
        if {[catch {::RMSXFlipbookTimeline::Collections::load $timeline_collection_dir "" {*}[timeline_plot_options]} result]} {set_status "Collection load failed: $result"; return}
        set timeline_collection [::RMSXFlipbookTimeline::Collections::datasets]
        set timeline_collection_index [::RMSXFlipbookTimeline::Collections::index]
        add_dataset_item "TML Collection" collection $timeline_collection_dir
        set_status "Loaded [llength $timeline_collection] datasets. Use Saved data to switch."
        return $result
    }

    proc apply_filter {} {
        variable timeline_filter_min
        variable timeline_filter_max
        variable timeline_filter_first
        variable timeline_filter_last
        variable timeline_filter_frames
        if {[::RMSXFlipbookTimeline::Operation::running]} { return }
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current eq {} || ![dict exists $current dataset]} { set_status "No current matrix to filter."; return }
        set ::RMSXFlipbookTimeline::TimelinePlot::current_dataset [dict get $current dataset]
        if {[catch {
            ::RMSXFlipbookTimeline::filter_timeline_current \
                $timeline_filter_min \
                $timeline_filter_max \
                $timeline_filter_first \
                $timeline_filter_last \
                $timeline_filter_frames \
                {*}[timeline_plot_options]
        } result]} {
            set_status "Filter failed:\n$result"
            return
        }
        add_dataset_item "Filtered Matrix" matrix "current timeline"
        set_status "Applied matrix filter."
        return $result
    }

    proc copy_user_field {} {
        variable timeline_user_field
        if {[::RMSXFlipbookTimeline::Operation::running]} { return }
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current eq {} || ![dict exists $current dataset]} { set_status "No current matrix to copy."; return }
        if {[catch {::RMSXFlipbookTimeline::Matrix::copy_to_user [dict get $current dataset] $timeline_user_field} result]} { set_status "Copy failed: $result"; return }
        set_status "Copied current matrix to $timeline_user_field."
        return $result
    }

    proc export_current {kind} {
        if {[::RMSXFlipbookTimeline::Operation::running]} { return }
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current eq {} || ![dict exists $current dataset] || [dict get $current dataset] eq {}} { set_status "No current matrix to export."; return }
        set filename [choose_save_file $kind]
        if {$filename eq ""} { return }
        set dataset [dict get $current dataset]
        set opts {}
        if {[dict exists $current view_options]} { set opts [dict get $current view_options] }
        if {[catch {
            switch -- $kind {
                tml { set result [::RMSXFlipbookTimeline::TimelineIO::write_tml $dataset $filename] }
                svg { set result [::RMSXFlipbookTimeline::TimelinePlot::write_svg $dataset $filename {*}$opts] }
                png { set result [::RMSXFlipbookTimeline::TimelinePlot::write_png $dataset $filename {*}$opts] }
                default { error "Unknown matrix format: $kind" }
            }
        } message]} { set_status "Export failed: $message"; return }
        set_status "Exported [string toupper $kind]: $filename"
        return $result
    }

    proc choose_save_file {kind} {
        variable top
        if {[info commands tk_getSaveFile] eq ""} {
            return [file normalize [file join [pwd] "rmsxflipbooktimeline-dashboard.$kind"]]
        }
        return [tk_getSaveFile -parent $top -title "Export Timeline $kind" -defaultextension ".$kind"]
    }

    proc browse_path {variable_name kind} {
        variable top
        upvar 0 ::RMSXFlipbookTimeline::Dashboard::$variable_name target
        if {$kind eq "directory"} {
            set picked [tk_chooseDirectory -parent $top -title "Choose folder"]
        } else {
            set picked [tk_getOpenFile -parent $top -title "Choose file"]
        }
        if {$picked ne ""} {
            set target [file normalize $picked]
            refresh_dashboard
        }
    }

    proc on_metric_group_changed {} {
        variable metric_combo_widget
        variable timeline_metric
        if {$metric_combo_widget ne "" && [winfo exists $metric_combo_widget]} {
            $metric_combo_widget configure -values [current_metric_values]
        }
        refresh_dashboard
    }

    proc on_metric_changed {} {
        variable timeline_metric
        variable metric_group
        set metric_group [dict get [metric_record $timeline_metric] group]
        refresh_dashboard
    }

    proc on_native_metric_changed {} {
        ensure_native_metric
        refresh_dashboard
    }

    proc on_timeline_metric_changed {} {
        variable metric_group
        set metric_group [dict get [metric_record [ensure_timeline_metric]] group]
        refresh_dashboard
    }

    proc on_palette_changed {} {
        variable palette
        set palette [normalize_palette $palette]
        ::RMSXFlipbookTimeline::state_set palette $palette
        if {[info commands color] ne "" && [info commands ::RMSXFlipbookTimeline::Style::apply_palette] ne ""} {
            if {[catch {::RMSXFlipbookTimeline::Style::apply_palette $palette} applied] == 0} {
                set palette [normalize_palette $applied]
                ::RMSXFlipbookTimeline::state_set palette $palette
            }
        }
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current ne {}} { ::RMSXFlipbookTimeline::Results::update [dict create palette $palette] }
        catch {redraw_embedded_heatmap_after_resize}
        refresh_dashboard
    }

    proc dashboard_frame_count {} {
        variable native_start
        variable native_end
        variable native_total_frames
        variable native_detected_total_frames
        variable timeline_molid

        set start [string trim $native_start]
        set end [string trim $native_end]
        if {![string is integer -strict $start]} {
            return [dict create known 0 reason "First frame is not an integer."]
        }
        set first [expr {int($start)}]
        if {$first < 0} {
            return [dict create known 0 reason "First frame must be >= 0."]
        }

        set total_text [string trim $native_total_frames]
        set total ""
        if {$total_text ne "" && [string tolower $total_text] ne "auto"} {
            if {![string is integer -strict $total_text] || int($total_text) < 1} {
                return [dict create known 0 reason "Total frames must be auto or a positive integer."]
            }
            set total [expr {int($total_text)}]
        } elseif {[string is integer -strict $native_detected_total_frames] && int($native_detected_total_frames) > 1} {
            set total [expr {int($native_detected_total_frames)}]
        } elseif {[info commands molinfo] ne ""} {
            set requested [string trim $timeline_molid]
            if {$requested eq "" || $requested eq "top"} {
                catch {set requested [molinfo top]}
            }
            if {[string is integer -strict $requested]} {
                set molecule_total ""
                catch {set molecule_total [molinfo [expr {int($requested)}] get numframes]}
                if {[string is integer -strict $molecule_total] && int($molecule_total) > 1} {
                    set total [expr {int($molecule_total)}]
                }
            }
        }

        if {$end ne "" && $end ne "-1"} {
            if {![string is integer -strict $end]} {
                return [dict create known 0 reason "Last frame must be -1 or an integer."]
            }
            set last [expr {int($end)}]
            if {$last < $first} {
                return [dict create known 0 reason "Last frame is before first frame."]
            }
            if {$total ne "" && $last >= $total} {
                set last [expr {$total - 1}]
            }
            return [dict create known 1 frames [expr {$last - $first + 1}] total $total first $first last $last]
        }

        if {$total eq ""} {
            return [dict create known 0 reason "Set Total frames or choose topology/trajectory files so the preview can resolve -1."]
        }
        if {$first >= $total} {
            return [dict create known 0 reason "First frame is outside the total frame count."]
        }
        set last [expr {$total - 1}]
        return [dict create known 1 frames [expr {$last - $first + 1}] total $total first $first last $last]
    }

    proc slicing_plan {} {
        variable native_slicing_mode
        variable native_slices
        variable native_slice_size

        set frame_info [dashboard_frame_count]
        if {![dict get $frame_info known]} {
            return [dict create known 0 reason [dict get $frame_info reason]]
        }

        set frames [dict get $frame_info frames]
        if {$frames < 1} {
            return [dict create known 0 reason "Frame range contains no usable frames."]
        }

        if {$native_slicing_mode eq "slice_size"} {
            set slice_text [string trim $native_slice_size]
            if {![string is integer -strict $slice_text] || int($slice_text) < 1} {
                return [dict create known 0 reason "Frames per slice must be a positive integer."]
            }
            set slice_size [expr {int($slice_text)}]
            set slices [expr {int($frames / $slice_size)}]
            set leftover [expr {$frames % $slice_size}]
        } else {
            set slices_text [string trim $native_slices]
            if {![string is integer -strict $slices_text] || int($slices_text) < 1} {
                return [dict create known 0 reason "Slices must be a positive integer."]
            }
            set slices [expr {int($slices_text)}]
            set slice_size [expr {int($frames / $slices)}]
            set leftover [expr {$frames - ($slice_size * $slices)}]
        }

        set warnings {}
        if {$slices < 1 || $slice_size < 1} {
            lappend warnings "Not enough frames for the requested slicing."
            set slices 0
            set slice_size 0
            set leftover $frames
        } elseif {$slice_size < 2} {
            lappend warnings "RMSX needs at least 2 frames per slice."
        }
        if {$frames > 0 && $leftover > 0 && double($leftover) / double($frames) > 0.10} {
            lappend warnings "More than 10% of the selected frames would be ignored."
        }

        return [dict merge $frame_info [dict create \
            known 1 \
            mode $native_slicing_mode \
            slices $slices \
            slice_size $slice_size \
            leftover $leftover \
            used [expr {$slices * $slice_size}] \
            warnings $warnings]]
    }

    proc slicing_plan_summary {plan} {
        variable native_time_step
        variable native_total_time_ns
        variable native_time_estimate_source
        if {![dict get $plan known]} {
            return "Preview unavailable: [dict get $plan reason]"
        }
        set message [format "%d slices x %d frames; uses %d/%d selected; leftover %d." \
            [dict get $plan slices] \
            [dict get $plan slice_size] \
            [dict get $plan used] \
            [dict get $plan frames] \
            [dict get $plan leftover]]
        set time_note " Time unknown; using frame/slice indices."
        if {![catch {set override_ns [native_total_time_override_ns_value]}] && $override_ns ne ""} {
            set step_ps [time_step_from_total_ns $override_ns [dict get $plan frames]]
            set time_note [format " Time %s ns override; step %s ps." \
                [format_total_time_display_ns $override_ns] \
                [format_time_step_display_ps $step_ps]]
        } elseif {[string is double -strict [string trim $native_time_step]]} {
            set step_ps [effective_time_step_ps_for_run]
            set total_ns [expr {([dict get $plan frames] <= 1) ? 0.0 : ((([dict get $plan frames] - 1) * $step_ps) / 1000.0)}]
            set time_note [format " Time %s ns; step %s ps." \
                [format_total_time_display_ns $total_ns] \
                [format_time_step_display_ps $step_ps]]
            if {[string trim $native_time_estimate_source] ne "" && [string trim $native_time_estimate_source] ne "fallback"} {
                append time_note " Inferred from $native_time_estimate_source."
            }
        }
        append message $time_note
        set warnings [dict get $plan warnings]
        if {[llength $warnings] > 0} {
            append message " [join $warnings { }]"
        }
        return $message
    }

    proc current_native_frame_count_key {} {
        variable native_topology
        variable native_trajectory

        if {$native_topology eq "" || $native_trajectory eq ""} {
            return ""
        }
        if {![file exists $native_topology] || ![file exists $native_trajectory]} {
            return ""
        }
        return "[file normalize $native_topology]\n[file normalize $native_trajectory]"
    }

    proc schedule_auto_frame_count {{delay 650}} {
        if {[info commands ::RMSXFlipbookTimeline::Operation::running] ne "" && [::RMSXFlipbookTimeline::Operation::running]} { return }
        variable source_type
        variable native_total_frames
        variable native_detected_total_frames
        variable native_detected_time_step_ps
        variable native_detected_total_time_ns
        variable native_time_estimate_source
        variable native_frame_count_key
        variable native_frame_count_after
        variable native_frame_count_running
        variable native_frame_count_attempt_key

        if {$source_type ne "new_analysis"} {
            return
        }
        if {[info commands after] eq ""} {
            return
        }
        set key [current_native_frame_count_key]
        if {$native_frame_count_key ne "" && $native_frame_count_key ne $key} {
            variable native_time_step
            variable native_total_time_ns
            set native_time_step ""
            set native_total_time_ns auto
            set native_frame_count_key ""
            ::RMSXFlipbookTimeline::state_set native_time_step ""
            ::RMSXFlipbookTimeline::state_set native_total_time_ns auto
            set native_detected_total_frames ""
            set native_detected_time_step_ps ""
            set native_detected_total_time_ns ""
            set native_time_estimate_source ""
            set native_total_frames "auto"
            ::RMSXFlipbookTimeline::state_set native_total_frames $native_total_frames
            ::RMSXFlipbookTimeline::state_set native_detected_time_step_ps ""
            ::RMSXFlipbookTimeline::state_set native_detected_total_time_ns ""
            ::RMSXFlipbookTimeline::state_set native_time_estimate_source ""
        }
        if {$key eq ""} { return }
        if {$native_frame_count_key eq $key && $native_detected_total_frames ne ""} {
            return
        }
        if {$native_frame_count_attempt_key eq $key && $native_detected_total_frames eq ""} {
            return
        }
        if {$native_frame_count_running} {
            return
        }
        if {$native_frame_count_after ne ""} {
            catch {after cancel $native_frame_count_after}
        }
        set native_frame_count_after [after $delay [list ::RMSXFlipbookTimeline::Dashboard::auto_read_total_frames_if_needed $key]]
    }

    proc auto_read_total_frames_if_needed {key} {
        if {[info commands ::RMSXFlipbookTimeline::Operation::running] ne "" && [::RMSXFlipbookTimeline::Operation::running]} { return }
        variable native_frame_count_after
        variable native_frame_count_running
        variable native_frame_count_attempt_key

        set native_frame_count_after ""
        if {$native_frame_count_running} {
            return ""
        }
        if {[current_native_frame_count_key] ne $key} {
            return ""
        }
        set native_frame_count_running 1
        set native_frame_count_attempt_key $key
        if {[catch {read_total_frames_from_trajectory 1} result]} {
            set_status "Frame count failed:\n$result"
        }
        set native_frame_count_running 0
        return $result
    }

    proc read_total_frames_from_trajectory {{auto 0}} {
        variable native_topology
        variable native_trajectory
        variable native_total_frames
        variable native_detected_total_frames
        variable native_detected_time_step_ps
        variable native_detected_total_time_ns
        variable native_time_estimate_source
        variable native_frame_count_key

        if {$native_topology eq "" || ![file exists $native_topology]} {
            if {!$auto} {
                set_status "Choose a topology PDB before counting frames."
            }
            return ""
        }
        if {$native_trajectory eq "" || ![file exists $native_trajectory]} {
            if {!$auto} {
                set_status "Choose a trajectory DCD before counting frames."
            }
            return ""
        }
        if {[info commands mol] eq "" || [info commands molinfo] eq ""} {
            if {!$auto} {
                set_status "Frame counting needs VMD molecule commands."
            }
            return ""
        }
        if {[info commands ::RMSXFlipbookTimeline::NativeAnalysis::load_trajectory] eq ""} {
            if {!$auto} {
                set_status "Frame count failed: trajectory loader is unavailable."
            }
            return ""
        }

        if {!$auto} {
            set_status "Counting trajectory frames..."
        }
        set molid ""
        set before_mols {}
        catch {set before_mols [molinfo list]}
        if {[catch {
            set load_info [::RMSXFlipbookTimeline::NativeAnalysis::load_trajectory $native_topology $native_trajectory]
            set molid [dict get $load_info molid]
            set frames [expr {[dict get $load_info total_frame_count] - [::RMSXFlipbookTimeline::NativeAnalysis::resolve_frame_offset auto $load_info]}]
            update_time_estimate_from_loaded_trajectory $molid $frames $native_trajectory
        } err]} {
            if {$molid ne ""} {
                catch {mol delete $molid}
            } else {
                catch {
                    foreach maybe_new [molinfo list] {
                        if {[lsearch -exact $before_mols $maybe_new] < 0} {
                            mol delete $maybe_new
                        }
                    }
                }
            }
            set_status "Frame count failed:\n$err"
            return ""
        }
        catch {mol delete $molid}
        if {![string is integer -strict $frames] || int($frames) < 1} {
            set_status "Frame count failed: trajectory reported no frames."
            return ""
        }
        set native_total_frames [expr {int($frames)}]
        set native_detected_total_frames $native_total_frames
        set native_frame_count_key [current_native_frame_count_key]
        ::RMSXFlipbookTimeline::state_set native_total_frames $native_total_frames
        ::RMSXFlipbookTimeline::state_set native_detected_total_frames $native_detected_total_frames
        if {!$auto} {
            set time_status ""
            if {[string trim $native_detected_time_step_ps] ne ""} {
                set time_status [format " Step %s ps" $native_detected_time_step_ps]
                if {[string trim $native_detected_total_time_ns] ne ""} {
                    append time_status [format "; %.6g ns total" $native_detected_total_time_ns]
                }
                if {[string trim $native_time_estimate_source] ne ""} {
                    append time_status " ($native_time_estimate_source)."
                } else {
                    append time_status "."
                }
            }
            set_status "Detected $native_total_frames trajectory frames.$time_status"
        }
        refresh_dashboard
        return $native_total_frames
    }

    proc refresh_slice_preview {} {
        variable top
        set settings [easy_child settings]
        if {[info commands winfo] eq "" || ![winfo exists $settings.preview]} {
            return
        }
        set canvas $settings.preview
        set text $settings.preview_text
        set plan [slicing_plan]
        if {[winfo exists $text]} {
            $text configure -text [slicing_plan_summary $plan]
        }

        $canvas delete all
        set width [winfo width $canvas]
        if {$width < 80} {
            set width 360
        }
        set height [winfo height $canvas]
        if {$height < 18} {
            set height 18
        }
        set x0 4
        set y0 2
        set bar_h [expr {max(9, min(12, $height - 4))}]
        set bar_w [expr {max(24, $width - 8)}]

        if {![dict get $plan known]} {
            $canvas create rectangle $x0 $y0 [expr {$x0 + $bar_w}] [expr {$y0 + $bar_h}] -outline "#777777" -fill "#eeeeee"
            $canvas create text [expr {$width / 2}] [expr {$y0 + ($bar_h / 2.0)}] -text "Choose topology and trajectory to count frames" -anchor center -font TkDefaultFont
            return
        }

        set frames [dict get $plan frames]
        set slices [dict get $plan slices]
        set slice_size [dict get $plan slice_size]
        set leftover [dict get $plan leftover]
        if {$frames <= 0 || $slices <= 0 || $slice_size <= 0} {
            $canvas create rectangle $x0 $y0 [expr {$x0 + $bar_w}] [expr {$y0 + $bar_h}] -outline "#8a1f1f" -fill "#f5d4d4"
            $canvas create text [expr {$width / 2}] [expr {$y0 + ($bar_h / 2.0)}] -text "Requested slicing cannot produce slices" -anchor center -font TkDefaultFont
            return
        }

        set used [dict get $plan used]
        set scale [expr {$bar_w / double($frames)}]
        set used_w [expr {$used * $scale}]
        set show_slice_numbers [expr {$slices <= 30}]

        for {set i 0} {$i < $slices} {incr i} {
            set sx0 [expr {$x0 + ($i * $slice_size * $scale)}]
            set sx1 [expr {$x0 + (($i + 1) * $slice_size * $scale)}]
            $canvas create rectangle $sx0 $y0 $sx1 [expr {$y0 + $bar_h}] -outline "#123550" -fill "#4f97d7"
            if {$show_slice_numbers && $sx1 - $sx0 > 24} {
                $canvas create text [expr {($sx0 + $sx1) / 2.0}] [expr {$y0 + ($bar_h / 2.0)}] \
                    -text [expr {$i + 1}] \
                    -anchor center \
                    -font TkDefaultFont \
                    -fill black
            }
        }

        if {$leftover > 0} {
            set lx0 [expr {$x0 + $used_w}]
            set lx1 [expr {$x0 + $bar_w}]
            $canvas create rectangle $lx0 $y0 $lx1 [expr {$y0 + $bar_h}] -outline "#7c0000" -fill "#d00000"
            if {$lx1 - $lx0 > 28} {
                $canvas create text [expr {($lx0 + $lx1) / 2.0}] [expr {$y0 + ($bar_h / 2.0)}] \
                    -text "leftover" \
                    -anchor center \
                    -font TkDefaultFont \
                    -fill black
            }
        }
    }

    proc color_meaning {metric} {
        set key [metric_key $metric]
        set panel [metric_panel $metric]
        if {$key eq "secondary_structure"} {
            return "Color: categorical secondary-structure states. Similar colors mean similar state families, not magnitude."
        }
        if {$key eq "cross_correlation"} {
            return "Color: diverging correlation scale. Negative, neutral, and positive values carry different meanings."
        }
        if {$panel eq "contacts"} {
            return "Color: event or contact strength. Binary metrics emphasize present/absent events; fractional metrics use intensity."
        }
        if {$key in {phi psi delta_phi delta_psi}} {
            return "Color: angular values. Delta angle metrics are centered around the reference frame."
        }
        if {[metric_route $metric] eq "native"} {
            return "Color: continuous flipbook score mapped to VMD User fields and the selected palette."
        }
        return "Color: continuous matrix values using the current palette and scale mode."
    }

    proc has_live_molecule {} {
        if {[info commands molinfo] eq ""} {
            return 0
        }
        if {[catch {molinfo list} molids]} {
            return 0
        }
        return [expr {[llength $molids] > 0}]
    }

    proc refresh_metric_summary {parent metric} {
        if {![winfo exists $parent]} {
            return
        }
        if {[winfo exists $parent.group_text]} {
            $parent.group_text configure -text [dict get [metric_record $metric] group]
        }
        if {[winfo exists $parent.summary_text]} {
            $parent.summary_text configure -text [metric_description $metric]
        }
        if {[winfo exists $parent.route_text]} {
            $parent.route_text configure -text [string totitle [metric_route $metric]]
        }
        if {[winfo exists $parent.color_text]} {
            $parent.color_text configure -text [color_meaning $metric]
        }
    }

    proc refresh_metric_option_panels {options metric {mode timeline}} {
        variable show_advanced
        if {![winfo exists $options]} {
            return
        }
        foreach panel {native timeline structure contacts fields residue cross advanced} {
            catch {grid remove $options.$panel}
        }
        set first_panel_row [expr {[winfo exists $options.advanced_check] ? 1 : 0}]
        if {$mode eq "native"} {
            if {$show_advanced && [winfo exists $options.native]} {
                grid $options.native -row $first_panel_row -column 0 -sticky ew -pady {0 0}
            }
            return
        }

        set route [metric_route $metric]
        set base_panel [expr {$route eq "native" ? "native" : "timeline"}]
        if {$route eq "external"} {
            set base_panel advanced
        }
        set show_base_panel 1
        if {$mode eq "timeline" && $base_panel in {native timeline} && !$show_advanced} {
            set show_base_panel 0
        }
        if {$show_base_panel && [winfo exists $options.$base_panel]} {
            grid $options.$base_panel -row $first_panel_row -column 0 -sticky ew -pady {4 0}
        }
        set detail_row [expr {$first_panel_row + ($show_base_panel ? 1 : 0)}]
        switch -- [metric_panel $metric] {
            cross_correlation {
                grid $options.cross -row $detail_row -column 0 -sticky ew -pady {6 0}
            }
            residue_function {
                grid $options.residue -row $detail_row -column 0 -sticky ew -pady {6 0}
            }
            fields {
                grid $options.fields -row $detail_row -column 0 -sticky ew -pady {6 0}
            }
            contacts {
                grid $options.contacts -row $detail_row -column 0 -sticky ew -pady {6 0}
            }
            structure -
            angles {
                grid $options.structure -row $detail_row -column 0 -sticky ew -pady {6 0}
            }
        }
        if {$show_advanced && [winfo exists $options.advanced]} {
            grid $options.advanced -row [expr {$detail_row + 1}] -column 0 -sticky ew -pady {8 0}
        }
        if {[winfo exists $options.contacts]} {
            refresh_contacts_options $options.contacts
        }
    }

    proc refresh_dashboard {} {
        variable top
        variable native_metric
        variable timeline_metric
        variable metric_group
        variable metric_combo_widget
        variable native_metric_combo_widget
        variable timeline_metric_combo_widget
        variable show_advanced

        if {[info commands winfo] eq "" || ![winfo exists $top]} {
            return
        }

        refresh_output_display_indicator
        ensure_native_metric
        ensure_timeline_metric
        set metric_group [dict get [metric_record $timeline_metric] group]
        if {$metric_combo_widget ne "" && [winfo exists $metric_combo_widget]} {
            $metric_combo_widget configure -values [native_metric_values]
        }
        if {$native_metric_combo_widget ne "" && [winfo exists $native_metric_combo_widget]} {
            $native_metric_combo_widget configure -values [native_metric_values]
        }
        if {$timeline_metric_combo_widget ne "" && [winfo exists $timeline_metric_combo_widget]} {
            $timeline_metric_combo_widget configure -values [timeline_metric_values]
        }

        set easy [easy_content_root]
        refresh_metric_summary $easy.metric $native_metric
        refresh_metric_option_panels $easy.options $native_metric native
        if {[winfo exists $easy.options]} {
            if {$show_advanced} {
                grid $easy.options
            } else {
                grid remove $easy.options
            }
        }

        set matrix [tab_content matrix]
        if {[winfo exists $matrix.metric]} {
            refresh_metric_summary $matrix.metric $timeline_metric
        }
        if {[winfo exists $matrix.options]} {
            refresh_metric_option_panels $matrix.options $timeline_metric timeline
        }

        refresh_source_controls
        refresh_slicing_mode_controls
        schedule_auto_frame_count
        refresh_slice_preview
        refresh_result_header
        refresh_export_controls
        set plot [tab_content matrix].live.plot
        if {[winfo exists $plot]} {
            set ready [expr {![::RMSXFlipbookTimeline::Operation::running] && ![catch {dashboard_molid}]}]
            $plot configure -state [expr {$ready ? "normal" : "disabled"}]
        }
    }

    proc set_widget_list_visible {widgets visible} {
        foreach widget $widgets {
            if {[winfo exists $widget]} {
                if {$visible} {
                    grid $widget
                } else {
                    grid remove $widget
                }
            }
        }
    }

    proc refresh_contacts_options {panel} {
        variable timeline_metric
        set key [metric_key $timeline_metric]
        set native_widgets [list \
            $panel.native_ref_label \
            $panel.native_ref_entry \
            $panel.native_dist_label \
            $panel.native_dist_entry \
            $panel.native_from_label \
            $panel.native_from_entry \
            $panel.native_to_label \
            $panel.native_to_entry]
        set inter_widgets [list \
            $panel.inter_method_label \
            $panel.inter_method_combo \
            $panel.inter_dist_label \
            $panel.inter_dist_entry \
            $panel.inter_from_label \
            $panel.inter_from_entry \
            $panel.inter_to_label \
            $panel.inter_to_entry \
            $panel.inter_list_label \
            $panel.inter_list_entry]
        set_widget_list_visible $native_widgets [expr {$key eq "native_contacts"}]
        set_widget_list_visible $inter_widgets [expr {$key eq "inter_selection_contacts" || $key eq "inter_sel_contacts"}]
    }

    proc set_file_row_visible {parent variable_name visible} {
        foreach suffix {label entry browse status} {
            set widget $parent.${variable_name}_$suffix
            if {[winfo exists $widget]} {
                if {$visible} {
                    grid $widget
                } else {
                    grid remove $widget
                }
            }
        }
    }

    proc style_primary_action_button {button state} {
        if {[info commands winfo] ne "" && [winfo exists $button]} {
            catch {$button configure -style RMSX.Primary.TButton}
        }
    }

    proc invoke_action {command} {
        if {[::RMSXFlipbookTimeline::Operation::running]} { return }
        ::RMSXFlipbookTimeline::Operation::begin analysis
        after idle [list ::RMSXFlipbookTimeline::Dashboard::execute_operation $command]
    }

    proc set_action_button {button text command state} {
        if {![winfo exists $button]} { return }
        if {[::RMSXFlipbookTimeline::Operation::running]} { set state disabled }
        if {[string match "*.run" $button]} {
            $button configure -text $text -command [list ::RMSXFlipbookTimeline::Dashboard::invoke_action $command] -state $state
        } else {
            $button configure -text $text -command $command -state $state
        }
    }

    proc refresh_source_controls {} {
        variable top
        variable source_type
        variable native_metric
        variable timeline_metric
        variable native_topology
        variable native_trajectory
        variable native_output
        variable folder
        variable timeline_tml_file
        variable timeline_collection_dir

        set easy [easy_content_root]
        if {[info commands winfo] eq "" || ![winfo exists $easy.files]} {
            return
        }
        if {$source_type ni {new_analysis existing_folder}} {
            set source_type new_analysis
        }

        set files $easy.files
        set actions $easy.actions
        foreach row_var {
            native_topology
            native_trajectory
            native_output
            folder
            timeline_tml_file
            timeline_collection_dir
        } {
            set_file_row_visible $files $row_var 0
        }

        set native_ready [native_setup_ready]
        set folder_ready [expr {[string trim $folder] ne "" && [file isdirectory $folder]}]
        set run_state disabled
        set matrix_state disabled
        set popout_state disabled
        set save_state [expr {[llength [::RMSXFlipbookTimeline::state_get molids {}]] > 0 ? "normal" : "disabled"}]
        set run_text "Run $native_metric"
        set run_command ::RMSXFlipbookTimeline::Dashboard::run_native_metric

        switch -- $source_type {
            existing_folder {
                set_file_row_visible $files folder 1
                set run_state [expr {$folder_ready ? "normal" : "disabled"}]
                set matrix_state $run_state
                set popout_state $run_state
                set run_text "Load Folder"
                set run_command ::RMSXFlipbookTimeline::Dashboard::load_existing_folder
            }
            default {
                foreach row_var {native_topology native_trajectory native_output} {
                    set_file_row_visible $files $row_var 1
                }
                set run_state [expr {$native_ready ? "normal" : "disabled"}]
                set matrix_state [expr {$folder_ready ? "normal" : "disabled"}]
                set popout_state $matrix_state
            }
        }

        set_action_button $actions.run $run_text $run_command $run_state
        set_action_button $actions.save "3D Image" ::RMSXFlipbookTimeline::Dashboard::save_flipbook_image $save_state
        set_action_button $actions.popout "Heatmap ↗" ::RMSXFlipbookTimeline::Dashboard::open_full_plot_window $popout_state
    }

    proc refresh_slicing_mode_controls {} {
        variable top
        variable native_slicing_mode
        set settings [easy_child settings]
        if {[info commands winfo] eq "" || ![winfo exists $settings]} {
            return
        }
        foreach widget [list \
            $settings.native_slices_label \
            $settings.native_slices_entry \
            $settings.native_slice_size_label \
            $settings.native_slice_size_entry] {
            if {[winfo exists $widget]} {
                grid remove $widget
            }
        }
        if {$native_slicing_mode eq "slice_size"} {
            if {[winfo exists $settings.native_slice_size_label]} {
                grid $settings.native_slice_size_label -row 1 -column 2 -sticky w -padx {0 8} -pady 3
                grid $settings.native_slice_size_entry -row 1 -column 3 -sticky w -pady 3
            }
        } else {
            if {[winfo exists $settings.native_slices_label]} {
                grid $settings.native_slices_label -row 1 -column 2 -sticky w -padx {0 8} -pady 3
                grid $settings.native_slices_entry -row 1 -column 3 -sticky w -pady 3
            }
        }
    }

    proc open_classic {} {
        return [rmsxflipbooktimeline_classic]
    }

    proc open_help_url {} {
        variable help_url
        if {[catch {
            set opened_url [::RMSXFlipbookTimeline::open_help]
        } err]} {
            set_status "Help page:\n$help_url\n\nCould not open automatically: $err"
            return
        }
        set_status "Opened help page.\n$opened_url"
    }

    proc build_file_row {parent row label variable_name browse_kind} {
        if {$variable_name eq "native_output"} {
            ttk::frame $parent.${variable_name}_label
            ttk::label $parent.${variable_name}_label.text -text $label
            ttk::label $parent.${variable_name}_label.status \
                -textvariable ::RMSXFlipbookTimeline::Dashboard::output_display_var \
                -foreground "#257a3d" \
                -width 1
            pack $parent.${variable_name}_label.text -side left
            place $parent.${variable_name}_label.status -relx 1.0 -rely 0.5 -anchor e
        } else {
            ttk::label $parent.${variable_name}_label -text $label
        }
        if {$variable_name eq "native_output"} {
            $parent.${variable_name}_label.text configure -width 9
        } else {$parent.${variable_name}_label configure -width 9}
        ttk::entry $parent.${variable_name}_entry -width 1 -textvariable ::RMSXFlipbookTimeline::Dashboard::$variable_name -style RMSX.Path.TEntry
        ttk::button $parent.${variable_name}_browse -text "Browse" -width 6 -command [list ::RMSXFlipbookTimeline::Dashboard::browse_path $variable_name $browse_kind]
        bind $parent.${variable_name}_entry <KeyRelease> {after idle ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard}
        bind $parent.${variable_name}_entry <FocusOut> {::RMSXFlipbookTimeline::Dashboard::refresh_dashboard}
        grid $parent.${variable_name}_label -row $row -column 0 -sticky w -pady 3
        grid $parent.${variable_name}_entry -row $row -column 1 -sticky ew -padx {8 8} -pady 3
        grid $parent.${variable_name}_browse -row $row -column 2 -sticky e -pady 3
    }

    proc build_source_selector {parent} {
        ttk::label $parent.label -text Source -width 9
        grid $parent.label -row 0 -column 0 -sticky w -padx {0 8}
        foreach {col value label} {1 new_analysis {New analysis} 2 existing_folder {Result folder}} {
            ttk::radiobutton $parent.source_$value -text $label -value $value -variable ::RMSXFlipbookTimeline::Dashboard::source_type -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
            grid $parent.source_$value -row 0 -column $col -sticky w -padx {0 14}
        }
        help_tip $parent.source_new_analysis "Calculate a new result from topology and trajectory files."
        help_tip $parent.source_existing_folder "Open an existing flipbook result folder."
    }

    proc build_metric_controls {parent {include_advanced_toggle 0}} {
        variable metric_combo_widget
        variable native_metric_combo_widget
        ttk::label $parent.metric_label -text Metric -width 9
        ttk::combobox $parent.metric_combo -textvariable ::RMSXFlipbookTimeline::Dashboard::native_metric -values [native_metric_values] -state readonly -width 10
        set metric_combo_widget $parent.metric_combo
        set native_metric_combo_widget $parent.metric_combo
        bind $parent.metric_combo <<ComboboxSelected>> ::RMSXFlipbookTimeline::Dashboard::on_native_metric_changed
        ttk::label $parent.palette_label -text Palette
        ttk::combobox $parent.palette_combo -textvariable ::RMSXFlipbookTimeline::Dashboard::palette -values [palette_values] -state readonly -width 9
        bind $parent.palette_combo <<ComboboxSelected>> ::RMSXFlipbookTimeline::Dashboard::on_palette_changed
        ttk::checkbutton $parent.advanced_check -text Options -variable ::RMSXFlipbookTimeline::Dashboard::show_advanced -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        foreach {col widget} {0 metric_label 1 metric_combo 2 palette_label 3 palette_combo 4 advanced_check} {
            grid $parent.$widget -row 0 -column $col -sticky w -padx {0 10}
        }
        grid $parent.metric_label -padx {0 8}
        grid $parent.advanced_check -sticky e -padx 0
        grid columnconfigure $parent 4 -weight 1
        help_tip $parent.metric_combo "RMSX: local fluctuation. Shift-Map: displacement. 1-lDDT: structural difference; larger values indicate more change."
        help_tip $parent.palette_combo "Color palette for the current result. Numerical values do not change."
    }

    proc build_timeline_metric_controls {parent} {
        variable timeline_metric_combo_widget
        ttk::label $parent.metric_label -text Metric
        ttk::combobox $parent.metric_combo -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_metric -values [timeline_metric_values] -state readonly -width 24
        set timeline_metric_combo_widget $parent.metric_combo
        bind $parent.metric_combo <<ComboboxSelected>> ::RMSXFlipbookTimeline::Dashboard::on_timeline_metric_changed
        ttk::label $parent.palette_label -text Palette
        ttk::combobox $parent.palette_combo -textvariable ::RMSXFlipbookTimeline::Dashboard::palette -values [palette_values] -state readonly -width 9
        bind $parent.palette_combo <<ComboboxSelected>> ::RMSXFlipbookTimeline::Dashboard::on_palette_changed
        foreach {col widget} {0 metric_label 1 metric_combo 2 palette_label 3 palette_combo} { grid $parent.$widget -row 0 -column $col -sticky w -padx {0 8} }
        ttk::label $parent.summary_text -text "" -wraplength 560
        grid $parent.summary_text -row 1 -column 0 -columnspan 4 -sticky ew -pady {4 0}
        help_tip $parent.metric_combo "Calculate a frame-linked residue or contact matrix from the selected VMD molecule."
    }

    proc build_run_settings {parent} {
        ttk::label $parent.native_chain_label -text Chain
        ttk::combobox $parent.native_chain_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_chain -values {all} -width 7
        ttk::button $parent.chains -text ↻ -width 2 -command ::RMSXFlipbookTimeline::Dashboard::refresh_chain_choices
        ttk::label $parent.native_start_label -text Frames
        ttk::entry $parent.native_start_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_start -width 6
        ttk::label $parent.native_end_label -text –
        ttk::entry $parent.native_end_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::end_display -width 6
        foreach {col widget} {0 native_chain_label 1 native_chain_entry 2 chains 3 native_start_label 4 native_start_entry 5 native_end_label 6 native_end_entry} {
            grid $parent.$widget -row 0 -column $col -sticky w -padx {0 6} -pady 2
        }
        ttk::label $parent.mode_label -text By
        ttk::radiobutton $parent.mode_slices -text Slices -value slices -variable ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        ttk::radiobutton $parent.mode_size -text Frames -value slice_size -variable ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        ttk::label $parent.native_slices_label -text Count
        ttk::entry $parent.native_slices_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_slices -width 6
        ttk::label $parent.native_slice_size_label -text Size
        ttk::entry $parent.native_slice_size_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_slice_size -width 6
        foreach {col widget} {0 mode_label 1 mode_slices 2 mode_size} { grid $parent.$widget -row 1 -column $col -sticky w -padx {0 6} -pady 2 }
        ttk::label $parent.native_time_step_label -text "Step (ps)"
        ttk::entry $parent.native_time_step_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_time_step -width 9
        ttk::label $parent.native_total_time_ns_label -text "Span (ns)"
        ttk::entry $parent.native_total_time_ns_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_total_time_ns -width 9
        grid $parent.native_time_step_label -row 2 -column 0 -sticky w
        grid $parent.native_time_step_entry -row 2 -column 1 -columnspan 2 -sticky w
        grid $parent.native_total_time_ns_label -row 2 -column 3 -sticky w
        grid $parent.native_total_time_ns_entry -row 2 -column 4 -columnspan 3 -sticky w
        ttk::entry $parent.native_total_frames_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_total_frames -width 6
        canvas $parent.preview -height 20 -width 300 -background white -highlightthickness 0
        ttk::label $parent.preview_text -text "" -wraplength 560
        grid $parent.preview -row 3 -column 0 -columnspan 7 -sticky ew -pady {4 0}
        grid $parent.preview_text -row 4 -column 0 -columnspan 7 -sticky ew
        grid columnconfigure $parent 6 -weight 1
        bind $parent.preview <Configure> ::RMSXFlipbookTimeline::Dashboard::refresh_slice_preview
        bind $parent.native_end_entry <FocusOut> ::RMSXFlipbookTimeline::Dashboard::sync_end_display
        bind $parent.native_end_entry <Return> ::RMSXFlipbookTimeline::Dashboard::sync_end_display
        foreach widget {native_slices_entry native_slice_size_entry native_start_entry native_time_step_entry native_total_time_ns_entry native_chain_entry} {
            bind $parent.$widget <FocusOut> ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        }
        help_tip $parent.native_chain_entry "Exact chain/segment group from the topology; all analyzes every group. Refresh discovers labels and keeps blank segments distinct. Typed aliases must be unambiguous."
        help_tip $parent.chains "Read chain identifiers from the selected topology."
        help_tip $parent.native_end_entry "Last uses the final trajectory frame. Frame indices start at zero."
        help_tip $parent.native_slice_size_entry "Number of trajectory frames per slice."
        help_tip $parent.native_slices_entry "Number of slices. The preview reports any unused remainder."
        help_tip $parent.native_time_step_entry "Time interval between saved trajectory frames, in picoseconds. Leave blank when unknown; plots use frames or slices. A value detected from this source can be edited."
        help_tip $parent.native_total_time_ns_entry "Optional trajectory span in nanoseconds; auto uses detected timing."
        layout_run_settings $parent
        refresh_slicing_mode_controls
    }

    proc layout_run_settings {parent} {
        foreach widget [grid slaves $parent] {grid forget $widget}
        for {set col 0} {$col < 7} {incr col} {grid columnconfigure $parent $col -weight 0}
        foreach group {chain_group mode_group frame_group} {ttk::frame $parent.$group}
        grid $parent.native_chain_entry -in $parent.chain_group -row 0 -column 0 -sticky w
        grid $parent.chains -in $parent.chain_group -row 0 -column 1 -padx {4 0}
        grid $parent.mode_slices -in $parent.mode_group -row 0 -column 0 -sticky w
        grid $parent.mode_size -in $parent.mode_group -row 0 -column 1 -sticky w -padx {8 0}
        foreach {col widget} {0 native_start_entry 1 native_end_label 2 native_end_entry} {
            grid $parent.$widget -in $parent.frame_group -row 0 -column $col -sticky w -padx [expr {$col == 1 ? 5 : 0}]
        }
        foreach {row left field right value} {
            0 native_chain_label chain_group native_start_label frame_group
            1 mode_label mode_group native_slices_label native_slices_entry
            2 native_time_step_label native_time_step_entry native_total_time_ns_label native_total_time_ns_entry
        } {
            $parent.$left configure -width 9
            grid $parent.$left -row $row -column 0 -sticky w -padx {0 8} -pady 3
            grid $parent.$field -row $row -column 1 -sticky w -padx {0 16} -pady 3
            grid $parent.$right -row $row -column 2 -sticky w -padx {0 8} -pady 3
            grid $parent.$value -row $row -column 3 -sticky w -pady 3
        }
        grid columnconfigure $parent 1 -weight 1
        grid columnconfigure $parent 3 -weight 1
        grid $parent.preview -row 3 -column 0 -columnspan 4 -sticky ew -pady {7 3}
        grid $parent.preview_text -row 4 -column 0 -columnspan 4 -sticky ew
        bind $parent.preview_text <Configure> {::RMSXFlipbookTimeline::Dashboard::resize_label_wrap %W %w 100 4}
        # Widgets managed into a later-created grouping frame must sit above it.
        foreach widget {native_chain_entry chains mode_slices mode_size native_start_entry native_end_label native_end_entry} {raise $parent.$widget}
    }

    proc build_metric_option_panels {parent {include_advanced_toggle 1}} {
        if {$include_advanced_toggle} {
            ttk::checkbutton $parent.advanced_check \
                -text "Advanced" \
                -variable ::RMSXFlipbookTimeline::Dashboard::show_advanced \
                -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
            grid $parent.advanced_check -row 0 -column 0 -sticky w
        }
        grid columnconfigure $parent 0 -weight 1

        set native_panel [ttk::frame $parent.native]
        ttk::label $native_panel.type_label -text "Analysis Type"
        ttk::combobox $native_panel.type_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::native_analysis_type \
            -values {protein dna rna generic} \
            -state readonly
        ttk::label $native_panel.mask_label -text "Mask"
        ttk::entry $native_panel.mask_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::native_mask_selection
        ttk::button $native_panel.thinner -text "Thinner" -command {::RMSXFlipbookTimeline::Dashboard::nudge_thickness -0.05}
        ttk::button $native_panel.thicker -text "Thicker" -command {::RMSXFlipbookTimeline::Dashboard::nudge_thickness 0.05}
        grid $native_panel.type_label -row 0 -column 0 -sticky w -pady 3
        grid $native_panel.type_combo -row 0 -column 1 -sticky ew -padx {8 16} -pady 3
        grid $native_panel.mask_label -row 0 -column 2 -sticky w -pady 3
        grid $native_panel.mask_entry -row 0 -column 3 -sticky ew -padx {8 0} -pady 3
        grid $native_panel.thinner -row 1 -column 1 -sticky ew -padx {8 16} -pady {5 0}
        grid $native_panel.thicker -row 1 -column 3 -sticky ew -padx {8 0} -pady {5 0}
        grid columnconfigure $native_panel 1 -weight 1
        grid columnconfigure $native_panel 3 -weight 2

        set timeline_panel [ttk::frame $parent.timeline]
        ttk::label $timeline_panel.molid_label -text "Molecule"
        ttk::entry $timeline_panel.molid_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_molid -width 10
        ttk::label $timeline_panel.selection_label -text "Selection"
        ttk::entry $timeline_panel.selection_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_selection
        ttk::label $timeline_panel.scale_label -text "Scale"
        ttk::combobox $timeline_panel.scale_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_scale_mode \
            -values {fit every_residue} \
            -state readonly \
            -width 14
        ttk::label $timeline_panel.columns_label -text "Matrix Columns"
        ttk::radiobutton $timeline_panel.columns_frames \
            -text "Frames" \
            -value frames \
            -variable ::RMSXFlipbookTimeline::Dashboard::timeline_column_mode \
            -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        ttk::radiobutton $timeline_panel.columns_slices \
            -text "Slices" \
            -value slices \
            -variable ::RMSXFlipbookTimeline::Dashboard::timeline_column_mode \
            -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        ttk::label $timeline_panel.aggregation_label -text "Aggregation"
        ttk::combobox $timeline_panel.aggregation_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_slice_aggregation \
            -values {auto mean max min first last occupancy mode circular_mean} \
            -state readonly \
            -width 14
        ttk::label $timeline_panel.representative_label -text "Representative"
        ttk::combobox $timeline_panel.representative_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_slice_representative \
            -values {first middle last} \
            -state readonly \
            -width 10
        grid $timeline_panel.molid_label -row 0 -column 0 -sticky w -pady 3
        grid $timeline_panel.molid_entry -row 0 -column 1 -sticky ew -padx {8 16} -pady 3
        grid $timeline_panel.selection_label -row 0 -column 2 -sticky w -pady 3
        grid $timeline_panel.selection_entry -row 0 -column 3 -sticky ew -padx {8 16} -pady 3
        grid $timeline_panel.scale_label -row 0 -column 4 -sticky w -pady 3
        grid $timeline_panel.scale_combo -row 0 -column 5 -sticky ew -padx {8 0} -pady 3
        grid $timeline_panel.columns_label -row 1 -column 0 -sticky w -pady 3
        grid $timeline_panel.columns_frames -row 1 -column 1 -sticky w -padx {8 6} -pady 3
        grid $timeline_panel.columns_slices -row 1 -column 2 -sticky w -padx {0 16} -pady 3
        grid $timeline_panel.aggregation_label -row 1 -column 3 -sticky e -pady 3
        grid $timeline_panel.aggregation_combo -row 1 -column 4 -sticky ew -padx {8 16} -pady 3
        grid $timeline_panel.representative_label -row 1 -column 5 -sticky e -pady 3
        grid $timeline_panel.representative_combo -row 1 -column 6 -sticky ew -padx {8 0} -pady 3
        grid columnconfigure $timeline_panel 3 -weight 1

        set structure_panel [ttk::frame $parent.structure]
        ttk::label $structure_panel.note \
            -text "Structure and angle metrics color residues directly. Secondary structure is categorical; phi/psi and delta-angle metrics are residue values, so click cells to inspect them with the matrix-colored mini-flipbook." \
            -wraplength 720
        grid $structure_panel.note -row 0 -column 0 -sticky ew
        grid columnconfigure $structure_panel 0 -weight 1

        set contacts_panel [ttk::frame $parent.contacts]
        ttk::label $contacts_panel.filter_label -text "Filter min / max / passing frames"
        ttk::entry $contacts_panel.filter_min -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_filter_min -width 8
        ttk::entry $contacts_panel.filter_max -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_filter_max -width 8
        ttk::entry $contacts_panel.filter_frames -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_filter_frames -width 8
        ttk::button $contacts_panel.apply -text "Apply Filter" -command ::RMSXFlipbookTimeline::Dashboard::apply_filter
        grid $contacts_panel.filter_label -row 0 -column 0 -sticky w -pady 3
        grid $contacts_panel.filter_min -row 0 -column 1 -sticky ew -padx {8 4} -pady 3
        grid $contacts_panel.filter_max -row 0 -column 2 -sticky ew -padx {4 4} -pady 3
        grid $contacts_panel.filter_frames -row 0 -column 3 -sticky ew -padx {4 8} -pady 3
        grid $contacts_panel.apply -row 0 -column 4 -sticky ew -pady 3
        ttk::label $contacts_panel.native_ref_label -text "Reference"
        ttk::entry $contacts_panel.native_ref_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_native_ref_frame -width 8
        ttk::label $contacts_panel.native_dist_label -text "Cutoff"
        ttk::entry $contacts_panel.native_dist_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_native_dist -width 8
        ttk::label $contacts_panel.native_from_label -text "From selections"
        ttk::entry $contacts_panel.native_from_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_native_from_selection_list
        ttk::label $contacts_panel.native_to_label -text "To"
        ttk::entry $contacts_panel.native_to_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_native_to_selection
        grid $contacts_panel.native_ref_label -row 1 -column 0 -sticky w -pady 3
        grid $contacts_panel.native_ref_entry -row 1 -column 1 -sticky ew -padx {8 4} -pady 3
        grid $contacts_panel.native_dist_label -row 1 -column 2 -sticky w -padx {4 4} -pady 3
        grid $contacts_panel.native_dist_entry -row 1 -column 3 -sticky ew -padx {4 8} -pady 3
        grid $contacts_panel.native_to_label -row 1 -column 4 -sticky w -pady 3
        grid $contacts_panel.native_to_entry -row 1 -column 5 -sticky ew -padx {8 0} -pady 3
        grid $contacts_panel.native_from_label -row 2 -column 0 -sticky w -pady 3
        grid $contacts_panel.native_from_entry -row 2 -column 1 -columnspan 5 -sticky ew -padx {8 0} -pady 3

        ttk::label $contacts_panel.inter_method_label -text "Inter method"
        ttk::combobox $contacts_panel.inter_method_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_inter_method \
            -values {residues_to_selection pairs all} \
            -state readonly \
            -width 20
        ttk::label $contacts_panel.inter_dist_label -text "Cutoff"
        ttk::entry $contacts_panel.inter_dist_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_inter_dist -width 8
        ttk::label $contacts_panel.inter_from_label -text "From residues"
        ttk::entry $contacts_panel.inter_from_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_inter_from_selection
        ttk::label $contacts_panel.inter_to_label -text "To selection"
        ttk::entry $contacts_panel.inter_to_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_inter_to_selection
        ttk::label $contacts_panel.inter_list_label -text "Selection list"
        ttk::entry $contacts_panel.inter_list_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_inter_selection_list
        grid $contacts_panel.inter_method_label -row 3 -column 0 -sticky w -pady 3
        grid $contacts_panel.inter_method_combo -row 3 -column 1 -sticky ew -padx {8 4} -pady 3
        grid $contacts_panel.inter_dist_label -row 3 -column 2 -sticky w -padx {4 4} -pady 3
        grid $contacts_panel.inter_dist_entry -row 3 -column 3 -sticky ew -padx {4 8} -pady 3
        grid $contacts_panel.inter_from_label -row 4 -column 0 -sticky w -pady 3
        grid $contacts_panel.inter_from_entry -row 4 -column 1 -columnspan 2 -sticky ew -padx {8 8} -pady 3
        grid $contacts_panel.inter_to_label -row 4 -column 3 -sticky w -pady 3
        grid $contacts_panel.inter_to_entry -row 4 -column 4 -columnspan 2 -sticky ew -padx {8 0} -pady 3
        grid $contacts_panel.inter_list_label -row 5 -column 0 -sticky w -pady 3
        grid $contacts_panel.inter_list_entry -row 5 -column 1 -columnspan 5 -sticky ew -padx {8 0} -pady 3
        grid columnconfigure $contacts_panel 5 -weight 1

        set fields_panel [ttk::frame $parent.fields]
        ttk::label $fields_panel.user_label -text "User Field"
        ttk::combobox $fields_panel.user_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_user_field \
            -values {user user2 user3 user4} \
            -state readonly \
            -width 10
        ttk::button $fields_panel.copy -text "Copy Matrix to Field" -command ::RMSXFlipbookTimeline::Dashboard::copy_user_field
        grid $fields_panel.user_label -row 0 -column 0 -sticky w -pady 3
        grid $fields_panel.user_combo -row 0 -column 1 -sticky ew -padx {8 16} -pady 3
        grid $fields_panel.copy -row 0 -column 2 -sticky ew -pady 3
        grid columnconfigure $fields_panel 2 -weight 1

        set residue_panel [ttk::frame $parent.residue]
        foreach {row label var} {
            0 "Proc" timeline_residue_function
            1 "Context" timeline_residue_function_context
            2 "Label" timeline_residue_function_label
            3 "Unit" timeline_residue_function_unit
        } {
            ttk::label $residue_panel.${var}_label -text $label
            ttk::entry $residue_panel.${var}_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::$var
            grid $residue_panel.${var}_label -row $row -column 0 -sticky w -pady 3
            grid $residue_panel.${var}_entry -row $row -column 1 -sticky ew -padx {8 0} -pady 3
        }
        grid columnconfigure $residue_panel 1 -weight 1

        set cross_panel [ttk::frame $parent.cross]
        ttk::label $cross_panel.map_label -text "CC Map"
        ttk::entry $cross_panel.map_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_cc_map_file
        ttk::button $cross_panel.map_browse -text "Browse" -command {::RMSXFlipbookTimeline::Dashboard::browse_path timeline_cc_map_file file}
        ttk::label $cross_panel.vol_label -text "Vol"
        ttk::entry $cross_panel.vol_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_cc_vol_id -width 8
        ttk::label $cross_panel.res_label -text "Resolution"
        ttk::entry $cross_panel.res_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_cc_map_res -width 8
        ttk::label $cross_panel.method_label -text "Method"
        ttk::combobox $cross_panel.method_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_cc_method \
            -values {segments selections} \
            -state readonly \
            -width 12
        ttk::label $cross_panel.selections_label -text "Selections"
        ttk::entry $cross_panel.selections_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_cc_selection_list
        grid $cross_panel.map_label -row 0 -column 0 -sticky w -pady 3
        grid $cross_panel.map_entry -row 0 -column 1 -columnspan 5 -sticky ew -padx {8 8} -pady 3
        grid $cross_panel.map_browse -row 0 -column 6 -sticky ew -pady 3
        grid $cross_panel.vol_label -row 1 -column 0 -sticky w -pady 3
        grid $cross_panel.vol_entry -row 1 -column 1 -sticky ew -padx {8 16} -pady 3
        grid $cross_panel.res_label -row 1 -column 2 -sticky w -pady 3
        grid $cross_panel.res_entry -row 1 -column 3 -sticky ew -padx {8 16} -pady 3
        grid $cross_panel.method_label -row 1 -column 4 -sticky w -pady 3
        grid $cross_panel.method_combo -row 1 -column 5 -columnspan 2 -sticky ew -padx {8 0} -pady 3
        grid $cross_panel.selections_label -row 2 -column 0 -sticky w -pady 3
        grid $cross_panel.selections_entry -row 2 -column 1 -columnspan 6 -sticky ew -padx {8 0} -pady 3
        grid columnconfigure $cross_panel 1 -weight 1

        set advanced_panel [ttk::frame $parent.advanced]
        ttk::label $advanced_panel.scale_label -text "Scale min / max"
        ttk::entry $advanced_panel.scale_min -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_scale_min -width 8
        ttk::entry $advanced_panel.scale_max -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_scale_max -width 8
        ttk::label $advanced_panel.threshold_label -text "Threshold min / max"
        ttk::entry $advanced_panel.threshold_min -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_threshold_min -width 8
        ttk::entry $advanced_panel.threshold_max -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_threshold_max -width 8
        ttk::button $advanced_panel.classic -text "Classic controls…" -command ::RMSXFlipbookTimeline::Dashboard::open_classic
        grid $advanced_panel.scale_label -row 0 -column 0 -sticky w -pady 3
        grid $advanced_panel.scale_min -row 0 -column 1 -sticky ew -padx {8 4} -pady 3
        grid $advanced_panel.scale_max -row 0 -column 2 -sticky ew -padx {4 16} -pady 3
        grid $advanced_panel.threshold_label -row 0 -column 3 -sticky w -pady 3
        grid $advanced_panel.threshold_min -row 0 -column 4 -sticky ew -padx {8 4} -pady 3
        grid $advanced_panel.threshold_max -row 0 -column 5 -sticky ew -padx {4 16} -pady 3
        grid $advanced_panel.classic -row 0 -column 6 -sticky ew -pady 3
        compact_option_panels $parent
    }

    proc build_actions {parent} {
        ttk::button $parent.run -text "Run RMSX" -style RMSX.Primary.TButton
        ttk::button $parent.save -text "3D Image" -command ::RMSXFlipbookTimeline::Dashboard::save_flipbook_image
        ttk::button $parent.popout -text "Heatmap ↗" -command ::RMSXFlipbookTimeline::Dashboard::open_full_plot_window
        ttk::button $parent.figure -text Figure -command ::RMSXFlipbookTimeline::Dashboard::save_figure
        ttk::label $parent.spacing -text Spacing
        ttk::button $parent.spacing_minus -text − -width 2 -command {::RMSXFlipbookTimeline::Dashboard::nudge_spacing -2.0}
        ttk::button $parent.spacing_plus -text + -width 2 -command {::RMSXFlipbookTimeline::Dashboard::nudge_spacing 2.0}
        ttk::button $parent.reset_view -text Reset -command ::RMSXFlipbookTimeline::Dashboard::reset_view
        ttk::button $parent.clear -text "Remove…" -command ::RMSXFlipbookTimeline::Dashboard::clear_scene
        ttk::button $parent.retry -text "Retry view" -command ::RMSXFlipbookTimeline::Dashboard::retry_saved_result -state disabled
        ttk::frame $parent.analysis
        ttk::frame $parent.view
        ttk::separator $parent.separator -orient horizontal
        grid $parent.analysis -row 0 -column 0 -sticky ew
        grid $parent.separator -row 1 -column 0 -sticky ew -pady 8
        grid $parent.view -row 2 -column 0 -sticky ew
        foreach {col widget} {0 run 1 popout 2 save 3 figure} {
            grid $parent.$widget -in $parent.analysis -row 0 -column $col -sticky ew -padx [expr {$col == 3 ? "0 0" : "0 8"}]
            grid columnconfigure $parent.analysis $col -weight 1 -uniform actions
        }
        foreach {col widget} {0 spacing 1 spacing_minus 2 spacing_plus 4 reset_view 5 clear} {
            grid $parent.$widget -in $parent.view -row 0 -column $col -sticky w -padx [expr {$col == 5 ? "8 0" : "0 4"}]
        }
        $parent.reset_view configure -text "Reset View"
        grid columnconfigure $parent.view 3 -weight 1
        grid $parent.retry -row 3 -column 0 -sticky w -pady {8 0}
        grid remove $parent.retry
        grid columnconfigure $parent 0 -weight 1
        foreach widget {run popout save figure spacing spacing_minus spacing_plus reset_view clear} {raise $parent.$widget}
        help_tip $parent.clear "Remove plugin-owned molecules and the current result. Files are kept."
        help_tip $parent.figure "Export a figure from the committed current result."
        help_tip $parent.retry "Retry the last saved result whose display failed. This opens the saved files and never reruns the analysis."
    }

    proc build_results_tree {parent} {
        variable dataset_list_widget
        ttk::treeview $parent.tree -columns {kind detail} -show {tree headings} -height 2
        ttk::scrollbar $parent.ys -orient vertical -command [list $parent.tree yview]
        $parent.tree configure -yscrollcommand [list $parent.ys set]
        $parent.tree heading #0 -text "Dataset"
        $parent.tree heading kind -text "Type"
        $parent.tree heading detail -text "Detail"
        $parent.tree column #0 -width 180 -stretch 0
        $parent.tree column kind -width 90 -stretch 0
        $parent.tree column detail -width 420 -stretch 1
        set dataset_list_widget $parent.tree
        grid $parent.tree -row 0 -column 0 -sticky nsew
        grid $parent.ys -row 0 -column 1 -sticky ns
        grid columnconfigure $parent 0 -weight 1
        grid rowconfigure $parent 0 -weight 1
    }

    proc build_embedded_heatmap_panel {parent} {
        variable embedded_heatmap_canvas
        variable embedded_heatmap_status_var
        variable citation_footer_note
        grid columnconfigure $parent 0 -weight 1
        grid columnconfigure $parent 1 -weight 0
        canvas $parent.canvas \
            -background white \
            -height 320 \
            -width 500 \
            -scrollregion {0 0 560 320}
        ttk::label $parent.summary \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::embedded_heatmap_status_var \
            -wraplength 520 -anchor w
        ttk::checkbutton $parent.context \
            -text "Compare: RMSD / RMSF" \
            -variable ::RMSXFlipbookTimeline::Dashboard::native_show_context_plots \
            -command ::RMSXFlipbookTimeline::Dashboard::refresh_native_heatmap_view
        ttk::label $parent.citation \
            -text "Citation in Help" \
            -style RMSX.Citation.TLabel \
            -anchor e \
            -justify right \
            -wraplength 320
        set embedded_heatmap_canvas $parent.canvas
        grid $parent.canvas -row 2 -column 0 -columnspan 2 -sticky nsew
        grid $parent.summary -row 4 -column 0 -columnspan 2 -sticky ew -pady {3 0}
        grid $parent.context -row 0 -column 0 -sticky w -pady {2 4}
        help_tip $parent.context "Show comparison plots. Click RMSD to select a slice; click RMSF to select a residue. Heatmap selections mark both plots."
        # Citation is available in Help without occupying plot toolbar space.
        bind $parent.canvas <Configure> {::RMSXFlipbookTimeline::Dashboard::schedule_embedded_heatmap_resize_redraw %w}
        help_tip $parent.citation $citation_footer_note
        clear_embedded_heatmap
    }

    proc sync_scrollable_content {canvas item} {
        if {[info commands winfo] eq "" || ![winfo exists $canvas]} {
            return
        }
        set bbox [$canvas bbox all]
        if {$bbox eq ""} {
            set bbox {0 0 1 1}
        }
        $canvas configure -scrollregion $bbox
        set width [winfo width $canvas]
        if {$width > 1} {
            catch {$canvas itemconfigure $item -width $width}
        }
    }

    proc scroll_canvas_by_wheel {canvas delta} {
        if {[info commands winfo] eq "" || ![winfo exists $canvas]} {
            return
        }
        if {$delta == 0} {
            return
        }
        set units [expr {int(-1 * ($delta / 120.0))}]
        if {$units == 0} {
            set units [expr {$delta > 0 ? -1 : 1}]
        }
        $canvas yview scroll $units units
    }

    proc scroll_easy_canvas_by_wheel {canvas delta} {
        variable top
        if {[info commands winfo] eq "" || ![winfo exists $canvas] || ![winfo exists $top.tabs]} {
            return
        }
        if {[$top.tabs select] ne "$top.tabs.easy"} {
            return
        }
        scroll_canvas_by_wheel $canvas $delta
    }

    proc scroll_easy_canvas_by_key {canvas key} {
        variable top
        if {[info commands winfo] eq "" || ![winfo exists $canvas] || ![winfo exists $top.tabs]} {
            return
        }
        if {[$top.tabs select] ne "$top.tabs.easy"} {
            return
        }
        switch -- $key {
            Prior {
                $canvas yview scroll -1 pages
            }
            Next {
                $canvas yview scroll 1 pages
            }
            Home {
                $canvas yview moveto 0
            }
            End {
                $canvas yview moveto 1
            }
            Up {
                $canvas yview scroll -3 units
            }
            Down {
                $canvas yview scroll 3 units
            }
        }
    }

    proc scroll_easy_to_top {} {
        variable top
        set canvas $top.tabs.easy.scroll_canvas
        if {[info commands winfo] ne "" && [winfo exists $canvas]} {
            update idletasks
            $canvas yview moveto 0
        }
    }

    proc scroll_easy_to_heatmap {} {
        variable top
        set canvas $top.tabs.easy.scroll_canvas
        set heatmap [easy_child heatmap]
        if {[info commands winfo] eq "" || ![winfo exists $canvas] || ![winfo exists $heatmap]} {
            return
        }
        update idletasks
        set bbox [$canvas bbox all]
        if {$bbox eq ""} {
            return
        }
        set scroll_height [expr {double([lindex $bbox 3] - [lindex $bbox 1])}]
        if {$scroll_height <= 0.0} {
            return
        }
        set target [expr {max(0, [winfo y $heatmap] - 4)}]
        $canvas yview moveto [expr {$target / $scroll_height}]
    }

    proc maybe_scroll_easy_to_heatmap_after_run {} {
        variable easy_auto_scrolled_after_run
        if {$easy_auto_scrolled_after_run} {
            return
        }
        set easy_auto_scrolled_after_run "1"
        scroll_easy_to_heatmap
    }

    proc build_scrollable_easy_content {parent} { return [build_scrollable_content $parent] }

    proc build_easy_tab {parent} {
        set content [build_scrollable_easy_content $parent]
        grid columnconfigure $content 0 -weight 1

        set source [ttk::frame $content.source]
        set files [ttk::labelframe $content.files -text "Inputs" -padding {8 6}]
        set metric [ttk::frame $content.metric -padding {8 6}]
        set settings [ttk::labelframe $content.settings -text "Slices" -padding {8 6}]
        set options [ttk::frame $content.options -padding {0 0}]
        set actions [ttk::frame $content.actions -padding {8 6}]
        set heatmap [ttk::labelframe $content.heatmap -text "Heatmap" -padding 6]

        grid $source -in $files -row 0 -column 0 -columnspan 3 -sticky ew -pady {0 5}
        grid $files -row 1 -column 0 -sticky ew -pady {0 6}
        grid $metric -row 2 -column 0 -sticky ew -pady {0 6}
        grid $settings -row 3 -column 0 -sticky ew -pady {0 4}
        grid $actions -row 4 -column 0 -sticky ew -pady {0 6}
        grid $options -row 5 -column 0 -sticky ew -pady {0 5}
        grid $heatmap -row 6 -column 0 -sticky nsew -pady {0 5}

        grid columnconfigure $files 1 -weight 1
        build_source_selector $source
        raise $source
        build_file_row $files 1 "Topology" native_topology file
        build_file_row $files 2 "Trajectory" native_trajectory file
        build_file_row $files 3 "Output" native_output directory
        help_tip $files.native_output_entry "Parent folder for a new, unique run directory. Earlier results are kept."
        build_file_row $files 4 "RMSX Folder" folder directory
        build_file_row $files 5 "TML File" timeline_tml_file file
        build_file_row $files 6 "Collection" timeline_collection_dir directory
        build_metric_controls $metric 1
        build_run_settings $settings
        build_metric_option_panels $options 0
        build_actions $actions
        build_embedded_heatmap_panel $heatmap
    }

    proc build_matrix_tab {parent} {
        grid columnconfigure $parent 0 -weight 1
        set metric [ttk::labelframe $parent.metric -text "Metric" -padding 6]
        set live [ttk::labelframe $parent.live -text "Source" -padding 6]
        set import [ttk::labelframe $parent.import -text "Saved matrices" -padding 6]
        set filter [ttk::labelframe $parent.filter -text "Filter" -padding 6]
        set options [ttk::labelframe $parent.options -text "Metric Options" -padding 6]
        grid $metric -row 0 -column 0 -sticky ew -pady {0 6}
        grid $live -row 1 -column 0 -sticky ew -pady {0 6}
        grid $import -row 2 -column 0 -sticky ew -pady {0 6}
        grid $filter -row 3 -column 0 -sticky ew -pady {0 6}
        grid $options -row 4 -column 0 -sticky ew
        grid columnconfigure $live 3 -weight 1
        grid columnconfigure $import 1 -weight 1
        build_timeline_metric_controls $metric

        ttk::label $live.molid_label -text "Molecule"
        ttk::combobox $live.molid_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_molid -values [molecule_choices] -state readonly -postcommand ::RMSXFlipbookTimeline::Dashboard::refresh_molecule_choices -width 22
        ttk::label $live.selection_label -text "Selection"
        ttk::entry $live.selection_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_selection
        ttk::button $live.plot -text "Plot" -style RMSX.Primary.TButton -command {::RMSXFlipbookTimeline::Dashboard::invoke_action ::RMSXFlipbookTimeline::Dashboard::run_live_metric}
        ttk::label $live.columns_label -text "Columns"
        ttk::radiobutton $live.columns_frames \
            -text "Frames" \
            -value frames \
            -variable ::RMSXFlipbookTimeline::Dashboard::timeline_column_mode \
            -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        ttk::radiobutton $live.columns_slices \
            -text "Slices" \
            -value slices \
            -variable ::RMSXFlipbookTimeline::Dashboard::timeline_column_mode \
            -command ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        ttk::label $live.aggregation_label -text "Aggregation"
        ttk::combobox $live.aggregation_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_slice_aggregation \
            -values {auto mean max min first last occupancy mode circular_mean} \
            -state readonly \
            -width 14
        ttk::label $live.representative_label -text "Representative"
        ttk::combobox $live.representative_combo \
            -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_slice_representative \
            -values {first middle last} \
            -state readonly \
            -width 10
        grid $live.molid_label -row 0 -column 0 -sticky w -pady 3
        grid $live.molid_entry -row 0 -column 1 -columnspan 2 -sticky ew -padx 8
        grid $live.plot -row 0 -column 3 -sticky e
        grid $live.selection_label -row 1 -column 0 -sticky w -pady 3
        grid $live.selection_entry -row 1 -column 1 -columnspan 3 -sticky ew -padx {8 0}
        grid $live.columns_label -row 2 -column 0 -sticky w
        grid $live.columns_frames -row 2 -column 1 -sticky w -padx 8
        grid $live.columns_slices -row 2 -column 2 -sticky w
        $live.aggregation_label configure -text Combine
        $live.representative_label configure -text Snapshot
        grid $live.aggregation_label -row 3 -column 0 -sticky w -pady 3
        grid $live.aggregation_combo -row 3 -column 1 -sticky w -padx 8
        grid $live.representative_label -row 3 -column 2 -sticky w
        grid $live.representative_combo -row 3 -column 3 -sticky w -padx 8
        help_tip $live.aggregation_combo "How frame values are combined within each slice. Auto chooses a suitable method for the metric."
        help_tip $live.representative_combo "Which frame represents a slice when linking to the structure."
        help_tip $live.molid_entry "Choose an existing VMD molecule. Top is resolved once at the start of the calculation."

        build_file_row $import 0 "TML File" timeline_tml_file file
        build_file_row $import 1 "Collection" timeline_collection_dir directory
        ttk::button $import.load_tml -text "Load TML" -command ::RMSXFlipbookTimeline::Dashboard::load_tml
        ttk::button $import.load_collection -text "Load Collection" -command ::RMSXFlipbookTimeline::Dashboard::load_collection
        grid $import.load_tml -row 0 -column 3 -sticky ew -pady 3
        grid $import.load_collection -row 1 -column 3 -sticky ew -pady 3
        grid [::RMSXFlipbookTimeline::Collections::build_controls $import.saved] -row 2 -column 0 -columnspan 4 -sticky ew -pady {3 0}

        foreach {row col label var width} {
            0 0 Scale timeline_scale_mode 12
            0 2 "Min frames" timeline_filter_frames 6
            1 0 Min timeline_filter_min 9
            1 2 Max timeline_filter_max 9
        } {
            ttk::label $filter.${var}_label -text $label
            if {$var eq "timeline_scale_mode"} {
                ttk::combobox $filter.${var}_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::$var -values {fit every_residue} -state readonly -width $width
            } else {
                ttk::entry $filter.${var}_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::$var -width $width
            }
            grid $filter.${var}_label -row $row -column $col -sticky w -padx {0 6} -pady 3
            grid $filter.${var}_entry -row $row -column [expr {$col + 1}] -sticky w -padx {0 10}
        }
        ttk::button $filter.apply -text Apply -command ::RMSXFlipbookTimeline::Dashboard::apply_filter
        grid $filter.apply -row 1 -column 4 -sticky e
        grid columnconfigure $filter 4 -weight 1
        build_metric_option_panels $options
    }

    proc build_flipbook_tab {parent} {
        grid columnconfigure $parent 0 -weight 1
        set folder_panel [ttk::labelframe $parent.folder -text "RMSX Flipbook Folder" -padding 8]
        set actions [ttk::frame $parent.actions]
        set interaction [ttk::labelframe $parent.interaction -text "Flipbook Interaction" -padding 8]
        grid $folder_panel -row 0 -column 0 -sticky ew -pady {0 8}
        grid $actions -row 1 -column 0 -sticky ew -pady {0 8}
        grid $interaction -row 2 -column 0 -sticky ew
        grid columnconfigure $folder_panel 1 -weight 1
        build_file_row $folder_panel 0 "RMSX Folder" folder directory
        foreach col {0 1 2} {
            grid columnconfigure $actions $col -weight 1
        }
        ttk::button $actions.load -text "Load Flipbook" -command ::RMSXFlipbookTimeline::Dashboard::load_existing_folder
        ttk::button $actions.matrix -text "View Matrix" -command ::RMSXFlipbookTimeline::Dashboard::view_matrix
        ttk::button $actions.classic -text "Classic / Legacy Controls" -command ::RMSXFlipbookTimeline::Dashboard::open_classic
        grid $actions.load -row 0 -column 0 -sticky ew -padx {0 8}
        grid $actions.matrix -row 0 -column 1 -sticky ew -padx {0 8}
        grid $actions.classic -row 0 -column 2 -sticky ew

        foreach col {0 1 2 3} {
            grid columnconfigure $interaction $col -weight 1
        }
        ttk::button $interaction.spacing_minus -text "Spacing −" -width 12 -command {::RMSXFlipbookTimeline::Dashboard::nudge_spacing -2.0}
        ttk::button $interaction.spacing_plus -text "Spacing +" -width 12 -command {::RMSXFlipbookTimeline::Dashboard::nudge_spacing 2.0}
        ttk::button $interaction.reset_view -text "Reset View" -command ::RMSXFlipbookTimeline::Dashboard::reset_view
        ttk::button $interaction.clear -text "Clear" -command ::RMSXFlipbookTimeline::Dashboard::clear_scene

        grid $interaction.spacing_minus -row 0 -column 0 -sticky ew -padx {0 8} -pady 3
        grid $interaction.spacing_plus -row 0 -column 1 -sticky ew -padx {0 8} -pady 3
        grid $interaction.reset_view -row 0 -column 2 -sticky ew -padx {0 8} -pady 3
        grid $interaction.clear -row 0 -column 3 -sticky ew -pady 3
    }

    proc build_export_tab {parent} {
        ttk::labelframe $parent.image -text "Current result" -padding 8
        ttk::label $parent.image.note -text "Exports use the current result shown above." -wraplength 520
        ttk::button $parent.image.save -text "3D Image" -command ::RMSXFlipbookTimeline::Dashboard::save_flipbook_image
        ttk::button $parent.image.figure -text Figure -command ::RMSXFlipbookTimeline::Dashboard::save_figure
        ttk::checkbutton $parent.image.transparent -text "Transparent PNG" -variable ::RMSXFlipbookTimeline::Dashboard::render_transparent_png
        grid $parent.image -row 0 -column 0 -sticky ew -pady {0 8}
        grid $parent.image.note -row 0 -column 0 -columnspan 3 -sticky w -pady {0 8}
        grid $parent.image.save -row 1 -column 0 -padx {0 8}
        grid $parent.image.figure -row 1 -column 1 -padx {0 8}
        grid $parent.image.transparent -row 1 -column 2
        ttk::labelframe $parent.files -text Matrix -padding 8
        grid $parent.files -row 1 -column 0 -sticky ew -pady {0 8}
        foreach {col kind label} {0 tml TML 1 svg SVG 2 png PNG} {
            ttk::button $parent.files.$kind -text $label -command [list ::RMSXFlipbookTimeline::Dashboard::export_current $kind]
            grid $parent.files.$kind -row 0 -column $col -padx {0 8}
        }
        ttk::labelframe $parent.user -text "VMD field" -padding 8
        grid $parent.user -row 2 -column 0 -sticky ew
        ttk::combobox $parent.user.field -textvariable ::RMSXFlipbookTimeline::Dashboard::timeline_user_field -values {user user2 user3 user4} -state readonly -width 9
        ttk::button $parent.user.copy -text Copy -command ::RMSXFlipbookTimeline::Dashboard::copy_user_field
        grid $parent.user.field -row 0 -column 0 -padx {0 8}
        grid $parent.user.copy -row 0 -column 1
        grid columnconfigure $parent 0 -weight 1
        help_tip $parent.image.figure "Export heatmap, linked structure and context panels using the current result."
        help_tip $parent.user.copy "Copy the current matrix values into this VMD user field."
    }

    proc build_advanced_tab {parent} {
        set experimental [experimental_enabled]
        grid columnconfigure $parent 0 -weight 1
        grid columnconfigure $parent 1 -weight 1
        set utilities [ttk::labelframe $parent.utilities -text "Maintenance / Legacy Utilities" -padding 6]
        set native_panel [ttk::labelframe $parent.native -text "Run Options" -padding 6]
        set note [ttk::labelframe $parent.note -text "Classic / Legacy Controls" -padding 6]
        grid $utilities -row 0 -column 0 -columnspan 2 -sticky ew -pady {0 6}
        grid $native_panel -row 1 -column 0 -columnspan 2 -sticky ew -pady {0 6}
        grid $note -row 2 -column 0 -columnspan 2 -sticky ew -pady {0 6}
        if {$experimental} {
            set proc_panel [ttk::labelframe $parent.residue -text "Experimental Residue Function" -padding 6]
            set cross_panel [ttk::labelframe $parent.cross -text "Experimental Cross-Correlation" -padding 6]
            grid $proc_panel -row 3 -column 0 -columnspan 2 -sticky ew -pady {0 6}
            grid $cross_panel -row 4 -column 0 -columnspan 2 -sticky ew
        }

        ttk::checkbutton $native_panel.native_log_transform \
            -text "Log transform RMSX values" \
            -variable ::RMSXFlipbookTimeline::Dashboard::native_log_transform \
            -command ::RMSXFlipbookTimeline::Dashboard::persist_common_state
        ttk::label $native_panel.note \
            -text "Affects new RMSX, Shift-Map, and lDDT runs." \
            -wraplength 300
        grid $native_panel.native_log_transform -row 0 -column 0 -sticky w -pady 3
        grid $native_panel.note -row 1 -column 0 -sticky ew -pady {4 0}
        grid columnconfigure $native_panel 0 -weight 1

        foreach col {0 1 2 3} {
            grid columnconfigure $utilities $col -weight 1
        }
        ttk::button $utilities.plot -text "Full Plot Window" -command ::RMSXFlipbookTimeline::Dashboard::open_full_plot_window
        ttk::button $utilities.heatmap -text "Heatmap SVG" -command ::RMSXFlipbookTimeline::Dashboard::export_native_heatmap_svg
        ttk::button $utilities.report -text "Report SVG" -command ::RMSXFlipbookTimeline::Dashboard::export_native_report_svg
        ttk::button $utilities.repair -text "Repair B-Factors" -command ::RMSXFlipbookTimeline::Dashboard::repair_native_bfactors
        ttk::button $utilities.multimodel -text "Multi-model PDB" -command ::RMSXFlipbookTimeline::Dashboard::export_multimodel_pdb
        ttk::button $utilities.load_manifest -text "Load Manifest" -command ::RMSXFlipbookTimeline::Dashboard::load_manifest_file
        ttk::button $utilities.show_manifest -text "Show Manifest" -command ::RMSXFlipbookTimeline::Dashboard::show_manifest
        grid $utilities.plot -row 0 -column 0 -sticky ew -padx {0 8} -pady 3
        grid $utilities.heatmap -row 0 -column 1 -sticky ew -padx {0 8} -pady 3
        grid $utilities.report -row 0 -column 2 -sticky ew -padx {0 8} -pady 3
        grid $utilities.repair -row 0 -column 3 -sticky ew -pady 3
        grid $utilities.multimodel -row 1 -column 0 -sticky ew -padx {0 8} -pady 3
        grid $utilities.load_manifest -row 1 -column 1 -sticky ew -padx {0 8} -pady 3
        grid $utilities.show_manifest -row 1 -column 2 -sticky ew -padx {0 8} -pady 3
        if {$experimental} {
            ttk::button $utilities.hotkeys -text "Install Hotkeys" -command ::RMSXFlipbookTimeline::Dashboard::install_dashboard_hotkeys
            grid $utilities.hotkeys -row 1 -column 3 -sticky ew -pady 3

            foreach {row label var} {
                0 "Proc" timeline_residue_function
                1 "Context" timeline_residue_function_context
                2 "Label" timeline_residue_function_label
                3 "Unit" timeline_residue_function_unit
            } {
                ttk::label $proc_panel.${var}_label -text $label
                ttk::entry $proc_panel.${var}_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::$var
                grid $proc_panel.${var}_label -row $row -column 0 -sticky w -pady 3
                grid $proc_panel.${var}_entry -row $row -column 1 -sticky ew -padx {8 0} -pady 3
            }
            grid columnconfigure $proc_panel 1 -weight 1
            foreach {row label var} {
                0 "CC Map" timeline_cc_map_file
                1 "Vol" timeline_cc_vol_id
                2 "Resolution" timeline_cc_map_res
                3 "Selections" timeline_cc_selection_list
            } {
                ttk::label $cross_panel.${var}_label -text $label
                ttk::entry $cross_panel.${var}_entry -textvariable ::RMSXFlipbookTimeline::Dashboard::$var
                grid $cross_panel.${var}_label -row $row -column 0 -sticky w -pady 3
                grid $cross_panel.${var}_entry -row $row -column 1 -sticky ew -padx {8 0} -pady 3
            }
            grid columnconfigure $cross_panel 1 -weight 1
        }
        ttk::label $note.text -text "Additional controls for advanced workflows." -wraplength 300
        ttk::button $note.classic -text "Classic controls…" -command ::RMSXFlipbookTimeline::Dashboard::open_classic
        grid $note.text -row 0 -column 0 -sticky ew -pady {0 6}
        grid $note.classic -row 1 -column 0 -sticky ew
        grid columnconfigure $note 0 -weight 1
    }

    proc build_help_tab {parent} {
        variable help_url
        variable citation_note
        grid columnconfigure $parent 0 -weight 1
        set repo [ttk::labelframe $parent.github -text "Project" -padding 6]
        set cite [ttk::labelframe $parent.cite -text "Citation" -padding 6]
        grid $repo -row 0 -column 0 -sticky ew -pady {0 6}
        grid $cite -row 1 -column 0 -sticky ew
        grid columnconfigure $repo 0 -weight 1

        ttk::label $repo.text \
            -text "Source code, examples, and project notes." \
            -wraplength 500
        ttk::label $repo.url -text $help_url -foreground "#1d4ed8"
        ttk::button $repo.open -text "Open GitHub Repository" -command ::RMSXFlipbookTimeline::Dashboard::open_help_url

        grid $repo.text -row 0 -column 0 -sticky ew -pady {0 4}
        grid $repo.open -row 0 -column 1 -sticky e -padx {12 0}
        grid $repo.url -row 1 -column 0 -columnspan 2 -sticky w

        ttk::label $cite.text \
            -text $citation_note \
            -style RMSX.Citation.TLabel \
            -justify left \
            -wraplength 520
        grid $cite.text -row 0 -column 0 -sticky ew
        ttk::button $cite.copy -text "Copy Citation" -command ::RMSXFlipbookTimeline::Dashboard::copy_citation
        grid $cite.copy -row 1 -column 0 -sticky w -pady {6 0}
        grid columnconfigure $cite 0 -weight 1
    }

    proc copy_citation {} {
        variable top
        variable citation_note
        clipboard clear -displayof $top
        clipboard append -displayof $top $citation_note
    }

    proc configure_dashboard_styles {} {
        foreach {name base} {RMSX.TButton TButton RMSX.Primary.TButton TButton RMSX.TCheckbutton TCheckbutton RMSX.TRadiobutton TRadiobutton} {
            ttk::style configure $name -font TkDefaultFont -padding {5 3}
        }
        ttk::style configure RMSX.TButton -width 0 -padding {8 4}
        ttk::style configure RMSX.Primary.TButton -width 0 -font TkHeadingFont -padding {10 4}
        ttk::style configure RMSX.TLabelframe -borderwidth 0 -relief flat
        ttk::style configure RMSX.TLabelframe.Label -font TkHeadingFont
        ttk::style configure RMSX.Title.TLabel -font TkHeadingFont
        ttk::style configure RMSX.Path.TEntry -font TkTextFont
        ttk::style configure RMSX.Citation.TLabel -font TkSmallCaptionFont
        ttk::style configure RMSX.FooterCitation.TLabel -font TkSmallCaptionFont -foreground "#59636d"
    }

    proc apply_dashboard_styles {parent} {
        foreach widget [descendant_widgets $parent] {
            if {[winfo class $widget] eq "TButton" && [$widget cget -style] eq ""} {$widget configure -style RMSX.TButton}
            if {[winfo class $widget] eq "TLabelframe"} {$widget configure -style RMSX.TLabelframe}
        }
    }

    proc build {} {
        variable top
        variable status_widget
        variable end_display
        variable citation_note
        variable citation_footer_note
        package require Tk
        configure_dashboard_styles
        if {[winfo exists $top]} {
            wm deiconify $top; raise $top; refresh_dashboard
            if {[info commands ::RMSXFlipbookTimeline::Reviewer::mount] ne ""} { ::RMSXFlipbookTimeline::Reviewer::mount }
            return $top
        }
        sync_from_state
        if {$::RMSXFlipbookTimeline::Dashboard::native_metric eq "lDDT"} { set ::RMSXFlipbookTimeline::Dashboard::native_metric "1-lDDT" }
        set end_display [expr {$::RMSXFlipbookTimeline::Dashboard::native_end == -1 ? "Last" : $::RMSXFlipbookTimeline::Dashboard::native_end}]
        toplevel $top
        wm title $top "Flipbook $::RMSXFlipbookTimeline::version"
        set width [expr {min(660, [winfo screenwidth $top]-40)}]
        set height [expr {min(800, [winfo screenheight $top]-100)}]
        wm geometry $top ${width}x${height}
        wm minsize $top [expr {min(600,$width)}] [expr {min(540,$height)}]
        wm protocol $top WM_DELETE_WINDOW ::RMSXFlipbookTimeline::Dashboard::close_window
        bind $top <Map> {::RMSXFlipbookTimeline::Dashboard::restore_rotation_on_map %W}
        bind $top <Configure> {::RMSXFlipbookTimeline::Dashboard::request_scene_refresh %W}
        bind $top <Expose> {::RMSXFlipbookTimeline::Dashboard::request_scene_refresh %W}
        grid columnconfigure $top 0 -weight 1
        grid rowconfigure $top 1 -weight 1
        ttk::frame $top.header -padding {10 8}
        ttk::label $top.header.title -textvariable ::RMSXFlipbookTimeline::Dashboard::result_title -style RMSX.Title.TLabel -width 1 -anchor w
        ttk::button $top.header.details -text "Details…" -command ::RMSXFlipbookTimeline::Dashboard::show_result_details
        grid $top.header -row 0 -column 0 -sticky ew
        grid $top.header.title -row 0 -column 0 -sticky ew -padx {0 10}
        grid $top.header.details -row 0 -column 1 -sticky e
        grid columnconfigure $top.header 0 -weight 1
        bind $top.header.title <Configure> {::RMSXFlipbookTimeline::Dashboard::fit_result_title %w}
        set tabs [ttk::notebook $top.tabs]
        grid $tabs -row 1 -column 0 -sticky nsew -padx 8 -pady {0 6}
        foreach {name label} {easy "RMSX / Flipbook" matrix Timeline export Export advanced Advanced help Help} {
            ttk::frame $tabs.$name -padding 6
            $tabs add $tabs.$name -text $label
        }
        build_easy_tab $tabs.easy
        build_matrix_tab [build_scrollable_content $tabs.matrix]
        build_export_tab [build_scrollable_content $tabs.export]
        build_advanced_tab [build_scrollable_content $tabs.advanced]
        build_help_tab [build_scrollable_content $tabs.help]
        ttk::frame $top.footer -padding {8 0 8 6}
        grid $top.footer -row 2 -column 0 -sticky ew
        grid columnconfigure $top.footer 0 -weight 1
        ttk::label $top.footer.status -textvariable ::RMSXFlipbookTimeline::Dashboard::status_text -wraplength 380
        ttk::button $top.footer.stop -text Stop -state disabled -command ::RMSXFlipbookTimeline::Operation::request_cancel
        ttk::button $top.footer.details -text "Log…" -command ::RMSXFlipbookTimeline::Dashboard::show_log_details
        ttk::progressbar $top.footer.progress -mode determinate -maximum 100
        grid $top.footer.status -row 0 -column 0 -sticky ew
        bind $top.footer.status <Configure> {::RMSXFlipbookTimeline::Dashboard::resize_label_wrap %W %w 120 4}
        grid $top.footer.stop -row 0 -column 1 -padx 6
        grid $top.footer.details -row 0 -column 2
        grid $top.footer.progress -row 1 -column 0 -columnspan 3 -sticky ew -pady {4 0}
        grid remove $top.footer.progress
        ttk::frame $top.details
        ttk::frame $top.details.actions
        ttk::label $top.details.actions.title -text "Result Details" -font TkHeadingFont
        ttk::button $top.details.actions.copy -text "Copy Details" -command ::RMSXFlipbookTimeline::Dashboard::copy_result_details
        ttk::button $top.details.actions.save -text "Save Log…" -command ::RMSXFlipbookTimeline::Dashboard::save_detail_log
        ttk::button $top.details.actions.hide -text Hide -command ::RMSXFlipbookTimeline::Dashboard::hide_details
        grid $top.details.actions.title -row 0 -column 0 -sticky w
        grid $top.details.actions.copy -row 0 -column 1 -padx 4
        grid $top.details.actions.save -row 0 -column 2 -padx 4
        grid $top.details.actions.hide -row 0 -column 3
        grid columnconfigure $top.details.actions 0 -weight 1
        grid $top.details.actions -row 0 -column 0 -sticky ew -pady {0 4}
        ttk::notebook $top.details.tabs
        foreach {name label} {result Result log Log} {
            ttk::frame $top.details.tabs.$name
            text $top.details.tabs.$name.text -height 7 -width 1 -wrap word -state disabled -font TkTextFont -yscrollcommand [list $top.details.tabs.$name.scroll set]
            ttk::scrollbar $top.details.tabs.$name.scroll -command [list $top.details.tabs.$name.text yview]
            grid $top.details.tabs.$name.text -row 0 -column 0 -sticky nsew
            grid $top.details.tabs.$name.scroll -row 0 -column 1 -sticky ns
            grid columnconfigure $top.details.tabs.$name 0 -weight 1
            grid rowconfigure $top.details.tabs.$name 0 -weight 1
            $top.details.tabs add $top.details.tabs.$name -text $label
        }
        grid $top.details.tabs -row 1 -column 0 -sticky nsew
        grid columnconfigure $top.details 0 -weight 1
        ttk::label $top.citation -text [string map [list \n " · "] $citation_footer_note] \
            -style RMSX.FooterCitation.TLabel -anchor center -justify center -wraplength 620 -takefocus 1
        grid $top.citation -row 4 -column 0 -sticky ew -padx 8 -pady {0 6}
        bind $top.citation <Configure> {::RMSXFlipbookTimeline::Dashboard::resize_label_wrap %W %w 120 4}
        help_tip $top.citation "$citation_note\n\nUse Help → Copy Citation for the full reference."
        set status_widget $top.details.tabs.log.text
        apply_dashboard_styles $top
        help_tip $top.footer.stop "Request cancellation at the next safe checkpoint. A VMD file read or measurement already in progress must finish first."
        ::RMSXFlipbookTimeline::Operation::set_observer ::RMSXFlipbookTimeline::Dashboard::operation_changed
        set_status "Ready. Choose files or open a result folder."
        refresh_dashboard
        refresh_result_header
        if {[info commands ::RMSXFlipbookTimeline::Reviewer::mount] ne ""} { ::RMSXFlipbookTimeline::Reviewer::mount }
        return $top
    }

    proc restore_rotation_on_map {window} {
        variable top
        if {$window ne $top} {return}
        request_scene_refresh
        # Close releases the input trace while preserving the displayed result.
        # VMD caches the registered window and may deiconify it without calling
        # show again, so reacquire the hook on the toplevel's Map event too.
        if {![dict get [::RMSXFlipbookTimeline::mouse_rotation_status] enabled]} {
            ensure_default_mouse_rotation
        }
    }

    proc show {} {
        set window [build]
        restore_rotation_on_map $window
        return $window
    }
}

namespace eval ::RMSXFlipbookTimeline::Dashboard {
    variable result_title "No result loaded"
    variable result_title_full "No result loaded"
    variable result_summary "Run an analysis or open a result folder."
    variable status_text "Ready"
    variable detail_log ""
    variable details_open 0
    variable close_pending 0
    variable executing_operation 0
    variable operation_entry_allowed 0
    variable busy_controls {}
    variable end_display Last
    variable tooltip_text {}
    variable tooltip_after ""
    variable last_operation_phase ""

    proc tab_content {name} {
        variable top
        return $top.tabs.$name.content
    }

    proc unique_run_path {parent metric} {
        if {$parent eq "" || ![file isdirectory $parent]} { error "Choose an existing output parent folder." }
        set stem [string tolower [string map {" " _ "-" _} $metric]]
        set base [file join [file normalize $parent] "${stem}_[clock format [clock seconds] -format %Y%m%d_%H%M%S]"]
        set candidate $base
        set suffix 1
        while {[file exists $candidate]} { set candidate "${base}_[incr suffix]" }
        return $candidate
    }

    proc perform_operation {name command} {
        variable executing_operation
        variable operation_entry_allowed
        if {[::RMSXFlipbookTimeline::Operation::running]} {
            if {!$executing_operation || !$operation_entry_allowed} { error "An operation is already running" }
            set operation_entry_allowed 0
            return [uplevel #0 $command]
        }
        ::RMSXFlipbookTimeline::Operation::begin $name
        return [execute_operation $command 1]
    }

    proc execute_operation {command {propagate 0}} {
        variable executing_operation
        variable operation_entry_allowed
        variable close_pending
        set operation_entry_allowed [expr {[namespace tail [lindex $command 0]] in {run_native_metric run_live_metric load_existing_folder}}]
        set executing_operation 1
        set code [catch {uplevel #0 $command} result options]
        set executing_operation 0
        set operation_entry_allowed 0
        if {$code} {
            if {[::RMSXFlipbookTimeline::Operation::cancelled $options]} {
                set state cancelled
                set message "Cancelled. Previous result kept."
            } elseif {[dict exists $options -errorcode] && [lrange [dict get $options -errorcode] 0 1] eq {RMSXFLIPBOOK PARTIAL}} {
                set state partial
                set message $result
            } else {
                set state failed
                set message "Failed: $result"
            }
            set_status $message
            if {[dict exists $options -errorinfo]} { set_status "$message\n[dict get $options -errorinfo]" }
        } else {
            set state complete
            set message "Complete."
        }
        ::RMSXFlipbookTimeline::Operation::finish $state $message
        if {$close_pending && [info commands winfo] ne ""} { close_window }
        if {[info exists ::RMSXFlipbookTimeline::GUI::close_pending] && $::RMSXFlipbookTimeline::GUI::close_pending && [info commands winfo] ne ""} { ::RMSXFlipbookTimeline::GUI::close_window }
        if {$code && $propagate} { return -options $options $result }
        return $result
    }

    proc descendant_widgets {parent} {
        set result {}
        foreach widget [winfo children $parent] {
            lappend result $widget
            lappend result {*}[descendant_widgets $widget]
        }
        return $result
    }

    proc set_busy_controls {busy} {
        variable top
        variable busy_controls
        if {[info commands winfo] eq "" || ![winfo exists $top]} { return }
        if {$busy && $busy_controls eq {}} {
            foreach widget [descendant_widgets $top] {
                if {$widget in [list $top.footer.stop $top.footer.details $top.header.details] || [string match "$top.details.*" $widget]} { continue }
                if {![catch {$widget cget -state} state]} {
                    dict set busy_controls $widget $state
                    catch {$widget configure -state disabled}
                }
            }
        } elseif {!$busy && $busy_controls ne {}} {
            dict for {widget state} $busy_controls {
                if {[winfo exists $widget]} { catch {$widget configure -state $state} }
            }
            set busy_controls {}
            refresh_dashboard
        }
    }

    proc operation_changed {operation} {
        variable top
        variable status_text
        variable last_operation_phase
        if {$operation eq {}} { return }
        set status_text [dict get $operation message]
        set phase "[dict get $operation id]/[dict get $operation state]/[dict get $operation phase]"
        if {$phase ne $last_operation_phase} {
            set last_operation_phase $phase
            set_status $status_text
        }
        if {[info commands winfo] eq "" || ![winfo exists $top]} { return }
        set busy [::RMSXFlipbookTimeline::Operation::running]
        set_busy_controls $busy
        $top.footer.stop configure -state [expr {$busy && ![dict get $operation cancel_requested] ? "normal" : "disabled"}]
        if {$busy} {
            grid $top.footer.progress
            if {[dict exists $operation event completed] && [dict exists $operation event total] && [dict get $operation event total] > 0} {
                $top.footer.progress stop
                $top.footer.progress configure -mode determinate -value [expr {100.0 * [dict get $operation event completed] / [dict get $operation event total]}]
            } elseif {[dict exists $operation event slice] && [dict exists $operation event slice_count] && [dict get $operation event slice_count] > 0} {
                $top.footer.progress stop
                $top.footer.progress configure -mode determinate -value [expr {100.0 * [dict get $operation event slice] / [dict get $operation event slice_count]}]
            } else {
                $top.footer.progress configure -mode indeterminate
                $top.footer.progress start 120
            }
        } else {
            $top.footer.progress stop
            grid remove $top.footer.progress
            $top.footer.progress configure -mode determinate -value [expr {[dict get $operation state] eq "complete" ? 100 : 0}]
        }
    }

    proc result_dataset_name {current} {
        if {[dict exists $current source_paths] && [llength [dict get $current source_paths]]} {
            return [file rootname [file tail [lindex [dict get $current source_paths] 0]]]
        }
        foreach path {{source_name} {dataset title} {folder}} {
            if {[dict exists $current {*}$path] && [dict get $current {*}$path] ne ""} {
                return [file rootname [file tail [dict get $current {*}$path]]]
            }
        }
        return Result
    }

    proc refresh_result_header {} {
        variable result_title
        variable result_summary
        variable result_title_full
        variable top
        set current [::RMSXFlipbookTimeline::Results::get]
        set result_summary ""
        if {$current eq {}} {
            set result_title_full "No result loaded"
        } else {
            set metric Result
            foreach key {metric label} {if {[dict exists $current $key] && [dict get $current $key] ne ""} {set metric [dict get $current $key]}}
            if {[string equal -nocase $metric lddt]} {set metric 1-lDDT}
            set parts [list [result_dataset_name $current] $metric]
            if {[dict exists $current dataset column_count]} {
                set count [dict get $current dataset column_count]
                set noun slices
                if {[dict exists $current dataset column_mode] && [dict get $current dataset column_mode] eq "frame"} {set noun frames}
                if {$count == 1} {set noun [string trimright $noun s]}
                lappend parts "$count $noun"
            }
            set result_title_full [join $parts " · "]
        }
        set result_title $result_title_full
        if {[info commands winfo] ne "" && [winfo exists $top.header.title]} {fit_result_title [winfo width $top.header.title]}
        refresh_result_details
        refresh_export_controls
    }

    proc fit_result_title {width} {
        variable result_title
        variable result_title_full
        if {$width < 30 || [info commands font] eq ""} {return}
        set text $result_title_full
        if {[font measure TkHeadingFont $text] > $width} {
            while {[string length $text] && [font measure TkHeadingFont "$text…"] > $width-4} {set text [string range $text 0 end-1]}
            append text …
        }
        if {$result_title ne $text} {set result_title $text}
    }

    proc result_details_text {} {
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current eq {}} {return "No result loaded. Run an analysis or open a result folder."}
        set lines [list "Dataset: [result_dataset_name $current]"]
        foreach {path label} {
            metric Metric units Units status Status chain Chain/group
            selection Selection frame_first {First frame} frame_last {Last frame}
            {dataset row_count} Residues {dataset column_count} Columns
            {native_result parameters mask_selection} Mask time_known {Physical time known}
            time_step_ps {Time step (ps)} folder {Output folder} id {Result generation}
            {native_result run_id} {Run ID} source_molid {Source molecule}
        } {
            if {[dict exists $current {*}$path] && [dict get $current {*}$path] ne ""} {lappend lines "$label: [dict get $current {*}$path]"}
        }
        if {[dict exists $current source_paths]} {
            lappend lines "" "Input files:"
            foreach path [dict get $current source_paths] {lappend lines "  $path"}
        }
        if {[dict exists $current dataset columns]} {
            set mapping {}
            foreach column [dict get $current dataset columns] {
                if {[dict exists $column frame_start] && [dict exists $column frame_end]} {
                    lappend mapping "[expr {[llength $mapping]+1}]: [dict get $column frame_start]–[dict get $column frame_end]"
                }
            }
            if {[llength $mapping]} {lappend lines "" "Slice frame ranges: [join $mapping {; }]"}
        }
        set method {}
        foreach path {{native_result method} {provenance method}} {if {[dict exists $current {*}$path]} {set method [dict get $current {*}$path];break}}
        if {$method ne {}} {
            lappend lines "" "Method:"
            dict for {key value} $method {
                if {$key eq "parameters"} {
                    lappend lines "  Parameters:"
                    dict for {name setting} $value {lappend lines "    $name: $setting"}
                } else {lappend lines "  $key: $value"}
            }
        }
        return [join $lines "\n"]
    }

    proc refresh_result_details {} {
        variable top
        set widget $top.details.tabs.result.text
        if {[info commands winfo] eq "" || ![winfo exists $widget]} {return}
        set text [result_details_text]
        if {[$widget get 1.0 end-1c] eq $text} {return}
        $widget configure -state normal
        $widget delete 1.0 end
        $widget insert 1.0 $text
        $widget configure -state disabled
    }

    proc refresh_export_controls {} {
        variable top
        if {[info commands winfo] eq "" || ![winfo exists $top]} { return }
        set current [::RMSXFlipbookTimeline::Results::get]
        set busy [::RMSXFlipbookTimeline::Operation::running]
        set has_matrix [expr {$current ne {} && [dict exists $current dataset] && [dict get $current dataset] ne {}}]
        set has_scene [expr {$current ne {} && [dict exists $current folder] && [llength [::RMSXFlipbookTimeline::state_get molids {}]] > 0}]
        foreach widget [list [easy_child actions].save [tab_content export].image.save] {
            if {[winfo exists $widget]} { $widget configure -state [expr {$has_scene && !$busy ? "normal" : "disabled"}] }
        }
        foreach widget [list [easy_child actions].figure [tab_content export].image.figure] {
            if {[winfo exists $widget]} { $widget configure -state [expr {$has_scene && !$busy ? "normal" : "disabled"}] }
        }
        variable saved_result
        set retry [easy_child actions].retry
        if {[winfo exists $retry]} {
            set can_retry [expr {$saved_result ne {} && [dict exists $saved_result folder] && [file isdirectory [dict get $saved_result folder]]}]
            $retry configure -state [expr {$can_retry && !$busy ? "normal" : "disabled"}]
            if {$can_retry} {grid $retry} else {grid remove $retry}
        }
        foreach kind {tml svg png} {
            set widget [tab_content export].files.$kind
            if {[winfo exists $widget]} { $widget configure -state [expr {$has_matrix && !$busy ? "normal" : "disabled"}] }
        }
    }

    proc toggle_details {} {
        variable top
        variable details_open
        if {$details_open} { grid $top.details -row 3 -column 0 -sticky ew -padx 8 -pady {0 8} } else { grid remove $top.details }
    }

    proc show_result_details {} {
        variable details_open
        variable top
        refresh_result_details
        set details_open 1
        toggle_details
        $top.details.tabs select $top.details.tabs.result
    }
    proc show_log_details {} {
        variable top
        show_result_details
        $top.details.tabs select $top.details.tabs.log
    }
    proc hide_details {} {variable details_open;set details_open 0;toggle_details}
    proc copy_result_details {} {
        variable top
        clipboard clear -displayof $top
        clipboard append -displayof $top [result_details_text]
    }
    proc write_detail_log {text path} {
        set fp [open $path w]
        try {fconfigure $fp -encoding utf-8;puts -nonewline $fp $text} finally {close $fp}
    }
    proc save_detail_log {{path ""}} {
        variable top
        variable detail_log
        if {$path eq ""} {set path [tk_getSaveFile -parent $top -title "Save diagnostic log" -initialfile rmsx-log.txt -defaultextension .txt -filetypes {{{Text files} {.txt}} {{All files} {*}}}]}
        if {$path eq ""} {return}
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write $path [list ::RMSXFlipbookTimeline::Dashboard::write_detail_log "[result_details_text]\n\nDiagnostic log\n$detail_log"]
        return $path
    }

    proc sync_end_display {} {
        variable end_display
        variable native_end
        set text [string trim $end_display]
        if {[string equal -nocase $text Last]} { set native_end -1 } else { set native_end $text }
        refresh_dashboard
    }

    proc molecule_choices {} {
        set choices {top}
        if {[info commands molinfo] eq ""} { return $choices }
        foreach molid [molinfo list] {
            set name [file tail [molinfo $molid get name]]
            lappend choices "$molid: $name"
        }
        return $choices
    }

    proc refresh_molecule_choices {} {
        set widget [tab_content matrix].live.molid_entry
        if {[winfo exists $widget]} { $widget configure -values [molecule_choices] }
    }

    proc refresh_chain_choices {} {
        variable native_topology
        variable native_chain
        if {[::RMSXFlipbookTimeline::Operation::running]} { return }
        if {![file isfile $native_topology]} { set_status "Choose a topology first."; return }
        if {[catch {::RMSXFlipbookTimeline::NativeAnalysis::discover_chain_groups $native_topology "protein or nucleic" auto} groups]} {
            set_status "Could not read chains: $chains"
            return
        }
        variable native_chain_groups
        variable native_chain_groups_topology
        set native_chain_groups {}
        set native_chain_groups_topology [file normalize $native_topology]
        set choices {all}
        foreach group $groups {
            set label [dict get $group label]
            dict set native_chain_groups $label $group
            lappend choices $label
        }
        set widget [easy_child settings].native_chain_entry
        if {[winfo exists $widget]} { $widget configure -values $choices }
        if {[lsearch -exact $choices $native_chain] < 0} { set native_chain all }
        set_status "Chains: [join $choices {, }]"
    }

    proc selected_chain_group {} {
        variable native_chain
        variable native_chain_groups
        variable native_chain_groups_topology
        variable native_topology
        if {$native_chain_groups_topology ne "" && [file normalize $native_topology] eq $native_chain_groups_topology && [dict exists $native_chain_groups $native_chain]} {
            return [dict get $native_chain_groups $native_chain]
        }
        # Typed scalar aliases remain supported; the calculator rejects ambiguity.
        return $native_chain
    }

    proc help_tip {widget message} {
        variable tooltip_text
        dict set tooltip_text $widget $message
        bind $widget <Enter> +[list ::RMSXFlipbookTimeline::Dashboard::schedule_tooltip $widget]
        bind $widget <FocusIn> +[list ::RMSXFlipbookTimeline::Dashboard::schedule_tooltip $widget]
        bind $widget <Leave> +::RMSXFlipbookTimeline::Dashboard::hide_tooltip
        bind $widget <FocusOut> +::RMSXFlipbookTimeline::Dashboard::hide_tooltip
        bind $widget <Escape> +::RMSXFlipbookTimeline::Dashboard::hide_tooltip
    }

    proc schedule_tooltip {widget} {
        variable tooltip_after
        hide_tooltip
        set tooltip_after [after 500 [list ::RMSXFlipbookTimeline::Dashboard::show_tooltip $widget]]
    }

    proc show_tooltip {widget} {
        variable top
        variable tooltip_text
        variable tooltip_after
        set tooltip_after ""
        if {![winfo exists $widget] || ![dict exists $tooltip_text $widget]} { return }
        set tip $top.tooltip
        catch {destroy $tip}
        toplevel $tip
        wm overrideredirect $tip 1
        ttk::label $tip.text -text [dict get $tooltip_text $widget] -wraplength 330 -padding 7 -relief solid -borderwidth 1
        pack $tip.text
        update idletasks
        set x [expr {min([winfo rootx $widget], [winfo screenwidth $widget]-[winfo reqwidth $tip]-10)}]
        set y [expr {min([winfo rooty $widget]+[winfo height $widget]+4, [winfo screenheight $widget]-[winfo reqheight $tip]-10)}]
        wm geometry $tip +$x+$y
    }

    proc hide_tooltip {} {
        variable top
        variable tooltip_after
        if {$tooltip_after ne ""} { after cancel $tooltip_after; set tooltip_after "" }
        if {[info commands winfo] ne ""} { catch {destroy $top.tooltip} }
    }

    proc build_scrollable_content {parent} {
        grid columnconfigure $parent 0 -weight 1
        grid rowconfigure $parent 0 -weight 1
        canvas $parent.scroll_canvas -highlightthickness 0 -borderwidth 0 -background [ttk::style lookup TFrame -background] -yscrollcommand [list $parent.scrollbar set]
        ttk::scrollbar $parent.scrollbar -command [list $parent.scroll_canvas yview]
        ttk::frame $parent.content
        set item [$parent.scroll_canvas create window 0 0 -anchor nw -window $parent.content]
        grid $parent.scroll_canvas -row 0 -column 0 -sticky nsew
        grid $parent.scrollbar -row 0 -column 1 -sticky ns
        bind $parent.content <Configure> [list ::RMSXFlipbookTimeline::Dashboard::sync_scrollable_content $parent.scroll_canvas $item]
        bind $parent.scroll_canvas <Configure> [list ::RMSXFlipbookTimeline::Dashboard::sync_scrollable_content $parent.scroll_canvas $item]
        set root [winfo toplevel $parent]
        bind $root <MouseWheel> ::RMSXFlipbookTimeline::Dashboard::scroll_active_wheel\ %D
        bind $root <Button-4> {::RMSXFlipbookTimeline::Dashboard::scroll_active_wheel 120}
        bind $root <Button-5> {::RMSXFlipbookTimeline::Dashboard::scroll_active_wheel -120}
        bind $root <Prior> {::RMSXFlipbookTimeline::Dashboard::scroll_active_page -1}
        bind $root <Next> {::RMSXFlipbookTimeline::Dashboard::scroll_active_page 1}
        return $parent.content
    }

    proc scroll_active_wheel {delta} {
        variable top
        if {![winfo exists $top.tabs]} { return }
        set parent [$top.tabs select]
        scroll_canvas_by_wheel $parent.scroll_canvas $delta
    }

    proc scroll_active_page {direction} {
        variable top
        if {![winfo exists $top.tabs]} { return }
        set parent [$top.tabs select]
        $parent.scroll_canvas yview scroll $direction pages
    }

    proc save_figure {} {
        variable top
        if {[::RMSXFlipbookTimeline::Operation::running]} { return }
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current eq {}} { set_status "Load or run a result first."; return }
        set path [tk_getSaveFile -parent $top -title "Export figure" -defaultextension .svg -filetypes {{SVG .svg} {PNG .png}}]
        if {$path eq ""} { return }
        if {[catch {::RMSXFlipbookTimeline::write_flipbook_figure $path} result]} { set_status "Figure export failed: $result"; return }
        set_status "Figure exported: $path"
        return $result
    }
}

namespace eval ::RMSXFlipbookTimeline::Dashboard {
    proc select_embedded_native {canvas record} {
        variable embedded_heatmap_status_var
        set result [::RMSXFlipbookTimeline::PlotWindow::select_on_canvas $canvas $record]
        if {[dict exists $result message]} { set embedded_heatmap_status_var [dict get $result message] }
        return $result
    }
    proc select_embedded_timeline {canvas dataset record} {
        variable embedded_heatmap_status_var
        set result [::RMSXFlipbookTimeline::TimelinePlot::select_on_canvas $canvas $dataset $record]
        if {[dict exists $result message]} { set embedded_heatmap_status_var [dict get $result message] }
        return $result
    }
}

namespace eval ::RMSXFlipbookTimeline::Dashboard {
    proc reset_panel_grid {panel} {
        foreach widget [grid slaves $panel] { grid forget $widget }
        for {set col 0} {$col < 20} {incr col} { grid columnconfigure $panel $col -weight 0 }
        grid columnconfigure $panel 1 -weight 1
    }
    proc compact_option_panels {parent} {
        set panel $parent.native
        reset_panel_grid $panel
        grid $panel.type_label -row 0 -column 0 -sticky w -padx {0 8}
        grid $panel.type_combo -row 0 -column 1 -sticky ew
        grid $panel.mask_label -row 1 -column 0 -sticky w -padx {0 8} -pady 3
        grid $panel.mask_entry -row 1 -column 1 -sticky ew
        grid $panel.thinner -row 2 -column 0 -sticky w
        grid $panel.thicker -row 2 -column 1 -sticky w
        set panel $parent.timeline
        reset_panel_grid $panel
        ttk::label $panel.frames_label -text Frames
        ttk::entry $panel.first -width 6 -textvariable ::RMSXFlipbookTimeline::Dashboard::native_start
        ttk::label $panel.to -text –
        ttk::entry $panel.last -width 6 -textvariable ::RMSXFlipbookTimeline::Dashboard::end_display
        foreach {col widget} {0 frames_label 1 first 2 to 3 last} { grid $panel.$widget -row 0 -column $col -sticky w -padx {0 8} }
        bind $panel.last <FocusOut> ::RMSXFlipbookTimeline::Dashboard::sync_end_display
        help_tip $panel.last "Last uses the final source frame. The range is shared with the slice setup."
        $parent.structure.note configure -wraplength 490
        set panel $parent.contacts
        reset_panel_grid $panel
        foreach {row base label} {0 native_ref Reference 1 native_dist "Cutoff (Å)" 2 native_from From 3 native_to To 4 inter_method Method 5 inter_dist "Cutoff (Å)" 6 inter_from From 7 inter_to To 8 inter_list Selections} {
            $panel.${base}_label configure -text $label
            set entry $panel.${base}_entry
            if {$base eq "inter_method"} { set entry $panel.inter_method_combo }
            grid $panel.${base}_label -row $row -column 0 -sticky w -padx {0 8} -pady 2
            grid $entry -row $row -column 1 -sticky ew -pady 2
        }
        set panel $parent.advanced
        reset_panel_grid $panel
        $panel.scale_label configure -text "Scale range"
        $panel.threshold_label configure -text "Threshold"
        $panel.classic configure -text "Classic…"
        foreach {row label first last} {0 scale_label scale_min scale_max 1 threshold_label threshold_min threshold_max} {
            grid $panel.$label -row $row -column 0 -sticky w -padx {0 8} -pady 2
            grid $panel.$first -row $row -column 1 -sticky ew -padx {0 8}
            grid $panel.$last -row $row -column 2 -sticky ew
        }
        grid $panel.classic -row 2 -column 0 -sticky w -pady {4 0}
        set panel $parent.cross
        reset_panel_grid $panel
        foreach {row label entry} {0 map_label map_entry 1 vol_label vol_entry 2 res_label res_entry 3 method_label method_combo 4 selections_label selections_entry} {
            grid $panel.$label -row $row -column 0 -sticky w -padx {0 8} -pady 2
            grid $panel.$entry -row $row -column 1 -sticky ew
        }
        grid $panel.map_browse -row 0 -column 2 -padx {8 0}
    }
}

namespace eval ::RMSXFlipbookTimeline::Dashboard {
    proc native_setup_ready {} {
        variable native_topology
        variable native_trajectory
        variable native_output
        variable native_start
        variable native_end
        variable native_slicing_mode
        variable native_slices
        variable native_slice_size
        if {![file isfile $native_topology] || ![file isfile $native_trajectory] || ![file isdirectory $native_output]} { return 0 }
        if {![string is integer -strict $native_start] || $native_start < 0} { return 0 }
        if {![string is integer -strict $native_end] || $native_end < -1 || ($native_end != -1 && $native_end < $native_start)} { return 0 }
        set count [expr {$native_slicing_mode eq "slice_size" ? $native_slice_size : $native_slices}]
        if {![string is integer -strict $count] || $count < 1} { return 0 }
        if {[catch {effective_time_step_ps_for_run}]} { return 0 }
        return 1
    }
}

namespace eval ::RMSXFlipbookTimeline::Dashboard {
    proc discard_pending_native_view {} {
        variable pending_native_view
        if {$pending_native_view ne {} && [dict exists $pending_native_view canvas] && [dict get $pending_native_view canvas] ne ""} {
            catch {destroy [dict get $pending_native_view canvas]}
        }
        set pending_native_view {}
    }
    proc stage_native_view {metadata candidate} {
        variable pending_native_view
        variable embedded_heatmap_canvas
        variable native_view_serial
        discard_pending_native_view
        set folder [dict get $candidate result folder]
        set csv ""
        if {[dict exists $candidate dataset provenance csv]} {set csv [dict get $candidate dataset provenance csv]}
        set prepared [::RMSXFlipbookTimeline::PlotWindow::prepare {*}[embedded_native_plot_args $folder $csv [embedded_heatmap_width] $metadata]]
        set stage ""
        if {$embedded_heatmap_canvas ne "" && [info commands winfo] ne "" && [winfo exists $embedded_heatmap_canvas]} {
            set stage "[winfo parent $embedded_heatmap_canvas].candidate[incr native_view_serial]"
            canvas $stage -background white -width [winfo width $embedded_heatmap_canvas] -height [dict get $prepared layout canvas_height] -scrollregion [list 0 0 [dict get $prepared layout canvas_width] [dict get $prepared layout canvas_height]]
            set snapshot [::RMSXFlipbookTimeline::ViewState::capture ::RMSXFlipbookTimeline::PlotWindow]
            try {
                ::RMSXFlipbookTimeline::PlotWindow::draw_prepared $stage $prepared
            } on error {message options} {
                destroy $stage
                return -options $options $message
            } finally {::RMSXFlipbookTimeline::ViewState::restore $snapshot}
        }
        set pending_native_view [dict create prepared $prepared canvas $stage]
        return $pending_native_view
    }
    proc activate_native_view {} {
        variable pending_native_view
        variable embedded_heatmap_canvas
        variable embedded_heatmap_mode
        variable embedded_heatmap_status_var
        variable embedded_heatmap_last_width
        if {$pending_native_view eq {}} {return}
        set prepared [dict get $pending_native_view prepared]
        set stage [dict get $pending_native_view canvas]
        if {$stage ne ""} {
            set old $embedded_heatmap_canvas
            set embedded_heatmap_canvas $stage
            set ::RMSXFlipbookTimeline::PlotWindow::canvas $stage
            ::RMSXFlipbookTimeline::PlotWindow::install_record_map [dict get $prepared layout records]
            grid $stage -row 2 -column 0 -columnspan 2 -sticky nsew
            bind $stage <Configure> {::RMSXFlipbookTimeline::Dashboard::schedule_embedded_heatmap_resize_redraw %w}
            ::RMSXFlipbookTimeline::Navigation::attach $stage [dict get $prepared layout records] [list ::RMSXFlipbookTimeline::Dashboard::select_embedded_native $stage] [list ::RMSXFlipbookTimeline::PlotWindow::clear_on_canvas $stage]
            ::RMSXFlipbookTimeline::PlotWindow::context_attach $stage $prepared
            $stage bind pickable <Motion> {::RMSXFlipbookTimeline::Dashboard::embedded_native_plot_hover_current}
            if {$old ne $stage && [winfo exists $old]} {destroy $old}
            set embedded_heatmap_last_width [winfo width $stage]
            ::RMSXFlipbookTimeline::PlotWindow::install_pick_trace
            mount_heatmap_tools $stage [dict get [::RMSXFlipbookTimeline::Results::get] dataset]
        }
        set embedded_heatmap_mode native
        set embedded_heatmap_status_var "[dict get $prepared metric_label]: [dict get $prepared layout rows] rows × [dict get $prepared layout columns] slices"
        set pending_native_view {}
    }
    proc load_folder_with_view {folder metadata} {
        discard_pending_native_view
        try {
            set result [::RMSXFlipbookTimeline::load_folder $folder palette [::RMSXFlipbookTimeline::state_get palette viridis] activation_callback [list ::RMSXFlipbookTimeline::Dashboard::stage_native_view $metadata]]
            if {[dict exists $metadata dataset]} {
                dict set metadata dataset [::RMSXFlipbookTimeline::TimelineIO::attach_slice_targets [dict get $metadata dataset] $folder]
            }
            if {$metadata ne {}} {::RMSXFlipbookTimeline::Results::update $metadata}
            activate_native_view
            # The dashboard can already be mapped when a preview or retry loads
            # its first result. Acquire the hook after every successful activation.
            ensure_default_mouse_rotation
            request_scene_refresh
            return $result
        } on error {message options} {
            discard_pending_native_view
            return -options $options $message
        }
    }
    proc retry_saved_result {} {
        return [perform_operation retry_saved_result ::RMSXFlipbookTimeline::Dashboard::_retry_saved_result]
    }
    proc _retry_saved_result {} {
        variable saved_result
        if {$saved_result eq {} || ![dict exists $saved_result folder]} {error "No saved result is waiting for display"}
        set result [load_folder_with_view [dict get $saved_result folder] $saved_result]
        set saved_result {}
        refresh_dashboard
        set_status "Saved result displayed."
        return $result
    }
}

# VMD's OpenGL window is not a Tk child, so its resize/expose events do not
# reliably reach this dashboard. A bounded redraw pulse also covers that window.
namespace eval ::RMSXFlipbookTimeline::Dashboard {
    variable scene_refresh_after ""
    variable scene_refresh_generation 0
    variable scene_refresh_guard 0
    variable scene_refresh_count 0
    variable scene_refresh_error ""

    proc stop_scene_refresh {} {
        variable scene_refresh_after
        variable scene_refresh_generation
        incr scene_refresh_generation
        if {$scene_refresh_after ne ""} {catch {after cancel $scene_refresh_after}}
        set scene_refresh_after ""
    }

    proc request_scene_refresh {{window ""}} {
        variable top
        variable scene_refresh_after
        variable scene_refresh_generation
        if {$window ne "" && $window ne $top} {return}
        if {[info commands winfo] eq "" || ![winfo exists $top] || ![winfo ismapped $top]} {return}
        stop_scene_refresh
        ::RMSXFlipbookTimeline::Effects::register dashboard_scene_refresh \
            ::RMSXFlipbookTimeline::Dashboard::stop_scene_refresh window
        set scene_refresh_after [after 120 [list ::RMSXFlipbookTimeline::Dashboard::refresh_scene_tick $scene_refresh_generation]]
    }

    proc refresh_scene_tick {generation} {
        variable top
        variable scene_refresh_after
        variable scene_refresh_generation
        variable scene_refresh_guard
        variable scene_refresh_count
        variable scene_refresh_error
        if {$generation != $scene_refresh_generation} {return}
        set scene_refresh_after ""
        if {[info commands winfo] eq "" || ![winfo exists $top] || ![winfo ismapped $top]} {return}
        # Never redraw a partially loaded or temporarily reframed operation.
        set exporting [expr {[info exists ::RMSXFlipbookTimeline::Render::active] && $::RMSXFlipbookTimeline::Render::active > 0}]
        if {!$scene_refresh_guard && !$exporting && ![::RMSXFlipbookTimeline::Operation::running]} {
            if {[catch {::RMSXFlipbookTimeline::Hotkeys::loaded_molids} ids]} {return}
            incr scene_refresh_guard
            try {
                if {[::RMSXFlipbookTimeline::state_get view_preset] eq "principal" &&
                    [display get size] ne [::RMSXFlipbookTimeline::state_get principal_fit_size {}]} {
                    ::RMSXFlipbookTimeline::PrincipalView::fit $ids
                }
                # VMD can leave a resized OpenGL surface black until the scene
                # is marked dirty. Reapply one owned molecule's exact matrix;
                # this invalidates the scene without a geometric nudge.
                set id [lindex $ids 0]
                set matrix [::RMSXFlipbookTimeline::Style::normalize_matrix [molinfo $id get rotate_matrix]]
                ::RMSXFlipbookTimeline::Style::set_molecule_matrix $id rotate_matrix [dict create rotate_matrix $matrix]
                # Force the paint without changing the update setting, then
                # service native resize/expose events under the reentrancy guard.
                display update
                display update ui
                incr scene_refresh_count
                set scene_refresh_error ""
            } on error {message options} {
                set scene_refresh_error $message
            } finally {incr scene_refresh_guard -1}
        }
        if {$generation == $scene_refresh_generation && [winfo exists $top] && [winfo ismapped $top]} {
            set scene_refresh_after [after 750 [list ::RMSXFlipbookTimeline::Dashboard::refresh_scene_tick $generation]]
        }
    }
}

# One control panel for either embedded plot implementation.
namespace eval ::RMSXFlipbookTimeline::Dashboard {
    proc mount_heatmap_tools {canvas dataset} {
        if {$dataset eq {} || ![winfo exists $canvas]} {return}
        ::RMSXFlipbookTimeline::HeatmapTools::attach $canvas $dataset
        ::RMSXFlipbookTimeline::HeatmapTools::activate $canvas
        set parent [winfo parent $canvas]
        grid [::RMSXFlipbookTimeline::HeatmapTools::mount $parent $canvas] -row 1 -column 0 -columnspan 3 -sticky ew -pady {2 4}
        if {![winfo exists $parent.xbar]} {
            ttk::scrollbar $parent.xbar -orient horizontal
            ttk::scrollbar $parent.ybar -orient vertical
        }
        $parent.xbar configure -command [list $canvas xview]
        $parent.ybar configure -command [list $canvas yview]
        $canvas configure -xscrollcommand [list $parent.xbar set] -yscrollcommand [list $parent.ybar set]
        grid $parent.xbar -row 3 -column 0 -columnspan 2 -sticky ew
        grid $parent.ybar -row 2 -column 2 -sticky ns
    }
}
