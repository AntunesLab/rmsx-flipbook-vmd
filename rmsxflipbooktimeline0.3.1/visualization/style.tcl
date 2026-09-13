################################################################################
# RMSX Flipbook Timeline style application
################################################################################

namespace eval ::RMSXFlipbookTimeline::Style {
    proc configure_display_clarity {} {
        ::RMSXFlipbookTimeline::Scene::apply depthcue off
    }

    proc valid_molid {molid} {
        if {[info commands molinfo] eq ""} {
            return 0
        }
        return [expr {[lsearch -exact [molinfo list] $molid] != -1}]
    }

    proc normalize_matrix {matrix} {
        if {[llength $matrix] == 1} {
            set inner [lindex $matrix 0]
            if {[llength $inner] == 4 && [llength [lindex $inner 0]] == 4} {
                return $inner
            }
        }
        return $matrix
    }

    proc inverse_rotation_matrix {matrix} {
        set m [normalize_matrix $matrix]
        if {[llength $m] != 4} {
            return [transidentity]
        }

        for {set row 0} {$row < 4} {incr row} {
            if {[llength [lindex $m $row]] != 4} {
                return [transidentity]
            }
        }

        return [list \
            [list [lindex $m 0 0] [lindex $m 1 0] [lindex $m 2 0] 0.0] \
            [list [lindex $m 0 1] [lindex $m 1 1] [lindex $m 2 1] 0.0] \
            [list [lindex $m 0 2] [lindex $m 1 2] [lindex $m 2 2] 0.0] \
            [list 0.0 0.0 0.0 1.0]]
    }

    proc orthonormal_rotation_matrix {matrix} {
        set m [normalize_matrix $matrix]
        # VMD's stored rotation matrices accumulate small floating-point errors.
        # Their transpose is an inverse only after removing this scale/shear.
        set x [lrange [lindex $m 0] 0 2]
        set y [lrange [lindex $m 1] 0 2]
        if {[veclength $x] < 1.0e-12} {error "Degenerate display rotation axis"}
        set x [vecnorm $x]
        set y [vecsub $y [vecscale [vecdot $x $y] $x]]
        if {[veclength $y] < 1.0e-12} {error "Degenerate display rotation basis"}
        set y [vecnorm $y]
        set z [vecnorm [veccross $x $y]]
        return [list [concat $x 0.0] [concat $y 0.0] [concat $z 0.0] {0.0 0.0 0.0 1.0}]
    }

    proc display_delta_to_coordinate_delta {view_matrix display_delta} {
        set view [orthonormal_rotation_matrix $view_matrix]
        set inverse_view [inverse_rotation_matrix $view]
        # The native multiplication can round again. Keep the final coordinate
        # update rigid too, including during a sustained mouse flick/spin.
        return [orthonormal_rotation_matrix [transmult $inverse_view $display_delta $view]]
    }

    proc capture_view_matrices {{molids ""}} {
        if {$molids eq ""} {
            set molids [::RMSXFlipbookTimeline::state_get molids {}]
        }
        set snapshots {}
        foreach molid $molids {
            if {![valid_molid $molid]} {
                continue
            }
            set item [dict create molid $molid]
            foreach key {rotate_matrix global_matrix center_matrix scale_matrix} {
                if {![catch {set value [molinfo $molid get $key]}]} {
                    dict set item $key [normalize_matrix $value]
                }
            }
            lappend snapshots $item
        }
        return $snapshots
    }

    proc store_initial_view_matrices {{molids ""}} {
        set snapshots [capture_view_matrices $molids]
        ::RMSXFlipbookTimeline::state_set initial_view_matrices $snapshots
        return [llength $snapshots]
    }

    proc set_molecule_matrix {molid key value} {
        if {![valid_molid $molid] || ![dict exists $value $key]} {
            return 0
        }

        set matrix [dict get $value $key]
        set was_fixed 0
        if {![catch {molinfo $molid get fixed} fixed_value] && $fixed_value} {
            set was_fixed 1
            catch {molinfo $molid set fixed 0}
        }
        try {
            molinfo $molid set $key [list $matrix]
        } finally {
            if {$was_fixed} {
                catch {molinfo $molid set fixed 1}
            }
        }
        return 1
    }

