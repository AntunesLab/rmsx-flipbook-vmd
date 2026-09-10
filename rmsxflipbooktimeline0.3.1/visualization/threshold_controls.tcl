# Per-canvas threshold exploration. Data stays immutable; only view overlays change.
# Numeric bounds are inclusive. Persistence counts passing columns, not a dwell.
# No Tk or VMD dependency until attach. update_dataset also supports headless use.
namespace eval ::RMSXFlipbookTimeline::ThresholdControls {
    variable views {}
    variable serial 0
    variable ui
    variable debounce_ms 100
    array set ui {}

    proc finite {value} {
        if {![string is double -strict [string trim $value]]} {return 0}
        if {[catch {expr {abs(double($value)) < Inf}} answer]} {return 0}
        return $answer
    }

    proc missing {value} {
        set value [string trim $value]
        if {$value eq ""} {return 1}
        if {[string is double -strict $value] && ![finite $value]} {return 1}
        return [regexp -nocase {^[+-]?(nan|inf(inity)?)$} $value]
    }

    proc categorical {dataset} {
        return [expr {[::RMSXFlipbookTimeline::Matrix::dataset_value_kind $dataset] in {categorical binary} ||
            ([dict exists $dataset categories] && [llength [dict get $dataset categories]] > 0)}]
    }

    proc category_records {dataset} {
        set records {}; set seen {}
        if {[dict exists $dataset categories]} {
            foreach record [dict get $dataset categories] {
                if {![dict exists $record value]} {continue}
                set value [string trim [dict get $record value]]
                if {[missing $value] || [dict exists $seen $value]} {continue}
                if {![dict exists $record label]} {dict set record label $value}
                dict set record value $value
                lappend records $record
                dict set seen $value 1
            }
        }
        # Include observed codes even if the metadata omitted their legend entry.
        foreach column [dict get $dataset values] {
            foreach value $column {
                set value [string trim $value]
                if {[missing $value] || [dict exists $seen $value]} {continue}
                lappend records [dict create value $value label $value]
                dict set seen $value 1
            }
        }
        return $records
    }

    proc numeric_range {dataset} {
        set low ""; set high ""
        foreach column [dict get $dataset values] {
            set row 0
            foreach value $column {
                if {![::RMSXFlipbookTimeline::Matrix::row_masked $dataset $row] && [finite $value]} {
                    if {$low eq "" || $value < $low} {set low [expr {double($value)}]}
                    if {$high eq "" || $value > $high} {set high [expr {double($value)}]}
                }
                incr row
            }
        }
        if {$low eq ""} {return {0.0 1.0}}
        return [list $low $high]
    }

    proc defaults {dataset} {
        lassign [numeric_range $dataset] low high
        set categories {}
        if {[categorical $dataset]} {
            foreach record [category_records $dataset] {lappend categories [dict get $record value]}
        }
        return [dict create min $low max $high categories $categories min_frames 1 \
            first_column 0 last_column -1 enabled 0]
    }

    proc normalize_options {dataset options} {
        set keys {min max categories min_frames first_column last_column enabled}
        set complete 1
        foreach key $keys {if {![dict exists $options $key]} {set complete 0; break}}
        # Editing a slider should not scan the matrix before the debounce fires.
        set result [expr {$complete ? $options : [defaults $dataset]}]
        dict for {key value} $options {
            if {$key ni $keys} {error "Unknown threshold option: $key"}
            dict set result $key $value
        }
        foreach key {min max} {
            if {![finite [dict get $result $key]]} {error "Threshold $key must be a finite number"}
        }
        if {[dict get $result min] > [dict get $result max]} {error "Minimum threshold must not exceed maximum"}
        foreach key {first_column last_column min_frames} {
            set value [dict get $result $key]
            if {$value eq "" && $key eq "last_column"} {set value -1}
            if {$value eq "" && $key eq "first_column"} {set value 0}
            if {![string is integer -strict $value]} {error "$key must be an integer"}
            dict set result $key $value
        }
        if {[dict get $result min_frames] < 1} {error "Minimum passing columns must be at least one"}
        if {[dict get $result first_column] < 0 || [dict get $result last_column] < -1} {
            error "Column bounds must be nonnegative; use blank or -1 for the last column"
        }
        set columns [llength [dict get $dataset columns]]
        set first [dict get $result first_column]
        set last [dict get $result last_column]
        if {$columns > 0 && ($first >= $columns || ($last >= 0 && $last < $first))} {
            error "The persistence column range is empty"
        }
        if {![string is boolean -strict [dict get $result enabled]]} {error "enabled must be a boolean"}
        return $result
    }

