################################################################################
# RMSX Flipbook Timeline dashboard GUI smoke test
#
# Usage:
#   vmd -dispdev win -e tests/smoke_dashboard_show.tcl
################################################################################

set smoke_marker [file normalize [file join [pwd] outputs rmsxflipbooktimeline-dashboard-smoke.txt]]
file mkdir [file dirname $smoke_marker]

proc smoke_record {message} {
    global smoke_marker
    set fp [open $smoke_marker w]
    puts $fp $message
    close $fp
}

proc smoke_fail {message} {
    return -code error $message
}

proc run_smoke {} {
    set plugin_parent [file normalize [file join [pwd] workspace_plugins]]
    if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.2]]} {
        smoke_fail "plugin directory not found under $plugin_parent"
    }

    lappend ::auto_path $plugin_parent

    if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
        smoke_fail "package require failed: $err"
    }

    if {[catch {package require Tk} err]} {
        puts "RMSX Flipbook Timeline dashboard smoke skipped: Tk unavailable: $err"
        smoke_record "SKIP Tk unavailable: $err"
        return skip
    }

    if {[catch {winfo exists .} err]} {
        puts "RMSX Flipbook Timeline dashboard smoke skipped: Tk display unavailable: $err"
        smoke_record "SKIP Tk display unavailable: $err"
        return skip
    }

    if {[catch {rmsxflipbooktimeline_dashboard} err]} {
        if {[string match -nocase "*display*" $err] || [string match -nocase "*screen*" $err]} {
            puts "RMSX Flipbook Timeline dashboard smoke skipped: Tk display unavailable: $err"
            smoke_record "SKIP Tk display unavailable: $err"
            return skip
        }
        smoke_fail "rmsxflipbooktimeline_dashboard callback failed: $err"
    }

    if {![winfo exists .rmsxflipbooktimeline_dashboard]} {
        smoke_fail "expected .rmsxflipbooktimeline_dashboard window was not created"
    }

    if {[winfo exists .rmsxflipbooktimeline]} {
        smoke_fail "classic GUI should not open when dashboard launches"
    }

    foreach widget {
        .rmsxflipbooktimeline_dashboard.tabs
        .rmsxflipbooktimeline_dashboard.tabs.easy
        .rmsxflipbooktimeline_dashboard.tabs.matrix
        .rmsxflipbooktimeline_dashboard.tabs.export
        .rmsxflipbooktimeline_dashboard.tabs.advanced
        .rmsxflipbooktimeline_dashboard.tabs.help
        .rmsxflipbooktimeline_dashboard.tabs.help.github.url
        .rmsxflipbooktimeline_dashboard.tabs.help.github.open
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.source.source_new_analysis
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.source.source_existing_folder
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.native_topology_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.native_trajectory_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.native_output_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.native_output_label.status
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.timeline_tml_file_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.timeline_collection_dir_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.metric_combo
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.palette_combo
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.advanced_check
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.summary_text
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.color_text
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.native
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.native.thinner
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.native.thicker
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.timeline
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.timeline.columns_frames
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.timeline.columns_slices
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.timeline.aggregation_combo
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.timeline.representative_combo
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.cross
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.mode_slices
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.mode_size
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_slices_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_slice_size_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_total_frames_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_total_time_ns_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_time_step_entry
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.preview
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.preview_text
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.run
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.save
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.popout
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.spacing_minus
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.spacing_plus
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.reset_view
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.clear
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.heatmap.canvas
        .rmsxflipbooktimeline_dashboard.tabs.easy.content.heatmap.summary
        .rmsxflipbooktimeline_dashboard.tabs.matrix.metric.metric_combo
        .rmsxflipbooktimeline_dashboard.tabs.matrix.metric.palette_combo
        .rmsxflipbooktimeline_dashboard.tabs.matrix.metric.group_text
        .rmsxflipbooktimeline_dashboard.tabs.matrix.metric.summary_text
        .rmsxflipbooktimeline_dashboard.tabs.matrix.metric.color_text
        .rmsxflipbooktimeline_dashboard.tabs.matrix.live.plot
        .rmsxflipbooktimeline_dashboard.tabs.matrix.live.columns_frames
        .rmsxflipbooktimeline_dashboard.tabs.matrix.live.columns_slices
        .rmsxflipbooktimeline_dashboard.tabs.matrix.live.aggregation_combo
        .rmsxflipbooktimeline_dashboard.tabs.matrix.live.representative_combo
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.timeline
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts
        .rmsxflipbooktimeline_dashboard.tabs.matrix.import.timeline_tml_file_entry
        .rmsxflipbooktimeline_dashboard.tabs.matrix.import.timeline_collection_dir_entry
        .rmsxflipbooktimeline_dashboard.tabs.export.image.save
        .rmsxflipbooktimeline_dashboard.tabs.export.image.transparent_png
        .rmsxflipbooktimeline_dashboard.tabs.export.files.svg
        .rmsxflipbooktimeline_dashboard.tabs.advanced.native.native_log_transform
        .rmsxflipbooktimeline_dashboard.tabs.advanced.utilities.plot
        .rmsxflipbooktimeline_dashboard.tabs.advanced.utilities.heatmap
        .rmsxflipbooktimeline_dashboard.tabs.advanced.utilities.report
        .rmsxflipbooktimeline_dashboard.tabs.advanced.utilities.repair
        .rmsxflipbooktimeline_dashboard.tabs.advanced.utilities.multimodel
        .rmsxflipbooktimeline_dashboard.tabs.advanced.utilities.load_manifest
        .rmsxflipbooktimeline_dashboard.tabs.advanced.utilities.show_manifest
        .rmsxflipbooktimeline_dashboard.tabs.advanced.note.classic
        .rmsxflipbooktimeline_dashboard.status
    } {
        if {![winfo exists $widget]} {
            smoke_fail "expected dashboard widget was not created: $widget"
        }
    }

    if {[winfo exists .rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.metric_group_combo]} {
        smoke_fail "dashboard should use one metric dropdown, not a metric-group selector"
    }
    if {[winfo exists .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.read_frames]} {
        smoke_fail "dashboard should auto-count frames instead of showing a Read Frames button"
    }
    if {[wm title .rmsxflipbooktimeline_dashboard] ne "Flipbook"} {
        smoke_fail "dashboard window title should be Flipbook"
    }
    set native_metric_values [.rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.metric_combo cget -values]
    foreach metric {RMSX Shift-Map lDDT} {
        if {[lsearch -exact $native_metric_values $metric] < 0} {
            smoke_fail "native metric dropdown missing $metric"
        }
    }
    foreach metric {displacement secondary_structure native_contacts cross_correlation residue_function} {
        if {[lsearch -exact $native_metric_values $metric] >= 0} {
            smoke_fail "native metric dropdown should not include Timeline-only metric $metric"
        }
    }
    set timeline_metric_values [.rmsxflipbooktimeline_dashboard.tabs.matrix.metric.metric_combo cget -values]
    foreach metric {displacement secondary_structure native_contacts} {
        if {[lsearch -exact $timeline_metric_values $metric] < 0} {
            smoke_fail "interactive Timeline metric dropdown missing $metric"
        }
    }
    foreach metric {cross_correlation residue_function} {
        if {[lsearch -exact $timeline_metric_values $metric] >= 0} {
            smoke_fail "experimental Timeline metric should be hidden by default: $metric"
        }
    }
    set native_palette_values [.rmsxflipbooktimeline_dashboard.tabs.easy.content.metric.palette_combo cget -values]
    set timeline_palette_values [.rmsxflipbooktimeline_dashboard.tabs.matrix.metric.palette_combo cget -values]
    foreach palette {viridis magma inferno plasma cividis rocket mako turbo BWR RWB RGB} {
        if {[lsearch -exact $native_palette_values $palette] < 0} {
            smoke_fail "RMSX palette dropdown missing $palette"
        }
        if {[lsearch -exact $timeline_palette_values $palette] < 0} {
            smoke_fail "Timeline palette dropdown missing $palette"
        }
    }
    set ::RMSXFlipbookTimeline::Dashboard::palette magma
    ::RMSXFlipbookTimeline::Dashboard::on_palette_changed
    update idletasks
    if {[::RMSXFlipbookTimeline::state_get palette ""] ne "magma"} {
        smoke_fail "palette dropdown handler should persist the selected palette"
    }
    if {$::RMSXFlipbookTimeline::Dashboard::native_time_step ne "0.049"} {
        smoke_fail "dashboard should default to compact frame step 0.049"
    }
    if {$::RMSXFlipbookTimeline::Dashboard::timeline_column_mode ne "frames"} {
        smoke_fail "dashboard should default live Timeline matrices to frame columns"
    }

    set ::RMSXFlipbookTimeline::Dashboard::native_total_frames 1003
    set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slices
    set ::RMSXFlipbookTimeline::Dashboard::native_slices 8
    set ::RMSXFlipbookTimeline::Dashboard::native_start 0
    set ::RMSXFlipbookTimeline::Dashboard::native_end -1
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_slices_entry] eq ""} {
        smoke_fail "slices mode should show the slices input"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_slice_size_entry] ne ""} {
        smoke_fail "slices mode should hide the frames-per-slice input"
    }
    set preview_text [.rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.preview_text cget -text]
    if {![string match "*8 slices x 125 frames*leftover 3*" $preview_text]} {
        smoke_fail "slice preview summary did not update as expected: $preview_text"
    }

    set ::RMSXFlipbookTimeline::Dashboard::native_slicing_mode slice_size
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_slices_entry] ne ""} {
        smoke_fail "frames-per-slice mode should hide the slices input"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.settings.native_slice_size_entry] eq ""} {
        smoke_fail "frames-per-slice mode should show the size input"
    }

    update idletasks
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.native_topology_entry] eq ""} {
        smoke_fail "new-analysis source should show topology input"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.folder_entry] ne ""} {
        smoke_fail "new-analysis source should hide existing-folder input"
    }

    set ::RMSXFlipbookTimeline::Dashboard::source_type existing_folder
    set ::RMSXFlipbookTimeline::Dashboard::folder ""
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.folder_entry] eq ""} {
        smoke_fail "existing-folder source should show folder input"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.files.native_topology_entry] ne ""} {
        smoke_fail "existing-folder source should hide topology input"
    }
    if {[.rmsxflipbooktimeline_dashboard.tabs.easy.content.actions.run cget -state] ne "normal"} {
        smoke_fail "primary Run/Load action should stay clickable and report missing inputs in the status area"
    }

    set ::RMSXFlipbookTimeline::Dashboard::source_type tml_collection
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    if {$::RMSXFlipbookTimeline::Dashboard::source_type ne "new_analysis"} {
        smoke_fail "RMSX tab should coerce non-RMSX source modes back to new analysis"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.matrix.import.timeline_tml_file_entry] eq ""} {
        smoke_fail "Interactive Timeline tab should show TML input"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.matrix.import.timeline_collection_dir_entry] eq ""} {
        smoke_fail "Interactive Timeline tab should show collection input"
    }

    set ::RMSXFlipbookTimeline::Dashboard::timeline_metric secondary_structure
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.structure] ne ""} {
        smoke_fail "RMSX tab should not show Timeline-only structure options"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.matrix.options.structure] eq ""} {
        smoke_fail "secondary_structure should show the structure inspector panel"
    }

    set ::RMSXFlipbookTimeline::Dashboard::timeline_metric cross_correlation
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.easy.content.options.cross] ne ""} {
        smoke_fail "RMSX tab should not show Timeline-only cross-correlation options"
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.matrix.options.cross] eq ""} {
        smoke_fail "cross_correlation should show the cross-correlation inspector panel"
    }

    set ::RMSXFlipbookTimeline::Dashboard::timeline_metric native_contacts
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    foreach widget {
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.native_ref_entry
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.native_dist_entry
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.native_from_entry
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.native_to_entry
    } {
        if {![winfo exists $widget]} {
            smoke_fail "native_contacts option widget missing: $widget"
        }
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts] eq ""} {
        smoke_fail "native_contacts should show the contacts inspector panel"
    }

    set ::RMSXFlipbookTimeline::Dashboard::timeline_metric inter_selection_contacts
    ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
    update idletasks
    foreach widget {
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.inter_method_combo
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.inter_dist_entry
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.inter_from_entry
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.inter_to_entry
        .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.inter_list_entry
    } {
        if {![winfo exists $widget]} {
            smoke_fail "inter_selection_contacts option widget missing: $widget"
        }
        if {[grid info $widget] eq ""} {
            smoke_fail "inter_selection_contacts option widget should be visible: $widget"
        }
    }
    if {[grid info .rmsxflipbooktimeline_dashboard.tabs.matrix.options.contacts.native_ref_entry] ne ""} {
        smoke_fail "native contact widgets should be hidden for inter_selection_contacts"
    }

    puts "RMSX Flipbook Timeline dashboard GUI smoke passed"
    smoke_record "PASS RMSX Flipbook Timeline dashboard GUI smoke passed"
    return pass
}

if {[catch {run_smoke} err]} {
    puts "RMSX Flipbook Timeline dashboard GUI smoke failed: $err"
    smoke_record "FAIL $err"
    after 250 quit
} else {
    after 750 quit
}
