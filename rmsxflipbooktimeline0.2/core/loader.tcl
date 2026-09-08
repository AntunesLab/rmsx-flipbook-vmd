################################################################################
# RMSX Flipbook Timeline folder loading
################################################################################

namespace eval ::RMSXFlipbookTimeline::Loader {
    proc is_auto_spacing {value} {
        set cleaned [string tolower [string trim $value]]
        return [expr {$cleaned eq "" || $cleaned eq "auto"}]
    }

    proc resolve_spacing {molids spacing_setting} {
        if {[is_auto_spacing $spacing_setting]} {
            return [dict create mode auto value [::RMSXFlipbookTimeline::Layout::auto_spacing $molids]]
        }

        if {![string is double -strict $spacing_setting]} {
            error "Spacing must be 'auto' or a positive number"
        }
        set spacing [expr {double($spacing_setting)}]
        if {$spacing <= 0.0} {
            error "Spacing must be greater than 0.0"
        }

        return [dict create mode manual value $spacing]
    }

    proc current_options {} {
        return [dict create \
            palette [::RMSXFlipbookTimeline::state_get palette viridis] \
            quality [::RMSXFlipbookTimeline::state_get quality Balanced] \
            rep [::RMSXFlipbookTimeline::state_get rep NewTube] \
            thick [::RMSXFlipbookTimeline::state_get thick 0.30] \
            res [::RMSXFlipbookTimeline::state_get res 32] \
            aspect [::RMSXFlipbookTimeline::state_get aspect 1.00] \
            spline [::RMSXFlipbookTimeline::state_get spline 0] \
            color_method [::RMSXFlipbookTimeline::state_get color_method User2] \
            color_min [::RMSXFlipbookTimeline::state_get color_min 0.0] \
            color_max [::RMSXFlipbookTimeline::state_get color_max 10.0] \
            spacing [::RMSXFlipbookTimeline::state_get spacing_mode auto] \
            apply_mask [::RMSXFlipbookTimeline::state_get apply_mask 1] \
            mask_opacity [::RMSXFlipbookTimeline::state_get mask_opacity 0.30] \
            user_scale [::RMSXFlipbookTimeline::state_get user_scale 1.0] \
            user_offset [::RMSXFlipbookTimeline::state_get user_offset 2.0] \
            view_preset current \
            write_manifest 1]
    }

    proc state_set_options {opts} {
        foreach key {
            palette quality rep thick res aspect spline user_scale user_offset
            color_method color_min color_max apply_mask mask_opacity
            view_preset
        } {
            if {[dict exists $opts $key]} {
                ::RMSXFlipbookTimeline::state_set $key [dict get $opts $key]
            }
        }
    }

    proc discover_slice_files {folder} {
        set normalized_folder [file normalize $folder]
        if {![file isdirectory $normalized_folder]} {
            error "RMSX Flipbook Timeline folder does not exist: $normalized_folder"
        }

        set pairs {}
        foreach path [glob -nocomplain -directory $normalized_folder "slice_*_first_frame.pdb"] {
            set name [file tail $path]
            if {[regexp {^slice_([0-9]+)_first_frame\.pdb$} $name _ slice_index]} {
                lappend pairs [list [expr {$slice_index + 0}] [file normalize $path]]
            }
        }

        set pairs [lsort -integer -index 0 $pairs]
        set files {}
        foreach pair $pairs {
            lappend files [lindex $pair 1]
        }
        return $files
    }

    proc find_mask_file {folder} {
        set mask_path [file join [file normalize $folder] masked_residues.csv]
        if {[file exists $mask_path]} {
            return [file normalize $mask_path]
        }
        return ""
    }

    proc default_multimodel_path {folder output_name} {
        set cleaned [string trim $output_name]
        if {$cleaned eq "" || [file pathtype $cleaned] eq "relative"} {
            if {$cleaned eq ""} {
                set cleaned "rmsx_flipbook_multimodel.pdb"
            }
            return [file normalize [file join [file normalize $folder] $cleaned]]
        }
        return [file normalize $cleaned]
    }

