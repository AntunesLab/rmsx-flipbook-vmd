################################################################################
# RMSX Flipbook Timeline manifest
################################################################################

namespace eval ::RMSXFlipbookTimeline::Manifest {
    proc option_if_exists {opts_var payload section key option_key} {
        upvar 1 $opts_var opts
        if {[dict exists $payload $section $key]} {
            lappend opts $option_key [dict get $payload $section $key]
        }
    }

    proc write {filename} {
        set manifest [::RMSXFlipbookTimeline::state_dict]
        dict set manifest schema_version 2
        dict set manifest plugin_version [::RMSXFlipbookTimeline::state_get version "0.1"]
        dict set manifest created [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]

        if {[catch {vmdinfo version} vmd_version]} {
            set vmd_version unknown
        }
        if {[catch {vmdinfo arch} vmd_arch]} {
            set vmd_arch unknown
        }
        dict set manifest vmd_version $vmd_version
        dict set manifest vmd_arch $vmd_arch
        dict set manifest source [dict create \
            folder [::RMSXFlipbookTimeline::state_get source_folder ""] \
            slice_count [llength [::RMSXFlipbookTimeline::state_get slice_files {}]] \
            slice_files [::RMSXFlipbookTimeline::state_get slice_files {}] \
            mask_file [::RMSXFlipbookTimeline::state_get mask_file ""] \
            value_source [::RMSXFlipbookTimeline::state_get value_source ""] \
            value_file [::RMSXFlipbookTimeline::state_get value_file ""]]
        dict set manifest settings [dict create \
            quality [::RMSXFlipbookTimeline::state_get quality Balanced] \
            palette [::RMSXFlipbookTimeline::state_get palette viridis] \
            rep [::RMSXFlipbookTimeline::state_get rep NewTube] \
            thick [::RMSXFlipbookTimeline::state_get thick 0.30] \
            res [::RMSXFlipbookTimeline::state_get res 32] \
            aspect [::RMSXFlipbookTimeline::state_get aspect 1.00] \
            spline [::RMSXFlipbookTimeline::state_get spline 0] \
            color_method [::RMSXFlipbookTimeline::state_get color_method User2] \
            color_min [::RMSXFlipbookTimeline::state_get color_min 0.0] \
            color_max [::RMSXFlipbookTimeline::state_get color_max 10.0] \
            apply_mask [::RMSXFlipbookTimeline::state_get apply_mask 1] \
            mask_opacity [::RMSXFlipbookTimeline::state_get mask_opacity 0.30]]
        dict set manifest layout [dict create \
            spacing [::RMSXFlipbookTimeline::state_get spacing 0.0] \
            spacing_mode [::RMSXFlipbookTimeline::state_get spacing_mode auto] \
            offsets [::RMSXFlipbookTimeline::state_get layout_offsets {}]]
        dict set manifest ranges [dict create \
            raw_min [::RMSXFlipbookTimeline::state_get raw_min 0.0] \
            raw_max [::RMSXFlipbookTimeline::state_get raw_max 0.0] \
            norm_min [::RMSXFlipbookTimeline::state_get norm_min 0.0] \
            norm_max [::RMSXFlipbookTimeline::state_get norm_max 10.0]]

        dict set manifest current_result [::RMSXFlipbookTimeline::Results::get]
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write $filename [list ::RMSXFlipbookTimeline::Manifest::write_payload $manifest]

        puts "RMSX Flipbook Timeline: wrote manifest $filename"
        return $filename
    }

    proc write_payload {manifest filename} {
        set fp [open $filename w]
        fconfigure $fp -encoding utf-8 -translation lf
        try {
            puts $fp "# RMSX Flipbook Timeline session; Tcl dict data, never executable code"
            puts $fp $manifest
        } finally {close $fp}
    }

    proc read {filename} {
        set fp [open $filename r]
        fconfigure $fp -encoding utf-8
        set lines [split [::read $fp] "\n"]
        close $fp
        while {[llength $lines] && ([string trim [lindex $lines 0]] eq "" || [string match {#*} [string trimleft [lindex $lines 0]]])} {set lines [lrange $lines 1 end]}
        set payload [string trim [join $lines "\n"]]
        if {$payload eq ""} {
            error "Manifest has no Tcl dict payload: $filename"
        }
        return $payload
    }

    proc load {filename args} {
        set defaults [dict create \
            write_manifest 0 \
            view_preset ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set manifest_path [file normalize $filename]
        if {![file exists $manifest_path]} {
            error "Manifest does not exist: $manifest_path"
        }

        set payload [read $manifest_path]
        if {[dict exists $payload schema_version] && [dict get $payload schema_version] ni {1 2}} {
            error "Unsupported manifest schema_version [dict get $payload schema_version]"
        }

        if {[dict exists $payload source folder] && [dict get $payload source folder] ne ""} {
            set folder [dict get $payload source folder]
        } else {
            set folder [file dirname $manifest_path]
        }
        set folder [file normalize $folder]
        if {![file isdirectory $folder]} {
            error "Manifest source folder does not exist: $folder"
        }

        set load_args {}
        foreach key {quality palette rep res thick aspect spline color_method color_min color_max apply_mask mask_opacity} {
            option_if_exists load_args $payload settings $key $key
        }

        if {[dict exists $payload layout spacing_mode] && [dict get $payload layout spacing_mode] eq "auto"} {
            lappend load_args spacing auto
        } elseif {[dict exists $payload layout spacing]} {
            lappend load_args spacing [dict get $payload layout spacing]
        }

        set view_preset [string trim [dict get $opts view_preset]]
        if {$view_preset eq ""} {
            set view_preset principal
        }
        lappend load_args view_preset $view_preset

        set write_manifest [dict get $opts write_manifest]
        if {$write_manifest} {
            lappend load_args write_manifest 1 manifest_name [file tail $manifest_path]
        } else {
            lappend load_args write_manifest 0
        }

        set result [::RMSXFlipbookTimeline::Loader::load_folder $folder {*}$load_args]
        if {!$write_manifest} {
            ::RMSXFlipbookTimeline::state_set manifest_path $manifest_path
            dict set result manifest $manifest_path
        }
        dict set result manifest_loaded $manifest_path
        puts "RMSX Flipbook Timeline: loaded manifest $manifest_path"
        return $result
    }
}
