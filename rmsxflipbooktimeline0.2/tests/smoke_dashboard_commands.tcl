################################################################################
# RMSX Flipbook Timeline dashboard command smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline dashboard command smoke failed: $message"
    exit 1
}

proc assert_equal {actual expected message} {
    if {$actual ne $expected} {
        smoke_fail "$message: expected '$expected', got '$actual'"
    }
}

proc option_value {args key} {
    set index [lsearch -exact $args $key]
    if {$index < 0 || [llength $args] <= [expr {$index + 1}]} {
        return ""
    }
    return [lindex $args [expr {$index + 1}]]
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
    set workspace_root [file dirname $plugin_parent]
} else {
    set workspace_root [pwd]
    set plugin_parent [file normalize [file join $workspace_root workspace_plugins]]
    set plugin_dir [file join $plugin_parent rmsxflipbooktimeline0.2]
}

set ::env(RMSXFLIPBOOKTIMELINE_EXPERIMENTAL) 1
lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

if {[info commands rmsxflipbooktimeline_dashboard] eq ""} {
    smoke_fail "dashboard callback command missing"
}
if {[info commands ::RMSXFlipbookTimeline::GUI::show] ne ""} {
    smoke_fail "classic GUI should not be sourced by package require alone"
}

if {[catch {source [file join $plugin_dir gui dashboard_window.tcl]} err]} {
    smoke_fail "dashboard source failed: $err"
}

if {[info commands ::RMSXFlipbookTimeline::Dashboard::show] eq ""} {
    smoke_fail "dashboard show command missing"
}

::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "" "output display marker should be blank before any flipbook is displayed"
set ::RMSXFlipbookTimeline::Dashboard::native_output [file join /tmp rmsx-dashboard-out]
set ::RMSXFlipbookTimeline::Dashboard::displayed_flipbook_path [file join /tmp rmsx-dashboard-out combined]
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "\u2713" "combined output folder should count as displayed"
set ::RMSXFlipbookTimeline::Dashboard::displayed_flipbook_path [file join /tmp rmsx-dashboard-other combined]
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "!" "different displayed folder should show stale-output marker"
set ::RMSXFlipbookTimeline::Dashboard::native_output ""
set ::RMSXFlipbookTimeline::Dashboard::displayed_flipbook_path ""
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator

assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_route RMSX] native "RMSX route"
assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_route secondary_structure] timeline "secondary_structure route"
assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_panel cross_correlation] cross_correlation "cross-correlation panel"
assert_equal [::RMSXFlipbookTimeline::Dashboard::metric_panel residue_function] residue_function "residue-function panel"
if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::metric_values_for_group Primary] RMSX] < 0} {
    smoke_fail "Primary metric group should include RMSX"
}
if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::metric_values_for_group Contacts] cross_correlation] < 0} {
    smoke_fail "Contacts metric group should include cross_correlation"
}
foreach metric {RMSX displacement secondary_structure cross_correlation residue_function} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::current_metric_values] $metric] < 0} {
        smoke_fail "dashboard metric metadata values should include $metric"
    }
}
foreach metric {RMSX Shift-Map lDDT} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::native_metric_values] $metric] < 0} {
        smoke_fail "native metric values should include $metric"
    }
}
foreach metric {displacement secondary_structure native_contacts cross_correlation residue_function} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::timeline_metric_values] $metric] < 0} {
        smoke_fail "Timeline metric values should include $metric"
    }
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::native_metric_values] $metric] >= 0} {
        smoke_fail "native metric values should not include Timeline-only metric $metric"
    }
}
assert_equal $::RMSXFlipbookTimeline::Dashboard::native_time_step 0.049 "dashboard default frame step"
assert_equal $::RMSXFlipbookTimeline::Dashboard::native_total_time_ns auto "dashboard total-time override should default to auto"
foreach palette {viridis magma inferno plasma cividis rocket mako turbo BWR RWB RGB} {
    if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::palette_values] $palette] < 0} {
        smoke_fail "palette values should include $palette"
    }
}
set ::RMSXFlipbookTimeline::Dashboard::palette turbo
::RMSXFlipbookTimeline::Dashboard::persist_common_state
assert_equal $::RMSXFlipbookTimeline::Dashboard::palette turbo "dashboard palette variable should update"
assert_equal [::RMSXFlipbookTimeline::state_get palette ""] turbo "dashboard palette should persist to plugin state"

