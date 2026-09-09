################################################################################
# RMSX Flipbook Timeline GUI Timeline-command smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline GUI Timeline-command smoke failed: $message"
    exit 1
}

proc assert_call {expected_proc} {
    if {[llength $::rmsxflipbooktimeline_gui_timeline_calls] == 0} {
        smoke_fail "Expected GUI command call '$expected_proc', got no calls"
    }
    set call [lindex $::rmsxflipbooktimeline_gui_timeline_calls end]
    if {[dict get $call proc] ne $expected_proc} {
        smoke_fail "Expected GUI command call '$expected_proc', got '[dict get $call proc]'"
    }
    return $call
}

proc assert_metric_available {metric} {
    if {[lsearch -exact $::RMSXFlipbookTimeline::GUI::metric_values $metric] < 0} {
        smoke_fail "Metric '$metric' is missing from the shared GUI metric dropdown values"
    }
}

proc test_dataset {{title "GUI Timeline Dataset"}} {
    set rows [list \
        [dict create index 0 resid 1 resname GLY chain A label "A:1 GLY" selection "resid 1" row_mode residue] \
        [dict create index 1 resid 2 resname SER chain A label "A:2 SER" selection "resid 2" row_mode residue]]
    set columns [list \
        [dict create index 0 frame 0 label 0 target_type frame] \
        [dict create index 1 frame 1 label 1 target_type frame]]
    return [::RMSXFlipbookTimeline::Matrix::create \
        title $title \
        value_label displacement \
        row_mode residue \
        column_mode frame \
        rows $rows \
        columns $columns \
        values {{0.0 1.0} {0.5 1.5}}]
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir $::env(RMSX_TEST_PACKAGE)
    set plugin_parent $::env(RMSX_TEST_REPO)
} else {
    set plugin_parent $::env(RMSX_TEST_REPO)
    set plugin_dir [file join $plugin_parent rmsxflipbooktimeline0.3]
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

if {[catch {source -encoding utf-8 [file join $plugin_dir gui main_window.tcl]} err]} {
    smoke_fail "GUI source failed: $err"
}

foreach metric {
    RMSX Shift-Map lDDT
    displacement displacement_velocity rmsd rmsf sasa native_contacts
    secondary_structure phi delta_phi psi delta_psi
    hbonds salt_bridges inter_selection_contacts cross_correlation
    x y z user user2 user3 user4 user_field residue_function
    selection_empty test_free_selection rmsd_tool
} {
    assert_metric_available $metric
}

if {[info commands molinfo] eq ""} {
    proc molinfo {args} {
        set op [lindex $args 0]
        switch -- $op {
            num {return 1}
            top {return 0}
            list {return {0}}
            default {error "Unexpected molinfo call: $args"}
        }
    }
}

proc tk_getSaveFile {args} {
    return [file normalize [file join $::env(TMPDIR) rmsxflipbooktimeline-gui-export-[pid].out]]
}

set ::rmsxflipbooktimeline_gui_timeline_calls {}

rename ::RMSXFlipbookTimeline::show_live_timeline ::RMSXFlipbookTimeline::show_live_timeline_real
rename ::RMSXFlipbookTimeline::show_timeline_tml ::RMSXFlipbookTimeline::show_timeline_tml_real
rename ::RMSXFlipbookTimeline::show_timeline_rmsx_folder ::RMSXFlipbookTimeline::show_timeline_rmsx_folder_real
rename ::RMSXFlipbookTimeline::load_timeline_collection ::RMSXFlipbookTimeline::load_timeline_collection_real
rename ::RMSXFlipbookTimeline::show_timeline_dataset ::RMSXFlipbookTimeline::show_timeline_dataset_real
rename ::RMSXFlipbookTimeline::filter_timeline_current ::RMSXFlipbookTimeline::filter_timeline_current_real
rename ::RMSXFlipbookTimeline::copy_timeline_to_user ::RMSXFlipbookTimeline::copy_timeline_to_user_real
rename ::RMSXFlipbookTimeline::write_current_timeline_tml ::RMSXFlipbookTimeline::write_current_timeline_tml_real
rename ::RMSXFlipbookTimeline::write_current_timeline_svg ::RMSXFlipbookTimeline::write_current_timeline_svg_real
rename ::RMSXFlipbookTimeline::write_current_timeline_png ::RMSXFlipbookTimeline::write_current_timeline_png_real

proc ::RMSXFlipbookTimeline::show_live_timeline {molid metric args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc live molid $molid metric $metric args $args]
    return [dict create rows 2 columns 2 min 0.0 max 1.5 drawn 0 dataset [test_dataset "Live GUI Dataset"]]
}