    proc restore_initial_view_matrices {{molids ""}} {
        set snapshots [::RMSXFlipbookTimeline::state_get initial_view_matrices {}]
        if {[llength $snapshots] == 0} {
            return 0
        }

        set restore_filter {}
        if {$molids ne ""} {
            foreach molid $molids {
                dict set restore_filter $molid 1
            }
        }

        set restored 0
        foreach item $snapshots {
            if {![dict exists $item molid]} {
                continue
            }
            set molid [dict get $item molid]
            if {[dict size $restore_filter] > 0 && ![dict exists $restore_filter $molid]} {
                continue
            }
            if {![valid_molid $molid]} {
                continue
            }
            foreach key {center_matrix global_matrix scale_matrix rotate_matrix} {
                set_molecule_matrix $molid $key $item
            }
            incr restored
        }
        return $restored
    }

    proc coordinate_delta_for_display_axis {molid axis angle} {
        set display_delta [transaxis $axis $angle]
        if {![valid_molid $molid]} {
            return $display_delta
        }
        set view_matrix [normalize_matrix [molinfo $molid get rotate_matrix]]
        return [display_delta_to_coordinate_delta $view_matrix $display_delta]
    }

    proc delete_all_reps {molid} {
        set numreps [molinfo $molid get numreps]
        for {set repid [expr {$numreps - 1}]} {$repid >= 0} {incr repid -1} {
            catch {mol delrep $repid $molid}
        }
    }

    proc apply_palette {palette} {
        if {[catch {::RMSXFlipbookTimeline::Scene::apply palette $palette} err]} {
            puts "RMSX Flipbook Timeline: could not apply palette '$palette' ($err), trying viridis"
            if {[catch {::RMSXFlipbookTimeline::Scene::apply palette viridis}]} {
                catch {::RMSXFlipbookTimeline::Scene::apply palette BWR}
                return BWR
            }
            return viridis
        }
        return $palette
    }

    proc rep_indices {molid} {
        set rep_ids {}
        set numreps [molinfo $molid get numreps]
        for {set repid 0} {$repid < $numreps} {incr repid} {
            lappend rep_ids $repid
        }
        return $rep_ids
    }

    proc default_rep {} {
        # VMD 1.9.4 lacks NewTube. Its Tube ignores per-residue user values;
        # NewCartoon with the existing unit aspect ratio supports modulation.
        if {[info commands vmdinfo] ne "" && [package vcompare [vmdinfo version] 2.0a1] < 0} {return NewCartoon}
        return NewTube
    }
    proc default_resolution {} {
        # Legacy NewCartoon tessellates a surface mesh rather than NewTube's
        # tube primitives; 12 gives a smooth balanced mesh without excessive rays.
        return [expr {[default_rep] eq "NewCartoon" ? 12 : 32}]
    }
    proc representation_choices {} {
        set styles {NewTube NewCartoon Tube Ribbon Lines Licorice}
        if {[default_rep] eq "NewCartoon"} {set styles [lrange $styles 1 end]}
        return $styles
    }

    proc representation_args {rep thick res aspect spline} {
        switch -- $rep {
            Lines {
                return [list Lines]
            }
            Tube {
                return [list Tube $thick $res]
            }
            Licorice {
                return [list Licorice $thick $thick $res]
            }
            default {
                return [list $rep $thick $res $aspect $spline]
            }
        }
    }

    proc apply_geometry {molids rep thick res aspect spline} {
        set rep_args [representation_args $rep $thick $res $aspect $spline]
        foreach molid $molids {
            foreach repid [rep_indices $molid] {
                mol modstyle $repid $molid {*}$rep_args
                set actual [lindex [lindex [molinfo $molid get [list [list representation $repid]]] 0] 0]
                if {![string equal -nocase $actual $rep]} {error "Representation $rep is unavailable in this VMD build (VMD retained $actual); choose Tube or Lines"}
            }
        }
    }