set metadata_dir [file normalize [file join /tmp rmsxflipbooktimeline-dashboard-metadata-[pid]]]
file mkdir $metadata_dir
set metadata_traj [file join $metadata_dir sample.dcd]
set fp [open $metadata_traj w]
puts $fp "placeholder"
close $fp
set fp [open [file join $metadata_dir sample.log] w]
puts $fp "timestep 2 fs"
puts $fp "DCDfreq 500"
close $fp
set timing [::RMSXFlipbookTimeline::Dashboard::metadata_time_estimate $metadata_traj 101]
assert_equal [format "%.3f" [dict get $timing step_ps]] 1.000 "metadata timestep/frequency should estimate per-frame ps"
file delete -force $metadata_dir

set ::RMSXFlipbookTimeline::Dashboard::native_total_frames 317
set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end -1
set ::RMSXFlipbookTimeline::Dashboard::native_total_time_ns auto
set ::RMSXFlipbookTimeline::Dashboard::native_detected_time_step_ps 0.04888821
set ::RMSXFlipbookTimeline::Dashboard::native_time_step 0.049
assert_equal [format "%.8f" [::RMSXFlipbookTimeline::Dashboard::effective_time_step_ps_for_run]] 0.04888821 "rounded displayed step should preserve exact detected step for analysis"

set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end -1
set ::RMSXFlipbookTimeline::Dashboard::native_total_frames 1003
set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slices
set ::RMSXFlipbookTimeline::Dashboard::native_slices 8
set plan [::RMSXFlipbookTimeline::Dashboard::slicing_plan]
assert_equal [dict get $plan known] 1 "slice preview known for explicit total"
assert_equal [dict get $plan slices] 8 "slice-count mode slices"
assert_equal [dict get $plan slice_size] 125 "slice-count mode frames per slice"
assert_equal [dict get $plan leftover] 3 "slice-count mode leftover"

set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slice_size
set ::RMSXFlipbookTimeline::Dashboard::native_slice_size 120
set plan [::RMSXFlipbookTimeline::Dashboard::slicing_plan]
assert_equal [dict get $plan slices] 8 "slice-size mode slices"
assert_equal [dict get $plan used] 960 "slice-size mode used frames"
assert_equal [dict get $plan leftover] 43 "slice-size mode leftover"

set ::rmsxflipbooktimeline_dashboard_calls {}

foreach command {
    run_native_analysis
    run_native_all_chain_analysis
    run_native_shift_map
    run_native_all_chain_shift_map
    run_native_lddt_map
    run_native_all_chain_lddt_map
    load_folder
    show_live_timeline
    show_timeline_rmsx_folder
    show_timeline_tml
    load_timeline_collection
    show_timeline_dataset
    filter_timeline_current
    copy_timeline_to_user
    write_current_timeline_tml
    write_current_timeline_svg
    write_current_timeline_png
    render_flipbook_image
    repair_folder_bfactors
    write_heatmap_svg
    write_report_svg
    write_multimodel_pdb
    show_plot_window
    install_hotkeys
} {
    rename ::RMSXFlipbookTimeline::$command ::RMSXFlipbookTimeline::${command}_real
}

proc ::RMSXFlipbookTimeline::run_native_analysis {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc native_single topology $topology trajectory $trajectory output_dir $output_dir args $args]
    return [dict create output_dir $output_dir csv [file join $output_dir rmsx_vmd_native.csv] slice_count 3 total_frame_count 1003]
}

proc ::RMSXFlipbookTimeline::run_native_all_chain_analysis {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc native_all output_dir $output_dir args $args]
    return [dict create output_dir [file join $output_dir combined] csv_paths {} chains {A B} combined_slice_count 3]
}

proc ::RMSXFlipbookTimeline::run_native_shift_map {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc shift_single output_dir $output_dir args $args]
    return [dict create output_dir $output_dir csv [file join $output_dir shift_map.csv] slice_count 3]
}

proc ::RMSXFlipbookTimeline::run_native_all_chain_shift_map {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc shift_all output_dir $output_dir args $args]
    return [dict create output_dir [file join $output_dir combined] csv_paths {} chains {A B} combined_slice_count 3]
}

proc ::RMSXFlipbookTimeline::run_native_lddt_map {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc lddt_single output_dir $output_dir args $args]
    return [dict create output_dir $output_dir csv [file join $output_dir lddt_map.csv] slice_count 3]
}

