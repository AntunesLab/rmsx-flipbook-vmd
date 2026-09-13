################################################################################
# RMSX Flipbook Timeline VMD Plugin
# Publication-oriented release package.
################################################################################

package require Tcl 8.6

namespace eval ::RMSXFlipbookTimeline {
    set version_file [open [file join [file dirname [info script]] VERSION] r]
    variable version [string trim [read $version_file]]
    close $version_file
    unset version_file
    variable basedir [file dirname [info script]]
    variable build_fingerprint source-checkout
    if {[file isfile [file join $basedir BUILD_ID]]} {
        set build_file [open [file join $basedir BUILD_ID] r]
        try {
            set build_fingerprint [string trim [read $build_file]]
            if {![regexp {^[0-9a-f]{64}$} $build_fingerprint]} {
                error "Invalid RMSX build fingerprint"
            }
        } finally { close $build_file }
        unset build_file
    }
    variable state
    variable project_url "https://github.com/AntunesLab/rmsx-flipbook-vmd"
    variable citation_text "Beruldsen, F., de Freitas, M.V. & Antunes, D.A. High resolution mapping of protein motions in time and space with RMSX and Flipbook. Scientific Reports (2026). https://doi.org/10.1038/s41598-026-39869-7"

    if {![info exists ::env(RMSXFLIPBOOKTIMELINEDIR)] || $::env(RMSXFLIPBOOKTIMELINEDIR) eq ""} {
        set ::env(RMSXFLIPBOOKTIMELINEDIR) $basedir
    }

    proc init_state {} {
        variable state
        variable basedir
        variable version
        array unset state
        array set state {
            source_folder ""
            slice_files {}
            molids {}
            owned_molids {}
            quality Balanced
            palette viridis
            mask_file ""
            apply_mask 1
            mask_opacity 0.30
            mask_material Transparent
            masked_residue_count 0
            raw_min 0.0
            raw_max 0.0
            norm_min 0.0
            norm_max 10.0
            spacing 0.0
            spacing_mode auto
            layout_offsets {}
            initial_view_matrices {}
            rep NewTube
            thick 0.30
            res 32
            aspect 1.00
            spline 0
            user_scale 1.0
            user_offset 2.0
            value_source ""
            value_file ""
            color_method User2
            color_min 0.0
            color_max 10.0
            view_preset principal
            mouse_rotation_enabled 0
            mouse_rotation_intercepted 0
            mouse_rotation_mode coords
            mouse_rotation_sensitivity 2.0
            manifest_path ""
            timeline_neighborhood_enabled 1
            timeline_neighborhood_window 4
            timeline_neighborhood_step 1
            timeline_neighborhood_color_mode matrix
            timeline_neighborhood_spacing_scale 0.55
            native_total_time_ns auto
            native_detected_time_step_ps ""
            native_detected_total_time_ns ""
            native_time_estimate_source ""
            release_mode 1
            experimental_features 0
            quiet_console 0
        }
        set state(basedir) $basedir
        set state(rep) [::RMSXFlipbookTimeline::Style::default_rep]
        set state(res) [::RMSXFlipbookTimeline::Style::default_resolution]
        set state(version) $version
    }

    proc state_set {key value} {
        variable state
        set state($key) $value
    }

    proc state_get {key {default ""}} {
        variable state
        if {[info exists state($key)]} {
            return $state($key)
        }
        return $default
    }

    proc display_record {} {
        set record {}
        foreach key {palette color_method color_min color_max raw_min raw_max norm_min norm_max rep thick user_scale user_offset masked_residue_count mask_opacity spacing layout_offsets principal_axis_orientation} {
            dict set record $key [state_get $key]
        }
        return $record
    }
    proc sync_result_display {} {
        set result [::RMSXFlipbookTimeline::Results::get]
        if {$result ne {} && [dict exists $result molids] && [dict get $result molids] eq [state_get molids]} {
            ::RMSXFlipbookTimeline::Results::update [dict create display_settings [display_record]]
        }
    }

    proc state_replace {record} {
        variable state
        array unset state
        array set state $record
        return $record
    }

    proc state_dict {} {
        variable state
        set out [dict create]
        foreach key [lsort [array names state]] {
            dict set out $key $state($key)
        }
        return $out
    }

    proc package_root {} {
        variable basedir
        return $basedir
    }