    proc apply_color {molids color_method color_min color_max} {
        if {$color_max <= $color_min} {
            set color_max [expr {$color_min + 0.1}]
        }

        foreach molid $molids {
            foreach repid [rep_indices $molid] {
                mol modcolor $repid $molid $color_method
                mol scaleminmax $molid $repid $color_min $color_max
                catch {mol colupdate $repid $molid on}
            }
        }
    }

    proc center_row_top_molecule {} {
        set available {}
        foreach molid [::RMSXFlipbookTimeline::state_get molids {}] {
            if {[lsearch -exact [molinfo list] $molid] != -1} {
                lappend available $molid
            }
        }

        set count [llength $available]
        if {$count == 0} {
            return ""
        }

        set molid [lindex $available [expr {int(($count - 1) / 2)}]]
        catch {mol top $molid}
        return $molid
    }

    proc row_bounds {molids} {
        set have_atoms 0
        set row_min {}
        set row_max {}

        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }

            set sel [atomselect $molid "all"]
            try {
                if {[$sel num] == 0} {
                    continue
                }

                set bounds [measure minmax $sel]
                set local_min [lindex $bounds 0]
                set local_max [lindex $bounds 1]
                if {!$have_atoms} {
                    set row_min $local_min
                    set row_max $local_max
                    set have_atoms 1
                    continue
                }

                for {set i 0} {$i < 3} {incr i} {
                    if {[lindex $local_min $i] < [lindex $row_min $i]} {
                        lset row_min $i [lindex $local_min $i]
                    }
                    if {[lindex $local_max $i] > [lindex $row_max $i]} {
                        lset row_max $i [lindex $local_max $i]
                    }
                }
            } finally {
                catch {$sel delete}
            }
        }

        if {!$have_atoms} {
            return ""
        }
        return [dict create min $row_min max $row_max]
    }

    proc row_bound_corners {bounds {rotate_side 0}} {
        set mins [dict get $bounds min]
        set maxs [dict get $bounds max]
        set transform ""
        if {$rotate_side} {
            set transform [transaxis x 90]
        }
        set corners {}
        foreach x [list [lindex $mins 0] [lindex $maxs 0]] {
            foreach y [list [lindex $mins 1] [lindex $maxs 1]] {
                foreach z [list [lindex $mins 2] [lindex $maxs 2]] {
                    set coords [list $x $y $z]
                    if {$transform ne ""} {
                        set coords [coordtrans $transform $coords]
                    }
                    lappend corners $coords
                }
            }
        }
        return $corners
    }

    proc create_row_view_anchor {{rotate_side 0}} {
        set available {}
        foreach molid [::RMSXFlipbookTimeline::state_get molids {}] {
            if {[lsearch -exact [molinfo list] $molid] != -1} {
                lappend available $molid
            }
        }
        if {[llength $available] == 0} {
            return ""
        }

        set bounds [row_bounds $available]
        if {$bounds eq ""} {
            return ""
        }

        set anchor ""
        set anchor_path ""
        if {[catch {
            set fp [file tempfile anchor_path rmsx_view_anchor_]
            try {
                set atom_id 1
                foreach coords [row_bound_corners $bounds $rotate_side] {
                    puts $fp [format {ATOM  %5d  C   ANC A%4d    %8.3f%8.3f%8.3f  0.00  0.00           C} \
                        $atom_id \
                        $atom_id \
                        [lindex $coords 0] \
                        [lindex $coords 1] \
                        [lindex $coords 2]]
                    incr atom_id
                }
                puts $fp "END"
            } finally {
                catch {close $fp}
            }

            mol new $anchor_path type pdb waitfor all
            set anchor [molinfo top get id]
        } err]} {
            if {$anchor_path ne ""} {
                catch {file delete $anchor_path}
            }
            center_row_top_molecule
            return ""
        }
        if {$anchor_path ne ""} {
            catch {file delete $anchor_path}
        }

        catch {mol top $anchor}
        return $anchor
    }

    proc delete_row_view_anchor {anchor} {
        if {$anchor ne "" && [lsearch -exact [molinfo list] $anchor] != -1} {
            catch {mol delete $anchor}
        }
    }

    proc axis_vector {axis amount} {
        set cleaned [string tolower [string trim $axis]]
        if {![string is double -strict $amount]} {
            error "Nudge amount must be numeric"
        }
        set amount [expr {double($amount)}]
        switch -- $cleaned {
            x { return [list $amount 0.0 0.0] }
            y { return [list 0.0 $amount 0.0] }
            z { return [list 0.0 0.0 $amount] }
        }
        error "Nudge axis must be x, y, or z"
    }

    proc nudge_row {axis amount} {
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $molids] == 0} {
            error "No flipbook molecules are loaded"
        }
        set vector [axis_vector $axis $amount]
        set result [::RMSXFlipbookTimeline::Layout::move_molids_by $molids $vector]
        set offsets [::RMSXFlipbookTimeline::state_get layout_offsets {}]
        if {[llength $offsets] > 0} {
            ::RMSXFlipbookTimeline::state_set layout_offsets [::RMSXFlipbookTimeline::Layout::add_offset_vectors $offsets $vector]
        }
        catch {display update}
        return [dict merge $result [dict create axis [string tolower [string trim $axis]] amount [expr {double($amount)}]]]
    }

    proc view_diagnostics {} {
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        set available {}
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] != -1} {
                lappend available $molid
            }
        }
        set out [dict create molids $available count [llength $available]]
        if {![catch {display get size} size]} {
            dict set out display_size $size
        }
        if {![catch {display get projection} projection]} {
            dict set out projection $projection
        }
        if {![catch {molinfo top} top]} {
            dict set out top_molid $top
        }
        if {[llength $available] > 0} {
            set bounds [row_bounds $available]
            dict set out row_bounds $bounds
            if {$bounds ne ""} {
                set center {}
                for {set i 0} {$i < 3} {incr i} {
                    lappend center [expr {([lindex [dict get $bounds min] $i] + [lindex [dict get $bounds max] $i]) / 2.0}]
                }
                dict set out row_bounds_center $center
            }
            set middle [lindex $available [expr {int(([llength $available] - 1) / 2)}]]
            dict set out middle_molid $middle
            foreach key {center_matrix rotate_matrix scale_matrix global_matrix} {
                if {![catch {molinfo $middle get $key} value]} {
                    dict set out middle_$key $value
                }
            }
        }
        return $out
    }

    proc reset_display_on_row {{rotate_side 0}} {
        configure_display_clarity
        set unrelated {}
        set owned [::RMSXFlipbookTimeline::state_get molids {}]
        foreach id [molinfo list] {if {[lsearch -exact $owned $id] < 0} {lappend unrelated $id}}
        set previous_views [capture_view_matrices $unrelated]
        set anchor [create_row_view_anchor $rotate_side]
        try {
            catch {display resetview}
            if {$rotate_side} {
                catch {rotate x by 90}
            }
        } finally {
            delete_row_view_anchor $anchor
            foreach item $previous_views {
                foreach key {center_matrix global_matrix scale_matrix rotate_matrix} {set_molecule_matrix [dict get $item molid] $key $item}
            }
            center_row_top_molecule
            catch {display update}
        }
    }

    proc apply_view_preset {preset} {
        set cleaned [string tolower [string trim $preset]]
        if {$cleaned in {"" current manual none preserve}} {
            ::RMSXFlipbookTimeline::state_set view_preset current
            return current
        }

        if {$cleaned in {principal default upright}} {
            ::RMSXFlipbookTimeline::PrincipalView::apply
            return principal
        }

        if {$cleaned in {rmsx side side-on sideon y y-axis yaxis}} {
            if {[info commands ::RMSXFlipbookTimeline::MouseRotate::without_intercept] ne ""} {
                ::RMSXFlipbookTimeline::MouseRotate::without_intercept {
                    ::RMSXFlipbookTimeline::Style::reset_display_on_row 1
                }
            } else {
                reset_display_on_row 1
            }
            ::RMSXFlipbookTimeline::state_set view_preset rmsx
            return rmsx
        }

        if {$cleaned eq "reset"} {
            if {[info commands ::RMSXFlipbookTimeline::MouseRotate::without_intercept] ne ""} {
                ::RMSXFlipbookTimeline::MouseRotate::without_intercept {
                    ::RMSXFlipbookTimeline::Style::reset_display_on_row 0
                }
            } else {
                reset_display_on_row 0
            }
            ::RMSXFlipbookTimeline::state_set view_preset reset
            return reset
        }

        error "Unknown RMSX view preset '$preset'. Use principal, rmsx, current, or reset."
    }

    proc reset_view {} {
        set preset [apply_view_preset principal]
        set restored [store_initial_view_matrices]
        catch {display update}
        return [dict create view_preset $preset restored_molecules $restored]
    }

    proc apply_scene_settings {palette} {
        foreach name {VMDMODULATERIBBON VMDMODULATENEWTUBE VMDMODULATENEWCARTOON} {::RMSXFlipbookTimeline::Scene::apply_environment $name user}
        set applied [apply_palette $palette]
        foreach {key value} {projection Orthographic axes Off stage Off background white depthcue off} {
            ::RMSXFlipbookTimeline::Scene::apply $key $value
        }
        # Prefer smooth interactive shading where the native display supports it.
        # Keep these queryable settings in scene leases so Remove preserves any
        # later user changes, and a headless/older display remains usable.
        if {![catch {display get rendermodes} modes] && [lsearch -exact $modes GLSL] >= 0} {
            catch {::RMSXFlipbookTimeline::Scene::apply rendermode GLSL}
        }
        catch {::RMSXFlipbookTimeline::Scene::apply antialias on}
        return $applied
    }

    proc apply {molids args} {
        global env
        set defaults [dict create \
            rep [default_rep] \
            thick 0.30 \
            res [default_resolution] \
            aspect 1.00 \
            spline 0 \
            color_method User2 \
            color_min 0.0 \
            color_max 10.0 \
            palette viridis \
            scene 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set rep [dict get $opts rep]
        set thick [dict get $opts thick]
        set res [dict get $opts res]
        set aspect [dict get $opts aspect]
        set spline [dict get $opts spline]
        set color_method [dict get $opts color_method]
        set color_min [dict get $opts color_min]
        set color_max [dict get $opts color_max]

        if {[dict get $opts scene]} {::RMSXFlipbookTimeline::Scene::apply_environment VMDMODULATERIBBON user}
        if {[dict get $opts scene]} {::RMSXFlipbookTimeline::Scene::apply_environment VMDMODULATENEWTUBE user}
        if {[dict get $opts scene]} {::RMSXFlipbookTimeline::Scene::apply_environment VMDMODULATENEWCARTOON user}

        foreach molid $molids {
            delete_all_reps $molid
            mol representation {*}[representation_args $rep $thick $res $aspect $spline]
            mol selection all
            mol addrep $molid
            set repid [expr {[molinfo $molid get numreps] - 1}]
            catch {mol modmaterial $repid $molid AOChalky}
        }

        apply_geometry $molids $rep $thick $res $aspect $spline
        apply_color $molids $color_method $color_min $color_max
        set applied_palette [dict get $opts palette]
        if {[dict get $opts scene]} {
            set applied_palette [apply_scene_settings $applied_palette]
        }

        if {![::RMSXFlipbookTimeline::truthy [::RMSXFlipbookTimeline::state_get quiet_console 0]]} {
            puts [format {RMSX Flipbook Timeline: style rep=%s color=%s range=%.2f..%.2f palette=%s} \
                $rep $color_method $color_min $color_max $applied_palette]
        }
        return $applied_palette
    }
}