proc ::RMSXFlipbookTimeline::show_timeline_tml {filename args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc tml filename $filename args $args]
    return [dict create rows 2 columns 2 min 0.0 max 1.5 drawn 0 dataset [test_dataset "TML GUI Dataset"]]
}

proc ::RMSXFlipbookTimeline::show_timeline_rmsx_folder {folder args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc rmsx_folder folder $folder args $args]
    return [dict create rows 2 columns 2 min 0.0 max 1.5 drawn 0 dataset [test_dataset "RMSX Folder GUI Dataset"]]
}

proc ::RMSXFlipbookTimeline::load_timeline_collection {directory args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc collection directory $directory args $args]
    return [list [test_dataset "Collection GUI Dataset 1"] [test_dataset "Collection GUI Dataset 2"]]
}

proc ::RMSXFlipbookTimeline::show_timeline_dataset {dataset args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc dataset title [dict get $dataset title] args $args]
    return [dict create rows [dict get $dataset row_count] columns [dict get $dataset column_count] min [dict get $dataset min] max [dict get $dataset max] drawn 0 dataset $dataset]
}

proc ::RMSXFlipbookTimeline::filter_timeline_current {min_value max_value first last frames args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc filter min $min_value max $max_value first $first last $last frames $frames args $args]
    return [dict create rows 1 columns 2 min $min_value max $max_value drawn 0 dataset [test_dataset "Filtered GUI Dataset"]]
}

proc ::RMSXFlipbookTimeline::copy_timeline_to_user {field} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc copy field $field]
    return [dict create field $field rows 2 columns 2]
}

proc ::RMSXFlipbookTimeline::write_current_timeline_tml {filename} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc export_tml filename $filename]
    return $filename
}

proc ::RMSXFlipbookTimeline::write_current_timeline_svg {filename args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc export_svg filename $filename args $args]
    return $filename
}

proc ::RMSXFlipbookTimeline::write_current_timeline_png {filename args} {
    lappend ::rmsxflipbooktimeline_gui_timeline_calls [dict create proc export_png filename $filename args $args]
    return $filename
}

set ::RMSXFlipbookTimeline::GUI::palette viridis
set ::RMSXFlipbookTimeline::GUI::timeline_molid top
set ::RMSXFlipbookTimeline::GUI::timeline_selection protein
set ::RMSXFlipbookTimeline::GUI::timeline_metric rmsd
set ::RMSXFlipbookTimeline::GUI::timeline_first 0
set ::RMSXFlipbookTimeline::GUI::timeline_last 2
set ::RMSXFlipbookTimeline::GUI::timeline_scale_min 0.25
set ::RMSXFlipbookTimeline::GUI::timeline_scale_max 3.5
set ::RMSXFlipbookTimeline::GUI::timeline_threshold_min 0.0
set ::RMSXFlipbookTimeline::GUI::timeline_threshold_max 2.0
set ::RMSXFlipbookTimeline::GUI::timeline_scale_mode every_residue
set ::RMSXFlipbookTimeline::GUI::timeline_cc_map_file /tmp/rmsxflipbooktimeline-map.dx
set ::RMSXFlipbookTimeline::GUI::timeline_cc_vol_id 0
set ::RMSXFlipbookTimeline::GUI::timeline_cc_map_res 4.5
set ::RMSXFlipbookTimeline::GUI::timeline_cc_spacing 1.25
set ::RMSXFlipbookTimeline::GUI::timeline_cc_threshold 0.02
set ::RMSXFlipbookTimeline::GUI::timeline_cc_use_spacing 1
set ::RMSXFlipbookTimeline::GUI::timeline_cc_use_threshold 1
set ::RMSXFlipbookTimeline::GUI::timeline_cc_method selections
set ::RMSXFlipbookTimeline::GUI::timeline_cc_selection_list "{resid 1} {resid 2}"
set ::RMSXFlipbookTimeline::GUI::timeline_inter_method residues_to_selection
set ::RMSXFlipbookTimeline::GUI::timeline_inter_dist 4.25
set ::RMSXFlipbookTimeline::GUI::timeline_inter_from_selection "resid 1 to 5"
set ::RMSXFlipbookTimeline::GUI::timeline_inter_to_selection "resid 6 to 10"
set ::RMSXFlipbookTimeline::GUI::timeline_inter_selection_list "{resid 1 to 5} {resid 6 to 10}"

