################################################################################
# RMSX Flipbook Timeline 2D plot popup
################################################################################

namespace eval ::RMSXFlipbookTimeline::PlotWindow {
    variable window ".rmsxflipbooktimeline_plot"
    variable canvas ""
    variable status_var ""
    variable plot_records {}
    variable record_by_tag
    variable highlight_reps {}
    variable selected_record {}
    variable trace_installed 0

    array set record_by_tag {}

    proc reset_state {} {
        variable plot_records
        variable record_by_tag
        variable highlight_reps
        variable selected_record

        set plot_records {}
        catch {array unset record_by_tag}
        array set record_by_tag {}
        set highlight_reps {}
        set selected_record {}
    }

    proc remove_pick_trace {} {
        variable trace_installed
        if {$trace_installed} {
            catch {trace remove variable ::vmd_pick_atom write ::RMSXFlipbookTimeline::PlotWindow::pick_callback}
            catch {trace vdelete ::vmd_pick_atom w ::RMSXFlipbookTimeline::PlotWindow::pick_callback}
            set trace_installed 0
        }
    }

    proc install_pick_trace {} {
        variable trace_installed
        if {!$trace_installed} {
            trace add variable ::vmd_pick_atom write ::RMSXFlipbookTimeline::PlotWindow::pick_callback
            set trace_installed 1
        }
    }

    proc clear {{destroy_window 1}} {
        variable window
        variable canvas

        clear_structure_highlight
        remove_pick_trace
        if {$destroy_window && [info commands winfo] ne "" && [winfo exists $window]} {
            catch {destroy $window}
        }
        set canvas ""
        reset_state
        return 1
    }

    proc current_folder {folder} {
        set cleaned [string trim $folder]
        if {$cleaned ne ""} {
            return [file normalize $cleaned]
        }
        set loaded [::RMSXFlipbookTimeline::state_get source_folder ""]
        if {$loaded eq ""} {
            error "No RMSX folder is loaded; pass a folder to show_plot_window"
        }
        return [file normalize $loaded]
    }

    proc matrix_from_folder {folder csv_path} {
        set csv [::RMSXFlipbookTimeline::NativeAnalysis::resolve_folder_csv $folder $csv_path]
        set data [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $csv]
        set parsed [::RMSXFlipbookTimeline::NativeAnalysis::csv_to_records_and_columns $data]
        set residues [dict get $parsed residue_records]
        set columns [dict get $parsed slice_columns]
        if {[llength $residues] == 0 || [llength $columns] == 0} {
            error "Cannot draw plot for empty RMSX matrix: $csv"
        }
        set range [::RMSXFlipbookTimeline::NativeAnalysis::matrix_value_range $columns]
        set mask_metadata [::RMSXFlipbookTimeline::NativeAnalysis::read_mask_metadata_file [file join $folder masked_residues.csv]]
        return [dict create \
            csv $csv \
            residues $residues \
            columns $columns \
            mask_metadata $mask_metadata \
            min [lindex $range 0] \
            max [lindex $range 1]]
    }

    proc clamp {value min_val max_val} {
        if {$value < $min_val} {return $min_val}
        if {$value > $max_val} {return $max_val}
        return $value
    }

    proc record_kind {record} {
        if {[dict exists $record kind]} {
            return [dict get $record kind]
        }
        return cell
    }

    proc residue_label {record} {
        set chain [string trim [dict get $record chain]]
        set resid [dict get $record resid]
        if {$chain eq ""} {
            return $resid
        }
        return "$chain:$resid"
    }

    proc residue_axis_label {record} {
        if {[dict exists $record resid]} {
            return [dict get $record resid]
        }
        return [residue_label $record]
    }

    proc draw_y_axis_title {canvas x y text} {
        if {[catch {
            $canvas create text $x $y \
                -anchor center \
                -font TkDefaultFont \
                -fill "#333333" \
                -text $text \
                -angle 90
        }]} {
            $canvas create text $x $y \
                -anchor center \
                -font TkDefaultFont \
                -fill "#333333" \
                -text $text
        }
    }

    proc selection_for_record {record {molid ""}} {
        return [::RMSXFlipbookTimeline::ResidueIdentity::selection $record $molid]
    }

    proc chain_display_label {chain} {
        set cleaned [string trim $chain]
        if {$cleaned eq ""} {
            return "Unassigned Chain"
        }
        return "Chain $cleaned"
    }