    proc build_id {} {
        variable build_fingerprint
        return $build_fingerprint
    }

    proc citation {} {
        variable citation_text
        return $citation_text
    }

    proc help_url {} {
        variable project_url
        return $project_url
    }

    proc about {} {
        variable version
        return [dict create \
            package rmsxflipbooktimeline \
            version $version \
            build_id [build_id] \
            root [package_root] \
            help_url [help_url] \
            citation [citation] \
            experimental_features [experimental_enabled]]
    }

    proc open_help {} {
        set url [help_url]
        if {[info commands vmd_open_url] ne ""} {
            return [vmd_open_url $url]
        }
        if {[info commands exec] eq ""} {
            return $url
        }
        switch -- $::tcl_platform(os) {
            Darwin {
                exec open $url &
            }
            default {
                if {$::tcl_platform(platform) eq "windows"} {
                    set opener [auto_execok start]
                    if {$opener eq ""} {
                        error "No Windows URL opener found; open $url manually."
                    }
                    exec {*}$opener "" $url &
                } else {
                    exec xdg-open $url &
                }
            }
        }
        return $url
    }

    proc parse_kv_options {defaults args} {
        set opts $defaults
        if {[llength $args] % 2 != 0} {
            error "Options must be key/value pairs"
        }
        foreach {key value} $args {
            set clean_key [string trimleft $key "-"]
            dict set opts $clean_key $value
        }
        return $opts
    }

    proc truthy {value} {
        set lowered [string tolower [string trim $value]]
        return [expr {$lowered in {1 true yes y on}}]
    }

    proc experimental_enabled {} {
        global env
        if {[truthy [state_get experimental_features 0]]} {
            return 1
        }
        if {[info exists env(RMSXFLIPBOOKTIMELINE_EXPERIMENTAL)] && [truthy $env(RMSXFLIPBOOKTIMELINE_EXPERIMENTAL)]} {
            return 1
        }
        return 0
    }

    proc experimental_error {feature} {
        error "$feature is an experimental RMSX/Flipbook Timeline feature. Set RMSXFLIPBOOKTIMELINE_EXPERIMENTAL=1 before package load to enable it."
    }

    proc cleanup_side_effects {{delete_molecules 0} {scopes {operation result window input scene}}} {
        variable state
        set errors {}
        if {[info commands ::RMSXFlipbookTimeline::Effects::cleanup_all] ne ""} {
            if {[catch {::RMSXFlipbookTimeline::Effects::cleanup_all $scopes} err]} {
                lappend errors $err
            }
        }
        if {$delete_molecules && [info exists state(molids)] && [info commands molinfo] ne ""} {
            set owned $state(molids)
            if {[info exists state(owned_molids)]} {lappend owned {*}$state(owned_molids)}
            foreach molid [lsort -unique $owned] {
                if {[lsearch -exact [molinfo list] $molid] != -1} {
                    if {[catch {mol delete $molid} err]} {
                        lappend errors "molecule $molid: $err"
                    }
                }
            }
        }
        if {$delete_molecules} {
            if {[catch {::RMSXFlipbookTimeline::Scene::restore} message]} {lappend errors $message}
            if {[info commands ::RMSXFlipbookTimeline::Results::clear] ne ""} {::RMSXFlipbookTimeline::Results::clear}
        }
        if {[llength $errors] > 0} {
            error [join $errors {; }]
        }
        return 1
    }

    proc reset {{delete_molecules 1}} {
        cleanup_side_effects $delete_molecules
        init_state
    }

