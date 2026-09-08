################################################################################
# RMSX Flipbook Timeline layout
################################################################################

namespace eval ::RMSXFlipbookTimeline::Layout {
    proc auto_spacing {molids} {
        if {[llength $molids] == 0} {
            return 0.0
        }

        set first_mol [lindex $molids 0]
        set sel [atomselect $first_mol "all"]
        set center [measure center $sel]
        set maxdist 0.0
        foreach pos [$sel get {x y z}] {
            set dist [vecdist $center $pos]
            if {$dist > $maxdist} {
                set maxdist $dist
            }
        }
        $sel delete

        if {$maxdist <= 0.0} {
            return 10.0
        }
        return [expr {$maxdist * 2.2}]
    }

    proc offset_vector {offset} {
        if {[llength $offset] == 0} {
            return {0.0 0.0 0.0}
        }
        if {[llength $offset] >= 3} {
            return [list \
                [lindex $offset 0] \
                [lindex $offset 1] \
                [lindex $offset 2]]
        }
        return [list $offset 0.0 0.0]
    }

    proc molecule_center {molid} {
        set sel [atomselect $molid "all"]
        try {
            if {[$sel num] == 0} {
                return {0.0 0.0 0.0}
            }
            return [measure center $sel]
        } finally {
            catch {$sel delete}
        }
    }

    proc molecule_centers {molids} {
        set centers {}
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                lappend centers {0.0 0.0 0.0}
            } else {
                lappend centers [molecule_center $molid]
            }
        }
        return $centers
    }

    proc molecule_bounds {molid} {
        if {[lsearch -exact [molinfo list] $molid] == -1} {
            return {0.0 0.0 0.0 0.0 0.0 0.0}
        }
        set sel [atomselect $molid "all"]
        try {
            if {[$sel num] == 0} {
                return {0.0 0.0 0.0 0.0 0.0 0.0}
            }
            set minmax [measure minmax $sel]
            set mins [lindex $minmax 0]
            set maxs [lindex $minmax 1]
            return [list \
                [lindex $mins 0] [lindex $maxs 0] \
                [lindex $mins 1] [lindex $maxs 1] \
                [lindex $mins 2] [lindex $maxs 2]]
        } finally {
            catch {$sel delete}
        }
    }

    proc row_bounds_center {molids} {
        set have 0
        foreach molid $molids {
            lassign [molecule_bounds $molid] min_x max_x min_y max_y min_z max_z
            if {!$have} {
                set row_min_y $min_y
                set row_max_y $max_y
                set row_min_z $min_z
                set row_max_z $max_z
                set have 1
            } else {
                set row_min_y [expr {min($row_min_y, $min_y)}]
                set row_max_y [expr {max($row_max_y, $max_y)}]
                set row_min_z [expr {min($row_min_z, $min_z)}]
                set row_max_z [expr {max($row_max_z, $max_z)}]
            }
        }
        if {!$have} {
            return {0.0 0.0}
        }
        return [list \
            [expr {($row_min_y + $row_max_y) / 2.0}] \
            [expr {($row_min_z + $row_max_z) / 2.0}]]
    }

    proc row_center {centers} {
        set count [llength $centers]
        if {$count == 0} {
            return {0.0 0.0 0.0}
        }

        set total_x 0.0
        set total_y 0.0
        set total_z 0.0
        foreach center $centers {
            set total_x [expr {$total_x + [lindex $center 0]}]
            set total_y [expr {$total_y + [lindex $center 1]}]
            set total_z [expr {$total_z + [lindex $center 2]}]
        }

        return [list \
            [expr {$total_x / double($count)}] \
            [expr {$total_y / double($count)}] \
            [expr {$total_z / double($count)}]]
    }

    proc undo_offsets {molids offsets} {
        if {[llength $offsets] == 0} {
            return
        }

        foreach molid $molids offset $offsets {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }

            set vector [offset_vector $offset]
            set sel [atomselect $molid "all"]
            $sel moveby [list \
                [expr {-[lindex $vector 0]}] \
                [expr {-[lindex $vector 1]}] \
                [expr {-[lindex $vector 2]}]]
            $sel delete
        }
    }

    proc move_molids_by {molids vector} {
        set moved 0
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }
            set sel [atomselect $molid "all"]
            try {
                if {[$sel num] == 0} {
                    continue
                }
                $sel moveby $vector
                incr moved
            } finally {
                catch {$sel delete}
            }
        }
        return [dict create moved $moved vector $vector]
    }

    proc add_offset_vectors {offsets vector} {
        set updated {}
        foreach offset $offsets {
            set current [offset_vector $offset]
            lappend updated [list \
                [expr {[lindex $current 0] + [lindex $vector 0]}] \
                [expr {[lindex $current 1] + [lindex $vector 1]}] \
                [expr {[lindex $current 2] + [lindex $vector 2]}]]
        }
        return $updated
    }

    proc set_grid_spacing {molids spacing {previous_offsets {}}} {
        set count [llength $molids]
        if {$count == 0} {
            return {}
        }

        undo_offsets $molids $previous_offsets

        set centers [molecule_centers $molids]
        lassign [row_bounds_center $molids] row_y row_z
        set start_x [expr {-0.5 * ($count - 1) * $spacing}]

        for {set i 0} {$i < $count} {incr i} {
            set molid [lindex $molids $i]
            set center [lindex $centers $i]
            set target_x [expr {$start_x + ($i * $spacing)}]
            set dx [expr {$target_x - [lindex $center 0]}]
            set dy [expr {-$row_y}]
            set dz [expr {-$row_z}]
            set offset [list $dx $dy $dz]
            lappend offsets $offset
            set sel [atomselect $molid "all"]
            $sel moveby $offset
            $sel delete
        }

        if {![::RMSXFlipbookTimeline::truthy [::RMSXFlipbookTimeline::state_get quiet_console 0]]} {
            puts [format {RMSX Flipbook Timeline: positioned %d molecules, centered spacing %.2f A} $count $spacing]
        }
        return $offsets
    }
}