    proc build_layout {matrix args} {
        set defaults [dict create \
            width 960 \
            cell_max_width 82.0 \
            cell_min_width 10.0 \
            heatmap_min_height 300.0 \
            heatmap_max_height 560.0 \
            chain_heatmap_min_height 220.0 \
            chain_heatmap_max_height 380.0 \
            chain_panel_gap 82.0 \
            rmsd_points {} \
            rmsd_by_chain_points {} \
            rmsd_slice_points {} \
            rmsf_points {} \
            rmsd_height 76.0 \
            slice_rmsd_height 70.0 \
            summary_height 120.0 \
            chain_summary_height 86.0 \
            chart_gap 28.0 \
            rmsf_width 84.0 \
            side_gap 34.0 \
            left_margin 146.0 \
            min_plot_width 280.0 \
            rmsf_right_padding 44.0 \
            top_margin "" \
            bottom_margin "" \
            show_title 1 \
            show_heat_title 1 \
            show_rmsd_chart 1 \
            show_rmsf_chart 1 \
            show_slice_rmsd_chart 1 \
            show_summary_chart 1 \
            x_axis_labels {} \
            x_axis_title "" \
            x_axis_unit ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set residues [dict get $matrix residues]
        set columns [dict get $matrix columns]
        set mask_metadata {}
        if {[dict exists $matrix mask_metadata]} {
            set mask_metadata [dict get $matrix mask_metadata]
        }
        set rows [llength $residues]
        set cols [llength $columns]
        set rmsd_points [dict get $opts rmsd_points]
        set rmsd_by_chain_points [dict get $opts rmsd_by_chain_points]
        set rmsd_slice_points [dict get $opts rmsd_slice_points]
        set rmsf_points [dict get $opts rmsf_points]
        set show_title [expr {[dict get $opts show_title] ? 1 : 0}]
        set show_heat_title [expr {[dict get $opts show_heat_title] ? 1 : 0}]
        set show_summary [expr {[dict get $opts show_summary_chart] ? 1 : 0}]
        set row_groups [dict create]
        set chain_order {}
        for {set row 0} {$row < $rows} {incr row} {
            set residue [lindex $residues $row]
            set chain [string trim [dict get $residue chain]]
            set key $chain
            if {$key eq ""} {
                set key "__blank__"
            }
            if {![dict exists $row_groups $key]} {
                lappend chain_order $key
            }
            dict lappend row_groups $key $row
        }
        set multi_panel [expr {[llength $chain_order] > 1}]

        set has_rmsd [expr {[llength $rmsd_points] > 0}]
        if {$multi_panel && [dict size $rmsd_by_chain_points] > 0} {
            set has_rmsd 1
        }
        set show_rmsd [expr {[dict get $opts show_rmsd_chart] && $has_rmsd}]
        set show_slice_rmsd [expr {[dict get $opts show_slice_rmsd_chart] && [llength $rmsd_slice_points] > 0}]
        set show_rmsf [expr {[dict get $opts show_rmsf_chart] && [llength $rmsf_points] > 0}]
        set x_axis_labels [dict get $opts x_axis_labels]
        set x_axis_title [dict get $opts x_axis_title]
        set x_axis_unit [dict get $opts x_axis_unit]

        set requested_width [expr {double([dict get $opts width])}]
        set left [expr {double([dict get $opts left_margin])}]
        set side_gap [expr {double([dict get $opts side_gap])}]
        set rmsf_w [expr {$show_rmsf ? double([dict get $opts rmsf_width]) : 0.0}]
        set rmsf_right_padding [expr {double([dict get $opts rmsf_right_padding])}]
        set right [expr {$show_rmsf ? ($side_gap + $rmsf_w + $rmsf_right_padding) : 40.0}]
        set top [expr {$show_title ? 54.0 : 26.0}]
        set bottom 48.0
        if {[string trim [dict get $opts top_margin]] ne ""} {
            set top [expr {double([dict get $opts top_margin])}]
        }
        if {[string trim [dict get $opts bottom_margin]] ne ""} {
            set bottom [expr {double([dict get $opts bottom_margin])}]
        }
        set plot_w [expr {$requested_width - $left - $right}]
        set min_plot_w [expr {double([dict get $opts min_plot_width])}]
        if {$plot_w < $min_plot_w} {
            set plot_w $min_plot_w
        }
        set cell_w [expr {$plot_w / double($cols)}]
        set cell_w [clamp $cell_w [dict get $opts cell_min_width] [dict get $opts cell_max_width]]
        set plot_w [expr {$cell_w * double($cols)}]

        set heat_h [expr {double($rows) * 6.0}]
        set heat_h [clamp $heat_h [dict get $opts heatmap_min_height] [dict get $opts heatmap_max_height]]
        set cell_h [expr {$heat_h / double($rows)}]
        set rmsd_h [expr {$show_rmsd ? double([dict get $opts rmsd_height]) : 0.0}]
        set slice_rmsd_h [expr {$show_slice_rmsd ? double([dict get $opts slice_rmsd_height]) : 0.0}]
        set summary_h [expr {double([dict get $opts summary_height])}]
        set gap [expr {double([dict get $opts chart_gap])}]

        set x0 $left
        set cursor_y $top
        set rmsd_y0 $cursor_y
        set rmsd_y1 $cursor_y
        if {$show_rmsd && !$multi_panel} {
            set rmsd_y1 [expr {$rmsd_y0 + $rmsd_h}]
            set cursor_y [expr {$rmsd_y1 + $gap}]
        }
        set slice_rmsd_y0 $cursor_y
        set slice_rmsd_y1 $cursor_y
        if {$show_slice_rmsd} {
            set slice_rmsd_y1 [expr {$slice_rmsd_y0 + $slice_rmsd_h}]
            set cursor_y [expr {$slice_rmsd_y1 + $gap}]
        }
        set summary_y0 $cursor_y
        set summary_y1 $summary_y0
        if {!$multi_panel && $show_summary} {
            set summary_y1 [expr {$summary_y0 + $summary_h}]
        }
        set heat_title_y [expr {$summary_y1 + ($show_summary ? $gap : 6.0)}]
        set panel_y0 [expr {$heat_title_y + ($show_heat_title ? 28.0 : 6.0)}]
        set panels {}
        set chains {}
        foreach key $chain_order {
            set row_indices [dict get $row_groups $key]
            set display_row_indices [lreverse $row_indices]
            set panel_rows [llength $row_indices]
            set chain $key
            if {$chain eq "__blank__"} {
                set chain ""
            }
            lappend chains $chain

            if {$multi_panel} {
                set panel_h [expr {double($panel_rows) * 5.2}]
                set panel_h [clamp $panel_h [dict get $opts chain_heatmap_min_height] [dict get $opts chain_heatmap_max_height]]
            } else {
                set panel_h $heat_h
            }
            set panel_summary_y0 ""
            set panel_summary_y1 ""
            set panel_heat_y0 $panel_y0
            set panel_rmsd_y0 ""
            set panel_rmsd_y1 ""
            if {$multi_panel && $show_rmsd} {
                set panel_rmsd_y0 $panel_y0
                set panel_rmsd_y1 [expr {$panel_rmsd_y0 + $rmsd_h}]
                set panel_heat_y0 [expr {$panel_rmsd_y1 + 36.0}]
            }
            if {$multi_panel && $show_summary} {
                set panel_summary_y0 $panel_heat_y0
                set panel_summary_y1 [expr {$panel_summary_y0 + double([dict get $opts chain_summary_height])}]
                set panel_heat_y0 [expr {$panel_summary_y1 + 32.0}]
            }
            set panel_cell_h [expr {$panel_h / double($panel_rows)}]
            set panel_y1 [expr {$panel_heat_y0 + $panel_h}]
            lappend panels [dict create \
                chain $chain \
                label [chain_display_label $chain] \
                row_indices $display_row_indices \
                row_count $panel_rows \
                rmsd_y0 $panel_rmsd_y0 \
                rmsd_y1 $panel_rmsd_y1 \
                summary_y0 $panel_summary_y0 \
                summary_y1 $panel_summary_y1 \
                summary_records {} \
                mean_min "" \
                mean_max "" \
                y0 $panel_heat_y0 \
                y1 $panel_y1 \
                cell_height $panel_cell_h]
            set panel_gap 0.0
            if {$multi_panel} {
                set panel_gap [expr {double([dict get $opts chain_panel_gap])}]
            }
            set panel_y0 [expr {$panel_y1 + $panel_gap}]
        }

        set heat_y0 [dict get [lindex $panels 0] y0]
        set heat_y1 [dict get [lindex $panels end] y1]
        set rmsf_x0 [expr {$left + $plot_w + $side_gap}]
        set rmsf_x1 [expr {$rmsf_x0 + $rmsf_w}]
        set canvas_w [expr {int(ceil($left + $plot_w + $right))}]
        set canvas_h [expr {int(ceil($heat_y1 + $bottom))}]

        set records {}
        set cell_records {}
        set summary_records {}
        set masked_rows [dict create]
        set masked_cells 0
        set id 0

        for {set panel_index 0} {$panel_index < [llength $panels]} {incr panel_index} {
            set panel [lindex $panels $panel_index]
            set row_indices [dict get $panel row_indices]
            set panel_cell_h [dict get $panel cell_height]
            set panel_y0 [dict get $panel y0]

            for {set col 0} {$col < $cols} {incr col} {
                set column [lindex $columns $col]
                set slice_label [lindex $column 0]
                set values [lindex $column 1]
                for {set panel_row 0} {$panel_row < [llength $row_indices]} {incr panel_row} {
                    set row [lindex $row_indices $panel_row]
                    set residue [lindex $residues $row]
                    set value [expr {double([lindex $values $row])}]
                    set masked 0
                    if {[llength $mask_metadata] > $row && [dict get [lindex $mask_metadata $row] masked]} {
                        set masked 1
                        dict set masked_rows $row 1
                        incr masked_cells
                    }
                    set x [expr {$x0 + ($col * $cell_w)}]
                    set y [expr {$panel_y0 + ($panel_row * $panel_cell_h)}]
                    set record [dict create \
                        kind cell \
                        id $id \
                        tag "rec$id" \
                        row $row \
                        panel_row $panel_row \
                        panel_index $panel_index \
                        column $col \
                        slice_index [expr {$col + 1}] \
                        slice_label $slice_label \
                        axis_label [expr {$col < [llength $x_axis_labels] ? [lindex $x_axis_labels $col] : ""}] \
                        axis_unit $x_axis_unit \
                        resid [dict get $residue resid] \
                        chain [dict get $residue chain] \
                        masked $masked \
                        value $value \
                        x0 $x \
                        y0 $y \
                        x1 [expr {$x + $cell_w}] \
                        y1 [expr {$y + $panel_cell_h}] \
                        center_x [expr {$x + ($cell_w / 2.0)}] \
                        center_y [expr {$y + ($panel_cell_h / 2.0)}]]
                    set record [dict merge $residue $record]
                    lappend records $record
                    lappend cell_records $record
                    incr id
                }
            }
        }

        set mean_min ""
        set mean_max ""
        if {$show_summary} {
            for {set panel_index 0} {$panel_index < [llength $panels]} {incr panel_index} {
                set panel [lindex $panels $panel_index]
                set row_indices [dict get $panel row_indices]
                set chart_y0 $summary_y0
                set chart_y1 $summary_y1
                if {$multi_panel} {
                    set chart_y0 [dict get $panel summary_y0]
                    set chart_y1 [dict get $panel summary_y1]
                }
                set chart_h [expr {$chart_y1 - $chart_y0}]

                set means {}
                foreach column $columns {
                    set values [lindex $column 1]
                    set sum 0.0
                    set count 0
                    foreach row $row_indices {
                        set sum [expr {$sum + double([lindex $values $row])}]
                        incr count
                    }
                    if {$count == 0} {
                        set mean 0.0
                    } else {
                        set mean [expr {$sum / double($count)}]
                    }
                    lappend means [list [lindex $column 0] $mean]
                }

                set mean_values {}
                foreach item $means {
                    lappend mean_values [lindex $item 1]
                }
                set sorted_means [lsort -real $mean_values]
                set panel_mean_min [lindex $sorted_means 0]
                set panel_mean_max [lindex $sorted_means end]
                if {$mean_min eq "" || $panel_mean_min < $mean_min} {
                    set mean_min $panel_mean_min
                }
                if {$mean_max eq "" || $panel_mean_max > $mean_max} {
                    set mean_max $panel_mean_max
                }
                set mean_span [expr {double($panel_mean_max) - double($panel_mean_min)}]
                if {$mean_span == 0.0} {
                    set mean_span 1.0
                }

                set panel_summary_records {}
                for {set col 0} {$col < $cols} {incr col} {
                    set item [lindex $means $col]
                    set slice_label [lindex $item 0]
                    set mean [lindex $item 1]
                    set fraction [expr {(double($mean) - double($panel_mean_min)) / $mean_span}]
                    set fraction [clamp $fraction 0.0 1.0]
                    set cx [expr {$x0 + ($col * $cell_w) + ($cell_w / 2.0)}]
                    set cy [expr {$chart_y1 - ($fraction * $chart_h)}]
                    set record [dict create \
                        kind slice_summary \
                        id $id \
                        tag "rec$id" \
                        row "" \
                        panel_index $panel_index \
                        column $col \
                        slice_index [expr {$col + 1}] \
                        slice_label $slice_label \
                        axis_label [expr {$col < [llength $x_axis_labels] ? [lindex $x_axis_labels $col] : ""}] \
                        axis_unit $x_axis_unit \
                        resid "" \
                        chain [dict get $panel chain] \
                        value $mean \
                        center_x $cx \
                        center_y $cy \
                        x0 [expr {$cx - 5.0}] \
                        y0 $chart_y0 \
                        x1 [expr {$cx + 5.0}] \
                        y1 $chart_y1]
                    lappend records $record
                    lappend summary_records $record
                    lappend panel_summary_records $record
                    incr id
                }

                dict set panel summary_records $panel_summary_records
                dict set panel mean_min $panel_mean_min
                dict set panel mean_max $panel_mean_max
                lset panels $panel_index $panel
            }
        }

        return [dict create \
            records $records \
            cell_records $cell_records \
            summary_records $summary_records \
            rows $rows \
            columns $cols \
            canvas_width $canvas_w \
            canvas_height $canvas_h \
            left $left \
            right $right \
            top $top \
            bottom $bottom \
            plot_width $plot_w \
            cell_width $cell_w \
            cell_height $cell_h \
            show_title $show_title \
            show_heat_title $show_heat_title \
            show_summary $show_summary \
            show_rmsd $show_rmsd \
            show_slice_rmsd $show_slice_rmsd \
            show_rmsf $show_rmsf \
            rmsd_y0 $rmsd_y0 \
            rmsd_y1 $rmsd_y1 \
            slice_rmsd_y0 $slice_rmsd_y0 \
            slice_rmsd_y1 $slice_rmsd_y1 \
            summary_y0 $summary_y0 \
            summary_y1 $summary_y1 \
            heat_title_y $heat_title_y \
            heat_y0 $heat_y0 \
            heat_y1 $heat_y1 \
            panels $panels \
            multi_panel $multi_panel \
            chains $chains \
            chain_count [llength $chains] \
            rmsf_x0 $rmsf_x0 \
            rmsf_x1 $rmsf_x1 \
            rmsf_width $rmsf_w \
            masked_rows [dict size $masked_rows] \
            masked_cells $masked_cells \
            min [dict get $matrix min] \
            max [dict get $matrix max] \
            mean_min $mean_min \
            mean_max $mean_max \
            x_axis_labels $x_axis_labels \
            x_axis_title $x_axis_title \
            x_axis_unit $x_axis_unit]
    }

    proc install_record_map {records} {
        variable plot_records
        variable record_by_tag

        set plot_records $records
        catch {array unset record_by_tag}
        array set record_by_tag {}
        foreach record $records {
            set record_by_tag([dict get $record tag]) $record
        }
    }

    proc ensure_window {canvas_width canvas_height title} {
        variable window
        variable canvas

        package require Tk
        if {[winfo exists $window]} {
            destroy $window
        }
        toplevel $window
        wm title $window $title
        wm geometry $window [format "%dx%d" [expr {min($canvas_width + 28, 1180)}] [expr {min($canvas_height + 78, 860)}]]

        set outer [ttk::frame $window.outer -padding 8]
        grid $outer -row 0 -column 0 -sticky nsew
        grid rowconfigure $window 0 -weight 1
        grid columnconfigure $window 0 -weight 1
        grid rowconfigure $outer 0 -weight 1
        grid columnconfigure $outer 0 -weight 1

        set canvas $outer.canvas
        canvas $canvas \
            -background white \
            -width [expr {min($canvas_width, 1120)}] \
            -height [expr {min($canvas_height, 760)}] \
            -scrollregion [list 0 0 $canvas_width $canvas_height]
        set xbar $outer.xbar
        set ybar $outer.ybar
        ttk::scrollbar $xbar -orient horizontal -command [list $canvas xview]
        ttk::scrollbar $ybar -orient vertical -command [list $canvas yview]
        $canvas configure -xscrollcommand [list $xbar set] -yscrollcommand [list $ybar set]

        grid $canvas -row 0 -column 0 -sticky nsew
        grid $ybar -row 0 -column 1 -sticky ns
        grid $xbar -row 1 -column 0 -sticky ew

        ttk::label $outer.status \
            -textvariable ::RMSXFlipbookTimeline::PlotWindow::status_var \
            -anchor w
        grid $outer.status -row 2 -column 0 -columnspan 2 -sticky ew -pady {8 0}

        bind $window <Destroy> {+if {"%W" eq ".rmsxflipbooktimeline_plot"} {::RMSXFlipbookTimeline::PlotWindow::on_window_destroy}}
        return $canvas
    }

    proc on_window_destroy {} {
        variable canvas
        clear_structure_highlight
        remove_pick_trace
        set canvas ""
    }

    proc nice_step {count} {
        set step [expr {int(ceil($count / 10.0))}]
        if {$step < 1} {set step 1}
        return $step
    }

    proc nice_axis_step {count max_labels} {
        if {$max_labels < 1} {set max_labels 1}
        set step [expr {int(ceil(double($count) / double($max_labels)))}]
        if {$step < 1} {set step 1}
        return $step
    }

    proc numeric_extent {values} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::numeric_extent $values]
    }

    proc format_plot_number {value} {
        set number [expr {double($value)}]
        if {abs($number) < 1.0e-4} {
            return "0"
        }
        return [format "%.3g" $number]
    }

    proc format_time_ns_label {value} {
        set number [expr {double($value)}]
        if {abs($number) < 1.0e-9} {
            return "0"
        }
        if {abs($number) < 0.01} {
            return [format "%.3g" $number]
        }
        if {abs($number) < 10.0} {
            return [format "%.3g" $number]
        }
        return [format "%.4g" $number]
    }

    proc choose_time_axis_unit {max_time_ps} {
        if {[string is double -strict $max_time_ps] && double($max_time_ps) < 100.0} {
            return ps
        }
        return ns
    }

    proc format_time_axis_label {time_ps unit} {
        if {$unit eq "ps"} {
            return [format_plot_number $time_ps]
        }
        return [format_time_ns_label [expr {double($time_ps) / 1000.0}]]
    }

    proc axis_label_for_column {layout col fallback} {
        if {[dict exists $layout x_axis_labels]} {
            set labels [dict get $layout x_axis_labels]
            if {$col >= 0 && $col < [llength $labels]} {
                set label [string trim [lindex $labels $col]]
                if {$label ne ""} {
                    return $label
                }
            }
        }
        return $fallback
    }

    proc time_axis_spec_from_rmsd {rmsd_time_points column_count} {
        set count [llength $rmsd_time_points]
        if {$count == 0 || $column_count <= 0} {
            return [dict create labels {} unit ""]
        }
        set max_time_ps 0.0
        foreach point $rmsd_time_points {
            set time_ps [expr {double([lindex $point 1])}]
            if {$time_ps > $max_time_ps} {
                set max_time_ps $time_ps
            }
        }
        set unit [choose_time_axis_unit $max_time_ps]
        set labels {}
        for {set col 0} {$col < $column_count} {incr col} {
            set start [expr {int(floor(double($col) * double($count) / double($column_count)))}]
            set end [expr {int(floor(double($col + 1) * double($count) / double($column_count))) - 1}]
            if {$end < $start} {
                set end $start
            }
            if {$end >= $count} {
                set end [expr {$count - 1}]
            }
            set center [expr {int(floor(($start + $end) / 2.0))}]
            set time_ps [lindex [lindex $rmsd_time_points $center] 1]
            lappend labels [format_time_axis_label $time_ps $unit]
        }
        return [dict create labels $labels unit $unit]
    }

    proc time_axis_spec_from_step {column_count total_frames time_step_ps {first_frame 0}} {
        if {$column_count <= 0 || $total_frames <= 0 || ![string is double -strict $time_step_ps]} {
            return [dict create labels {} unit ""]
        }
        set time_step_ps [expr {double($time_step_ps)}]
        set first_frame [expr {int($first_frame)}]
        set max_frame [expr {$first_frame + int($total_frames) - 1}]
        set unit [choose_time_axis_unit [expr {double($max_frame) * $time_step_ps}]]
        set labels {}
        for {set col 0} {$col < $column_count} {incr col} {
            set start [expr {int(floor(double($col) * double($total_frames) / double($column_count)))}]
            set end [expr {int(floor(double($col + 1) * double($total_frames) / double($column_count))) - 1}]
            if {$end < $start} {
                set end $start
            }
            if {$end >= $total_frames} {
                set end [expr {$total_frames - 1}]
            }
            set center_frame [expr {$first_frame + int(floor(($start + $end) / 2.0))}]
            lappend labels [format_time_axis_label [expr {double($center_frame) * $time_step_ps}] $unit]
        }
        return [dict create labels $labels unit $unit]
    }

    proc xy_extents {points} {
        set xs {}
        set ys {}
        foreach point $points {
            lappend xs [lindex $point 0]
            lappend ys [lindex $point 1]
        }
        lassign [numeric_extent $xs] x_min x_max
        lassign [numeric_extent $ys] y_min y_max
        return [list $x_min $x_max $y_min $y_max]
    }

    proc map_xy {point x y w h x_min x_max y_min y_max} {
        set px [lindex $point 0]
        set py [lindex $point 1]
        if {$x_max <= $x_min} {
            set sx [expr {$x + ($w / 2.0)}]
        } else {
            set sx [expr {$x + ((double($px) - double($x_min)) / (double($x_max) - double($x_min)) * $w)}]
        }
        if {$y_max <= $y_min} {
            set sy [expr {$y + ($h / 2.0)}]
        } else {
            set sy [expr {$y + $h - ((double($py) - double($y_min)) / (double($y_max) - double($y_min)) * $h)}]
        }
        return [list $sx $sy]
    }

    proc draw_chart_grid {canvas x y w h {vertical 4} {horizontal 4}} {
        set grid_color "#e6e6e6"
        for {set i 1} {$i < $vertical} {incr i} {
            set gx [expr {$x + (double($i) / double($vertical) * $w)}]
            $canvas create line $gx $y $gx [expr {$y + $h}] -fill $grid_color -width 1
        }
        for {set i 1} {$i < $horizontal} {incr i} {
            set gy [expr {$y + (double($i) / double($horizontal) * $h)}]
            $canvas create line $x $gy [expr {$x + $w}] $gy -fill $grid_color -width 1
        }
    }

    proc panel_rmsf_points {panel rmsf_points} {
        set row_to_panel [dict create]
        set local_row 0
        foreach row [dict get $panel row_indices] {
            dict set row_to_panel $row $local_row
            incr local_row
        }

        set out {}
        foreach point $rmsf_points {
            set row [lindex $point 0]
            if {[dict exists $row_to_panel $row]} {
                lappend out [list [dict get $row_to_panel $row] [lindex $point 1]]
            }
        }
        return $out
    }

    proc read_rmsd_by_chain_points {csv_path} {
        if {$csv_path eq "" || ![file exists $csv_path]} {
            return [dict create]
        }
        set csv_data [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $csv_path]
        set header [dict get $csv_data header]
        set chain_index [::RMSXFlipbookTimeline::NativeAnalysis::csv_column_index $header ChainID]
        set frame_index [::RMSXFlipbookTimeline::NativeAnalysis::csv_column_index $header Frame]
        set rmsd_index [::RMSXFlipbookTimeline::NativeAnalysis::csv_column_index $header RMSD]
        set by_chain [dict create]
        foreach row [dict get $csv_data rows] {
            set chain [string trim [lindex $row $chain_index]]
            set frame [string trim [lindex $row $frame_index]]
            set rmsd [string trim [lindex $row $rmsd_index]]
            if {![string is double -strict $frame] || ![string is double -strict $rmsd]} {
                continue
            }
            dict lappend by_chain $chain [list [expr {double($frame)}] [expr {double($rmsd)}]]
        }
        return $by_chain
    }

    proc chain_rmsd_points {panel rmsd_points rmsd_by_chain_points} {
        set chain [string trim [dict get $panel chain]]
        if {[dict exists $rmsd_by_chain_points $chain]} {
            return [dict get $rmsd_by_chain_points $chain]
        }
        if {$chain eq "" && [dict exists $rmsd_by_chain_points "__blank__"]} {
            return [dict get $rmsd_by_chain_points "__blank__"]
        }
        return $rmsd_points
    }

    proc draw_line_chart {canvas x y w h points title color {point_radius 2.8} {label_position top}} {
        if {$label_position eq "y_axis"} {
            draw_y_axis_title $canvas [expr {$x - 52}] [expr {$y + ($h / 2.0)}] $title
        } else {
            $canvas create text $x [expr {$y - 10}] \
                -anchor w \
                -font TkHeadingFont \
                -fill "#333333" \
                -text $title
        }
        draw_chart_grid $canvas $x $y $w $h 6 5
        $canvas create line $x [expr {$y + $h}] [expr {$x + $w}] [expr {$y + $h}] -fill "#333333" -width 1
        $canvas create line $x $y $x [expr {$y + $h}] -fill "#333333" -width 1

        if {[llength $points] == 0} {
            $canvas create text [expr {$x + 8}] [expr {$y + ($h / 2.0)}] \
                -anchor w \
                -font TkSmallCaptionFont \
                -fill "#777777" \
                -text "No data"
            return
        }

        lassign [xy_extents $points] x_min x_max y_min y_max
        set coords {}
        foreach point $points {
            lassign [map_xy $point $x $y $w $h $x_min $x_max $y_min $y_max] sx sy
            lappend coords $sx $sy
        }
        if {[llength $coords] >= 4} {
            $canvas create line {*}$coords -fill $color -width 1.25 -smooth 0
        }
        if {[llength $points] <= 500 && $point_radius > 0.0} {
            foreach {sx sy} $coords {
                $canvas create oval \
                    [expr {$sx - $point_radius}] [expr {$sy - $point_radius}] \
                    [expr {$sx + $point_radius}] [expr {$sy + $point_radius}] \
                    -fill $color \
                    -outline white \
                    -width 1
            }
        }
        $canvas create text [expr {$x - 12}] $y -anchor e -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $y_max]
        $canvas create text [expr {$x - 12}] [expr {$y + $h}] -anchor e -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $y_min]
    }

    proc draw_summary_record_chart {canvas x y w h records title y_min y_max {color "#252525"}} {
        $canvas create text $x [expr {$y - 12}] \
            -anchor w \
            -font TkHeadingFont \
            -fill "#333333" \
            -text $title
        $canvas create line $x [expr {$y + $h}] [expr {$x + $w}] [expr {$y + $h}] -fill "#333333" -width 1
        $canvas create line $x $y $x [expr {$y + $h}] -fill "#333333" -width 1
        $canvas create line $x [expr {$y + ($h / 2.0)}] [expr {$x + $w}] [expr {$y + ($h / 2.0)}] -fill "#e5e7eb"
        $canvas create text [expr {$x - 8}] $y -anchor e -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $y_max]
        $canvas create text [expr {$x - 8}] [expr {$y + $h}] -anchor e -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $y_min]

        if {[llength $records] == 0} {
            $canvas create text [expr {$x + 8}] [expr {$y + ($h / 2.0)}] \
                -anchor w \
                -font TkSmallCaptionFont \
                -fill "#777777" \
                -text "No data"
            return
        }

        set points {}
        foreach record $records {
            lappend points [dict get $record center_x] [dict get $record center_y]
        }
        if {[llength $points] >= 4} {
            $canvas create line {*}$points -fill $color -width 2 -smooth 0
        }
        foreach record $records {
            set tag [dict get $record tag]
            set cx [dict get $record center_x]
            set cy [dict get $record center_y]
            $canvas create oval [expr {$cx - 4}] [expr {$cy - 4}] [expr {$cx + 4}] [expr {$cy + 4}] \
                -fill $color \
                -outline white \
                -width 1 \
                -tags [list pickable summary_point $tag]
        }
    }

    proc draw_rmsf_side_chart {canvas layout rmsf_points} {
        if {![dict get $layout show_rmsf]} {
            return
        }
        set x [dict get $layout rmsf_x0]
        set w [dict get $layout rmsf_width]
        set multi_panel [dict get $layout multi_panel]

        foreach panel [dict get $layout panels] {
            set y [dict get $panel y0]
            set h [expr {[dict get $panel y1] - [dict get $panel y0]}]
            set row_count [dict get $panel row_count]
            set panel_points [panel_rmsf_points $panel $rmsf_points]

            draw_chart_grid $canvas $x $y $w $h 4 5
            $canvas create line $x [expr {$y + $h}] [expr {$x + $w}] [expr {$y + $h}] -fill "#333333" -width 1
            $canvas create line $x $y $x [expr {$y + $h}] -fill "#333333" -width 1
            set rmsf_label "RMSF"
            if {$multi_panel} {
                set rmsf_label "RMSF ([dict get $panel label])"
            }
            $canvas create text [expr {$x + ($w / 2.0)}] [expr {$y + $h + 22}] \
                -anchor n \
                -font TkDefaultFont \
                -fill "#333333" \
                -text $rmsf_label
            if {[llength $panel_points] == 0 || $row_count <= 1} {
                $canvas create text [expr {$x + 8}] [expr {$y + 18}] \
                    -anchor w \
                    -font TkSmallCaptionFont \
                    -fill "#777777" \
                    -text "No data"
                continue
            }

            set values {}
            foreach point $panel_points {
                lappend values [lindex $point 1]
            }
            lassign [numeric_extent $values] min_val max_val
            set coords {}
            foreach point $panel_points {
                set row [lindex $point 0]
                set value [lindex $point 1]
                if {$max_val <= $min_val} {
                    set sx [expr {$x + ($w / 2.0)}]
                } else {
                    set sx [expr {$x + ((double($value) - double($min_val)) / (double($max_val) - double($min_val)) * $w)}]
                }
                set sy [expr {$y + (double($row) / double($row_count - 1) * $h)}]
                lappend coords $sx $sy
            }
            if {[llength $coords] >= 4} {
                $canvas create line {*}$coords -fill "#111111" -width 1.25 -smooth 0
            }
            $canvas create text $x [expr {$y + $h + 8}] -anchor nw -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $min_val]
            $canvas create text [expr {$x + $w}] [expr {$y + $h + 8}] -anchor ne -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $max_val]
        }
    }

    proc draw_mask_hatch {canvas record} {
        set x0 [dict get $record x0]
        set y0 [dict get $record y0]
        set x1 [dict get $record x1]
        set y1 [dict get $record y1]
        set tag [dict get $record tag]
        set w [expr {$x1 - $x0}]
        set h [expr {$y1 - $y0}]
        if {$w <= 0.0 || $h <= 0.0} {
            return
        }

        set hatch_tags [list pickable heat_cell mask_hatch $tag]
        set inset 0.7
        if {$h < 5.0 || $w < 18.0} {
            $canvas create line \
                [expr {$x0 + $inset}] [expr {$y1 - $inset}] \
                [expr {$x1 - $inset}] [expr {$y0 + $inset}] \
                -fill "#f8fafc" \
                -width 3 \
                -tags $hatch_tags
            $canvas create line \
                [expr {$x0 + $inset}] [expr {$y1 - $inset}] \
                [expr {$x1 - $inset}] [expr {$y0 + $inset}] \
                -fill "#111827" \
                -width 1 \
                -tags $hatch_tags
            return
        }
        set stripe_step 8.0
        if {$w > 120.0} {
            set stripe_step 10.0
        }
        set length [expr {max(4.0, min(12.0, $h * 1.7))}]
        set sx [expr {$x0 + $inset}]
        while {$sx < ($x1 - $inset)} {
            set ex [expr {$sx + $length}]
            if {$ex > ($x1 - $inset)} {
                set ex [expr {$x1 - $inset}]
            }
            set ey [expr {($y1 - $inset) - ($ex - $sx)}]
            if {$ey < ($y0 + $inset)} {
                set ey [expr {$y0 + $inset}]
                set ex [expr {$sx + (($y1 - $inset) - $ey)}]
            }
            if {$ex > $sx + 1.0} {
                $canvas create line \
                    $sx [expr {$y1 - $inset}] \
                    $ex $ey \
                    -fill "#f8fafc" \
                    -width 3 \
                    -tags $hatch_tags
                $canvas create line \
                    $sx [expr {$y1 - $inset}] \
                    $ex $ey \
                    -fill "#111827" \
                    -width 1 \
                    -tags $hatch_tags
            }
            set sx [expr {$sx + $stripe_step}]
        }
    }

    proc draw_mask_rails {canvas layout} {
        set drawn_rows [dict create]
        foreach record [dict get $layout cell_records] {
            if {![dict exists $record masked] || ![dict get $record masked]} {
                continue
            }
            set row_key "[dict get $record panel_index]:[dict get $record row]"
            if {[dict exists $drawn_rows $row_key]} {
                continue
            }
            dict set drawn_rows $row_key 1

            set x0 [dict get $record x0]
            set y0 [dict get $record y0]
            set y1 [dict get $record y1]
            $canvas create rectangle \
                [expr {$x0 - 7.0}] $y0 \
                [expr {$x0 - 3.0}] $y1 \
                -outline "" \
                -fill "#f59e0b" \
                -tags [list mask_rail]
        }
    }

    proc draw_canvas {layout matrix palette metric_label folder rmsd_points rmsd_by_chain_points rmsd_slice_points rmsf_points} {
        variable canvas

        $canvas delete all
        set min_val [dict get $layout min]
        set max_val [dict get $layout max]
        set left [dict get $layout left]
        set plot_w [dict get $layout plot_width]
        set x_right [expr {$left + $plot_w}]
        set summary_y0 [dict get $layout summary_y0]
        set summary_y1 [dict get $layout summary_y1]
        set heat_y0 [dict get $layout heat_y0]
        set heat_y1 [dict get $layout heat_y1]
        set multi_panel [dict get $layout multi_panel]

        if {[dict get $layout show_title]} {
            $canvas create text $left 24 \
                -anchor w \
                -font TkHeadingFont \
                -fill "#222222" \
                -text "$metric_label plot"
            $canvas create text $x_right 24 \
                -anchor e \
                -font TkDefaultFont \
                -fill "#555555" \
                -text [file tail $folder]
        }

        if {[dict get $layout show_rmsd] && !$multi_panel} {
            draw_line_chart \
                $canvas \
                $left \
                [dict get $layout rmsd_y0] \
                $plot_w \
                [expr {[dict get $layout rmsd_y1] - [dict get $layout rmsd_y0]}] \
                $rmsd_points \
                "RMSD" \
                "#111111" \
                0.0 \
                y_axis
        }

        if {[dict get $layout show_rmsd] && $multi_panel} {
            foreach panel [dict get $layout panels] {
                set panel_rmsd_y0 [dict get $panel rmsd_y0]
                set panel_rmsd_y1 [dict get $panel rmsd_y1]
                if {$panel_rmsd_y0 eq "" || $panel_rmsd_y1 eq ""} {
                    continue
                }
                draw_line_chart \
                    $canvas \
                    $left \
                    $panel_rmsd_y0 \
                    $plot_w \
                    [expr {$panel_rmsd_y1 - $panel_rmsd_y0}] \
                    [chain_rmsd_points $panel $rmsd_points $rmsd_by_chain_points] \
                    "RMSD ([dict get $panel label])" \
                    "#111111" \
                    0.0 \
                    y_axis
            }
        }

        if {[dict get $layout show_slice_rmsd]} {
            draw_line_chart \
                $canvas \
                $left \
                [dict get $layout slice_rmsd_y0] \
                $plot_w \
                [expr {[dict get $layout slice_rmsd_y1] - [dict get $layout slice_rmsd_y0]}] \
                $rmsd_slice_points \
                "Mean RMSD per slice" \
                "#7c3aed" \
                3.0
        }

        if {!$multi_panel && [dict get $layout show_summary]} {
            draw_summary_record_chart \
                $canvas \
                $left \
                $summary_y0 \
                $plot_w \
                [expr {$summary_y1 - $summary_y0}] \
                [dict get $layout summary_records] \
                "Mean $metric_label per slice" \
                [dict get $layout mean_min] \
                [dict get $layout mean_max]
        }
        if {[dict get $layout show_heat_title]} {
            set heat_title "$metric_label by residue and slice"
            if {$multi_panel} {
                set heat_title "Per-chain $metric_label plots"
            }
            $canvas create text $left [expr {[dict get $layout heat_title_y] - 8}] \
                -anchor w \
                -font TkHeadingFont \
                -fill "#333333" \
                -text $heat_title
        }

        if {$multi_panel && [dict get $layout show_summary]} {
            foreach panel [dict get $layout panels] {
                draw_summary_record_chart \
                    $canvas \
                    $left \
                    [dict get $panel summary_y0] \
                    $plot_w \
                    [expr {[dict get $panel summary_y1] - [dict get $panel summary_y0]}] \
                    [dict get $panel summary_records] \
                    "Mean $metric_label per slice ([dict get $panel label])" \
                    [dict get $panel mean_min] \
                    [dict get $panel mean_max]
            }
        }

        foreach record [dict get $layout cell_records] {
            set tag [dict get $record tag]
            set value [dict get $record value]
            $canvas create rectangle \
                [dict get $record x0] [dict get $record y0] \
                [dict get $record x1] [dict get $record y1] \
                -outline "" \
                -fill [::RMSXFlipbookTimeline::NativeAnalysis::heatmap_color $value $min_val $max_val $palette] \
                -tags [list pickable heat_cell $tag]
            if {[dict exists $record masked] && [dict get $record masked]} {
                draw_mask_hatch $canvas $record
            }
        }

        set cols [dict get $layout columns]
        set rows [dict get $layout rows]
        set cell_w [dict get $layout cell_width]
        set col_step [nice_axis_step $cols 5]
        set residues [dict get $matrix residues]
        foreach panel [dict get $layout panels] {
            set panel_y0 [dict get $panel y0]
            set panel_y1 [dict get $panel y1]
            set panel_cell_h [dict get $panel cell_height]
            set row_indices [dict get $panel row_indices]
            set panel_rows [dict get $panel row_count]

            if {$multi_panel} {
                $canvas create text $left [expr {$panel_y0 - 13}] \
                    -anchor w \
                    -font TkHeadingFont \
                    -fill "#333333" \
                    -text [format "%s (%d residues)" [dict get $panel label] $panel_rows]
            }
            draw_y_axis_title $canvas [expr {$left - 50}] [expr {($panel_y0 + $panel_y1) / 2.0}] "Residue (index)"

            $canvas create rectangle $left $panel_y0 $x_right $panel_y1 -outline "#333333" -width 1
            for {set col 0} {$col < $cols} {incr col $col_step} {
                set x [expr {$left + ($col * $cell_w) + ($cell_w / 2.0)}]
                $canvas create line $x $panel_y1 $x [expr {$panel_y1 + 5}] -fill "#444444"
                $canvas create text $x [expr {$panel_y1 + 8}] \
                    -anchor n \
                    -font TkSmallCaptionFont \
                    -fill "#444444" \
                    -text [axis_label_for_column $layout $col [expr {$col + 1}]]
            }
            if {[string trim [dict get $layout x_axis_title]] ne ""} {
                $canvas create text [expr {$left + ($plot_w / 2.0)}] [expr {$panel_y1 + 24}] \
                    -anchor n \
                    -font TkDefaultFont \
                    -fill "#333333" \
                    -text [dict get $layout x_axis_title]
            }

            set row_step [nice_step $panel_rows]
            for {set panel_row 0} {$panel_row < $panel_rows} {incr panel_row $row_step} {
                set row [lindex $row_indices $panel_row]
                set y [expr {$panel_y0 + ($panel_row * $panel_cell_h) + ($panel_cell_h / 2.0)}]
                set label [residue_axis_label [lindex $residues $row]]
                $canvas create line [expr {$left - 5}] $y $left $y -fill "#444444"
                $canvas create text [expr {$left - 8}] $y \
                    -anchor e \
                    -font TkSmallCaptionFont \
                    -fill "#444444" \
                    -text $label
            }
        }

        draw_vertical_legend \
            $canvas \
            20 \
            [expr {$heat_y0 + (($heat_y1 - $heat_y0 - min(180.0, max(96.0, ($heat_y1 - $heat_y0) * 0.58))) / 2.0)}] \
            14 \
            [expr {min(180.0, max(96.0, ($heat_y1 - $heat_y0) * 0.58))}] \
            $min_val \
            $max_val \
            $palette \
            $metric_label
        if {[dict get $layout masked_rows] > 0} {
            $canvas create text $left [expr {$heat_y1 + 38}] \
                -anchor nw \
                -font TkSmallCaptionFont \
                -fill "#555555" \
                -text "Masked residues are shown with diagonal hatch marks."
        }
        draw_rmsf_side_chart $canvas $layout $rmsf_points

        $canvas bind pickable <Button-1> {::RMSXFlipbookTimeline::PlotWindow::pick_current}
        $canvas bind pickable <Motion> {::RMSXFlipbookTimeline::PlotWindow::hover_current}
        $canvas bind pickable <Leave> {::RMSXFlipbookTimeline::PlotWindow::clear_hover}
        ::RMSXFlipbookTimeline::Navigation::attach $canvas [dict get $layout records] [list ::RMSXFlipbookTimeline::PlotWindow::select_on_canvas $canvas] [list ::RMSXFlipbookTimeline::PlotWindow::clear_on_canvas $canvas]
    }

    proc draw_vertical_legend {canvas x y w h min_val max_val palette metric_label} {
        set steps 80
        for {set i 0} {$i < $steps} {incr i} {
            set t [expr {$i / double($steps - 1)}]
            set value [expr {$max_val - (($max_val - $min_val) * $t)}]
            set y0 [expr {$y + ($i * ($h / double($steps)))}]
            set y1 [expr {$y + (($i + 1) * ($h / double($steps)))}]
            $canvas create rectangle $x $y0 [expr {$x + $w}] $y1 \
                -outline "" \
                -fill [::RMSXFlipbookTimeline::NativeAnalysis::heatmap_color $value $min_val $max_val $palette]
        }
        $canvas create rectangle $x $y [expr {$x + $w}] [expr {$y + $h}] -outline "#444444"
        $canvas create text [expr {$x + ($w / 2.0)}] [expr {$y - 18}] \
            -anchor s \
            -font TkDefaultFont \
            -fill "#333333" \
            -text $metric_label
        $canvas create text [expr {$x + $w + 7}] $y \
            -anchor w \
            -font TkSmallCaptionFont \
            -fill "#555555" \
            -text [format_plot_number $max_val]
        $canvas create text [expr {$x + $w + 7}] [expr {$y + $h}] \
            -anchor w \
            -font TkSmallCaptionFont \
            -fill "#555555" \
            -text [format_plot_number $min_val]
    }

    proc draw_legend {canvas x y w h min_val max_val palette metric_label} {
        set steps 80
        for {set i 0} {$i < $steps} {incr i} {
            set t [expr {$i / double($steps - 1)}]
            set value [expr {$min_val + (($max_val - $min_val) * $t)}]
            set x0 [expr {$x + ($i * ($w / double($steps)))}]
            set x1 [expr {$x + (($i + 1) * ($w / double($steps)))}]
            $canvas create rectangle $x0 $y $x1 [expr {$y + $h}] \
                -outline "" \
                -fill [::RMSXFlipbookTimeline::NativeAnalysis::heatmap_color $value $min_val $max_val $palette]
        }
        $canvas create rectangle $x $y [expr {$x + $w}] [expr {$y + $h}] -outline "#444444"
        $canvas create text $x [expr {$y + $h + 5}] -anchor nw -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $min_val]
        $canvas create text [expr {$x + $w}] [expr {$y + $h + 5}] -anchor ne -font TkSmallCaptionFont -fill "#555555" -text [format_plot_number $max_val]
        $canvas create text [expr {$x + ($w / 2.0)}] [expr {$y + $h + 5}] -anchor n -font TkSmallCaptionFont -fill "#555555" -text $metric_label
    }

    proc record_from_current {} {
        variable canvas
        variable record_by_tag

        if {$canvas eq "" || [info commands winfo] eq "" || ![winfo exists $canvas]} {
            return {}
        }
        set current [$canvas find withtag current]
        if {[llength $current] == 0} {
            return {}
        }
        foreach tag [$canvas gettags [lindex $current 0]] {
            if {[info exists record_by_tag($tag)]} {
                return $record_by_tag($tag)
            }
        }
        return {}
    }

    proc pick_current {} {
        set record [record_from_current]
        if {$record eq ""} {
            return
        }
        return [select_record $record]
    }

    proc hover_current {} {
        variable status_var
        set record [record_from_current]
        if {$record eq ""} {
            return
        }
        set status_var [status_for_record $record]
    }

    proc clear_hover {} {
        variable status_var
        if {$status_var eq ""} {
            return
        }
    }

    proc clear_canvas_highlight {} {
        variable canvas
        if {$canvas ne "" && [info commands winfo] ne "" && [winfo exists $canvas]} {
            catch {$canvas delete selection_highlight}
        }
    }

    proc clear_structure_highlight {} {
        variable highlight_reps
        foreach item $highlight_reps {
            set molid [lindex $item 0]
            set repid [lindex $item 1]
            if {[lsearch -exact [molinfo list] $molid] != -1} {
                catch {mol delrep $repid $molid}
            }
        }
        set highlight_reps {}
    }

    proc add_highlight_rep {molid selection} {
        variable highlight_reps
        if {[lsearch -exact [molinfo list] $molid] == -1} {
            return
        }
        mol representation VDW 0.9 12
        mol selection $selection
        mol color ColorID 4
        mol material Opaque
        mol addrep $molid
        set repid [expr {[molinfo $molid get numreps] - 1}]
        lappend highlight_reps [list $molid $repid]
    }

    proc draw_canvas_selection {record} {
        variable canvas
        if {$canvas eq "" || [info commands winfo] eq "" || ![winfo exists $canvas]} {
            return
        }

        if {[record_kind $record] eq "slice_summary"} {
            set x [dict get $record center_x]
            set y [dict get $record center_y]
            $canvas create line $x [dict get $record y0] $x [dict get $record y1] \
                -fill "#facc15" \
                -width 2 \
                -tags selection_highlight
            $canvas create oval [expr {$x - 8}] [expr {$y - 8}] [expr {$x + 8}] [expr {$y + 8}] \
                -outline "#facc15" \
                -width 3 \
                -tags selection_highlight
        } else {
            set x0 [dict get $record x0]
            set y0 [dict get $record y0]
            set x1 [dict get $record x1]
            set y1 [dict get $record y1]
            set cx [dict get $record center_x]
            set cy [dict get $record center_y]
            $canvas create rectangle $x0 $y0 $x1 $y1 \
                -outline "#facc15" \
                -width 3 \
                -tags selection_highlight
            $canvas create line $x0 $cy $x1 $cy \
                -fill "#facc15" \
                -width 2 \
                -tags selection_highlight
            $canvas create line $cx $y0 $cx $y1 \
                -fill "#facc15" \
                -width 2 \
                -tags selection_highlight
        }
    }

    proc status_for_record {record} {
        set time_part ""
        if {[dict exists $record axis_label] && [string trim [dict get $record axis_label]] ne ""} {
            set unit ns
            if {[dict exists $record axis_unit] && [string trim [dict get $record axis_unit]] ne ""} {
                set unit [dict get $record axis_unit]
            }
            set time_part [format {, time %s %s} [dict get $record axis_label] $unit]
        }
        set value_text [dict get $record value]
        if {[string is double -strict $value_text]} {
            set value_text [format "%.2f" [expr {double($value_text)}]]
        }
        if {[record_kind $record] eq "slice_summary"} {
            set chain [string trim [dict get $record chain]]
            if {$chain ne ""} {
                return [format {Slice %d%s, %s mean value %s} \
                    [dict get $record slice_index] \
                    $time_part \
                    [chain_display_label $chain] \
                    $value_text]
            }
            return [format {Slice %d%s, mean value %s} \
                [dict get $record slice_index] \
                $time_part \
                $value_text]
        }
        set suffix ""
        if {[dict exists $record masked] && [dict get $record masked]} {
            set suffix " (masked)"
        }
        return [format {Slice %d%s, residue %s, value %s} \
            [dict get $record slice_index] \
            $time_part \
            [residue_label $record] \
            $value_text]$suffix
    }

    proc select_on_canvas {target record} {
        variable canvas
        set old_canvas $canvas; set canvas $target
        try {return [select_record $record]} finally {set canvas $old_canvas}
    }
    proc clear_on_canvas {target} {
        variable canvas; variable selected_record
        set old_canvas $canvas; set canvas $target
        try {clear_canvas_highlight; clear_structure_highlight; set selected_record {}} finally {set canvas $old_canvas}
    }

    proc select_record {record} {
        variable selected_record
        variable status_var
        clear_canvas_highlight
        clear_structure_highlight
        set selected_record $record
        draw_canvas_selection $record

        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        set slice_zero [expr {[dict get $record slice_index] - 1}]
        if {$slice_zero >= 0 && $slice_zero < [llength $molids]} {
            set molid [lindex $molids $slice_zero]
            if {[record_kind $record] eq "cell"} {
                add_highlight_rep $molid [selection_for_record $record $molid]
            }
            catch {mol top $molid}
        }

        set status_var [status_for_record $record]
        puts "RMSX Flipbook Timeline plot: $status_var"
        return [dict merge $record [dict create message $status_var]]
    }

    proc select_cell {row column} {
        variable plot_records
        set row [expr {int($row)}]
        set column [expr {int($column)}]
        foreach record $plot_records {
            if {[record_kind $record] ne "cell"} {
                continue
            }
            if {[dict get $record row] == $row && [dict get $record column] == $column} {
                return [select_record $record]
            }
        }
        error "Plot cell not found: row=$row column=$column"
    }

    proc select_slice {slice_index} {
        variable plot_records
        set slice_index [expr {int($slice_index)}]
        set fallback {}
        foreach record $plot_records {
            if {[dict get $record slice_index] != $slice_index} {
                continue
            }
            if {[record_kind $record] eq "slice_summary"} {
                return [select_record $record]
            }
            if {$fallback eq "" && [record_kind $record] eq "cell"} {
                set fallback $record
            }
        }
        if {$fallback ne ""} {
            return [select_record $fallback]
        }
        error "Plot slice not found: $slice_index"
    }

    proc select_structure_atom {molid atom_index} {
        variable plot_records
        set slice_zero [lsearch -exact [::RMSXFlipbookTimeline::state_get molids {}] $molid]
        if {$slice_zero < 0} {error "Picked molecule is not part of the loaded RMSX flipbook: $molid"}
        set picked [atomselect $molid "index $atom_index"]
        try {
            if {[$picked num] != 1} {error "Picked atom is not present: $atom_index"}
            set residue [lindex [$picked get residue] 0]
        } finally {$picked delete}
        set matches {}
        foreach record $plot_records {
            if {[record_kind $record] ne "cell" || [dict get $record slice_index] != $slice_zero+1} {continue}
            # Resolving against the actual target also rejects ambiguous legacy rows.
            if {[selection_for_record $record $molid] eq "residue $residue"} {lappend matches $record}
        }
        if {[llength $matches] != 1} {error "Picked residue maps to [llength $matches] plot cells"}
        return [select_record [lindex $matches 0]]
    }

    proc pick_callback {name element op} {
        global vmd_pick_atom vmd_pick_mol
        if {![info exists vmd_pick_mol] || ![info exists vmd_pick_atom]} {
            return
        }
        if {$vmd_pick_atom eq ""} {
            return
        }
        if {[lsearch -exact [::RMSXFlipbookTimeline::state_get molids {}] $vmd_pick_mol] != -1} {
            if {[catch {select_structure_atom $vmd_pick_mol $vmd_pick_atom} result]} {
                return
            }
            return $result
        }
        return
    }

    proc prepare {args} {
        set defaults [dict create \
            folder "" \
            csv "" \
            rmsd_csv rmsd.csv \
            rmsd_by_chain_csv rmsd_by_chain.csv \
            rmsf_csv rmsf.csv \
            palette "" \
            metric_label "" \
            min_value "" \
            max_value "" \
            width 960 \
            rmsd_height 76.0 \
            heatmap_min_height 300.0 \
            heatmap_max_height 560.0 \
            chain_heatmap_min_height 220.0 \
            chain_heatmap_max_height 380.0 \
            chart_gap 28.0 \
            rmsf_width 84.0 \
            side_gap 34.0 \
            left_margin 146.0 \
            min_plot_width 280.0 \
            rmsf_right_padding 44.0 \
            top_margin "" \
            bottom_margin "" \
            show_title 1 \
            show_heat_title 1 \
            show_rmsd_chart 1 \
            show_rmsf_chart 1 \
            show_slice_rmsd_chart 1 \
            show_summary_chart 1 \
            time_step_ps "" \
            total_frames "" \
            first_frame 0 \
            draw 1 \
            pick 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set folder [current_folder [dict get $opts folder]]
        set matrix [matrix_from_folder $folder [dict get $opts csv]]
        if {[string trim [dict get $opts min_value]] ne ""} {
            dict set matrix min [expr {double([dict get $opts min_value])}]
        }
        if {[string trim [dict get $opts max_value]] ne ""} {
            dict set matrix max [expr {double([dict get $opts max_value])}]
        }
        set palette [string trim [dict get $opts palette]]
        if {$palette eq ""} {
            set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        }
        set metric_label [string trim [dict get $opts metric_label]]
        if {$metric_label eq ""} {
            set metric_label [::RMSXFlipbookTimeline::NativeAnalysis::infer_metric_label [dict get $matrix csv]]
        }

        set rmsd_path [::RMSXFlipbookTimeline::NativeAnalysis::resolve_optional_output_file $folder [dict get $opts rmsd_csv] rmsd.csv]
        set rmsd_by_chain_path [::RMSXFlipbookTimeline::NativeAnalysis::resolve_optional_output_file $folder [dict get $opts rmsd_by_chain_csv] rmsd_by_chain.csv]
        set rmsf_path [::RMSXFlipbookTimeline::NativeAnalysis::resolve_optional_output_file $folder [dict get $opts rmsf_csv] rmsf.csv]
        set rmsd_points {}
        set rmsd_by_chain_points [dict create]
        set rmsd_slice_points {}
        set rmsf_points {}
        if {[file exists $rmsd_path]} {
            set rmsd_points [::RMSXFlipbookTimeline::NativeAnalysis::read_numeric_xy_csv $rmsd_path Frame RMSD]
            set rmsd_time_points [::RMSXFlipbookTimeline::NativeAnalysis::read_numeric_xy_csv $rmsd_path Frame Time]
            set rmsd_slice_points [::RMSXFlipbookTimeline::NativeAnalysis::binned_y_means $rmsd_points [llength [dict get $matrix columns]]]
        }
        if {[file exists $rmsd_by_chain_path]} {
            set rmsd_by_chain_points [read_rmsd_by_chain_points $rmsd_by_chain_path]
        }
        if {[file exists $rmsf_path]} {
            set rmsf_points [::RMSXFlipbookTimeline::NativeAnalysis::read_rmsf_points_for_records $rmsf_path [dict get $matrix residues]]
        }

        set x_axis_labels {}
        set x_axis_title ""
        set x_axis_unit ""
        set column_count [llength [dict get $matrix columns]]
        if {[info exists rmsd_time_points] && [llength $rmsd_time_points] > 0} {
            set time_spec [time_axis_spec_from_rmsd $rmsd_time_points $column_count]
            set x_axis_labels [dict get $time_spec labels]
            set x_axis_unit [dict get $time_spec unit]
        } elseif {[string trim [dict get $opts time_step_ps]] ne "" && [string trim [dict get $opts total_frames]] ne ""} {
            if {[string is integer -strict [dict get $opts total_frames]] && [dict get $opts total_frames] > 0} {
                set time_spec [time_axis_spec_from_step \
                    $column_count \
                    [dict get $opts total_frames] \
                    [dict get $opts time_step_ps] \
                    [dict get $opts first_frame]]
                set x_axis_labels [dict get $time_spec labels]
                set x_axis_unit [dict get $time_spec unit]
            }
        }
        if {[llength $x_axis_labels] == $column_count && $column_count > 0} {
            if {$x_axis_unit eq ""} {
                set x_axis_unit ns
            }
            set x_axis_title "Time ($x_axis_unit)"
        }

        set layout [build_layout $matrix \
            width [dict get $opts width] \
            heatmap_min_height [dict get $opts heatmap_min_height] \
            heatmap_max_height [dict get $opts heatmap_max_height] \
            chain_heatmap_min_height [dict get $opts chain_heatmap_min_height] \
            chain_heatmap_max_height [dict get $opts chain_heatmap_max_height] \
            chart_gap [dict get $opts chart_gap] \
            rmsd_height [dict get $opts rmsd_height] \
            rmsf_width [dict get $opts rmsf_width] \
            side_gap [dict get $opts side_gap] \
            left_margin [dict get $opts left_margin] \
            min_plot_width [dict get $opts min_plot_width] \
            rmsf_right_padding [dict get $opts rmsf_right_padding] \
            top_margin [dict get $opts top_margin] \
            bottom_margin [dict get $opts bottom_margin] \
            rmsd_points $rmsd_points \
            rmsd_by_chain_points $rmsd_by_chain_points \
            rmsd_slice_points $rmsd_slice_points \
            rmsf_points $rmsf_points \
            show_title [dict get $opts show_title] \
            show_heat_title [dict get $opts show_heat_title] \
            show_rmsd_chart [dict get $opts show_rmsd_chart] \
            show_rmsf_chart [dict get $opts show_rmsf_chart] \
            show_slice_rmsd_chart [dict get $opts show_slice_rmsd_chart] \
            show_summary_chart [dict get $opts show_summary_chart] \
            x_axis_labels $x_axis_labels \
            x_axis_title $x_axis_title \
            x_axis_unit $x_axis_unit]
        return [dict create \
            opts $opts \
            folder $folder \
            matrix $matrix \
            palette $palette \
            metric_label $metric_label \
            rmsd_points $rmsd_points \
            rmsd_by_chain_points $rmsd_by_chain_points \
            rmsd_slice_points $rmsd_slice_points \
            rmsf_points $rmsf_points \
            layout $layout]
    }

    proc draw_prepared {target_canvas prepared} {
        variable canvas
        set canvas $target_canvas
        set layout [dict get $prepared layout]
        install_record_map [dict get $layout records]
        draw_canvas \
            $layout \
            [dict get $prepared matrix] \
            [dict get $prepared palette] \
            [dict get $prepared metric_label] \
            [dict get $prepared folder] \
            [dict get $prepared rmsd_points] \
            [dict get $prepared rmsd_by_chain_points] \
            [dict get $prepared rmsd_slice_points] \
            [dict get $prepared rmsf_points]
        return [result_from_prepared $prepared 1 [dict get [dict get $prepared opts] pick]]
    }

    proc result_from_prepared {prepared drawn pick} {
        set layout [dict get $prepared layout]
        set matrix [dict get $prepared matrix]
        set rmsd_points [dict get $prepared rmsd_points]
        set rmsd_slice_points [dict get $prepared rmsd_slice_points]
        set rmsf_points [dict get $prepared rmsf_points]
        return [dict create \
            window [expr {$drawn ? $::RMSXFlipbookTimeline::PlotWindow::window : ""}] \
            drawn $drawn \
            cells [llength [dict get $layout cell_records]] \
            summary_points [llength [dict get $layout summary_records]] \
            rows [dict get $layout rows] \
            columns [dict get $layout columns] \
            masked_rows [dict get $layout masked_rows] \
            masked_cells [dict get $layout masked_cells] \
            chain_panels [dict get $layout chain_count] \
            chains [dict get $layout chains] \
            split_by_chain [dict get $layout multi_panel] \
            csv [dict get $matrix csv] \
            rmsd_csv [::RMSXFlipbookTimeline::NativeAnalysis::resolve_optional_output_file [dict get $prepared folder] [dict get [dict get $prepared opts] rmsd_csv] rmsd.csv] \
            rmsf_csv [::RMSXFlipbookTimeline::NativeAnalysis::resolve_optional_output_file [dict get $prepared folder] [dict get [dict get $prepared opts] rmsf_csv] rmsf.csv] \
            rmsd_points [llength $rmsd_points] \
            rmsd_slice_points [llength $rmsd_slice_points] \
            rmsf_points [llength $rmsf_points] \
            flanking_plots [expr {[dict get $layout show_rmsd] || [dict get $layout show_rmsf]}] \
            folder [dict get $prepared folder] \
            metric_label [dict get $prepared metric_label] \
            min [dict get $layout min] \
            max [dict get $layout max] \
            palette [dict get $prepared palette] \
            pick $pick]
    }

    proc show {args} {
        variable status_var
        variable canvas

        clear 0
        set prepared [prepare {*}$args]
        set opts [dict get $prepared opts]
        set layout [dict get $prepared layout]
        install_record_map [dict get $layout records]
        set drawn 0

        if {[dict get $opts draw]} {
            set canvas [ensure_window [dict get $layout canvas_width] [dict get $layout canvas_height] "RMSX Flipbook Timeline Plot"]
            draw_prepared $canvas $prepared
            set status_var "Click a heatmap cell or slice-mean point; RMSD/RMSF context is shown when available."
            set drawn 1
        } else {
            set canvas ""
            set status_var ""
        }

        if {[dict get $opts pick]} {
            install_pick_trace
        }

        set result [result_from_prepared $prepared $drawn [dict get $opts pick]]

        ::RMSXFlipbookTimeline::state_set plot_window_open $drawn
        puts [format {RMSX Flipbook Timeline: 2D plot prepared with %d heatmap cells, %d slice points, %d RMSD points, and %d RMSF points from %s} \
            [dict get $result cells] \
            [dict get $result summary_points] \
            [dict get $result rmsd_points] \
            [dict get $result rmsf_points] \
            [file tail [dict get $result csv]]]
        return $result
    }
}
