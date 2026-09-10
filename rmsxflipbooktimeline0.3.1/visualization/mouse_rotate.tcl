################################################################################
# RMSX Flipbook Timeline mouse-style rotation prototype
################################################################################

namespace eval ::RMSXFlipbookTimeline::MouseRotate {
    variable installed 0
    variable enabled 0
    variable guard 0
    variable intercepted 0
    variable last_result {}
    variable total_us 0
    variable last_us 0
    variable max_us 0
    variable errors 0
    variable mode coords
    variable sensitivity 2.0

    proc loaded_molids {} {
        return [::RMSXFlipbookTimeline::Hotkeys::loaded_molids]
    }

    proc parse_rotate_command {command axis_var angle_var} {
        upvar 1 $axis_var axis
        upvar 1 $angle_var angle

        set cleaned [string trim $command]
        if {![regexp {^rotate[[:space:]]+([xyzXYZ])[[:space:]]+by[[:space:]]+([-+]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?)[[:space:]]*$} $cleaned _ axis angle]} {
            return 0
        }

        set axis [string tolower $axis]
        set angle [expr {double($angle)}]
        if {$angle == 0.0} {
            return 0
        }
        return 1
    }

    proc with_molecule_unfixed {molid script} {
        set was_fixed 0
        if {![catch {molinfo $molid get fixed} fixed_value] && $fixed_value} {
            set was_fixed 1
            molinfo $molid set fixed 0
        }

        try {
            uplevel 1 $script
        } finally {
            if {$was_fixed} {
                catch {molinfo $molid set fixed 1}
            }
        }
    }