    proc category_matches {first second} {
        set first [string trim $first]; set second [string trim $second]
        if {[finite $first] && [finite $second]} {return [expr {double($first) == double($second)}]}
        return [expr {$first eq $second}]
    }

    # Pure counts: values are column-major, matching Matrix::cell_value.
    # eligible_counts counts unmasked, present values, regardless of threshold.
    proc analyze {dataset {options {}}} {
        ::RMSXFlipbookTimeline::Matrix::validate $dataset
        set options [normalize_options $dataset $options]
        set category_mode [categorical $dataset]
        set rows [llength [dict get $dataset rows]]
        set columns [llength [dict get $dataset columns]]
        set row_passes [lrepeat $rows 0]
        set eligible_rows {}; set counts {}; set eligible_counts {}
        set first [dict get $options first_column]
        set last [dict get $options last_column]
        if {$last < 0 || $last >= $columns} {set last [expr {$columns - 1}]}
        set col 0; set peak 0
        foreach values [dict get $dataset values] {
            set count 0; set eligible 0; set row 0
            foreach value $values {
                if {![::RMSXFlipbookTimeline::Matrix::row_masked $dataset $row] &&
                    ![missing $value] && ($category_mode || [finite $value])} {
                    incr eligible
                    dict set eligible_rows $row 1
                    set passes 0
                    if {$category_mode} {
                        foreach category [dict get $options categories] {
                            if {[category_matches $category $value]} {set passes 1; break}
                        }
                    } else {
                        set passes [expr {$value >= [dict get $options min] && $value <= [dict get $options max]}]
                    }
                    if {$passes} {
                        incr count
                        if {$col >= $first && $col <= $last} {
                            lset row_passes $row [expr {[lindex $row_passes $row] + 1}]
                        }
                    }
                }
                incr row
            }
            lappend counts $count; lappend eligible_counts $eligible
            if {$count > $peak} {set peak $count}
            incr col
        }
        set qualifying {}
        for {set row 0} {$row < $rows} {incr row} {
            if {[lindex $row_passes $row] >= [dict get $options min_frames]} {lappend qualifying $row}
        }
        return [dict create counts $counts eligible_counts $eligible_counts row_passes $row_passes \
            qualifying_rows $qualifying peak_count $peak eligible_row_count [dict size $eligible_rows] \
            first_column $first last_column $last categorical $category_mode]
    }

