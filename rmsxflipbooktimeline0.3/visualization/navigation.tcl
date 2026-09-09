# Per-canvas cell navigation. Views retain their own records across pop-outs.
namespace eval ::RMSXFlipbookTimeline::Navigation {
    variable views {}
    proc forget {canvas actual} {
        variable views
        if {$canvas eq $actual} {dict unset views $canvas}
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
        dict set views $canvas [dict create cells $cells select $select_command clear $clear_command selected $selected]
        $canvas configure -takefocus 1 -highlightthickness 1 -highlightcolor "#2563eb"
        foreach key {Left Right Up Down Home End Return Escape Control-Home Control-End} {
            bind $canvas <$key> "[list ::RMSXFlipbookTimeline::Navigation::key $canvas $key]; break"
        }
        bind $canvas <Button-1> [list focus $canvas]
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
        $canvas create rectangle [dict get $record x0] [dict get $record y0] [dict get $record x1] [dict get $record y1] \
            -outline "#2563eb" -width 2 -tags keyboard_selection
    }
    proc choose {canvas coordinate} {
        variable views
        if {![dict exists $views $canvas cells $coordinate]} {return {}}
        if {[info commands ::RMSXFlipbookTimeline::Operation::running] ne "" && [::RMSXFlipbookTimeline::Operation::running]} {return {}}
        set view [dict get $views $canvas]
        set record [dict get $view cells $coordinate]
        set answer [uplevel #0 [list {*}[dict get $view select] $record]]
        dict set views $canvas selected $coordinate
        if {[winfo exists $canvas]} {highlight $canvas $record; reveal $canvas $record}
        if {[::RMSXFlipbookTimeline::Results::get] ne {}} {
            ::RMSXFlipbookTimeline::Results::update [dict create selected_cell $coordinate]
        }
        return $answer
    }
    proc reveal {canvas record} {
        set region [$canvas cget -scrollregion]
        if {[llength $region] != 4} {return}
        foreach axis {x y} {
            set start [dict get $record ${axis}0]; set end [dict get $record ${axis}1]
            set length [expr {$axis eq "x" ? [winfo width $canvas] : [winfo height $canvas]}]
            set visible [$canvas canvas$axis 0]
            if {$start < $visible || $end > $visible + $length} {
                set index [expr {$axis eq "x" ? 2 : 3}]
                set full [lindex $region $index]
                if {$full > 0} {$canvas ${axis}view moveto [expr {max(0.0,($start-8.0)/$full)}]}
            }
        }
    }
    proc pick {canvas x y} {
        variable views
        if {![dict exists $views $canvas]} {return}
        focus $canvas
        set x [$canvas canvasx $x]; set y [$canvas canvasy $y]
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
        if {$key eq "Escape"} {
            uplevel #0 [dict get $view clear]
            $canvas delete keyboard_selection
            dict set views $canvas selected {}
            return
        }
        set next [next_coordinate [dict get $view cells] [dict get $view selected] $key]
        if {$next ne {}} {return [choose $canvas $next]}
    }
}
