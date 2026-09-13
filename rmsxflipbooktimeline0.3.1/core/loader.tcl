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
            write_manifest 0]
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
        set options [::RMSXFlipbookTimeline::parse_kv_options [dict create output_name rmsx_flipbook_multimodel.pdb overwrite 0] {*}$args]
        set target [default_multimodel_path $folder [dict get $options output_name]]
        if {[lsearch -exact [discover_slice_files $folder] $target] >= 0} {error "Multimodel export cannot replace a source slice"}
        if {[file exists $target] && ![dict get $options overwrite]} {error "Multimodel output already exists: $target"}
        return [::RMSXFlipbookTimeline::OutputTxn::atomic_write $target [list ::RMSXFlipbookTimeline::Loader::multimodel_payload $folder $args]]
    }
    proc multimodel_payload {folder args filename} {
        return [write_multimodel_impl $folder {*}$args output_name $filename overwrite 1]
    }
    proc write_multimodel_impl {folder args} {
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

    proc delete_molecules {ids} {
        set errors {}
        foreach id [lsort -unique $ids] {
            if {[lsearch -exact [molinfo list] $id] >= 0 && [catch {mol delete $id} message]} {lappend errors $message}
        }
        if {[llength $errors]} {error [join $errors {; }]}
    }

    proc load_pdb_files {files} {
        set before [molinfo list]
        set ids {}
        try {
            foreach path $files {
                set id [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb $path]
                lappend ids $id
                mol off $id
                if {[molinfo $id get numatoms] < 1 || [molinfo $id get numframes] < 1} {
                    error "Slice has no usable coordinates: $path"
                }
            }
        } on error {message options} {
            set created {}
            foreach id [molinfo list] {if {[lsearch -exact $before $id] < 0} {lappend created $id}}
            catch {delete_molecules $created}
            return -options $options $message
        }
        return $ids
    }

    proc prepare_folder {folder args} {
        set defaults [dict create palette viridis quality Balanced write_manifest 0 \
            manifest_name rmsx_flipbook_timeline_manifest.tcldict rep [::RMSXFlipbookTimeline::Style::default_rep] thick 0.30 \
            res [::RMSXFlipbookTimeline::Style::default_resolution] aspect 1.00 spline 0 user_scale 1.0 user_offset 2.0 color_method User2 \
            color_min 0.0 color_max 10.0 spacing auto apply_mask 1 mask_opacity 0.30 \
            view_preset principal activation_callback ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set source_folder [file normalize $folder]
        set files [discover_slice_files $source_folder]
        if {![llength $files]} {error "No slice_<n>_first_frame.pdb files found in $source_folder"}
        set scene [::RMSXFlipbookTimeline::Scene::snapshot]
        set material_before [material list]
        set ids {}
        try {
            set ids [load_pdb_files $files]
            set mask_file [find_mask_file $source_folder]
            set state [::RMSXFlipbookTimeline::state_dict]
            foreach {key value} [list source_folder $source_folder slice_files $files molids $ids owned_molids $ids mask_file $mask_file manifest_path ""] {dict set state $key $value}
            foreach key {palette quality rep thick res aspect spline user_scale user_offset color_method color_min color_max apply_mask mask_opacity view_preset} {
                dict set state $key [dict get $opts $key]
            }
            set spacing_info [resolve_spacing $ids [dict get $opts spacing]]
            set spacing [dict get $spacing_info value]
            dict set state spacing $spacing
            dict set state spacing_mode [dict get $spacing_info mode]
            dict set state layout_offsets [::RMSXFlipbookTimeline::Layout::set_grid_spacing $ids $spacing]
            set values [::RMSXFlipbookTimeline::Values::assign_from_bfactors $ids \
                source_folder $source_folder slice_files $files \
                user_scale [dict get $opts user_scale] user_offset [dict get $opts user_offset]]
            foreach key {raw_min raw_max norm_min norm_max} {dict set state $key [dict get $values $key]}
            dict set state value_source [dict get $values source]
            dict set state value_file [dict get $values value_file]
            set style_args [list scene 0]
            foreach key {rep thick res aspect spline color_method color_min color_max palette} {lappend style_args $key [dict get $opts $key]}
            ::RMSXFlipbookTimeline::Style::apply $ids {*}$style_args
            set mask [dict create masked_residues 0 reps_added 0 marker_reps_added 0]
            if {[dict get $opts apply_mask] && $mask_file ne ""} {
                set mask [::RMSXFlipbookTimeline::Mask::apply $ids $mask_file opacity [dict get $opts mask_opacity] \
                    color_min [dict get $opts color_min] color_max [dict get $opts color_max]]
            }
            dict set state masked_residue_count [dict get $mask masked_residues]
            # Validate linked data before touching the existing result. PDB-only
            # flipbooks remain supported; a malformed existing CSV is an error.
            set dataset {}
            set csvs [::RMSXFlipbookTimeline::Values::candidate_csv_files $source_folder]
            if {[llength $csvs] && [info commands ::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder] ne ""} {
                set dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $source_folder]
                ::RMSXFlipbookTimeline::Matrix::validate $dataset
            }
            set result [dict create folder $source_folder files [llength $files] molecules [llength $ids] molids $ids \
                raw_min [dict get $values raw_min] raw_max [dict get $values raw_max] \
                value_source [dict get $values source] value_file [dict get $values value_file] \
                mapped_values [dict get $values record_count] assigned_atoms [dict get $values assigned_atoms] \
                masked_residues [dict get $mask masked_residues] mask_reps_added [dict get $mask reps_added] \
                mask_marker_reps_added [dict get $mask marker_reps_added] mask_file $mask_file spacing $spacing \
                view_preset [dict get $opts view_preset] manifest ""]
            # mol new can adjust the previous camera/top. Undo that immediately.
            ::RMSXFlipbookTimeline::Scene::restore_snapshot $scene
            return [dict create state $state opts $opts result $result scene $scene dataset $dataset material_before $material_before]
        } on error {message options} {
            catch {delete_molecules $ids}
            cleanup_candidate_materials $material_before
            catch {::RMSXFlipbookTimeline::Scene::restore_snapshot $scene}
            return -options $options $message
        }
    }

    proc cleanup_candidate_materials {before} {
        foreach name [material list] {
            if {[string match RMSXFlipbook_* $name] && [lsearch -exact $before $name] < 0} {
                catch {material delete $name}
                ::RMSXFlipbookTimeline::Effects::unregister "material:$name"
            }
        }
    }
    proc discard_candidate {candidate} {
        catch {delete_molecules [dict get $candidate state molids]}
        cleanup_candidate_materials [dict get $candidate material_before]
    }
    proc commit_candidate {candidate} {
        set old_state [::RMSXFlipbookTimeline::state_dict]
        set old_result [::RMSXFlipbookTimeline::Results::get]
        set new_state [dict get $candidate state]
        set ids [dict get $new_state molids]
        set opts [dict get $candidate opts]
        set result [dict get $candidate result]
        try {
            ::RMSXFlipbookTimeline::state_replace $new_state
            ::RMSXFlipbookTimeline::Style::apply_scene_settings [dict get $opts palette]
            foreach id $ids {mol on $id}
            dict set result view_preset [::RMSXFlipbookTimeline::Style::apply_view_preset [dict get $opts view_preset]]
            dict set result spacing [::RMSXFlipbookTimeline::state_get spacing]
            ::RMSXFlipbookTimeline::Style::store_initial_view_matrices $ids
            if {[dict get $opts write_manifest]} {
                set path [file join [dict get $result folder] [dict get $opts manifest_name]]
                ::RMSXFlipbookTimeline::state_set manifest_path $path
                ::RMSXFlipbookTimeline::Manifest::write $path
                dict set result manifest $path
            }
            set callback [dict get $opts activation_callback]
            if {$callback ne ""} {uplevel #0 [list {*}$callback $candidate]}
        } on error {message options} {
            discard_candidate $candidate
            ::RMSXFlipbookTimeline::state_replace $old_state
            catch {::RMSXFlipbookTimeline::Scene::restore_snapshot [dict get $candidate scene]}
            return -options $options $message
        }
        # Candidate activation passed. Dispose previous result resources, never
        # the scene lease needed by the newly displayed result.
        set committed_state [::RMSXFlipbookTimeline::state_dict]
        set warnings {}
        if {[catch {::RMSXFlipbookTimeline::Effects::cleanup_all {result window}} message]} {lappend warnings $message}
        set old_ids {}
        foreach key {owned_molids molids} {if {[dict exists $old_state $key]} {lappend old_ids {*}[dict get $old_state $key]}}
        if {[catch {delete_molecules $old_ids} message]} {lappend warnings $message}
        ::RMSXFlipbookTimeline::state_replace $committed_state
        set dataset [dict get $candidate dataset]
        if {$dataset ne {}} {set dataset [::RMSXFlipbookTimeline::TimelineIO::attach_slice_targets $dataset [dict get $result folder]]}
        set record [dict merge $result [dict create kind flipbook dataset $dataset status complete \
            label [file tail [dict get $result folder]] display_settings [::RMSXFlipbookTimeline::display_record] view_options [current_options]]]
        if {$dataset ne {}} {
            foreach {from to} {value_label metric unit units provenance provenance} {
                if {[dict exists $dataset $from]} {dict set record $to [dict get $dataset $from]}
            }
        }
        ::RMSXFlipbookTimeline::Results::publish $record
        if {[llength $warnings]} {dict set result cleanup_warnings $warnings}
        return $result
    }
    proc load_folder {folder args} {
        set candidate [prepare_folder $folder {*}$args]
        return [commit_candidate $candidate]
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

        ::RMSXFlipbookTimeline::sync_result_display
        puts "RMSX Flipbook Timeline: applied current settings"
        return $result
    }
}
