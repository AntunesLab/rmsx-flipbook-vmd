################################################################################
# Launch RMSX/Flipbook Timeline 0.2 inside VMD.
################################################################################

namespace eval ::RMSXFlipbookTimelineReleaseLaunch {
    proc workspace_root {} {
        global env
        if {[info exists env(RMSXFLIPBOOKTIMELINE_WORKSPACE_ROOT)] && $env(RMSXFLIPBOOKTIMELINE_WORKSPACE_ROOT) ne ""} {
            return [file normalize $env(RMSXFLIPBOOKTIMELINE_WORKSPACE_ROOT)]
        }
        set script_name [info script]
        if {$script_name ne ""} {
            return [file normalize [file join [file dirname $script_name] ..]]
        }
        return [file normalize [pwd]]
    }

    proc set_path_arg {key index} {
        global argc argv
        if {$argc > $index} {
            set value [lindex $argv $index]
            if {$value ne ""} {
                ::RMSXFlipbookTimeline::state_set $key [file normalize $value]
            }
        }
    }

    proc set_value_arg {key index} {
        global argc argv
        if {$argc > $index} {
            set value [lindex $argv $index]
            if {$value ne ""} {
                ::RMSXFlipbookTimeline::state_set $key $value
            }
        }
    }

    proc main {} {
        global auto_path env

        set root [workspace_root]
        set plugin_parent [file join $root workspace_plugins]
        if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.2]]} {
            error "RMSX/Flipbook Timeline 0.2 plugin directory not found under $plugin_parent"
        }

        lappend auto_path $plugin_parent
        package require rmsxflipbooktimeline 0.2

        set_path_arg source_folder 0
        set_path_arg native_topology 1
        set_path_arg native_trajectory 2
        set_path_arg native_output 3
        set_value_arg native_chain 4
        set_value_arg native_slices 5
        set_value_arg native_start 6
        set_value_arg native_end 7
        set_value_arg native_time_step 8
        set_value_arg native_metric 9
        set_value_arg timeline_metric 9
        set_value_arg native_analysis_type 10
        set_value_arg native_mask_selection 11
        set_value_arg native_slice_size 12
        set_value_arg native_total_time_ns 13

        if {[info exists env(RMSXFLIPBOOKTIMELINE_LAUNCH_SMOKE)] && $env(RMSXFLIPBOOKTIMELINE_LAUNCH_SMOKE) ne ""} {
            puts [join [list \
                "RMSX/Flipbook Timeline 0.2 launcher smoke:" \
                "root=$root" \
                "plugin_parent=$plugin_parent" \
                "package_root=[::RMSXFlipbookTimeline::package_root]" \
                "package_env=[expr {[info exists env(RMSXFLIPBOOKTIMELINEDIR)] ? $env(RMSXFLIPBOOKTIMELINEDIR) : ""}]" \
                "default_command=[expr {[info commands rmsxflipbooktimeline] ne ""}]" \
                "dashboard_command=[expr {[info commands rmsxflipbooktimeline_dashboard] ne ""}]" \
                "classic_command=[expr {[info commands rmsxflipbooktimeline_classic] ne ""}]" \
                "experimental=[::RMSXFlipbookTimeline::experimental_enabled]" \
                "native_topology=[::RMSXFlipbookTimeline::state_get native_topology ""]" \
                "native_trajectory=[::RMSXFlipbookTimeline::state_get native_trajectory ""]" \
                "native_output=[::RMSXFlipbookTimeline::state_get native_output ""]" \
                "native_metric=[::RMSXFlipbookTimeline::state_get native_metric ""]" \
                "native_chain=[::RMSXFlipbookTimeline::state_get native_chain ""]" \
                "native_slices=[::RMSXFlipbookTimeline::state_get native_slices ""]"] { }]
            quit
            return
        }

        return [rmsxflipbooktimeline]
    }
}

::RMSXFlipbookTimelineReleaseLaunch::main