    source -encoding utf-8 [file join $basedir core effects.tcl]
    source -encoding utf-8 [file join $basedir core residue_identity.tcl]
    source -encoding utf-8 [file join $basedir core output_txn.tcl]
    source -encoding utf-8 [file join $basedir core session.tcl]
    source -encoding utf-8 [file join $basedir visualization navigation.tcl]
    source -encoding utf-8 [file join $basedir core values.tcl]
    source -encoding utf-8 [file join $basedir visualization layout.tcl]
    source -encoding utf-8 [file join $basedir visualization style.tcl]
    source -encoding utf-8 [file join $basedir visualization principal_view.tcl]
    source -encoding utf-8 [file join $basedir visualization mask.tcl]
    source -encoding utf-8 [file join $basedir visualization hotkeys.tcl]
    source -encoding utf-8 [file join $basedir visualization mouse_rotate.tcl]
    source -encoding utf-8 [file join $basedir visualization plot_window.tcl]
    source -encoding utf-8 [file join $basedir visualization render.tcl]
    source -encoding utf-8 [file join $basedir core manifest.tcl]
    source -encoding utf-8 [file join $basedir core loader.tcl]
    source -encoding utf-8 [file join $basedir core native_analysis.tcl]
    source -encoding utf-8 [file join $basedir core matrix.tcl]
    source -encoding utf-8 [file join $basedir core timeline_io.tcl]
    source -encoding utf-8 [file join $basedir core timeline_analysis.tcl]
    source -encoding utf-8 [file join $basedir visualization timeline_plot.tcl]
    source -encoding utf-8 [file join $basedir visualization neighborhood_flipbook.tcl]
    source -encoding utf-8 [file join $basedir visualization threshold_controls.tcl]
    source -encoding utf-8 [file join $basedir visualization heatmap_tools.tcl]
    source -encoding utf-8 [file join $basedir core collections.tcl]
    if {[experimental_enabled]} {
        source -encoding utf-8 [file join $basedir visualization viewer_plot.tcl]
        source -encoding utf-8 [file join $basedir visualization angle_overlay.tcl]
    }