proc ::RMSXFlipbookTimeline::run_native_all_chain_lddt_map {topology trajectory output_dir args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc lddt_all output_dir $output_dir args $args]
    return [dict create output_dir [file join $output_dir combined] csv_paths {} chains {A B} combined_slice_count 3]
}

proc ::RMSXFlipbookTimeline::load_folder {folder args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc load_folder folder $folder args $args]
    ::RMSXFlipbookTimeline::state_set source_folder $folder
    ::RMSXFlipbookTimeline::state_set molids {11 12 13}
    return [dict create files 3 molecules 3 raw_min 0.0 raw_max 1.0 spacing 1.0 spacing_mode auto]
}

proc ::RMSXFlipbookTimeline::show_live_timeline {molid metric args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc live molid $molid metric $metric args $args]
    return [dict create rows 2 columns 2 min 0 max 1 drawn 0]
}

proc ::RMSXFlipbookTimeline::show_timeline_rmsx_folder {folder args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc rmsx_matrix folder $folder args $args]
    return [dict create rows 2 columns 2 min 0 max 1 drawn 0]
}

proc ::RMSXFlipbookTimeline::show_timeline_tml {filename args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc tml filename $filename args $args]
    return [dict create rows 2 columns 2 min 0 max 1 drawn 0]
}

proc ::RMSXFlipbookTimeline::load_timeline_collection {directory args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc collection directory $directory args $args]
    return [list [dict create title one row_count 0 column_count 0 rows {} columns {} values {} min 0 max 1]]
}

proc ::RMSXFlipbookTimeline::show_timeline_dataset {dataset args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc dataset title [dict get $dataset title] args $args]
    return [dict create rows 0 columns 0 min 0 max 1 drawn 0]
}

proc ::RMSXFlipbookTimeline::filter_timeline_current {min_value max_value first last frames args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc filter min $min_value max $max_value first $first last $last frames $frames args $args]
    return [dict create rows 1 columns 2 min $min_value max $max_value drawn 0]
}

proc ::RMSXFlipbookTimeline::copy_timeline_to_user {field} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc copy field $field]
    return [dict create field $field rows 2 columns 2]
}

proc ::RMSXFlipbookTimeline::write_current_timeline_tml {filename} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc export_tml filename $filename]
    return $filename
}

proc ::RMSXFlipbookTimeline::write_current_timeline_svg {filename args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc export_svg filename $filename args $args]
    return $filename
}

proc ::RMSXFlipbookTimeline::write_current_timeline_png {filename args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc export_png filename $filename args $args]
    return $filename
}

proc ::RMSXFlipbookTimeline::render_flipbook_image {args} {
    set filename [option_value $args -output_name]
    if {$filename eq ""} {
        set filename [file normalize [file join /tmp rmsxflipbooktimeline-dashboard-render.png]]
    }
    set ext [string tolower [file extension $filename]]
    set format [expr {$ext eq ".png" ? "png" : ($ext in {.jpg .jpeg} ? "jpeg" : "tga")}]
    set transparent [expr {[option_value $args -transparent_background] in {1 true yes on} && $format eq "png"}]
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc render_image filename $filename args $args]
    return [dict create image $filename method TachyonInternal format $format bytes 1234 transparent_background $transparent]
}

proc ::RMSXFlipbookTimeline::repair_folder_bfactors {folder args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc repair folder $folder args $args]
    return [dict create csv [file join $folder rmsx_vmd_native.csv] updated_count 2]
}

proc ::RMSXFlipbookTimeline::write_heatmap_svg {folder args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc heatmap_svg folder $folder args $args]
    return [dict create svg [file join $folder rmsx_heatmap.svg] csv [file join $folder rmsx_vmd_native.csv]]
}

proc ::RMSXFlipbookTimeline::write_report_svg {folder args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc report_svg folder $folder args $args]
    return [dict create svg [file join $folder rmsx_report.svg] csv [file join $folder rmsx_vmd_native.csv]]
}

proc ::RMSXFlipbookTimeline::write_multimodel_pdb {folder args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc multimodel folder $folder args $args]
    return [dict create pdb [file join $folder rmsx_flipbook_multimodel.pdb] models 3]
}

proc ::RMSXFlipbookTimeline::show_plot_window {args} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc plot_window args $args]
    return [dict create rows 2 columns 2 cells 4 summary_points 2]
}