    proc molecule_center {molid} {
        return [::RMSXFlipbookTimeline::Hotkeys::molecule_center $molid]
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

    proc sync_pivots {{molids ""}} {
        if {$molids eq ""} {
            set molids [loaded_molids]
        }

        set synced 0
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }
            if {[molinfo $molid get numatoms] == 0} {
                continue
            }

            set center [molecule_center $molid]
            set center_matrix [transoffset [vecinvert $center]]
            set global_matrix [transoffset $center]
            with_molecule_unfixed $molid {
                molinfo $molid set center_matrix [list $center_matrix]
                molinfo $molid set global_matrix [list $global_matrix]
            }
            incr synced
        }
        return $synced
    }

    proc apply_coordinate_rotation {axis angle} {
        set axis [string tolower [string trim $axis]]
        if {$axis ni {x y z}} {
            error "Rotation axis must be x, y, or z"
        }

        set angle [expr {double($angle)}]
        set molids [loaded_molids]
        set rotated 0

        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }
            if {[molinfo $molid get numatoms] == 0} {
                continue
            }

            set sel [atomselect $molid all]
            try {
                if {[$sel num] == 0} {
                    continue
                }
                set center [molecule_center $molid]
                set delta [::RMSXFlipbookTimeline::Style::coordinate_delta_for_display_axis \
                    $molid \
                    $axis \
                    $angle]
                $sel moveby [vecscale -1 $center]
                $sel move $delta
                $sel moveby $center
                incr rotated
            } finally {
                catch {$sel delete}
            }
        }

        return [dict create \
            rotated $rotated \
            axis $axis \
            angle $angle \
            axis_frame display \
            mode coords]
    }

    proc apply_display_rotation {axis angle} {
        set axis [string tolower [string trim $axis]]
        if {$axis ni {x y z}} {
            error "Rotation axis must be x, y, or z"
        }

        set angle [expr {double($angle)}]
        set delta [transaxis $axis $angle]
        set molids [loaded_molids]
        set rotated 0
        set fixed_restored 0

        sync_pivots $molids

        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }
            if {[molinfo $molid get numatoms] == 0} {
                continue
            }

            set current [normalize_matrix [molinfo $molid get rotate_matrix]]
            set next [transmult $delta $current]
            set was_fixed 0
            if {![catch {molinfo $molid get fixed} fixed_value] && $fixed_value} {
                set was_fixed 1
            }
            with_molecule_unfixed $molid {
                molinfo $molid set rotate_matrix [list $next]
            }
            if {$was_fixed} {
                incr fixed_restored
            }
            incr rotated
        }

        set result [dict create \
            rotated $rotated \
            axis $axis \
            angle $angle \
            fixed_restored $fixed_restored]
        return $result
    }

    proc apply_rotation {axis angle} {
        variable mode

        if {$mode eq "display"} {
            return [apply_display_rotation $axis $angle]
        }
        return [apply_coordinate_rotation $axis $angle]
    }

    proc normalize_sensitivity {value} {
        if {![string is double -strict $value]} {
            error "Mouse rotation sensitivity must be a positive number"
        }
        set value [expr {double($value)}]
        if {$value <= 0.0} {
            error "Mouse rotation sensitivity must be greater than 0"
        }
        return $value
    }

    proc set_sensitivity {value} {
        variable sensitivity
        set sensitivity [normalize_sensitivity $value]
        ::RMSXFlipbookTimeline::state_set mouse_rotation_sensitivity $sensitivity
        return [status]
    }

    proc format_status {{status_dict ""}} {
        if {$status_dict eq ""} {
            set status_dict [status]
        }
        set pieces [list \
            "enabled=[dict get $status_dict enabled]" \
            "mode=[dict get $status_dict mode]" \
            [format "sensitivity=%.2f" [dict get $status_dict sensitivity]] \
            "intercepts=[dict get $status_dict intercepted]" \
            [format "avg=%.3fms" [dict get $status_dict avg_ms]] \
            [format "last=%.3fms" [dict get $status_dict last_ms]] \
            [format "max=%.3fms" [dict get $status_dict max_ms]] \
            "errors=[dict get $status_dict errors]"]
        return [join $pieces "  "]
    }

    proc without_intercept {script} {
        variable guard
        incr guard
        try {
            uplevel 1 $script
        } finally {
            incr guard -1
        }
    }

    proc callback {name element op} {
        variable enabled
        variable guard
        variable intercepted
        variable last_result
        variable total_us
        variable last_us
        variable max_us
        variable errors
        variable sensitivity

        if {!$enabled || $guard > 0} {
            return
        }

        upvar #0 ::vmd_logfile command
        if {![info exists command]} {
            return
        }
        if {![parse_rotate_command $command axis angle]} {
            return
        }

        incr guard
        set start_us [clock clicks -microseconds]
        try {
            if {[catch {
                set scaled_angle [expr {$angle * $sensitivity}]
                catch {rotate $axis by [expr {-$angle}]}
                set last_result [apply_rotation $axis $scaled_angle]
                incr intercepted
                ::RMSXFlipbookTimeline::state_set mouse_rotation_intercepted $intercepted
            } err opts]} {
                incr errors
                set enabled 0
                set last_result [dict create error $err]
                ::RMSXFlipbookTimeline::state_set mouse_rotation_enabled 0
                puts "RMSX Flipbook Timeline mouse rotation prototype disabled after error: $err"
            }
        } finally {
            set last_us [expr {[clock clicks -microseconds] - $start_us}]
            set total_us [expr {$total_us + $last_us}]
            if {$last_us > $max_us} {
                set max_us $last_us
            }
            incr guard -1
        }
    }

    proc normalize_mode {value} {
        set cleaned [string tolower [string trim $value]]
        if {$cleaned in {"" coord coords coordinate coordinates atom atoms}} {
            return coords
        }
        if {$cleaned in {display matrix matrices transform transforms}} {
            return display
        }
        error "Mouse rotation mode must be coords or display"
    }

    proc reset_display_matrices {{molids ""}} {
        if {$molids eq ""} {
            set molids [loaded_molids]
        }
        set reset_count 0
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }
            set identity [transidentity]
            with_molecule_unfixed $molid {
                molinfo $molid set rotate_matrix [list $identity]
                molinfo $molid set global_matrix [list $identity]
            }
            incr reset_count
        }
        return $reset_count
    }

    proc count_loaded_molecules {{molids ""}} {
        if {$molids eq ""} {
            set molids [loaded_molids]
        }

        set count 0
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] != -1 && [molinfo $molid get numatoms] > 0} {
                incr count
            }
        }
        return $count
    }

    proc install {{requested_mode coords} {requested_sensitivity ""}} {
        variable installed
        variable enabled
        variable intercepted
        variable last_result
        variable mode
        variable sensitivity

        set mode [normalize_mode $requested_mode]
        if {$requested_sensitivity ne ""} {
            set sensitivity [normalize_sensitivity $requested_sensitivity]
        }
        set molids [loaded_molids]
        if {$mode eq "display"} {
            set prepared [sync_pivots $molids]
        } else {
            set prepared [count_loaded_molecules $molids]
        }
        catch {display update on}

        if {!$installed} {
            trace add variable ::vmd_logfile write ::RMSXFlipbookTimeline::MouseRotate::callback
            set installed 1
        }
        set enabled 1
        set last_result {}
        ::RMSXFlipbookTimeline::state_set mouse_rotation_enabled 1
        ::RMSXFlipbookTimeline::state_set mouse_rotation_intercepted $intercepted
        ::RMSXFlipbookTimeline::state_set mouse_rotation_mode $mode
        ::RMSXFlipbookTimeline::state_set mouse_rotation_sensitivity $sensitivity
        # Preserve the user's mouse mode; VMD provides no portable getter.

        if {![::RMSXFlipbookTimeline::truthy [::RMSXFlipbookTimeline::state_get quiet_console 0]]} {
            puts [format {RMSX Flipbook Timeline mouse rotation prototype: enabled in %s mode, sensitivity %.2f for %d molecules. Use normal rotate-drag; call ::RMSXFlipbookTimeline::uninstall_mouse_rotation to restore global rotation.} $mode $sensitivity $prepared]
        }
        return [status]
    }

    proc uninstall {} {
        variable installed
        variable enabled

        if {$installed} {
            catch {trace remove variable ::vmd_logfile write ::RMSXFlipbookTimeline::MouseRotate::callback}
            set installed 0
        }
        set enabled 0
        ::RMSXFlipbookTimeline::state_set mouse_rotation_enabled 0
        catch {display update on}
        return [status]
    }

    proc reset_stats {} {
        variable intercepted
        variable last_result
        variable total_us
        variable last_us
        variable max_us
        variable errors

        set intercepted 0
        set last_result {}
        set total_us 0
        set last_us 0
        set max_us 0
        set errors 0
        ::RMSXFlipbookTimeline::state_set mouse_rotation_intercepted 0
        return [status]
    }

    proc burst {{count 240} {axis y} {angle 0.75}} {
        set count [expr {int($count)}]
        set axis [string tolower [string trim $axis]]
        set angle [expr {double($angle)}]
        if {$count < 1} {
            error "Burst count must be positive"
        }
        if {$axis ni {x y z}} {
            error "Burst axis must be x, y, or z"
        }

        reset_stats
        set start_us [clock clicks -microseconds]
        for {set i 0} {$i < $count} {incr i} {
            rotate $axis by $angle
        }
        catch {display update}
        set elapsed_ms [expr {([clock clicks -microseconds] - $start_us) / 1000.0}]
        set status_dict [status]
        set per_rotate [expr {$elapsed_ms / double($count)}]
        return [dict merge $status_dict [dict create \
            burst_count $count \
            burst_axis $axis \
            burst_angle $angle \
            burst_total_ms $elapsed_ms \
            burst_loop_avg_ms $per_rotate]]
    }

    proc status {} {
        variable installed
        variable enabled
        variable intercepted
        variable last_result
        variable total_us
        variable last_us
        variable max_us
        variable errors
        variable mode
        variable sensitivity

        set total_ms [expr {$total_us / 1000.0}]
        set last_ms [expr {$last_us / 1000.0}]
        set max_ms [expr {$max_us / 1000.0}]
        set avg_ms 0.0
        if {$intercepted > 0} {
            set avg_ms [expr {$total_ms / double($intercepted)}]
        }

        return [dict create \
            installed $installed \
            enabled $enabled \
            mode $mode \
            sensitivity $sensitivity \
            intercepted $intercepted \
            total_ms $total_ms \
            avg_ms $avg_ms \
            last_ms $last_ms \
            max_ms $max_ms \
            errors $errors \
            last_result $last_result]
    }
}