    proc write_multimodel_pdb {folder args} {
        set defaults [dict create \
            output_name rmsx_flipbook_multimodel.pdb \
            remark 1 \
            include_ter 1 \
            overwrite 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set source_folder [file normalize $folder]
        set files [discover_slice_files $source_folder]
        if {[llength $files] == 0} {
            error "No slice_<n>_first_frame.pdb files found in $source_folder"
        }

        set out_path [default_multimodel_path $source_folder [dict get $opts output_name]]
        set out_dir [file dirname $out_path]
        if {![file isdirectory $out_dir]} {
            file mkdir $out_dir
        }
        if {[file exists $out_path] && ![dict get $opts overwrite]} {
            error "Multi-model flipbook PDB already exists: $out_path"
        }

        set atom_count 0
        set model_index 0
        set out [open $out_path w]
        try {
            if {[dict get $opts remark]} {
                puts $out "REMARK RMSX Flipbook Timeline multi-model PDB written by rmsxflipbooktimeline"
                puts $out "REMARK Source folder: $source_folder"
                puts $out "REMARK Slice count: [llength $files]"
            }
            foreach path $files {
                incr model_index
                puts $out [format "MODEL     %4d" $model_index]
                if {[dict get $opts remark]} {
                    puts $out "REMARK Slice file: [file tail $path]"
                }
                set fp [open $path r]
                try {
                    while {[gets $fp line] >= 0} {
                        if {[string match "ATOM*" $line] || [string match "HETATM*" $line]} {
                            puts $out $line
                            incr atom_count
                        } elseif {[dict get $opts include_ter] && [string match "TER*" $line]} {
                            puts $out $line
                        }
                    }
                } finally {
                    catch {close $fp}
                }
                puts $out "ENDMDL"
            }
            puts $out "END"
        } finally {
            catch {close $out}
        }

        set result [dict create \
            pdb $out_path \
            folder $source_folder \
            files [llength $files] \
            models $model_index \
            atoms $atom_count]
        puts [format {RMSX Flipbook Timeline: wrote %d-model PDB %s} $model_index $out_path]
        return $result
    }

    proc load_pdb_files {files} {
        set molids {}
        foreach path $files {
            mol new $path type pdb waitfor all
            lappend molids [molinfo top get id]
        }
        return $molids
    }

    proc load_folder {folder args} {
        set defaults [dict create \
            palette viridis \
            quality Balanced \
            write_manifest 1 \
            manifest_name rmsx_flipbook_timeline_manifest.tcldict \
            rep NewTube \
            thick 0.30 \
            res 32 \
            aspect 1.00 \
            spline 0 \
            user_scale 1.0 \
            user_offset 2.0 \
            color_method User2 \
            color_min 0.0 \
            color_max 10.0 \
            spacing auto \
            apply_mask 1 \
            mask_opacity 0.30 \
            view_preset rmsx]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        ::RMSXFlipbookTimeline::reset 1

        set source_folder [file normalize $folder]
        set files [discover_slice_files $source_folder]
        if {[llength $files] == 0} {
            error "No slice_<n>_first_frame.pdb files found in $source_folder"
        }

        puts [format {RMSX Flipbook Timeline: loading %d slice PDB files} [llength $files]]
        set molids [load_pdb_files $files]
        set mask_file [find_mask_file $source_folder]

        ::RMSXFlipbookTimeline::state_set source_folder $source_folder
        ::RMSXFlipbookTimeline::state_set slice_files $files
        ::RMSXFlipbookTimeline::state_set molids $molids
        ::RMSXFlipbookTimeline::state_set mask_file $mask_file
        state_set_options $opts

        set spacing_result [resolve_spacing $molids [dict get $opts spacing]]
        set spacing [dict get $spacing_result value]
        set offsets [::RMSXFlipbookTimeline::Layout::set_grid_spacing $molids $spacing]
        ::RMSXFlipbookTimeline::state_set spacing $spacing
        ::RMSXFlipbookTimeline::state_set spacing_mode [dict get $spacing_result mode]
        ::RMSXFlipbookTimeline::state_set layout_offsets $offsets

        set value_result [::RMSXFlipbookTimeline::Values::assign_from_bfactors \
            $molids \
            source_folder $source_folder \
            slice_files $files \
            user_scale [dict get $opts user_scale] \
            user_offset [dict get $opts user_offset]]

        ::RMSXFlipbookTimeline::state_set raw_min [dict get $value_result raw_min]
        ::RMSXFlipbookTimeline::state_set raw_max [dict get $value_result raw_max]
        ::RMSXFlipbookTimeline::state_set norm_min [dict get $value_result norm_min]
        ::RMSXFlipbookTimeline::state_set norm_max [dict get $value_result norm_max]
        ::RMSXFlipbookTimeline::state_set value_source [dict get $value_result source]
        ::RMSXFlipbookTimeline::state_set value_file [dict get $value_result value_file]

        set applied_palette [::RMSXFlipbookTimeline::Style::apply \
            $molids \
            rep [dict get $opts rep] \
            thick [dict get $opts thick] \
            res [dict get $opts res] \
            aspect [dict get $opts aspect] \
            spline [dict get $opts spline] \
            color_method [dict get $opts color_method] \
            color_min [dict get $opts color_min] \
            color_max [dict get $opts color_max] \
            palette [dict get $opts palette]]
        ::RMSXFlipbookTimeline::state_set palette $applied_palette

        set applied_view_preset [::RMSXFlipbookTimeline::Style::apply_view_preset [dict get $opts view_preset]]

        set masked_count 0
        set mask_reps_added 0
        set mask_marker_reps_added 0
        if {[dict get $opts apply_mask] && $mask_file ne ""} {
            set mask_result [::RMSXFlipbookTimeline::Mask::apply \
                $molids \
                $mask_file \
                opacity [dict get $opts mask_opacity] \
                color_min [dict get $opts color_min] \
                color_max [dict get $opts color_max]]
            set masked_count [dict get $mask_result masked_residues]
            if {[dict exists $mask_result reps_added]} {
                set mask_reps_added [dict get $mask_result reps_added]
            }
            if {[dict exists $mask_result marker_reps_added]} {
                set mask_marker_reps_added [dict get $mask_result marker_reps_added]
            }
            ::RMSXFlipbookTimeline::state_set masked_residue_count $masked_count
        }
        ::RMSXFlipbookTimeline::Style::store_initial_view_matrices $molids

        set manifest_path ""
        if {[dict get $opts write_manifest]} {
            set manifest_path [file join $source_folder [dict get $opts manifest_name]]
            ::RMSXFlipbookTimeline::state_set manifest_path $manifest_path
            ::RMSXFlipbookTimeline::Manifest::write $manifest_path
        }

        set result [dict create \
            folder $source_folder \
            files [llength $files] \
            molecules [llength $molids] \
            molids $molids \
            raw_min [::RMSXFlipbookTimeline::state_get raw_min] \
            raw_max [::RMSXFlipbookTimeline::state_get raw_max] \
            value_source [::RMSXFlipbookTimeline::state_get value_source] \
            value_file [::RMSXFlipbookTimeline::state_get value_file] \
            mapped_values [dict get $value_result record_count] \
            assigned_atoms [dict get $value_result assigned_atoms] \
            masked_residues $masked_count \
            mask_reps_added $mask_reps_added \
            mask_marker_reps_added $mask_marker_reps_added \
            mask_file $mask_file \
            spacing $spacing \
            view_preset $applied_view_preset \
            manifest $manifest_path]

        puts "RMSX Flipbook Timeline: backend load complete"
        return $result
    }

    proc apply_settings {args} {
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $molids] == 0} {
            error "No RMSX flipbook molecules are loaded"
        }