    proc selected_rows {dataset {options {}}} {return [dict get [analyze $dataset $options] qualifying_rows]}
    proc state {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return {}}
        return [dict get $views $canvas]
    }
    proc busy {} {
        return [expr {[info commands ::RMSXFlipbookTimeline::Operation::running] ne "" &&
            [::RMSXFlipbookTimeline::Operation::running]}]
    }
    proc widget_exists {widget} {
        return [expr {$widget ne "" && [info commands winfo] ne "" && [winfo exists $widget]}]
    }
    proc host_allowed {canvas} {
        # Standalone/headless users need no HeatmapTools result registration.
        if {[info commands ::RMSXFlipbookTimeline::HeatmapTools::state] ne "" &&
            [::RMSXFlipbookTimeline::HeatmapTools::state $canvas] ne {}} {
            return [::RMSXFlipbookTimeline::HeatmapTools::allowed $canvas]
        }
        return 1
    }

    proc cancel_pending {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return}
        set pending [dict get $views $canvas pending]
        if {$pending ne ""} {after cancel $pending}
        dict set views $canvas pending ""
        dict set views $canvas generation [expr {[dict get $views $canvas generation] + 1}]
    }

    proc update_dataset {canvas dataset} {
        variable views
        variable serial
        ::RMSXFlipbookTimeline::Matrix::validate $dataset
        if {[dict exists $views $canvas]} {
            cancel_pending $canvas
            set record [dict get $views $canvas]
        } else {
            set record [dict create id [incr serial] frame "" pending "" generation 0 render_count 0 expanded 0]
        }
        set options [defaults $dataset]
        dict set record dataset $dataset
        dict set record category_records [expr {[categorical $dataset] ? [category_records $dataset] : {}}]
        dict set record options $options
        dict set record analysis [analyze $dataset $options]
        dict set record error ""
        dict set views $canvas $record
        if {[widget_exists [dict get $record frame]]} {build_controls $canvas}
        refresh $canvas
        return [state $canvas]
    }

    proc schedule {canvas} {
        variable views
        variable debounce_ms
        if {![dict exists $views $canvas]} {return ""}
        cancel_pending $canvas
        set generation [dict get $views $canvas generation]
        set pending [after $debounce_ms [list ::RMSXFlipbookTimeline::ThresholdControls::apply_pending $canvas $generation]]
        dict set views $canvas pending $pending
        return $pending
    }

    proc set_options {canvas changes} {
        variable views
        if {![dict exists $views $canvas]} {error "No threshold dataset is attached to $canvas"}
        set options [dict merge [dict get $views $canvas options] $changes]
        set options [normalize_options [dict get $views $canvas dataset] $options]
        dict set views $canvas options $options
        dict set views $canvas error ""
        sync_fields $canvas
        schedule $canvas
        return [state $canvas]
    }

    proc set_range {canvas minimum maximum} {
        return [set_options $canvas [dict create min $minimum max $maximum enabled 1]]
    }

    proc apply_pending {canvas generation} {
        variable views
        if {![dict exists $views $canvas] || [dict get $views $canvas generation] != $generation} {return}
        dict set views $canvas pending ""
        if {[busy]} {schedule $canvas; return}
        if {![host_allowed $canvas]} {return}
        set record [dict get $views $canvas]
        dict set record analysis [analyze [dict get $record dataset] [dict get $record options]]
        dict incr record render_count
        dict set views $canvas $record
        refresh $canvas
    }

    proc reset {canvas} {
        set record [state $canvas]
        if {$record eq {}} {return {}}
        return [set_options $canvas [defaults [dict get $record dataset]]]
    }
    proc clear {canvas} {return [set_options $canvas [dict create enabled 0]]}

    proc navigation_view {canvas} {
        if {[info exists ::RMSXFlipbookTimeline::Navigation::views] &&
            [dict exists $::RMSXFlipbookTimeline::Navigation::views $canvas]} {
            return [dict get $::RMSXFlipbookTimeline::Navigation::views $canvas]
        }
        return {}
    }

    proc current_column {canvas} {
        set navigation [navigation_view $canvas]
        if {$navigation ne {} && [dict exists $navigation selected] && [llength [dict get $navigation selected]] == 2} {
            return [lindex [dict get $navigation selected] 1]
        }
        return 0
    }

    proc select_column {canvas column} {
        if {[busy] || ![host_allowed $canvas]} {return {}}
        set navigation [navigation_view $canvas]
        if {$navigation eq {}} {return {}}
        set row 0
        if {[dict exists $navigation selected] && [llength [dict get $navigation selected]] == 2} {
            set row [lindex [dict get $navigation selected] 0]
        }
        if {![dict exists $navigation cells [list $row $column]]} {
            set found 0
            foreach coordinate [dict keys [dict get $navigation cells]] {
                if {[lindex $coordinate 1] == $column} {set row [lindex $coordinate 0]; set found 1; break}
            }
            if {!$found} {return {}}
        }
        set answer [::RMSXFlipbookTimeline::Navigation::choose $canvas [list $row $column]]
        sync_selection $canvas
        return $answer
    }

    proc highlight_rows {canvas record} {
        if {![widget_exists $canvas]} {return}
        $canvas delete threshold_qualifying
        if {![dict get $record options enabled] || ![host_allowed $canvas]} {return}
        set navigation [navigation_view $canvas]
        if {$navigation eq {}} {return}
        set wanted {}
        foreach row [dict get $record analysis qualifying_rows] {dict set wanted $row 1}
        set boxes {}
        dict for {coordinate cell} [dict get $navigation cells] {
            set row [lindex $coordinate 0]
            if {![dict exists $wanted $row]} {continue}
            set box [list [dict get $cell x0] [dict get $cell y0] [dict get $cell x1] [dict get $cell y1]]
            if {[dict exists $boxes $row]} {
                lassign [dict get $boxes $row] x0 y0 x1 y1
                lassign $box a b c d
                set box [list [expr {min($x0,$a)}] [expr {min($y0,$b)}] [expr {max($x1,$c)}] [expr {max($y1,$d)}]]
            }
            dict set boxes $row $box
        }
        dict for {row box} $boxes {
            lassign $box x0 y0 x1 y1
            if {[info commands ::RMSXFlipbookTimeline::Navigation::to_canvas] ne ""} {
                lassign [::RMSXFlipbookTimeline::Navigation::to_canvas $canvas $x0 $y0] x0 y0
                lassign [::RMSXFlipbookTimeline::Navigation::to_canvas $canvas $x1 $y1] x1 y1
            }
            $canvas create rectangle $x0 $y0 $x1 $y1 -outline "#0f766e" -width 2 -state disabled -tags threshold_qualifying
        }
        $canvas raise keyboard_selection
    }

    proc sync_selection {canvas} {
        variable views
        variable ui
        if {![dict exists $views $canvas]} {return}
        set record [dict get $views $canvas]
        set column [current_column $canvas]
        set analysis [dict get $record analysis]
        set counts [dict get $analysis counts]
        if {$column < 0 || $column >= [llength $counts]} {set column 0}
        set count [lindex $counts $column]; set eligible [lindex [dict get $analysis eligible_counts] $column]
        if {$count eq ""} {set count 0; set eligible 0}
        set id [dict get $record id]
        set ui($id,summary) "Column $column: $count passing / $eligible eligible · Peak: [dict get $analysis peak_count]"
        set ui($id,persistence) "[llength [dict get $analysis qualifying_rows]] rows pass in at least [dict get $record options min_frames] columns; matches need not be consecutive."
        if {![dict get $record options enabled]} {append ui($id,persistence) " Highlighting off."}
        draw_chart $canvas
    }

    proc refresh {canvas} {
        set record [state $canvas]
        if {$record eq {}} {return}
        highlight_rows $canvas $record
        sync_selection $canvas
    }

    proc draw_chart {canvas} {
        set record [state $canvas]
        if {$record eq {}} {return}
        set chart [dict get $record frame].body.chart
        if {![widget_exists $chart]} {return}
        $chart delete all
        set counts [dict get $record analysis counts]
        if {![llength $counts]} {return}
        set width [expr {max(240,[winfo width $chart])}]
        set left 30; set right [expr {$width-8}]; set base 73; set plot_height 53
        set maximum [expr {max(1,[dict get $record analysis peak_count])}]
        set step [expr {($right-$left)/double([llength $counts])}]
        set column 0; set current [current_column $canvas]
        foreach count $counts {
            set x0 [expr {$left+$column*$step}]; set x1 [expr {$left+($column+1)*$step}]
            set y [expr {$base-max(2.0,$plot_height*$count/double($maximum))}]
            set color [expr {$column == $current ? "#2563eb" : "#0f766e"}]
            set tag threshold_column_$column
            $chart create rectangle $x0 $y $x1 $base -fill $color -outline white -tags $tag
            $chart bind $tag <Button-1> [list ::RMSXFlipbookTimeline::ThresholdControls::select_column $canvas $column]
            incr column
        }
        $chart create text 26 20 -anchor e -text $maximum -fill "#475569"
        $chart create text 26 $base -anchor e -text 0 -fill "#475569"
        $chart create text $left 85 -anchor w -text 0 -fill "#475569"
        $chart create text $right 85 -anchor e -text [expr {[llength $counts]-1}] -fill "#475569"
    }

    proc sync_fields {canvas} {
        variable ui
        set record [state $canvas]
        if {$record eq {}} {return}
        set id [dict get $record id]
        foreach key {min max min_frames first_column last_column} {set ui($id,$key) [dict get $record options $key]}
        if {$ui($id,last_column) == -1} {set ui($id,last_column) ""}
        set index 0
        if {[categorical [dict get $record dataset]]} {
            foreach category [dict get $record category_records] {
                set enabled 0
                foreach selected [dict get $record options categories] {
                    if {[category_matches $selected [dict get $category value]]} {set enabled 1; break}
                }
                set ui($id,category,$index) $enabled
                incr index
            }
        }
        set ui($id,error) [dict get $record error]
    }

    proc read_controls {canvas args} {
        variable ui
        variable views
        set record [state $canvas]
        if {$record eq {}} {return}
        set id [dict get $record id]
        set changes [dict create enabled 1]
        foreach key {min max min_frames first_column last_column} {dict set changes $key $ui($id,$key)}
        if {[categorical [dict get $record dataset]]} {
            set categories {}; set index 0
            foreach category [dict get $record category_records] {
                if {$ui($id,category,$index)} {lappend categories [dict get $category value]}
                incr index
            }
            dict set changes categories $categories
        }
        if {[catch {set_options $canvas $changes} message]} {
            cancel_pending $canvas
            dict set views $canvas error $message
            set ui($id,error) $message
        }
    }

    proc toggle {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return}
        set frame [dict get $views $canvas frame]
        set expanded [expr {![dict get $views $canvas expanded]}]
        dict set views $canvas expanded $expanded
        if {$expanded} {grid $frame.body -row 1 -column 0 -sticky ew} else {grid remove $frame.body}
        $frame.toggle configure -text [expr {$expanded ? "▾ Thresholds and persistence" : "▸ Thresholds and persistence"}]
        sync_selection $canvas
    }

    proc build_controls {canvas} {
        variable ui
        set record [state $canvas]
        set frame [dict get $record frame]; set id [dict get $record id]
        foreach child [winfo children $frame] {destroy $child}
        sync_fields $canvas
        set expanded [dict get $record expanded]
        ttk::button $frame.toggle -text [expr {$expanded ? "▾ Thresholds and persistence" : "▸ Thresholds and persistence"}] \
            -command [list ::RMSXFlipbookTimeline::ThresholdControls::toggle $canvas]
        grid $frame.toggle -row 0 -column 0 -sticky w
        set body $frame.body
        ttk::frame $body -padding {4 4}
        grid columnconfigure $frame 0 -weight 1
        grid columnconfigure $body 0 -weight 1
        set inputs $body.inputs
        ttk::frame $inputs
        grid $inputs -row 0 -column 0 -sticky ew
        if {[categorical [dict get $record dataset]]} {
            set index 0
            foreach category [dict get $record category_records] {
                ttk::checkbutton $inputs.c$index -text [dict get $category label] \
                    -variable ::RMSXFlipbookTimeline::ThresholdControls::ui($id,category,$index) \
                    -command [list ::RMSXFlipbookTimeline::ThresholdControls::read_controls $canvas]
                grid $inputs.c$index -row [expr {$index/3}] -column [expr {$index%3}] -sticky w -padx {0 8}
                incr index
            }
        } else {
            lassign [numeric_range [dict get $record dataset]] low high
            if {$low == $high} {set high [expr {$low+max(1.0,abs($low)*0.1)}]}
            set row 0
            foreach key {min max} label {Minimum Maximum} {
                ttk::label $inputs.${key}label -text $label
                ttk::scale $inputs.${key}scale -from $low -to $high \
                    -variable ::RMSXFlipbookTimeline::ThresholdControls::ui($id,$key) \
                    -command [list ::RMSXFlipbookTimeline::ThresholdControls::read_controls $canvas]
                ttk::entry $inputs.${key}entry -width 10 -textvariable ::RMSXFlipbookTimeline::ThresholdControls::ui($id,$key)
                bind $inputs.${key}entry <KeyRelease> [list ::RMSXFlipbookTimeline::ThresholdControls::read_controls $canvas]
                grid $inputs.${key}label -row $row -column 0 -sticky w -padx {0 6}
                grid $inputs.${key}scale -row $row -column 1 -sticky ew -padx {0 6}
                grid $inputs.${key}entry -row $row -column 2 -sticky ew
                incr row
            }
            grid columnconfigure $inputs 1 -weight 1
        }
        ttk::frame $body.persistence
        set position 0
        foreach key {min_frames first_column last_column} label {"Min passing columns" "First (0-based)" "Last (blank=all)"} {
            ttk::label $body.persistence.l$key -text $label
            ttk::entry $body.persistence.e$key -width 5 -textvariable ::RMSXFlipbookTimeline::ThresholdControls::ui($id,$key)
            bind $body.persistence.e$key <KeyRelease> [list ::RMSXFlipbookTimeline::ThresholdControls::read_controls $canvas]
            grid $body.persistence.l$key -row 0 -column $position -sticky w -padx {0 12}
            grid $body.persistence.e$key -row 1 -column $position -sticky w -padx {0 12}
            incr position
        }
        grid $body.persistence -row 1 -column 0 -sticky w -pady {6 0}
        ttk::label $body.note -textvariable ::RMSXFlipbookTimeline::ThresholdControls::ui($id,persistence) -wraplength 530
        grid $body.note -row 2 -column 0 -sticky w -pady {4 0}
        ttk::label $body.summary -textvariable ::RMSXFlipbookTimeline::ThresholdControls::ui($id,summary)
        grid $body.summary -row 3 -column 0 -sticky w -pady {4 0}
        canvas $body.chart -height 96 -width 400 -background white -highlightthickness 0
        grid $body.chart -row 4 -column 0 -sticky ew
        bind $body.chart <Configure> [list ::RMSXFlipbookTimeline::ThresholdControls::draw_chart $canvas]
        ttk::frame $body.actions
        ttk::button $body.actions.reset -text Reset -command [list ::RMSXFlipbookTimeline::ThresholdControls::reset $canvas]
        ttk::button $body.actions.clear -text "Clear highlight" -command [list ::RMSXFlipbookTimeline::ThresholdControls::clear $canvas]
        ttk::label $body.actions.hint -text "Click a bar to select its column."
        pack $body.actions.reset $body.actions.clear $body.actions.hint -side left -padx {0 6}
        grid $body.actions -row 5 -column 0 -sticky w
        ttk::label $body.error -foreground "#b91c1c" -wraplength 530 -textvariable ::RMSXFlipbookTimeline::ThresholdControls::ui($id,error)
        grid $body.error -row 6 -column 0 -sticky w
        if {$expanded} {grid $body -row 1 -column 0 -sticky ew}
    }

    proc attach {parent canvas dataset} {
        variable views
        package require Tk 8.6
        if {![winfo exists $parent] || ![winfo exists $canvas]} {error "Threshold controls require an existing parent and heatmap canvas"}
        detach $canvas
        update_dataset $canvas $dataset
        set frame $parent.thresholds[dict get $views $canvas id]
        ttk::frame $frame
        dict set views $canvas frame $frame
        build_controls $canvas
        bind $frame <Destroy> [list ::RMSXFlipbookTimeline::ThresholdControls::destroyed $canvas $frame %W]
        set destroy_script [list ::RMSXFlipbookTimeline::ThresholdControls::destroyed $canvas $canvas %W]
        dict set views $canvas destroy_script $destroy_script
        bind $canvas <Destroy> +$destroy_script
        refresh $canvas
        return $frame
    }

    proc destroyed {canvas expected actual} {if {$expected eq $actual} {detach $canvas}}
    proc detach {canvas} {
        variable views
        variable ui
        if {![dict exists $views $canvas]} {return}
        cancel_pending $canvas
        set record [dict get $views $canvas]
        dict unset views $canvas
        foreach key [array names ui "[dict get $record id],*"] {unset ui($key)}
        if {[widget_exists $canvas]} {
            $canvas delete threshold_qualifying
            if {[dict exists $record destroy_script]} {
                set remaining {}
                foreach line [split [bind $canvas <Destroy>] \n] {
                    if {$line ne [dict get $record destroy_script]} {lappend remaining $line}
                }
                bind $canvas <Destroy> [join $remaining \n]
            }
        }
        set frame [dict get $record frame]
        if {[widget_exists $frame]} {destroy $frame}
    }
}
