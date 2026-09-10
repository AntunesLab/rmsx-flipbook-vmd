################################################################################
# RMSX Flipbook Timeline VMD hotkey-style controls
################################################################################

namespace eval ::RMSXFlipbookTimeline::Hotkeys {
    variable installed 0
    variable bindings {
        u {::RMSXFlipbookTimeline::Hotkeys::rotate_all x 5}
        i {::RMSXFlipbookTimeline::Hotkeys::rotate_all x -5}
        n {::RMSXFlipbookTimeline::Hotkeys::rotate_all y 5}
        m {::RMSXFlipbookTimeline::Hotkeys::rotate_all y -5}
        j {::RMSXFlipbookTimeline::Hotkeys::rotate_all z 5}
        k {::RMSXFlipbookTimeline::Hotkeys::rotate_all z -5}
        = {::RMSXFlipbookTimeline::Hotkeys::adjust_spacing 2.0}
        + {::RMSXFlipbookTimeline::Hotkeys::adjust_spacing 2.0}
        - {::RMSXFlipbookTimeline::Hotkeys::adjust_spacing -2.0}
        {[} {::RMSXFlipbookTimeline::Hotkeys::adjust_thickness 0.05}
        {]} {::RMSXFlipbookTimeline::Hotkeys::adjust_thickness -0.05}
        9 {::RMSXFlipbookTimeline::Hotkeys::adjust_user_scale 0.9}
        0 {::RMSXFlipbookTimeline::Hotkeys::adjust_user_scale 1.1}
        _ {::RMSXFlipbookTimeline::Hotkeys::adjust_user_offset -0.2}
        {;} {::RMSXFlipbookTimeline::Hotkeys::adjust_user_offset 0.2}
        {,} {::RMSXFlipbookTimeline::Hotkeys::adjust_color_min 0.5}
        {.} {::RMSXFlipbookTimeline::Hotkeys::adjust_color_max 0.5}
        c {::RMSXFlipbookTimeline::Hotkeys::toggle_color_method}
    }