proc ::RMSXFlipbookTimeline::install_hotkeys {} {
    lappend ::rmsxflipbooktimeline_dashboard_calls [dict create proc hotkeys]
    return [dict create installed 1]
}

if {[info commands molinfo] eq ""} {
    proc molinfo {args} {
        set op [lindex $args 0]
        if {$op eq "top"} {
            return 0
        }
        if {$op eq "list"} {
            return {0}
        }
        return 0
    }
}

rename molinfo molinfo_dashboard_basic
array set ::dashboard_fake_frames {0 1}
set ::dashboard_fake_top 0
set ::dashboard_fake_next 41

proc mol {op args} {
    global dashboard_fake_frames dashboard_fake_top dashboard_fake_next
    switch -- $op {
        new {
            set molid $dashboard_fake_next
            incr dashboard_fake_next
            set dashboard_fake_top $molid
            set dashboard_fake_frames($molid) 1
            return $molid
        }
        addfile {
            set molid $dashboard_fake_top
            set index [lsearch -exact $args molid]
            if {$index >= 0 && [llength $args] > [expr {$index + 1}]} {
                set molid [lindex $args [expr {$index + 1}]]
            }
            set dashboard_fake_frames($molid) 317
            return $molid
        }
        delete {
            set molid [lindex $args 0]
            catch {unset dashboard_fake_frames($molid)}
            if {$dashboard_fake_top eq $molid} {
                set dashboard_fake_top 0
            }
            return ""
        }
        top {
            set dashboard_fake_top [lindex $args 0]
            return $dashboard_fake_top
        }
        default {
            return ""
        }
    }
}

proc molinfo {args} {
    global dashboard_fake_frames dashboard_fake_top
    set target [lindex $args 0]
    if {$target eq "top"} {
        if {[llength $args] == 1} {
            return $dashboard_fake_top
        }
        if {[lindex $args 1] eq "get" && [lindex $args 2] eq "id"} {
            return $dashboard_fake_top
        }
        return $dashboard_fake_top
    }
    if {$target eq "list"} {
        return [lsort -integer [array names dashboard_fake_frames]]
    }
    if {[llength $args] >= 3 && [lindex $args 1] eq "get"} {
        set field [lindex $args 2]
        if {$field eq "numframes"} {
            if {[info exists dashboard_fake_frames($target)]} {
                return $dashboard_fake_frames($target)
            }
            return 0
        }
        if {$field eq "id"} {
            return $target
        }
    }
    return 0
}

set ::RMSXFlipbookTimeline::Dashboard::native_total_frames auto
set ::RMSXFlipbookTimeline::Dashboard::native_detected_total_frames ""
set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end -1
set plan [::RMSXFlipbookTimeline::Dashboard::slicing_plan]
assert_equal [dict get $plan known] 0 "auto frame count should ignore one-frame or empty top molecule"

set ::RMSXFlipbookTimeline::Dashboard::native_detected_total_frames 1003
set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slices
set ::RMSXFlipbookTimeline::Dashboard::native_slices 8
set plan [::RMSXFlipbookTimeline::Dashboard::slicing_plan]
assert_equal [dict get $plan known] 1 "auto frame count should use detected trajectory frames"
assert_equal [dict get $plan slices] 8 "detected frame count slices"
assert_equal [dict get $plan leftover] 3 "detected frame count leftover"

set topology [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files 1UBQ.pdb]
set trajectory [file join $workspace_root downloads rmsx AntunesLab-rmsx test_files mon_sys.dcd]
set output_dir [file normalize [file join /tmp rmsxflipbooktimeline-dashboard-native-[pid]]]
file mkdir $output_dir