    ::RMSXFlipbookTimeline::Effects::register viewer_plot {
        if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::clear] ne ""} {
            ::RMSXFlipbookTimeline::ViewerPlot::clear
        }
    } window
    ::RMSXFlipbookTimeline::Effects::register plot_window {
        if {[info commands ::RMSXFlipbookTimeline::PlotWindow::clear] ne ""} {
            ::RMSXFlipbookTimeline::PlotWindow::clear
        }
    } window
    ::RMSXFlipbookTimeline::Effects::register timeline_plot {
        if {[info commands ::RMSXFlipbookTimeline::TimelinePlot::clear] ne ""} {
            ::RMSXFlipbookTimeline::TimelinePlot::clear
        }
    } window
    ::RMSXFlipbookTimeline::Effects::register neighborhood_flipbook {
        if {[info commands ::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear] ne ""} {
            ::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear
        }
    }
    ::RMSXFlipbookTimeline::Effects::register angle_overlay {
        if {[info commands ::RMSXFlipbookTimeline::AngleOverlay::clear] ne ""} {
            ::RMSXFlipbookTimeline::AngleOverlay::clear
        }
    }
    ::RMSXFlipbookTimeline::Effects::register mouse_rotation {
        if {[info commands ::RMSXFlipbookTimeline::MouseRotate::uninstall] ne ""} {
            ::RMSXFlipbookTimeline::MouseRotate::uninstall
        }
    } input

    proc load_folder {folder args} {
        return [::RMSXFlipbookTimeline::Loader::load_folder $folder {*}$args]
    }

    proc load_manifest {filename args} {
        return [::RMSXFlipbookTimeline::Manifest::load $filename {*}$args]
    }

    proc apply_settings {args} {
        return [::RMSXFlipbookTimeline::Loader::apply_settings {*}$args]
    }

    proc write_multimodel_pdb {folder args} {
        return [::RMSXFlipbookTimeline::Loader::write_multimodel_pdb $folder {*}$args]
    }

    proc write_flipbook_figure {filename args} {
        return [::RMSXFlipbookTimeline::Render::write_figure $filename {*}$args]
    }

    proc render_flipbook_image {args} {
        return [::RMSXFlipbookTimeline::Render::render_current {*}$args]
    }

    proc apply_view_preset {{preset principal}} {
        return [::RMSXFlipbookTimeline::Style::apply_view_preset $preset]
    }

    proc run_native_analysis {topology trajectory output_dir args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::run $topology $trajectory $output_dir {*}$args]
    }

    proc run_native_all_chain_analysis {topology trajectory output_dir args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::run_all_chains $topology $trajectory $output_dir {*}$args]
    }

    proc run_native_shift_map {topology trajectory output_dir args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::run_shift_map $topology $trajectory $output_dir {*}$args]
    }

    proc run_native_all_chain_shift_map {topology trajectory output_dir args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::run_all_chain_shift_map $topology $trajectory $output_dir {*}$args]
    }

    proc run_native_lddt_map {topology trajectory output_dir args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::run_lddt_map $topology $trajectory $output_dir {*}$args]
    }

    proc run_native_all_chain_lddt_map {topology trajectory output_dir args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::run_all_chain_lddt_map $topology $trajectory $output_dir {*}$args]
    }

    proc repair_folder_bfactors {folder args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::repair_folder_bfactors $folder {*}$args]
    }

    proc write_heatmap_svg {folder args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::write_heatmap_svg $folder {*}$args]
    }

    proc write_report_svg {folder args} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::write_report_svg $folder {*}$args]
    }

    proc show_viewer_plot {args} {
        if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::show] eq ""} {
            experimental_error "3D viewer plot"
        }
        return [::RMSXFlipbookTimeline::ViewerPlot::show {*}$args]
    }

    proc clear_viewer_plot {} {
        if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::clear] eq ""} {
            return 1
        }
        return [::RMSXFlipbookTimeline::ViewerPlot::clear]
    }

    proc show_plot_window {args} {
        return [::RMSXFlipbookTimeline::PlotWindow::show {*}$args]
    }

    proc clear_plot_window {} {
        return [::RMSXFlipbookTimeline::PlotWindow::clear]
    }

    proc select_plot_window_cell {row column} {
        return [::RMSXFlipbookTimeline::PlotWindow::select_cell $row $column]
    }

    proc select_plot_window_slice {slice_index} {
        return [::RMSXFlipbookTimeline::PlotWindow::select_slice $slice_index]
    }

    proc select_plot_window_structure_atom {molid atom_index} {
        return [::RMSXFlipbookTimeline::PlotWindow::select_structure_atom $molid $atom_index]
    }

    proc calculate_timeline {molid metric args} {
        return [::RMSXFlipbookTimeline::TimelineAnalysis::calculate $molid $metric {*}$args]
    }

    proc aggregate_timeline_to_slices {dataset args} {
        return [::RMSXFlipbookTimeline::Matrix::aggregate_to_slices $dataset {*}$args]
    }

    proc build_ramachandran_dataset_from_angles {phi_dataset psi_dataset args} {
        if {[info commands ::RMSXFlipbookTimeline::AngleOverlay::build_dataset_from_phi_psi] eq ""} {
            experimental_error "Phi/psi region overlay"
        }
        return [::RMSXFlipbookTimeline::AngleOverlay::build_dataset_from_phi_psi $phi_dataset $psi_dataset {*}$args]
    }

    proc build_ramachandran_dataset {molid args} {
        if {[info commands ::RMSXFlipbookTimeline::AngleOverlay::build_dataset] eq ""} {
            experimental_error "Phi/psi region overlay"
        }
        return [::RMSXFlipbookTimeline::AngleOverlay::build_dataset $molid {*}$args]
    }

    proc apply_ramachandran_overlay {molid args} {
        if {[info commands ::RMSXFlipbookTimeline::AngleOverlay::apply] eq ""} {
            experimental_error "Phi/psi region overlay"
        }
        return [::RMSXFlipbookTimeline::AngleOverlay::apply $molid {*}$args]
    }

    proc clear_angle_overlay {} {
        if {[info commands ::RMSXFlipbookTimeline::AngleOverlay::clear] eq ""} {
            return 1
        }
        return [::RMSXFlipbookTimeline::AngleOverlay::clear]
    }

    proc publish_matrix_result {dataset {view_options {}}} {
        set current [::RMSXFlipbookTimeline::Results::get]
        set source_folder ""
        if {[dict exists $dataset provenance folder]} {set source_folder [dict get $dataset provenance folder]}
        if {$current ne {} && $source_folder ne "" && [dict exists $current folder] && [dict get $current folder] eq $source_folder} {
            return [::RMSXFlipbookTimeline::Results::update [dict create dataset $dataset view_options $view_options]]
        }
        set result [dict create kind matrix dataset $dataset status complete view_options $view_options \
            label [dict get $dataset title] metric [dict get $dataset value_label] units [dict get $dataset unit] molids {}]
        if {[dict exists $dataset molid]} {dict set result source_molid [dict get $dataset molid]}
        if {[dict exists $dataset provenance]} {dict set result provenance [dict get $dataset provenance]}
        return [::RMSXFlipbookTimeline::Results::publish $result]
    }

    proc show_timeline_dataset {dataset args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::show $dataset {*}$args]
    }

    proc show_live_timeline {molid metric args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::show_live $molid $metric {*}$args]
    }

    proc show_timeline_tml {filename args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::show_tml $filename {*}$args]
    }

    proc show_timeline_rmsx_csv {filename args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::show_rmsx_csv $filename {*}$args]
    }

    proc show_timeline_rmsx_folder {folder args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::show_rmsx_folder $folder {*}$args]
    }

    proc clear_timeline_plot {} {
        return [::RMSXFlipbookTimeline::TimelinePlot::clear]
    }

    proc show_timeline_neighborhood {args} {
        return [::RMSXFlipbookTimeline::NeighborhoodFlipbook::show_current {*}$args]
    }

    proc clear_timeline_neighborhood {} {
        return [::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear]
    }

    proc timeline_neighborhood_status {} {
        return [::RMSXFlipbookTimeline::NeighborhoodFlipbook::status]
    }

    proc select_timeline_cell {row column} {
        return [::RMSXFlipbookTimeline::TimelinePlot::select_cell $row $column]
    }

    proc select_timeline_slice {column} {
        return [::RMSXFlipbookTimeline::TimelinePlot::select_slice $column]
    }

    proc flipbook_view_diagnostics {} {
        return [::RMSXFlipbookTimeline::Style::view_diagnostics]
    }

    proc nudge_flipbook_row {axis amount} {
        return [::RMSXFlipbookTimeline::Style::nudge_row $axis $amount]
    }

    proc filter_timeline_current {min_value max_value frame_start frame_end frames_required args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::filter_current $min_value $max_value $frame_start $frame_end $frames_required {*}$args]
    }

    proc copy_timeline_to_user {{field user2}} {
        return [::RMSXFlipbookTimeline::TimelinePlot::copy_current_to_user $field]
    }

    proc read_timeline_tml {filename args} {
        return [::RMSXFlipbookTimeline::TimelineIO::read_tml $filename {*}$args]
    }

    proc read_timeline_rmsx_csv {filename args} {
        return [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_csv $filename {*}$args]
    }

    proc read_timeline_rmsx_folder {folder args} {
        return [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $folder {*}$args]
    }

    proc write_timeline_tml {dataset filename} {
        return [::RMSXFlipbookTimeline::TimelineIO::write_tml $dataset $filename]
    }

    proc load_timeline_collection {directory args} {
        return [::RMSXFlipbookTimeline::TimelineIO::load_collection $directory {*}$args]
    }

    proc write_timeline_svg {dataset filename args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::write_svg $dataset $filename {*}$args]
    }

    proc write_timeline_png {dataset filename args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::write_png $dataset $filename {*}$args]
    }

    proc write_current_timeline_tml {filename} {
        return [::RMSXFlipbookTimeline::TimelinePlot::write_current_tml $filename]
    }

    proc write_current_timeline_svg {filename args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::write_current_svg $filename {*}$args]
    }

    proc write_current_timeline_png {filename args} {
        return [::RMSXFlipbookTimeline::TimelinePlot::write_current_png $filename {*}$args]
    }

    proc select_viewer_plot_cell {row column} {
        if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::select_cell] eq ""} {
            experimental_error "3D viewer plot"
        }
        return [::RMSXFlipbookTimeline::ViewerPlot::select_cell $row $column]
    }

    proc select_viewer_plot_slice {slice_index} {
        if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::select_slice] eq ""} {
            experimental_error "3D viewer plot"
        }
        return [::RMSXFlipbookTimeline::ViewerPlot::select_slice $slice_index]
    }

    proc select_viewer_plot_atom {atom_index} {
        if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::select_atom] eq ""} {
            experimental_error "3D viewer plot"
        }
        return [::RMSXFlipbookTimeline::ViewerPlot::select_atom $atom_index]
    }

    proc select_viewer_plot_structure_atom {molid atom_index} {
        if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::select_structure_atom] eq ""} {
            experimental_error "3D viewer plot"
        }
        return [::RMSXFlipbookTimeline::ViewerPlot::select_structure_atom $molid $atom_index]
    }

    proc install_hotkeys {} {
        return [::RMSXFlipbookTimeline::Hotkeys::install]
    }

    proc install_mouse_rotation {{mode coords} {sensitivity ""}} {
        return [::RMSXFlipbookTimeline::MouseRotate::install $mode $sensitivity]
    }

    proc uninstall_mouse_rotation {} {
        return [::RMSXFlipbookTimeline::MouseRotate::uninstall]
    }

    proc mouse_rotation_status {} {
        return [::RMSXFlipbookTimeline::MouseRotate::status]
    }

    proc mouse_rotation_format_status {{status_dict ""}} {
        return [::RMSXFlipbookTimeline::MouseRotate::format_status $status_dict]
    }

    proc mouse_rotation_reset_stats {} {
        return [::RMSXFlipbookTimeline::MouseRotate::reset_stats]
    }

    proc mouse_rotation_set_sensitivity {value} {
        return [::RMSXFlipbookTimeline::MouseRotate::set_sensitivity $value]
    }

    proc mouse_rotation_burst {{count 240} {axis y} {angle 0.75}} {
        return [::RMSXFlipbookTimeline::MouseRotate::burst $count $axis $angle]
    }

    proc rotate_flipbook {axis angle} {
        return [::RMSXFlipbookTimeline::Hotkeys::rotate_all $axis $angle]
    }

    proc adjust_spacing {delta} {
        return [::RMSXFlipbookTimeline::Hotkeys::adjust_spacing $delta]
    }

    proc adjust_thickness {delta} {
        return [::RMSXFlipbookTimeline::Hotkeys::adjust_thickness $delta]
    }

    proc adjust_color_min {delta} {
        return [::RMSXFlipbookTimeline::Hotkeys::adjust_color_min $delta]
    }

    proc adjust_color_max {delta} {
        return [::RMSXFlipbookTimeline::Hotkeys::adjust_color_max $delta]
    }

    proc toggle_color_method {} {
        return [::RMSXFlipbookTimeline::Hotkeys::toggle_color_method]
    }

    proc adjust_user_scale {factor} {
        return [::RMSXFlipbookTimeline::Hotkeys::adjust_user_scale $factor]
    }

    proc adjust_user_offset {delta} {
        return [::RMSXFlipbookTimeline::Hotkeys::adjust_user_offset $delta]
    }

    proc reset_view {} {
        return [::RMSXFlipbookTimeline::Style::reset_view]
    }

    proc show_classic {} {
        if {[catch {package require Tk} err]} {
            error "RMSX Flipbook Timeline GUI requires Tk: $err"
        }

        set gui_file [file join [state_get basedir [file dirname [info script]]] gui main_window.tcl]
        if {[file exists $gui_file]} {
            source -encoding utf-8 $gui_file
        }

        if {[info commands ::RMSXFlipbookTimeline::GUI::show] eq ""} {
            error "RMSX Flipbook Timeline GUI is not implemented yet; backend is available via ::RMSXFlipbookTimeline::load_folder"
        }
        return [::RMSXFlipbookTimeline::GUI::show]
    }

    proc show {} {
        return [show_dashboard]
    }

    proc show_dashboard {} {
        if {[catch {package require Tk} err]} {
            error "RMSX Flipbook Timeline Dashboard requires Tk: $err"
        }

        set dashboard_file [file join [state_get basedir [file dirname [info script]]] gui dashboard_window.tcl]
        if {[info commands ::RMSXFlipbookTimeline::Dashboard::show] eq "" && [file exists $dashboard_file]} {
            source -encoding utf-8 $dashboard_file
        }

        if {[info commands ::RMSXFlipbookTimeline::Dashboard::show] eq ""} {
            error "RMSX Flipbook Timeline Dashboard is not implemented yet"
        }
        if {[info commands ::RMSXFlipbookTimeline::Reviewer::mount] eq ""} {
            source -encoding utf-8 [file join [package_root] gui reviewer.tcl]
        }
        return [::RMSXFlipbookTimeline::Dashboard::show]
    }

    init_state
}

proc rmsxflipbooktimeline {} {
    return [::RMSXFlipbookTimeline::show_dashboard]
}

proc rmsxflipbooktimeline_dashboard {} {
    return [::RMSXFlipbookTimeline::show_dashboard]
}

proc rmsxflipbooktimeline_classic {} {
    return [::RMSXFlipbookTimeline::show_classic]
}

proc rmsxflipbooktimeline_about {} {
    return [::RMSXFlipbookTimeline::about]
}

proc rmsxflipbooktimeline_citation {} {
    return [::RMSXFlipbookTimeline::citation]
}

::RMSXFlipbookTimeline::state_set rep [::RMSXFlipbookTimeline::Style::default_rep]
package provide rmsxflipbooktimeline $::RMSXFlipbookTimeline::version