set ::RMSXFlipbookTimeline::GUI::timeline_metric RMSX
set call_count [llength $::rmsxflipbooktimeline_gui_timeline_calls]
::RMSXFlipbookTimeline::GUI::show_live_timeline_matrix
if {[llength $::rmsxflipbooktimeline_gui_timeline_calls] != $call_count} {
    smoke_fail "Native-only RMSX metric should not dispatch through the live Timeline calculator"
}

set ::RMSXFlipbookTimeline::GUI::timeline_metric rmsd
::RMSXFlipbookTimeline::GUI::show_live_timeline_matrix
set call [assert_call live]
if {[dict get $call molid] != 0 || [dict get $call metric] ne "rmsd"} {
    smoke_fail "Unexpected live call: $call"
}
foreach needle {selection protein first_frame 0 last_frame 2 palette viridis scale_mode every_residue scale_min 0.25 scale_max 3.5 threshold_min 0.0 threshold_max 2.0} {
    if {[lsearch -exact [dict get $call args] $needle] < 0} {
        smoke_fail "Live call args missing '$needle': [dict get $call args]"
    }
}

set ::RMSXFlipbookTimeline::GUI::timeline_metric user_field
set ::RMSXFlipbookTimeline::GUI::timeline_user_field user3
::RMSXFlipbookTimeline::GUI::show_live_timeline_matrix
set call [assert_call live]
if {[dict get $call metric] ne "user_field"} {
    smoke_fail "Unexpected user_field live metric: $call"
}
foreach needle {user_field user3} {
    if {[lsearch -exact [dict get $call args] $needle] < 0} {
        smoke_fail "user_field live args missing '$needle': [dict get $call args]"
    }
}

set ::RMSXFlipbookTimeline::GUI::timeline_metric residue_function
set ::RMSXFlipbookTimeline::GUI::timeline_residue_function ::rmsxflipbooktimeline_gui_residue_size
set ::RMSXFlipbookTimeline::GUI::timeline_residue_function_label residue_atom_count
set ::RMSXFlipbookTimeline::GUI::timeline_residue_function_unit atoms
set ::RMSXFlipbookTimeline::GUI::timeline_residue_function_context "protein and backbone"
::RMSXFlipbookTimeline::GUI::show_live_timeline_matrix
set call [assert_call live]
if {[dict get $call metric] ne "residue_function"} {
    smoke_fail "Unexpected residue_function live metric: $call"
}
foreach needle {residue_function ::rmsxflipbooktimeline_gui_residue_size residue_function_label residue_atom_count residue_function_unit atoms residue_function_context_selection {protein and backbone}} {
    if {[lsearch -exact [dict get $call args] $needle] < 0} {
        smoke_fail "residue_function live args missing '$needle': [dict get $call args]"
    }
}

set ::RMSXFlipbookTimeline::GUI::timeline_metric cross_correlation
::RMSXFlipbookTimeline::GUI::show_live_timeline_matrix
set call [assert_call live]
if {[dict get $call metric] ne "cross_correlation"} {
    smoke_fail "Unexpected cross_correlation live metric: $call"
}
set live_args [dict create {*}[dict get $call args]]
foreach {key expected} {
    cc_map_file /tmp/rmsxflipbooktimeline-map.dx
    cc_vol_id 0
    cc_map_res 4.5
    cc_spacing 1.25
    cc_threshold 0.02
    cc_use_spacing 1
    cc_use_threshold 1
    cc_method selections
    cc_selection_list {{resid 1} {resid 2}}
} {
    if {![dict exists $live_args $key] || [dict get $live_args $key] ne $expected} {
        smoke_fail "cross_correlation live arg $key mismatch: expected '$expected', args=[dict get $call args]"
    }
}

set ::RMSXFlipbookTimeline::GUI::timeline_metric inter_selection_contacts
::RMSXFlipbookTimeline::GUI::show_live_timeline_matrix
set call [assert_call live]
if {[dict get $call metric] ne "inter_selection_contacts"} {
    smoke_fail "Unexpected inter_selection_contacts live metric: $call"
}
set live_args [dict create {*}[dict get $call args]]
foreach {key expected} {
    inter_method residues_to_selection
    inter_dist 4.25
    inter_from_selection {resid 1 to 5}
    inter_to_selection {resid 6 to 10}
    inter_selection_list {{resid 1 to 5} {resid 6 to 10}}
} {
    if {![dict exists $live_args $key] || [dict get $live_args $key] ne $expected} {
        smoke_fail "inter_selection_contacts live arg $key mismatch: expected '$expected', args=[dict get $call args]"
    }
}