set ::RMSXFlipbookTimeline::Dashboard::native_topology $topology
set ::RMSXFlipbookTimeline::Dashboard::native_trajectory $trajectory
set ::RMSXFlipbookTimeline::Dashboard::native_output $output_dir
set ::RMSXFlipbookTimeline::Dashboard::native_chain 7
set ::RMSXFlipbookTimeline::Dashboard::native_slices 9
set ::RMSXFlipbookTimeline::Dashboard::native_slice_size 105
set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slice_size
set ::RMSXFlipbookTimeline::Dashboard::native_total_frames 101
set ::RMSXFlipbookTimeline::Dashboard::native_total_time_ns 1.0
set ::RMSXFlipbookTimeline::Dashboard::native_detected_total_frames ""
set ::RMSXFlipbookTimeline::Dashboard::native_start 0
set ::RMSXFlipbookTimeline::Dashboard::native_end -1
set ::RMSXFlipbookTimeline::Dashboard::native_log_transform 1
set ::RMSXFlipbookTimeline::Dashboard::timeline_metric RMSX
set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::run_analysis
set call [lindex $::rmsxflipbooktimeline_dashboard_calls $before]
assert_equal [dict get $call proc] native_single "RMSX dashboard dispatch"
assert_equal $::RMSXFlipbookTimeline::Dashboard::displayed_flipbook_path $output_dir "native run should remember displayed flipbook folder"
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "\u2713" "matching output field should show displayed marker"
set original_output_dir $::RMSXFlipbookTimeline::Dashboard::native_output
set ::RMSXFlipbookTimeline::Dashboard::native_output [file join $output_dir alternate]
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "!" "mismatched output field should show warning marker"
set ::RMSXFlipbookTimeline::Dashboard::native_output $original_output_dir
::RMSXFlipbookTimeline::Dashboard::refresh_output_display_indicator
assert_equal $::RMSXFlipbookTimeline::Dashboard::output_display_var "\u2713" "restored matching output field should show displayed marker"
assert_equal [format "%.3f" [option_value [dict get $call args] -rmsd_time_step]] 10.000 "total-time override should derive RMSD time step"
assert_equal [option_value [dict get $call args] -manual_length_ns] 1.0 "total-time override should pass manual RMSX length"
set ::RMSXFlipbookTimeline::Dashboard::native_total_time_ns auto
if {[lsearch -exact [dict get $call args] -slice_size] < 0} {
    smoke_fail "native dashboard dispatch should include -slice_size"
}
assert_equal [option_value [dict get $call args] -log_transform] 1 "advanced native log-transform should be passed"
assert_equal $::RMSXFlipbookTimeline::Dashboard::native_total_frames 1003 "native run should cache trajectory frame count"

set ::RMSXFlipbookTimeline::Dashboard::timeline_metric secondary_structure
set ::RMSXFlipbookTimeline::Dashboard::timeline_selection protein
set ::RMSXFlipbookTimeline::Dashboard::source_type new_analysis
set ::RMSXFlipbookTimeline::Dashboard::timeline_molid top
set ::RMSXFlipbookTimeline::Dashboard::timeline_column_mode slices
set ::RMSXFlipbookTimeline::Dashboard::timeline_slice_aggregation auto
set ::RMSXFlipbookTimeline::Dashboard::timeline_slice_representative middle
set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::run_analysis
set call [lindex $::rmsxflipbooktimeline_dashboard_calls $before]
assert_equal [dict get $call proc] live "secondary_structure dashboard dispatch"
assert_equal [dict get $call metric] secondary_structure "secondary_structure metric passed to live plot"
assert_equal [option_value [dict get $call args] column_mode] slices "slice column mode passed to live plot"
assert_equal [option_value [dict get $call args] slice_aggregation] auto "slice aggregation passed to live plot"
assert_equal [option_value [dict get $call args] slice_representative] middle "slice representative frame passed to live plot"
if {[dict get $call molid] == 0} {
    smoke_fail "new-analysis Timeline metrics should load the selected PDB/DCD, not use one-frame top molecule"
}
assert_equal [molinfo [dict get $call molid] get numframes] 317 "new-analysis Timeline metric frame count"

set ::RMSXFlipbookTimeline::Dashboard::timeline_metric inter_selection_contacts
set ::RMSXFlipbookTimeline::Dashboard::timeline_inter_method residues_to_selection
set ::RMSXFlipbookTimeline::Dashboard::timeline_inter_dist 4.5
set ::RMSXFlipbookTimeline::Dashboard::timeline_inter_from_selection "resid 1 to 5"
set ::RMSXFlipbookTimeline::Dashboard::timeline_inter_to_selection "resid 6 to 10"
set ::RMSXFlipbookTimeline::Dashboard::timeline_inter_selection_list "{resid 1 to 5} {resid 6 to 10}"
set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::run_analysis
set call [lindex $::rmsxflipbooktimeline_dashboard_calls $before]
assert_equal [dict get $call proc] live "inter_selection_contacts dashboard dispatch"
assert_equal [dict get $call metric] inter_selection_contacts "inter-selection metric passed to live plot"
assert_equal [option_value [dict get $call args] inter_method] residues_to_selection "inter-selection method passed"
assert_equal [option_value [dict get $call args] inter_dist] 4.5 "inter-selection cutoff passed"
assert_equal [option_value [dict get $call args] inter_from_selection] "resid 1 to 5" "inter-selection from selection passed"
assert_equal [option_value [dict get $call args] inter_to_selection] "resid 6 to 10" "inter-selection to selection passed"

