# Per-canvas cell navigation. Views retain their own records across pop-outs.
namespace eval ::RMSXFlipbookTimeline::Navigation {
    variable views {}
    proc forget {canvas actual} {
        variable views
        if {$canvas eq $actual} {dict unset views $canvas}
    }
    proc available {canvas} {
        variable views
        return [expr {[dict exists $views $canvas] && [info commands winfo] ne "" && [winfo exists $canvas]}]
    }
    proc busy {} {
        return [expr {[info commands ::RMSXFlipbookTimeline::Operation::running] ne "" && [::RMSXFlipbookTimeline::Operation::running]}]
    }
    proc inactive {canvas} {
        return [expr {[info commands ::RMSXFlipbookTimeline::HeatmapTools::state] ne "" && [::RMSXFlipbookTimeline::HeatmapTools::state $canvas] ne {} && ![::RMSXFlipbookTimeline::HeatmapTools::valid $canvas]}]
    }
    proc attach {canvas records select_command clear_command} {
        variable views
        if {$canvas eq "" || [info commands winfo] eq "" || ![winfo exists $canvas]} {return}
        set cells {}
        foreach record $records {
            if {![dict exists $record row] || ![dict exists $record column]} {continue}
            if {[dict exists $record kind] && [dict get $record kind] ni {cell heat_cell}} {continue}
            dict set cells [list [dict get $record row] [dict get $record column]] $record
        }
        set selected {}
        if {[dict exists $views $canvas selected]} {set selected [dict get $views $canvas selected]}
        # A redraw creates new canvas IDs. Attaching a second callback to the
        # same drawing must not reset its transform or multiply it again.
        set items [$canvas find all]
        set same 0
        if {[dict exists $views $canvas items] && [dict get $views $canvas cells] eq $cells} {
            foreach id [dict get $views $canvas items] {
                if {[lsearch -exact $items $id] >= 0} {set same 1; break}
            }
        }
        if {!$same} {
            set region [$canvas bbox all]
            if {[llength $region] != 4} {set region {0 0 1 1}}
            lassign $region x0 y0 x1 y1
            set region [list [expr {min(0,$x0-8)}] [expr {min(0,$y0-8)}] [expr {$x1+8}] [expr {$y1+8}]]
            dict set views $canvas [dict create sx 1.0 sy 1.0 base_region $region items $items labels {} label_items {} every 0 drag {}]
        }
        dict set views $canvas cells $cells
        dict set views $canvas select $select_command
        dict set views $canvas clear $clear_command
        dict set views $canvas selected $selected
        $canvas configure -takefocus 1 -highlightthickness 1 -highlightcolor "#2563eb"
        foreach key {Left Right Up Down Home End Return Escape Control-Home Control-End} {
            bind $canvas <$key> "[list ::RMSXFlipbookTimeline::Navigation::key $canvas $key]; break"
        }
        bind $canvas <Button-1> [list focus $canvas]
        bind $canvas <ButtonPress-3> "[list ::RMSXFlipbookTimeline::Navigation::rectangle_start $canvas %x %y]; break"
        bind $canvas <B3-Motion> "[list ::RMSXFlipbookTimeline::Navigation::rectangle_move $canvas %x %y]; break"
        bind $canvas <ButtonRelease-3> "[list ::RMSXFlipbookTimeline::Navigation::rectangle_end $canvas %x %y]; break"
        foreach {event axis amount} {<MouseWheel> y %D <Shift-MouseWheel> x %D <Button-4> y 120 <Button-5> y -120 <Shift-Button-4> x 120 <Shift-Button-5> x -120} {
            bind $canvas $event "[list ::RMSXFlipbookTimeline::Navigation::wheel $canvas $axis $amount]; break"
        }
        bind $canvas <Destroy> [list ::RMSXFlipbookTimeline::Navigation::forget $canvas %W]
        $canvas bind pickable <Button-1> [list ::RMSXFlipbookTimeline::Navigation::pick $canvas %x %y]
        $canvas bind pickable <B1-Motion> [list ::RMSXFlipbookTimeline::Navigation::pick $canvas %x %y]
        if {$selected ne {} && [dict exists $cells $selected]} {
            set record [dict get $cells $selected]
            highlight $canvas $record
        }
    }
    proc highlight {canvas record} {
        $canvas delete keyboard_selection
        lassign [to_canvas $canvas [dict get $record x0] [dict get $record y0]] x0 y0
        lassign [to_canvas $canvas [dict get $record x1] [dict get $record y1]] x1 y1
        $canvas create rectangle $x0 $y0 $x1 $y1 \
            -outline "#2563eb" -width 2 -tags keyboard_selection
    }
    proc choose {canvas coordinate} {
        variable views
        if {![dict exists $views $canvas cells $coordinate]} {return {}}
        if {[busy] || [inactive $canvas]} {return {}}
        set view [dict get $views $canvas]
        set record [dict get $view cells $coordinate]
        # Selection callbacks continue to receive model geometry. Transform
        # only the new markers they draw, including comparison-chart markers.
        set before {}
        foreach id [$canvas find all] {dict set before $id 1}
        try {
            set answer [uplevel #0 [list {*}[dict get $view select] $record]]
        } finally {
            if {[winfo exists $canvas]} {
                foreach id [$canvas find all] {
                    if {![dict exists $before $id]} {$canvas scale $id 0 0 [dict get $view sx] [dict get $view sy]}
                }
            }
        }
        dict set views $canvas selected $coordinate
        if {[winfo exists $canvas]} {highlight $canvas $record; reveal $canvas $record}
        if {[::RMSXFlipbookTimeline::Results::get] ne {}} {
            ::RMSXFlipbookTimeline::Results::update [dict create selected_cell $coordinate]
        }
        if {[info commands ::RMSXFlipbookTimeline::HeatmapTools::selection_changed] ne ""} {
            ::RMSXFlipbookTimeline::HeatmapTools::selection_changed $canvas $coordinate
        }
        return $answer
    }
    proc reveal {canvas record} {
        set region [$canvas cget -scrollregion]
        if {[llength $region] != 4} {return}
        variable views
        foreach axis {x y} {
            set factor [dict get $views $canvas s$axis]
            set start [expr {[dict get $record ${axis}0]*$factor}]; set end [expr {[dict get $record ${axis}1]*$factor}]
            set length [expr {$axis eq "x" ? [winfo width $canvas] : [winfo height $canvas]}]
            set visible [$canvas canvas$axis 0]
            if {$start < $visible || $end > $visible + $length} {
                set index [expr {$axis eq "x" ? 2 : 3}]
                set origin [lindex $region [expr {$index-2}]]
                set full [expr {[lindex $region $index]-$origin}]
                if {$full > 0} {$canvas ${axis}view moveto [expr {max(0.0,($start-8.0-$origin)/$full)}]}
            }
        }
    }
    proc pick {canvas x y} {
        variable views
        if {![dict exists $views $canvas]} {return}
        focus $canvas
        lassign [to_model $canvas [$canvas canvasx $x] [$canvas canvasy $y]] x y
        dict for {coordinate record} [dict get $views $canvas cells] {
            if {$x >= [dict get $record x0] && $x <= [dict get $record x1] && $y >= [dict get $record y0] && $y <= [dict get $record y1]} {
                return [choose $canvas $coordinate]
            }
        }
    }
    proc next_coordinate {cells selected key} {
        set row_positions {}; set columns {}
        dict for {coordinate record} $cells {
            lassign $coordinate row col
            dict set row_positions $row [dict get $record y0]
            dict lappend columns $row $col
        }
        set pairs {}
        dict for {row y} $row_positions {lappend pairs [list $y $row]}
        set rows {}
        foreach pair [lsort -real -index 0 $pairs] {lappend rows [lindex $pair 1]}
        if {![llength $rows]} {return {}}
        if {$selected eq {} || ![dict exists $cells $selected]} {set selected [list [lindex $rows 0] [lindex [lsort -integer [dict get $columns [lindex $rows 0]]] 0]]}
        lassign $selected row col
        set r [lsearch -exact $rows $row]
        switch -- $key {
            Up {set r [expr {max(0,$r-1)}]}
            Down {set r [expr {min([llength $rows]-1,$r+1)}]}
            Control-Home {set r 0}
            Control-End {set r [expr {[llength $rows]-1}]}
        }
        set row [lindex $rows $r]
        set cols [lsort -integer -unique [dict get $columns $row]]
        set c [lsearch -exact $cols $col]
        if {$c < 0} {set c 0}
        switch -- $key {
            Left {set c [expr {max(0,$c-1)}]}
            Right {set c [expr {min([llength $cols]-1,$c+1)}]}
            Home - Control-Home {set c 0}
            End - Control-End {set c [expr {[llength $cols]-1}]}
        }
        return [list $row [lindex $cols $c]]
    }
    proc key {canvas key} {
        variable views
        if {![dict exists $views $canvas]} {return}
        set view [dict get $views $canvas]
        if {[busy] || [inactive $canvas]} {return}
        if {$key eq "Escape"} {
            $canvas delete navigation_zoom_box
            dict set views $canvas drag {}
            uplevel #0 [dict get $view clear]
            $canvas delete keyboard_selection
            dict set views $canvas selected {}
            if {[info commands ::RMSXFlipbookTimeline::HeatmapTools::clear_event] ne ""} {
                ::RMSXFlipbookTimeline::HeatmapTools::clear_event $canvas
            }
            return
        }
        set next [next_coordinate [dict get $view cells] [dict get $view selected] $key]
        if {$next ne {}} {return [choose $canvas $next]}
    }
}

namespace eval ::RMSXFlipbookTimeline::Navigation {
    # Geometry stays in model coordinates in every data record. Tk scales item
    # positions but deliberately retains named-font sizes for readable text.
    proc zoom_state {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return {}}
        set view [dict get $views $canvas]
        return [dict create x [dict get $view sx] y [dict get $view sy] every_residue [dict get $view every]]
    }
    proc to_model {canvas x y} {
        variable views
        if {![dict exists $views $canvas]} {return [list $x $y]}
        return [list [expr {$x/[dict get $views $canvas sx]}] [expr {$y/[dict get $views $canvas sy]}]]
    }
    proc to_canvas {canvas x y} {
        variable views
        if {![dict exists $views $canvas]} {return [list $x $y]}
        return [list [expr {$x*[dict get $views $canvas sx]}] [expr {$y*[dict get $views $canvas sy]}]]
    }
    proc geometry_changed {canvas} {
        if {[info commands ::RMSXFlipbookTimeline::HeatmapTools::geometry_changed] ne ""} {
            ::RMSXFlipbookTimeline::HeatmapTools::geometry_changed $canvas
        }
    }
    proc update_region {canvas} {
        variable views
        lassign [dict get $views $canvas base_region] x0 y0 x1 y1
        lassign [to_canvas $canvas $x0 $y0] x0 y0
        lassign [to_canvas $canvas $x1 $y1] x1 y1
        set bbox [$canvas bbox all]
        if {[llength $bbox] == 4} {
            lassign $bbox bx0 by0 bx1 by1
            set x0 [expr {min($x0,$bx0-8)}]; set y0 [expr {min($y0,$by0-8)}]
            set x1 [expr {max($x1,$bx1+8)}]; set y1 [expr {max($y1,$by1+8)}]
        }
        $canvas configure -scrollregion [list $x0 $y0 $x1 $y1]
    }
    proc zoom {canvas xfactor yfactor} {
        variable views
        if {![available $canvas] || [busy]} {return {}}
        foreach factor [list $xfactor $yfactor] {
            if {![string is double -strict $factor] || $factor <= 0 || $factor == Inf} {error "Zoom factors must be finite positive numbers"}
        }
        set oldx [dict get $views $canvas sx]; set oldy [dict get $views $canvas sy]
        set sx [expr {max(0.02,min(64.0,$oldx*$xfactor))}]
        set sy [expr {max(0.02,min(64.0,$oldy*$yfactor))}]
        lassign [to_model $canvas [$canvas canvasx 0] [$canvas canvasy 0]] left top
        $canvas delete navigation_zoom_box
        $canvas scale all 0 0 [expr {$sx/$oldx}] [expr {$sy/$oldy}]
        dict set views $canvas sx $sx
        dict set views $canvas sy $sy
        if {[dict get $views $canvas every]} {draw_row_labels $canvas}
        update_region $canvas
        position $canvas [expr {$left*$sx}] [expr {$top*$sy}]
        geometry_changed $canvas
        return [zoom_state $canvas]
    }
    proc position {canvas left top} {
        lassign [$canvas cget -scrollregion] x0 y0 x1 y1
        if {$x1 > $x0} {$canvas xview moveto [expr {($left-$x0)/double($x1-$x0)}]}
        if {$y1 > $y0} {$canvas yview moveto [expr {($top-$y0)/double($y1-$y0)}]}
    }
    proc restore_row_labels {canvas} {
        variable views
        $canvas delete navigation_row_label
        foreach id [dict get $views $canvas label_items] {
            if {[$canvas type $id] ne ""} {$canvas itemconfigure $id -state normal}
        }
        dict set views $canvas every 0
    }
    proc reset_zoom {canvas} {
        variable views
        if {![available $canvas] || [busy]} {return {}}
        restore_row_labels $canvas
        zoom $canvas [expr {1.0/[dict get $views $canvas sx]}] [expr {1.0/[dict get $views $canvas sy]}]
        $canvas xview moveto 0; $canvas yview moveto 0
        return [zoom_state $canvas]
    }
    proc fit {canvas} {
        variable views
        if {![available $canvas] || [busy]} {return {}}
        restore_row_labels $canvas
        lassign [dict get $views $canvas base_region] x0 y0 x1 y1
        set sx [expr {max(1.0,[winfo width $canvas]-24)/max(1.0,$x1-$x0)}]
        set sy [expr {max(1.0,[winfo height $canvas]-24)/max(1.0,$y1-$y0)}]
        zoom $canvas [expr {$sx/[dict get $views $canvas sx]}] [expr {$sy/[dict get $views $canvas sy]}]
        $canvas xview moveto 0; $canvas yview moveto 0
        return [zoom_state $canvas]
    }
    proc row_labels {canvas labels} {
        variable views
        if {![available $canvas]} {return}
        dict set views $canvas labels $labels
        if {[dict get $views $canvas every]} {draw_row_labels $canvas; update_region $canvas}
    }
    proc row_records {canvas} {
        variable views
        set rows {}
        dict for {coordinate record} [dict get $views $canvas cells] {
            set row [dict get $record row]
            if {![dict exists $rows $row] || [dict get $record x0] < [dict get $rows $row x0]} {dict set rows $row $record}
        }
        return $rows
    }
    proc draw_row_labels {canvas} {
        variable views
        $canvas delete navigation_row_label
        set rows [row_records $canvas]
        # Remember and hide sparse residue-axis labels, leaving chart and
        # legend text intact. The original labels return in Fit/Reset.
        foreach id [dict get $views $canvas items] {
            if {[$canvas type $id] ne "text" || [$canvas itemcget $id -anchor] ne "e"} {continue}
            lassign [$canvas coords $id] x y
            lassign [to_model $canvas $x $y] x y
            dict for {row record} $rows {
                if {$x < [dict get $record x0] && $x > [dict get $record x0]-45 && $y >= [dict get $record y0] && $y <= [dict get $record y1]} {
                    $canvas itemconfigure $id -state hidden
                    if {[lsearch -exact [dict get $views $canvas label_items] $id] < 0} {dict set views $canvas label_items [concat [dict get $views $canvas label_items] [list $id]]}
                    break
                }
            }
        }
        dict for {row record} $rows {
            set label [expr {$row+1}]
            foreach field {resid label row_label} {if {[dict exists $record $field]} {set label [dict get $record $field]}}
            if {[dict exists $views $canvas labels $row]} {set label [dict get $views $canvas labels $row]}
            lassign [to_canvas $canvas [dict get $record x0] [expr {([dict get $record y0]+[dict get $record y1])/2.0}]] x y
            $canvas create text [expr {$x-8}] $y -anchor e -font TkDefaultFont -fill "#374151" -text $label -tags navigation_row_label
        }
    }
    proc every_residue {canvas} {
        variable views
        if {![available $canvas] || [busy]} {return {}}
        set height Inf
        dict for {row record} [row_records $canvas] {
            set h [expr {[dict get $record y1]-[dict get $record y0]}]
            if {$h > 0} {set height [expr {min($height,$h)}]}
        }
        if {$height == Inf} {return {}}
        set target [expr {max(18,[font metrics TkDefaultFont -linespace]+4)}]
        dict set views $canvas every 1
        set sy [expr {max([dict get $views $canvas sy],$target/$height)}]
        zoom $canvas 1 [expr {$sy/[dict get $views $canvas sy]}]
        set selected [dict get $views $canvas selected]
        if {$selected ne {} && [dict exists $views $canvas cells $selected]} {
            reveal $canvas [dict get $views $canvas cells $selected]
        } else {
            set coordinate [next_coordinate [dict get $views $canvas cells] {} Control-Home]
            if {$coordinate ne {}} {reveal $canvas [dict get $views $canvas cells $coordinate]}
        }
        return [zoom_state $canvas]
    }
    proc wheel {canvas axis delta} {
        if {![available $canvas] || [busy] || $delta == 0} {return}
        set units [expr {$delta > 0 ? -1 : 1}]
        if {abs($delta) >= 120} {set units [expr {-int($delta/120)}]}
        $canvas ${axis}view scroll $units units
    }
    proc rectangle_start {canvas x y} {
        variable views
        if {![available $canvas] || [busy]} {return}
        focus $canvas
        set x [$canvas canvasx $x]; set y [$canvas canvasy $y]
        dict set views $canvas drag [list $x $y]
        $canvas delete navigation_zoom_box
        $canvas create rectangle $x $y $x $y -outline "#2563eb" -dash {4 3} -width 2 -tags navigation_zoom_box
    }
    proc rectangle_move {canvas x y} {
        variable views
        if {![available $canvas] || [dict get $views $canvas drag] eq {}} {return}
        lassign [dict get $views $canvas drag] x0 y0
        $canvas coords navigation_zoom_box $x0 $y0 [$canvas canvasx $x] [$canvas canvasy $y]
    }
    proc rectangle_end {canvas x y} {
        variable views
        if {![available $canvas] || [dict get $views $canvas drag] eq {}} {return}
        lassign [dict get $views $canvas drag] x0 y0
        set x1 [$canvas canvasx $x]; set y1 [$canvas canvasy $y]
        dict set views $canvas drag {}
        $canvas delete navigation_zoom_box
        if {[busy] || abs($x1-$x0) < 6 || abs($y1-$y0) < 6} {return}
        lassign [to_model $canvas [expr {min($x0,$x1)}] [expr {min($y0,$y1)}]] left top
        zoom $canvas [expr {max(1,[winfo width $canvas]-24)/abs($x1-$x0)}] [expr {max(1,[winfo height $canvas]-24)/abs($y1-$y0)}]
        lassign [to_canvas $canvas $left $top] left top
        position $canvas [expr {$left-10}] [expr {$top-10}]
        return [zoom_state $canvas]
    }
}