    proc loaded_molids {} {
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        set existing {}
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] != -1} {
                lappend existing $molid
            }
        }
        if {[llength $existing] == 0} {
            error "No RMSX flipbook molecules are loaded"
        }
        return $existing
    }

    proc state_number {key default} {
        set value [::RMSXFlipbookTimeline::state_get $key $default]
        if {![string is double -strict $value]} {
            return $default
        }
        return [expr {double($value)}]
    }

    proc molecule_center {molid} {
        set sel [atomselect $molid all]
        try {
            if {[$sel num] == 0} {
                return {0.0 0.0 0.0}
            }
            if {[catch {measure center $sel weight mass} center]} {
                set center [measure center $sel]
            }
            return $center
        } finally {
            catch {$sel delete}
        }
    }

    proc rotate_all {axis angle} {
        set axis [string tolower [string trim $axis]]
        if {$axis ni {x y z}} {
            error "Rotation axis must be x, y, or z"
        }
        set angle [expr {double($angle)}]
        set moved 0
        foreach molid [loaded_molids] {
            if {![catch {molinfo $molid get fixed} fixed] && $fixed} {
                continue
            }
            set sel [atomselect $molid all]
            try {
                if {[$sel num] == 0} {
                    continue
                }
                set center [molecule_center $molid]
                set matrix [::RMSXFlipbookTimeline::Style::coordinate_delta_for_display_axis \
                    $molid \
                    $axis \
                    $angle]
                $sel moveby [vecscale -1 $center]
                $sel move $matrix
                $sel moveby $center
                incr moved
            } finally {
                catch {$sel delete}
            }
        }
        puts [format {RMSX Flipbook Timeline hotkey: rotated %d molecules around %s by %.2f degrees} $moved $axis $angle]
        return [dict create rotated $moved axis $axis angle $angle axis_frame display]
    }

    proc set_spacing {spacing} {
        set spacing [expr {double($spacing)}]
        if {$spacing < 0.5} {
            set spacing 0.5
        }
        set molids [loaded_molids]
        set offsets [::RMSXFlipbookTimeline::Layout::set_grid_spacing \
            $molids \
            $spacing \
            [::RMSXFlipbookTimeline::state_get layout_offsets {}]]
        ::RMSXFlipbookTimeline::state_set spacing $spacing
        ::RMSXFlipbookTimeline::state_set spacing_mode manual
        ::RMSXFlipbookTimeline::state_set layout_offsets $offsets
        return [dict create spacing $spacing molids [llength $molids]]
    }

    proc adjust_spacing {delta} {
        set current [state_number spacing 0.0]
        if {$current <= 0.0} {
            set current [::RMSXFlipbookTimeline::Layout::auto_spacing [loaded_molids]]
        }
        return [set_spacing [expr {$current + double($delta)}]]
    }

    proc apply_geometry_state {} {
        set molids [loaded_molids]
        ::RMSXFlipbookTimeline::Style::apply_geometry \
            $molids \
            [::RMSXFlipbookTimeline::state_get rep NewTube] \
            [::RMSXFlipbookTimeline::state_get thick 0.30] \
            [::RMSXFlipbookTimeline::state_get res 32] \
            [::RMSXFlipbookTimeline::state_get aspect 1.00] \
            [::RMSXFlipbookTimeline::state_get spline 0]
        ::RMSXFlipbookTimeline::sync_result_display
        return $molids
    }

    proc apply_color_state {} {
        set color_min [state_number color_min 0.0]
        set color_max [state_number color_max 10.0]
        if {$color_max <= $color_min} {
            set color_max [expr {$color_min + 0.1}]
            ::RMSXFlipbookTimeline::state_set color_max $color_max
        }
        set molids [loaded_molids]
        ::RMSXFlipbookTimeline::Style::apply_color \
            $molids \
            [::RMSXFlipbookTimeline::state_get color_method User2] \
            $color_min \
            $color_max
        ::RMSXFlipbookTimeline::sync_result_display
        return $molids
    }

    proc adjust_thickness {delta} {
        set thick [expr {[state_number thick 0.30] + double($delta)}]
        if {$thick < 0.05} {
            set thick 0.05
        }
        ::RMSXFlipbookTimeline::state_set thick $thick
        set molids [apply_geometry_state]
        puts [format {RMSX Flipbook Timeline hotkey: thickness %.3f} $thick]
        return [dict create thick $thick molids [llength $molids]]
    }

    proc adjust_color_min {delta} {
        set color_min [expr {[state_number color_min 0.0] + double($delta)}]
        ::RMSXFlipbookTimeline::state_set color_min $color_min
        set molids [apply_color_state]
        return [dict create color_min [::RMSXFlipbookTimeline::state_get color_min] color_max [::RMSXFlipbookTimeline::state_get color_max] molids [llength $molids]]
    }

    proc adjust_color_max {delta} {
        set color_max [expr {[state_number color_max 10.0] + double($delta)}]
        ::RMSXFlipbookTimeline::state_set color_max $color_max
        set molids [apply_color_state]
        return [dict create color_min [::RMSXFlipbookTimeline::state_get color_min] color_max [::RMSXFlipbookTimeline::state_get color_max] molids [llength $molids]]
    }

    proc toggle_color_method {} {
        set method [::RMSXFlipbookTimeline::state_get color_method User2]
        if {$method eq "User2"} {
            set method Beta
        } else {
            set method User2
        }
        ::RMSXFlipbookTimeline::state_set color_method $method
        set molids [apply_color_state]
        puts "RMSX Flipbook Timeline hotkey: coloring by $method"
        return [dict create color_method $method molids [llength $molids]]
    }

    proc reassign_value_fields {} {
        set molids [loaded_molids]
        set value_result [::RMSXFlipbookTimeline::Values::assign_from_bfactors \
            $molids \
            source_folder [::RMSXFlipbookTimeline::state_get source_folder ""] \
            slice_files [::RMSXFlipbookTimeline::state_get slice_files {}] \
            user_scale [::RMSXFlipbookTimeline::state_get user_scale 1.0] \
            user_offset [::RMSXFlipbookTimeline::state_get user_offset 2.0]]
        ::RMSXFlipbookTimeline::state_set raw_min [dict get $value_result raw_min]
        ::RMSXFlipbookTimeline::state_set raw_max [dict get $value_result raw_max]
        ::RMSXFlipbookTimeline::state_set norm_min [dict get $value_result norm_min]
        ::RMSXFlipbookTimeline::state_set norm_max [dict get $value_result norm_max]
        ::RMSXFlipbookTimeline::state_set value_source [dict get $value_result source]
        ::RMSXFlipbookTimeline::state_set value_file [dict get $value_result value_file]
        ::RMSXFlipbookTimeline::sync_result_display
        return $value_result
    }

    proc adjust_user_scale {factor} {
        set user_scale [expr {[state_number user_scale 1.0] * double($factor)}]
        ::RMSXFlipbookTimeline::state_set user_scale $user_scale
        set result [reassign_value_fields]
        puts [format {RMSX Flipbook Timeline hotkey: user scale %.3f} $user_scale]
        return [dict merge $result [dict create user_scale $user_scale]]
    }

    proc adjust_user_offset {delta} {
        set user_offset [expr {[state_number user_offset 2.0] + double($delta)}]
        ::RMSXFlipbookTimeline::state_set user_offset $user_offset
        set result [reassign_value_fields]
        puts [format {RMSX Flipbook Timeline hotkey: user offset %.3f} $user_offset]
        return [dict merge $result [dict create user_offset $user_offset]]
    }

    variable previous {}
    variable applied {}
    proc key_bindings {} {
        set found {}
        foreach item [user list keys] {
            if {[llength $item] < 2} {error "VMD does not expose readable key bindings"}
            dict set found [lindex $item 0] [lrange $item 1 end]
        }
        return $found
    }
    proc uninstall {} {
        variable installed; variable previous; variable applied
        if {[dict size $applied] == 0} {set installed 0; return 1}
        set now [key_bindings]
        set errors {}
        dict for {key script} $applied {
            if {[dict exists $now $key] && [lindex [dict get $now $key] 0] eq $script} {
                if {[catch {
                    if {[dict exists $previous $key]} {
                        user add key $key [lindex [dict get $previous $key] 0]
                    } else {user del key $key}
                } message]} {lappend errors "$key: $message"; continue}
            }
            dict unset applied $key
        }
        if {[llength $errors]} {error [join $errors {; }]}
        set installed 0
        set previous {}
        return 1
    }
    proc install {} {
        variable installed; variable bindings; variable previous; variable applied
        if {$installed} {return [dict create installed 1 keys [dict keys $applied] errors {}]}
        if {[catch {key_bindings} prior]} {
            return [dict create installed 0 keys {} errors [list $prior] message "Global hotkeys unavailable; use the focused heatmap and panel controls."]
        }
        set previous $prior
        set errors {}; set registered {}
        foreach {key script} $bindings {
            # VMD has no supported remove-key command. Only replace readable existing bindings.
            if {![dict exists $prior $key] || [lindex [dict get $prior $key] 1] ne ""} {continue}
            if {[catch {user add key $key $script} err]} {lappend errors [list $key $err]} else {
                dict set applied $key $script
                lappend registered $key
            }
        }
        set installed [expr {[llength $errors] == 0}]
        ::RMSXFlipbookTimeline::Effects::register hotkeys ::RMSXFlipbookTimeline::Hotkeys::uninstall input
        return [dict create installed $installed keys $registered errors $errors]
    }
}