set rmsx_folder [file normalize [file join /tmp rmsxflipbooktimeline-dashboard-folder-[pid]]]
file mkdir $rmsx_folder
set fp [open [file join $rmsx_folder rmsx_vmd_native.csv] w]
puts $fp "ResidueID,ChainID,slice_1.dcd,slice_2.dcd"
puts $fp "1,7,1.0,2.0"
puts $fp "2,7,1.5,2.5"
close $fp
set fp [open [file join $rmsx_folder lddt_vmd_native.csv] w]
puts $fp "ResidueID,ChainID,slice_1.dcd,slice_2.dcd"
puts $fp "1,7,0.2,0.3"
puts $fp "2,7,0.4,0.5"
close $fp
set fp [open [file join $rmsx_folder rmsd.csv] w]
puts $fp "Frame,Time,RMSD"
puts $fp "0,0.0,0.0"
puts $fp "1,0.1,0.5"
puts $fp "2,0.2,0.7"
puts $fp "3,0.3,0.6"
close $fp
set fp [open [file join $rmsx_folder rmsf.csv] w]
puts $fp "ResidueID,RMSF"
puts $fp "1,0.25"
puts $fp "2,0.45"
close $fp
set ::RMSXFlipbookTimeline::Dashboard::folder $rmsx_folder
set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::load_existing_folder
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] load_folder "existing folder load"
set ::RMSXFlipbookTimeline::Dashboard::timeline_metric RMSX
set matrix_result [::RMSXFlipbookTimeline::Dashboard::view_matrix]
assert_equal [file tail [dict get $matrix_result csv]] rmsx_vmd_native.csv "RMSX matrix should use RMSX CSV when lDDT CSV is also present"
assert_equal [dict get $matrix_result flanking_plots] 1 "native embedded plot should include RMSD/RMSF flanking context"
set ::RMSXFlipbookTimeline::Dashboard::timeline_metric lDDT
set matrix_result [::RMSXFlipbookTimeline::Dashboard::view_matrix]
assert_equal [file tail [dict get $matrix_result csv]] lddt_vmd_native.csv "lDDT matrix should use lDDT CSV"

set before [llength $::rmsxflipbooktimeline_dashboard_calls]
set ::RMSXFlipbookTimeline::Dashboard::render_transparent_png 1
::RMSXFlipbookTimeline::Dashboard::save_flipbook_image
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] render_image "dashboard save image dispatch"
assert_equal [option_value [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] args] -transparent_background] 1 "dashboard save image should pass transparent PNG option"

set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::open_full_plot_window
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] plot_window "advanced full plot dispatch"

set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::repair_native_bfactors
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] repair "advanced repair dispatch"

set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::export_native_heatmap_svg
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] heatmap_svg "advanced heatmap SVG dispatch"

set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::export_native_report_svg
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] report_svg "advanced report SVG dispatch"

set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::export_multimodel_pdb
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] multimodel "advanced multi-model PDB dispatch"

set before [llength $::rmsxflipbooktimeline_dashboard_calls]
::RMSXFlipbookTimeline::Dashboard::install_dashboard_hotkeys
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls $before] proc] hotkeys "advanced hotkey dispatch"

set tml_path [file normalize [file join /tmp rmsxflipbooktimeline-dashboard-[pid].tml]]
set fp [open $tml_path w]
puts $fp "# VMD Timeline data file"
close $fp
set ::RMSXFlipbookTimeline::Dashboard::timeline_tml_file $tml_path
::RMSXFlipbookTimeline::Dashboard::load_tml
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls end] proc] tml "TML load"

set collection_dir [file normalize [file join /tmp rmsxflipbooktimeline-dashboard-collection-[pid]]]
file mkdir $collection_dir
set ::RMSXFlipbookTimeline::Dashboard::timeline_collection_dir $collection_dir
::RMSXFlipbookTimeline::Dashboard::load_collection
assert_equal [dict get [lindex $::rmsxflipbooktimeline_dashboard_calls end] proc] dataset "collection display"

file delete -force $output_dir $rmsx_folder $tml_path $collection_dir
puts "RMSX Flipbook Timeline dashboard command smoke passed"
exit 0