        set defaults [current_options]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        state_set_options $opts

        set spacing_result [resolve_spacing $molids [dict get $opts spacing]]
        set spacing [dict get $spacing_result value]
        set offsets [::RMSXFlipbookTimeline::Layout::set_grid_spacing \
            $molids \
            $spacing \
            [::RMSXFlipbookTimeline::state_get layout_offsets {}]]
        ::RMSXFlipbookTimeline::state_set spacing $spacing
        ::RMSXFlipbookTimeline::state_set spacing_mode [dict get $spacing_result mode]
        ::RMSXFlipbookTimeline::state_set layout_offsets $offsets

        set applied_palette [::RMSXFlipbookTimeline::Style::apply \
            $molids \
            rep [dict get $opts rep] \
            thick [dict get $opts thick] \
            res [dict get $opts res] \
            aspect [dict get $opts aspect] \
            spline [dict get $opts spline] \
            color_method [dict get $opts color_method] \
            color_min [dict get $opts color_min] \
            color_max [dict get $opts color_max] \
            palette [dict get $opts palette]]
        ::RMSXFlipbookTimeline::state_set palette $applied_palette

        set applied_view_preset [::RMSXFlipbookTimeline::Style::apply_view_preset [dict get $opts view_preset]]

        set masked_count 0
        set mask_reps_added 0
        set mask_marker_reps_added 0
        set mask_file [::RMSXFlipbookTimeline::state_get mask_file ""]
        if {[dict get $opts apply_mask] && $mask_file ne ""} {
            set mask_result [::RMSXFlipbookTimeline::Mask::apply \
                $molids \
                $mask_file \
                opacity [dict get $opts mask_opacity] \
                color_min [dict get $opts color_min] \
                color_max [dict get $opts color_max]]
            set masked_count [dict get $mask_result masked_residues]
            if {[dict exists $mask_result reps_added]} {
                set mask_reps_added [dict get $mask_result reps_added]
            }
            if {[dict exists $mask_result marker_reps_added]} {
                set mask_marker_reps_added [dict get $mask_result marker_reps_added]
            }
        }
        ::RMSXFlipbookTimeline::state_set masked_residue_count $masked_count

        set manifest_path [::RMSXFlipbookTimeline::state_get manifest_path ""]
        if {[dict get $opts write_manifest] && $manifest_path ne ""} {
            ::RMSXFlipbookTimeline::Manifest::write $manifest_path
        }

        set result [dict create \
            molecules [llength $molids] \
            molids $molids \
            spacing $spacing \
            spacing_mode [dict get $spacing_result mode] \
            rep [dict get $opts rep] \
            thick [dict get $opts thick] \
            res [dict get $opts res] \
            color_min [dict get $opts color_min] \
            color_max [dict get $opts color_max] \
            masked_residues $masked_count \
            mask_reps_added $mask_reps_added \
            mask_marker_reps_added $mask_marker_reps_added \
            view_preset $applied_view_preset \
            manifest $manifest_path]

        puts "RMSX Flipbook Timeline: applied current settings"
        return $result
    }
}
