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

    proc install {} {
        variable installed
        variable bindings
        set registered {}
        set errors {}
        foreach {key script} $bindings {
            if {[catch {user add key $key $script} err]} {
                lappend errors [list $key $err]
            } else {
                lappend registered $key
            }
        }
        if {[llength $errors] == 0} {
            set installed 1
        }
        puts {RMSX Flipbook Timeline hotkeys: u/i X-rotate, n/m Y-rotate, j/k Z-rotate, +/- spacing, [/] thickness, 9/0/_/; size modulation, ,/. color range, c color toggle}
        return [dict create installed $installed keys $registered errors $errors]
    }
}