set tml_path [file normalize [file join $::env(TMPDIR) rmsxflipbooktimeline-gui-command-[pid].tml]]
set fp [open $tml_path w]
puts $fp "# VMD Timeline data file"
close $fp
set ::RMSXFlipbookTimeline::GUI::timeline_tml_file $tml_path
::RMSXFlipbookTimeline::GUI::load_timeline_tml_file
set call [assert_call tml]
if {[dict get $call filename] ne $tml_path} {
    smoke_fail "Unexpected TML file in call: $call"
}

set rmsx_folder [file normalize [file join $::env(TMPDIR) rmsxflipbooktimeline-gui-rmsx-folder-[pid]]]
file mkdir $rmsx_folder
set ::RMSXFlipbookTimeline::GUI::folder $rmsx_folder
::RMSXFlipbookTimeline::GUI::load_timeline_rmsx_folder
set call [assert_call rmsx_folder]
if {[dict get $call folder] ne $rmsx_folder} {
    smoke_fail "Unexpected RMSX folder in call: $call"
}

set collection_dir [file normalize [file join $::env(TMPDIR) rmsxflipbooktimeline-gui-command-collection-[pid]]]
file mkdir $collection_dir
set ::RMSXFlipbookTimeline::GUI::timeline_collection_dir $collection_dir
::RMSXFlipbookTimeline::GUI::load_timeline_collection_dir
set call [assert_call dataset]
if {[dict get $call title] ne "Collection GUI Dataset 1"} {
    smoke_fail "Expected collection dataset to be displayed, got $call"
}
::RMSXFlipbookTimeline::GUI::next_timeline_collection_dataset
set call [assert_call dataset]
if {[dict get $call title] ne "Collection GUI Dataset 2"} {
    smoke_fail "Expected next collection dataset to be displayed, got $call"
}
::RMSXFlipbookTimeline::GUI::previous_timeline_collection_dataset
set call [assert_call dataset]
if {[dict get $call title] ne "Collection GUI Dataset 1"} {
    smoke_fail "Expected previous collection dataset to be displayed, got $call"
}

set ::RMSXFlipbookTimeline::GUI::timeline_filter_min 0.0
set ::RMSXFlipbookTimeline::GUI::timeline_filter_max 1.0
set ::RMSXFlipbookTimeline::GUI::timeline_filter_first 0
set ::RMSXFlipbookTimeline::GUI::timeline_filter_last -1
set ::RMSXFlipbookTimeline::GUI::timeline_filter_frames 1
::RMSXFlipbookTimeline::GUI::filter_timeline_matrix
set call [assert_call filter]
if {[dict get $call last] != -1 || [dict get $call frames] != 1} {
    smoke_fail "Unexpected filter call: $call"
}

set ::RMSXFlipbookTimeline::GUI::timeline_user_field user4
::RMSXFlipbookTimeline::GUI::copy_timeline_user_field
set call [assert_call copy]
if {[dict get $call field] ne "user4"} {
    smoke_fail "Unexpected copy field: $call"
}

::RMSXFlipbookTimeline::GUI::export_timeline_matrix tml
assert_call export_tml
::RMSXFlipbookTimeline::GUI::export_timeline_matrix svg
set call [assert_call export_svg]
foreach needle {palette viridis scale_mode every_residue scale_min 0.25 scale_max 3.5 threshold_min 0.0 threshold_max 2.0} {
    if {[lsearch -exact [dict get $call args] $needle] < 0} {
        smoke_fail "SVG export args missing '$needle': [dict get $call args]"
    }
}
::RMSXFlipbookTimeline::GUI::export_timeline_matrix png
set call [assert_call export_png]
foreach needle {palette viridis scale_mode every_residue scale_min 0.25 scale_max 3.5 threshold_min 0.0 threshold_max 2.0} {
    if {[lsearch -exact [dict get $call args] $needle] < 0} {
        smoke_fail "PNG export args missing '$needle': [dict get $call args]"
    }
}

file delete -force $tml_path $rmsx_folder $collection_dir
puts "RMSX Flipbook Timeline GUI Timeline-command smoke passed"
exit 0
