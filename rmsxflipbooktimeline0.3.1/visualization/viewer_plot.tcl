################################################################################
# RMSX Flipbook Timeline in-viewer plot overlay
################################################################################

namespace eval ::RMSXFlipbookTimeline::ViewerPlot {
    variable plot_molid ""
    variable plot_records {}
    variable plot_atom_map
    variable plot_tmp_path ""
    variable plot_trace_installed 0
    variable highlight_reps {}
    variable highlight_graphics {}
    variable selected_record {}

    array set plot_atom_map {}

    proc reset_plot_state {} {
        variable plot_records
        variable plot_atom_map
        variable highlight_reps
        variable highlight_graphics
        variable selected_record

        set plot_records {}
        array unset plot_atom_map
        array set plot_atom_map {}
        set highlight_reps {}
        set highlight_graphics {}
        set selected_record {}
    }

    proc remove_pick_trace {} {
        variable plot_trace_installed
        if {$plot_trace_installed} {
            catch {trace remove variable ::vmd_pick_atom write ::RMSXFlipbookTimeline::ViewerPlot::pick_callback}
            catch {trace vdelete ::vmd_pick_atom w ::RMSXFlipbookTimeline::ViewerPlot::pick_callback}
            set plot_trace_installed 0
        }
    }

    proc install_pick_trace {} {
        variable plot_trace_installed
        if {!$plot_trace_installed} {
            trace add variable ::vmd_pick_atom write ::RMSXFlipbookTimeline::ViewerPlot::pick_callback
            set plot_trace_installed 1
        }
    }

    proc clear {} {
        variable plot_molid
        variable plot_tmp_path

        clear_highlight
        remove_pick_trace

        if {$plot_molid ne "" && [lsearch -exact [molinfo list] $plot_molid] != -1} {
            catch {mol delete $plot_molid}
        }
        set plot_molid ""

        if {$plot_tmp_path ne "" && [file exists $plot_tmp_path]} {
            catch {file delete $plot_tmp_path}
        }
        set plot_tmp_path ""
        reset_plot_state
        return 1
    }

    proc current_folder {folder} {
        set cleaned [string trim $folder]
        if {$cleaned ne ""} {
            return [file normalize $cleaned]
        }
        set loaded [::RMSXFlipbookTimeline::state_get source_folder ""]
        if {$loaded eq ""} {
            error "No RMSX folder is loaded; pass a folder to show_viewer_plot"
        }
        return [file normalize $loaded]
    }

    proc molecule_bounds {molids} {
        set initialized 0
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }
            set sel [atomselect $molid all]
            if {[$sel num] == 0} {
                $sel delete
                continue
            }
            set mm [measure minmax $sel]
            $sel delete
            set minv [lindex $mm 0]
            set maxv [lindex $mm 1]
            if {!$initialized} {
                set xmin [lindex $minv 0]
                set ymin [lindex $minv 1]
                set zmin [lindex $minv 2]
                set xmax [lindex $maxv 0]
                set ymax [lindex $maxv 1]
                set zmax [lindex $maxv 2]
                set initialized 1
            } else {
                if {[lindex $minv 0] < $xmin} {set xmin [lindex $minv 0]}
                if {[lindex $minv 1] < $ymin} {set ymin [lindex $minv 1]}
                if {[lindex $minv 2] < $zmin} {set zmin [lindex $minv 2]}
                if {[lindex $maxv 0] > $xmax} {set xmax [lindex $maxv 0]}
                if {[lindex $maxv 1] > $ymax} {set ymax [lindex $maxv 1]}
                if {[lindex $maxv 2] > $zmax} {set zmax [lindex $maxv 2]}
            }
        }

        if {!$initialized} {
            return [dict create xmin -25.0 xmax 25.0 ymin -10.0 ymax 10.0 zmin 0.0 zmax 0.0]
        }
        return [dict create xmin $xmin xmax $xmax ymin $ymin ymax $ymax zmin $zmin zmax $zmax]
    }

    proc clamp {value min_val max_val} {
        if {$value < $min_val} {return $min_val}
        if {$value > $max_val} {return $max_val}
        return $value
    }

    proc unique_tmp_pdb {} {
        set channel [file tempfile path rmsx_viewer_plot_]
        close $channel
        return $path
    }

    proc pdb_atom_line {serial x y z value {resname PLT} {atom_name C}} {
        set chain P
        set resid [expr {($serial % 9999) + 1}]
        return [format "ATOM  %5d  %-3s %3s %1s%4d    %8.3f%8.3f%8.3f  1.00%6.2f           C" \
            $serial $atom_name $resname $chain $resid $x $y $z $value]
    }

    proc write_plot_pdb {path records} {
        set fp [open $path w]
        try {
            puts $fp "REMARK RMSX Flipbook Timeline in-viewer plot pseudoatoms"
            set serial 1
            foreach record $records {
                set resname PLT
                set atom_name C
                if {[dict exists $record kind] && [dict get $record kind] eq "slice_summary"} {
                    set resname AVG
                    set atom_name M
                }
                puts $fp [pdb_atom_line \
                    $serial \
                    [dict get $record x] \
                    [dict get $record y] \
                    [dict get $record z] \
                    [dict get $record value] \
                    $resname \
                    $atom_name]
                incr serial
            }
            puts $fp "END"
        } finally {
            catch {close $fp}
        }
    }

    proc matrix_from_folder {folder csv_path} {
        set csv [::RMSXFlipbookTimeline::NativeAnalysis::resolve_folder_csv $folder $csv_path]
        set data [::RMSXFlipbookTimeline::NativeAnalysis::read_simple_csv $csv]
        set parsed [::RMSXFlipbookTimeline::NativeAnalysis::csv_to_records_and_columns $data]
        set residues [dict get $parsed residue_records]
        set columns [dict get $parsed slice_columns]
        if {[llength $residues] == 0 || [llength $columns] == 0} {
            error "Cannot draw viewer plot for empty RMSX matrix: $csv"
        }
        set range [::RMSXFlipbookTimeline::NativeAnalysis::matrix_value_range $columns]
        return [dict create csv $csv residues $residues columns $columns min [lindex $range 0] max [lindex $range 1]]
    }

    proc build_records {matrix args} {
        set defaults [dict create \
            width auto \
            max_height 34.0 \
            margin 8.0 \
            z_offset 0.0 \
            summary 1 \
            summary_height 9.0 \
            summary_gap 4.0]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set residues [dict get $matrix residues]
        set columns [dict get $matrix columns]
        set rows [llength $residues]
        set cols [llength $columns]
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        set bounds [molecule_bounds $molids]

        set scene_width [expr {double([dict get $bounds xmax] - [dict get $bounds xmin])}]
        if {$scene_width <= 0.0} {
            set scene_width 50.0
        }

        set requested_width [string trim [dict get $opts width]]
        if {$requested_width eq "" || [string tolower $requested_width] eq "auto"} {
            set plot_width [clamp $scene_width 28.0 180.0]
        } else {
            set plot_width [expr {double($requested_width)}]
        }
        set cell_dx [expr {$plot_width / double($cols)}]
        set cell_dx [clamp $cell_dx 0.75 4.0]
        set plot_width [expr {$cell_dx * double($cols)}]

        set max_height [expr {double([dict get $opts max_height])}]
        set cell_dy [expr {$max_height / double($rows)}]
        set cell_dy [clamp $cell_dy 0.28 0.85]
        set plot_height [expr {$cell_dy * double($rows)}]

        set center_x [expr {([dict get $bounds xmin] + [dict get $bounds xmax]) / 2.0}]
        set x0 [expr {$center_x - ($plot_width / 2.0) + ($cell_dx / 2.0)}]
        set y_top [expr {[dict get $bounds ymin] - double([dict get $opts margin])}]
        set show_summary [expr {[dict get $opts summary] ? 1 : 0}]
        set summary_height [expr {double([dict get $opts summary_height])}]
        set summary_gap [expr {double([dict get $opts summary_gap])}]
        if {!$show_summary} {
            set summary_height 0.0
            set summary_gap 0.0
        }
        set summary_y_top $y_top
        set summary_y_bottom [expr {$summary_y_top - $summary_height}]
        if {$show_summary} {
            set y_top [expr {$summary_y_bottom - $summary_gap}]
        }
        set y0 [expr {$y_top - ($cell_dy / 2.0)}]
        set z0 [expr {[dict get $bounds zmin] + double([dict get $opts z_offset])}]
        set x_left [expr {$x0 - ($cell_dx / 2.0)}]
        set x_right [expr {$x_left + $plot_width}]
        set y_bottom [expr {$y_top - $plot_height}]

        set records {}
        set atom_index 0
        for {set col 0} {$col < $cols} {incr col} {
            set column [lindex $columns $col]
            set slice_label [lindex $column 0]
            set values [lindex $column 1]
            for {set row 0} {$row < $rows} {incr row} {
                set residue [lindex $residues $row]
                set value [expr {double([lindex $values $row])}]
                set x [expr {$x0 + ($col * $cell_dx)}]
                set y [expr {$y0 - ($row * $cell_dy)}]
                lappend records [dict merge $residue [dict create \
                    kind cell \
                    atom_index $atom_index \
                    row $row \
                    column $col \
                    slice_index [expr {$col + 1}] \
                    slice_label $slice_label \
                    resid [dict get $residue resid] \
                    chain [dict get $residue chain] \
                    value $value \
                    x $x \
                    y $y \
                    z $z0 \
                    cell_dx $cell_dx \
                    cell_dy $cell_dy \
                    plot_x_left $x_left \
                    plot_x_right $x_right \
                    plot_y_top $y_top \
                    plot_y_bottom $y_bottom]]
                incr atom_index
            }
        }

        set summary_records {}
        set summary_min ""
        set summary_max ""
        if {$show_summary} {
            set means {}
            foreach column $columns {
                set slice_label [lindex $column 0]
                set values [lindex $column 1]
                set sum 0.0
                set count 0
                foreach value $values {
                    set sum [expr {$sum + double($value)}]
                    incr count
                }
                if {$count == 0} {
                    set mean 0.0
                } else {
                    set mean [expr {$sum / double($count)}]
                }
                lappend means [list $slice_label $mean]
            }
            set mean_values {}
            foreach item $means {
                lappend mean_values [lindex $item 1]
            }
            set sorted_means [lsort -real $mean_values]
            set summary_min [lindex $sorted_means 0]
            set summary_max [lindex $sorted_means end]
            set summary_span [expr {double($summary_max) - double($summary_min)}]
            if {$summary_span == 0.0} {
                set summary_span 1.0
            }

            for {set col 0} {$col < $cols} {incr col} {
                set item [lindex $means $col]
                set slice_label [lindex $item 0]
                set mean [lindex $item 1]
                set fraction [expr {(double($mean) - double($summary_min)) / $summary_span}]
                set fraction [clamp $fraction 0.0 1.0]
                set x [expr {$x0 + ($col * $cell_dx)}]
                set y [expr {$summary_y_bottom + ($fraction * $summary_height)}]
                set record [dict create \
                    kind slice_summary \
                    atom_index $atom_index \
                    row "" \
                    column $col \
                    slice_index [expr {$col + 1}] \
                    slice_label $slice_label \
                    resid "" \
                    chain "" \
                    value $mean \
                    x $x \
                    y $y \
                    z [expr {$z0 + 0.12}] \
                    cell_dx [expr {max($cell_dx, 1.2)}] \
                    cell_dy 1.2 \
                    plot_x_left $x_left \
                    plot_x_right $x_right \
                    plot_y_top $summary_y_top \
                    plot_y_bottom $summary_y_bottom \
                    summary_min $summary_min \
                    summary_max $summary_max]
                lappend records $record
                lappend summary_records $record
                incr atom_index
            }
        }

        return [dict create \
            records $records \
            summary_records $summary_records \
            rows $rows \
            columns $cols \
            x0 $x0 \
            y0 $y0 \
            z0 $z0 \
            cell_dx $cell_dx \
            cell_dy $cell_dy \
            width $plot_width \
            height $plot_height \
            x_left $x_left \
            x_right $x_right \
            y_top $y_top \
            y_bottom $y_bottom \
            summary $show_summary \
            summary_y_top $summary_y_top \
            summary_y_bottom $summary_y_bottom \
            summary_height $summary_height \
            summary_gap $summary_gap \
            summary_min $summary_min \
            summary_max $summary_max]
    }

    proc install_record_map {records} {
        variable plot_atom_map
        variable plot_records

        array unset plot_atom_map
        array set plot_atom_map {}
        set plot_records $records
        foreach record $records {
            set plot_atom_map([dict get $record atom_index]) $record
        }
    }

    proc configure_plot_molecule {molid records min_val max_val palette cell_radius summary_radius} {
        set sel [atomselect $molid all]
        set values {}
        set summary_count 0
        foreach record $records {
            lappend values [dict get $record value]
            if {[dict exists $record kind] && [dict get $record kind] eq "slice_summary"} {
                incr summary_count
            }
        }
        $sel set user2 $values
        $sel set beta $values
        $sel set occupancy [lrepeat [llength $values] 1.0]
        $sel delete

        mol rename $molid "RMSX Viewer Plot"
        mol delrep 0 $molid
        mol representation VDW $cell_radius 10
        mol selection "resname PLT"
        mol color User2
        mol material AOChalky
        mol addrep $molid
        mol scaleminmax $molid 0 $min_val $max_val
        catch {mol colupdate 0 $molid on}
        if {$summary_count > 0} {
            mol representation VDW $summary_radius 16
            mol selection "resname AVG"
            mol color User2
            mol material AOChalky
            mol addrep $molid
            mol scaleminmax $molid 1 $min_val $max_val
            catch {mol colupdate 1 $molid on}
        }
        ::RMSXFlipbookTimeline::Style::apply_palette $palette
    }

    proc draw_summary_chart {molid layout metric_label} {
        set records [dict get $layout summary_records]
        if {[llength $records] == 0} {
            return
        }

        set x_left [dict get $layout x_left]
        set x_right [dict get $layout x_right]
        set y_top [dict get $layout summary_y_top]
        set y_bottom [dict get $layout summary_y_bottom]
        set z [expr {[dict get $layout z0] + 0.07}]
        set min_val [dict get $layout summary_min]
        set max_val [dict get $layout summary_max]

        graphics $molid color black
        graphics $molid line [list $x_left $y_bottom $z] [list $x_right $y_bottom $z] width 2
        graphics $molid line [list $x_left $y_bottom $z] [list $x_left $y_top $z] width 2
        graphics $molid text [list $x_left [expr {$y_top + 1.2}] $z] "Mean $metric_label per slice" size 0.65
        graphics $molid text [list [expr {$x_left - 4.8}] [expr {$y_bottom - 0.25}] $z] [format "%.3g" $min_val] size 0.5
        graphics $molid text [list [expr {$x_left - 4.8}] [expr {$y_top - 0.25}] $z] [format "%.3g" $max_val] size 0.5

        set previous {}
        graphics $molid color black
        foreach record $records {
            set point [list [dict get $record x] [dict get $record y] $z]
            if {$previous ne ""} {
                graphics $molid line $previous $point width 2
            }
            set previous $point
        }
    }

    proc draw_axes {molid layout metric_label min_val max_val folder} {
        set x_left [dict get $layout x_left]
        set x_right [dict get $layout x_right]
        set y_top [dict get $layout y_top]
        set y_bottom [dict get $layout y_bottom]
        set z [expr {[dict get $layout z0] + 0.05}]

        graphics $molid materials off
        graphics $molid color black
        graphics $molid line [list $x_left $y_top $z] [list $x_right $y_top $z] width 2
        graphics $molid line [list $x_left $y_top $z] [list $x_left $y_bottom $z] width 2
        set title_y [expr {$y_top + 2.4}]
        if {[dict get $layout summary]} {
            set title_y [expr {[dict get $layout summary_y_top] + 2.4}]
        }
        graphics $molid text [list $x_left $title_y $z] "$metric_label viewer plot" size 1.0
        graphics $molid text [list $x_left [expr {$y_bottom - 2.2}] $z] [format "%.3g" $min_val] size 0.7
        graphics $molid text [list [expr {$x_right - 5.0}] [expr {$y_bottom - 2.2}] $z] [format "%.3g" $max_val] size 0.7
        graphics $molid text [list [expr {$x_left + 12.0}] [expr {$y_bottom - 2.2}] $z] [file tail $folder] size 0.7

        set cols [dict get $layout columns]
        set rows [dict get $layout rows]
        set step_col [expr {int(ceil($cols / 8.0))}]
        set step_row [expr {int(ceil($rows / 8.0))}]
        if {$step_col < 1} {set step_col 1}
        if {$step_row < 1} {set step_row 1}

        for {set col 0} {$col < $cols} {incr col $step_col} {
            set x [expr {[dict get $layout x0] + ($col * [dict get $layout cell_dx])}]
            graphics $molid color gray
            graphics $molid line [list $x $y_top $z] [list $x [expr {$y_top + 1.0}] $z] width 1
            graphics $molid color black
            graphics $molid text [list [expr {$x - 0.6}] [expr {$y_top + 1.3}] $z] [expr {$col + 1}] size 0.55
        }

        for {set row 0} {$row < $rows} {incr row $step_row} {
            set y [expr {[dict get $layout y0] - ($row * [dict get $layout cell_dy])}]
            graphics $molid color gray
            graphics $molid line [list [expr {$x_left - 1.0}] $y $z] [list $x_left $y $z] width 1
            graphics $molid color black
            graphics $molid text [list [expr {$x_left - 4.6}] [expr {$y - 0.25}] $z] [expr {$row + 1}] size 0.55
        }

        draw_summary_chart $molid $layout $metric_label
    }

    proc selection_for_record {record {molid ""}} {
        return [::RMSXFlipbookTimeline::ResidueIdentity::selection $record $molid]
    }

    proc clear_highlight {} {
        variable highlight_reps
        variable highlight_graphics

        foreach item $highlight_reps {
            set molid [lindex $item 0]
            set repid [lindex $item 1]
            if {[lsearch -exact [molinfo list] $molid] != -1} {
                catch {mol delrep $repid $molid}
            }
        }
        set highlight_reps {}

        foreach item $highlight_graphics {
            set molid [lindex $item 0]
            set gid [lindex $item 1]
            if {[lsearch -exact [molinfo list] $molid] != -1} {
                catch {graphics $molid delete $gid}
            }
        }
        set highlight_graphics {}
    }

    proc add_highlight_rep {molid selection color radius} {
        variable highlight_reps
        if {[lsearch -exact [molinfo list] $molid] == -1} {
            return
        }
        mol representation VDW $radius 12
        mol selection $selection
        mol color ColorID $color
        mol material Opaque
        mol addrep $molid
        set repid [expr {[molinfo $molid get numreps] - 1}]
        lappend highlight_reps [list $molid $repid]
    }

    proc draw_plot_pick_marker {record} {
        variable plot_molid
        variable highlight_graphics
        if {$plot_molid eq "" || [lsearch -exact [molinfo list] $plot_molid] == -1} {
            return
        }
        set x [dict get $record x]
        set y [dict get $record y]
        set z [expr {[dict get $record z] + 0.45}]
        set dx [dict get $record cell_dx]
        set dy [dict get $record cell_dy]
        set x0 [expr {$x - ($dx / 2.0)}]
        set x1 [expr {$x + ($dx / 2.0)}]
        set y0 [expr {$y - ($dy / 2.0)}]
        set y1 [expr {$y + ($dy / 2.0)}]
        set line_z [expr {[dict get $record z] + 0.25}]
        graphics $plot_molid color yellow
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list [dict get $record plot_x_left] $y $line_z] [list [dict get $record plot_x_right] $y $line_z] width 2]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list $x [dict get $record plot_y_top] $line_z] [list $x [dict get $record plot_y_bottom] $line_z] width 2]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list $x0 $y0 $line_z] [list $x1 $y0 $line_z] width 3]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list $x1 $y0 $line_z] [list $x1 $y1 $line_z] width 3]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list $x1 $y1 $line_z] [list $x0 $y1 $line_z] width 3]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list $x0 $y1 $line_z] [list $x0 $y0 $line_z] width 3]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid sphere [list $x $y $z] radius 0.55 resolution 12]]
        graphics $plot_molid color black
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid text [list [expr {$x + 0.8}] [expr {$y + 0.8}] $z] [format "S%d %s %.3g" \
            [dict get $record slice_index] \
            [residue_label $record] \
            [dict get $record value]] size 0.65]]
    }

    proc draw_summary_pick_marker {record} {
        variable plot_molid
        variable highlight_graphics
        if {$plot_molid eq "" || [lsearch -exact [molinfo list] $plot_molid] == -1} {
            return
        }
        set x [dict get $record x]
        set y [dict get $record y]
        set z [expr {[dict get $record z] + 0.45}]
        set line_z [expr {[dict get $record z] + 0.25}]
        graphics $plot_molid color yellow
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list $x [dict get $record plot_y_top] $line_z] [list $x [dict get $record plot_y_bottom] $line_z] width 3]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid line [list [dict get $record plot_x_left] $y $line_z] [list [dict get $record plot_x_right] $y $line_z] width 2]]
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid sphere [list $x $y $z] radius 0.7 resolution 16]]
        graphics $plot_molid color black
        lappend highlight_graphics [list $plot_molid [graphics $plot_molid text [list [expr {$x + 0.9}] [expr {$y + 0.9}] $z] [format "S%d mean %.3g" \
            [dict get $record slice_index] \
            [dict get $record value]] size 0.65]]
    }

    proc draw_slice_marker {molid record} {
        variable highlight_graphics
        if {[lsearch -exact [molinfo list] $molid] == -1} {
            return
        }
        set sel [atomselect $molid all]
        if {[$sel num] == 0} {
            $sel delete
            return
        }
        set mm [measure minmax $sel]
        $sel delete
        set minv [lindex $mm 0]
        set maxv [lindex $mm 1]
        set x [expr {([lindex $minv 0] + [lindex $maxv 0]) / 2.0}]
        set y [expr {[lindex $maxv 1] + 3.0}]
        set z [expr {[lindex $maxv 2] + 0.5}]
        graphics $molid color yellow
        lappend highlight_graphics [list $molid [graphics $molid text [list $x $y $z] [format "slice %d" [dict get $record slice_index]] size 1.0]]
    }

    proc residue_label {record} {
        return [::RMSXFlipbookTimeline::ResidueIdentity::label $record]
    }

    proc record_chain_matches {record chain segid} {
        set record_chain [string trim [dict get $record chain]]
        if {$record_chain eq ""} {
            return 1
        }
        if {[string trim $chain] ne "" && $record_chain eq [string trim $chain]} {
            return 1
        }
        if {[string trim $segid] ne "" && $record_chain eq [string trim $segid]} {
            return 1
        }
        return 0
    }

    proc record_kind {record} {
        if {[dict exists $record kind]} {
            return [dict get $record kind]
        }
        return cell
    }

    proc record_for_structure_residue {slice_index resid chain segid} {
        # Compatibility API: missing insertion/occurrence information is allowed
        # only when it identifies exactly one matrix cell.
        return [record_for_structure_identity $slice_index [dict create resid $resid chain $chain segid $segid]]
    }

    proc record_for_structure_identity {slice_index actual} {
        variable plot_records
        set matches {}
        foreach record $plot_records {
            if {[record_kind $record] ne "cell" || [dict get $record slice_index] != $slice_index} {
                continue
            }
            if {[::RMSXFlipbookTimeline::ResidueIdentity::full $actual]} {
                set match [::RMSXFlipbookTimeline::ResidueIdentity::matches $record $actual]
            } else {
                set match [::RMSXFlipbookTimeline::ResidueIdentity::matches $actual $record]
            }
            if {$match} {lappend matches $record}
        }
        if {[llength $matches] > 1} {error "Picked residue matches multiple viewer plot cells; full residue identity is required"}
        return [lindex $matches 0]
    }

    proc select_record {record} {
        variable selected_record
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        set slice_zero [expr {[dict get $record slice_index] - 1}]
        set kind [record_kind $record]
        set selection ""
        if {$kind eq "cell" && $slice_zero >= 0 && $slice_zero < [llength $molids]} {
            set selection [selection_for_record $record [lindex $molids $slice_zero]]
        }
        clear_highlight
        set selected_record $record
        if {$slice_zero >= 0 && $slice_zero < [llength $molids]} {
            set molid [lindex $molids $slice_zero]
            if {$kind eq "cell"} {
                add_highlight_rep $molid $selection 4 0.9
            }
            draw_slice_marker $molid $record
            catch {mol top $molid}
        }
        if {$kind eq "slice_summary"} {
            add_highlight_rep [plot_molid] "index [dict get $record atom_index]" 4 0.75
            draw_summary_pick_marker $record
            set message [format {RMSX Flipbook Timeline viewer plot: slice %d (%s), mean value %.6g} \
                [dict get $record slice_index] \
                [dict get $record slice_label] \
                [dict get $record value]]
        } else {
            add_highlight_rep [plot_molid] "index [dict get $record atom_index]" 4 0.55
            draw_plot_pick_marker $record
            set message [format {RMSX Flipbook Timeline viewer plot: slice %d (%s), residue %s, value %.6g} \
                [dict get $record slice_index] \
                [dict get $record slice_label] \
                [residue_label $record] \
                [dict get $record value]]
        }
        puts $message
        return [dict merge $record [dict create message $message]]
    }

    proc plot_molid {} {
        variable plot_molid
        return $plot_molid
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
        error "Viewer plot cell not found: row=$row column=$column"
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
        error "Viewer plot slice not found: $slice_index"
    }

    proc select_atom {atom_index} {
        variable plot_atom_map
        if {![info exists plot_atom_map($atom_index)]} {
            error "Viewer plot atom is not mapped: $atom_index"
        }
        return [select_record $plot_atom_map($atom_index)]
    }

    proc select_structure_atom {molid atom_index} {
        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        set slice_zero [lsearch -exact $molids $molid]
        if {$slice_zero == -1} {
            error "Picked molecule is not part of the loaded RMSX flipbook: $molid"
        }

        set sel [atomselect $molid "index $atom_index"]
        try {
            if {[$sel num] == 0} {
                error "Picked atom is not present in molecule $molid: $atom_index"
            }
            set residue [lindex [$sel get residue] 0]
        } finally {
            catch {$sel delete}
        }
        set sel [atomselect $molid all]
        try {set identities [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $sel]} finally {$sel delete}
        set actual {}
        foreach identity $identities {
            if {[dict get $identity residue] == $residue} {set actual $identity; break}
        }
        if {$actual eq {}} {error "Picked residue is not present in molecule $molid"}
        set slice_index [expr {$slice_zero + 1}]
        set record [record_for_structure_identity $slice_index $actual]
        if {$record eq ""} {
            error "No viewer plot cell matches slice $slice_index residue [residue_label $actual]"
        }
        return [select_record $record]
    }

    proc pick_callback {name element op} {
        variable plot_molid
        global vmd_pick_atom vmd_pick_mol
        if {$plot_molid eq ""} {
            return
        }
        if {![info exists vmd_pick_mol] || ![info exists vmd_pick_atom]} {
            return
        }
        if {$vmd_pick_atom eq ""} {
            return
        }
        if {$vmd_pick_mol eq $plot_molid} {
            if {[catch {select_atom $vmd_pick_atom} result]} {
                return
            }
            return $result
        }
        if {[lsearch -exact [::RMSXFlipbookTimeline::state_get molids {}] $vmd_pick_mol] != -1} {
            if {[catch {select_structure_atom $vmd_pick_mol $vmd_pick_atom} result]} {
                return
            }
            return $result
        }
        return
    }

    proc show {args} {
        variable plot_molid
        variable plot_tmp_path

        set defaults [dict create \
            folder "" \
            csv "" \
            palette "" \
            metric_label "" \
            min_value "" \
            max_value "" \
            width auto \
            max_height 34.0 \
            margin 8.0 \
            radius 0.32 \
            summary 1 \
            summary_height 9.0 \
            summary_gap 4.0 \
            summary_radius "" \
            pick 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        clear

        set folder [current_folder [dict get $opts folder]]
        set matrix [matrix_from_folder $folder [dict get $opts csv]]
        set min_val [dict get $matrix min]
        set max_val [dict get $matrix max]
        if {[string trim [dict get $opts min_value]] ne ""} {
            set min_val [expr {double([dict get $opts min_value])}]
        }
        if {[string trim [dict get $opts max_value]] ne ""} {
            set max_val [expr {double([dict get $opts max_value])}]
        }
        set palette [string trim [dict get $opts palette]]
        if {$palette eq ""} {
            set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        }
        set metric_label [string trim [dict get $opts metric_label]]
        if {$metric_label eq ""} {
            set metric_label [::RMSXFlipbookTimeline::NativeAnalysis::infer_metric_label [dict get $matrix csv]]
        }

        set layout [build_records $matrix \
            width [dict get $opts width] \
            max_height [dict get $opts max_height] \
            margin [dict get $opts margin] \
            summary [dict get $opts summary] \
            summary_height [dict get $opts summary_height] \
            summary_gap [dict get $opts summary_gap]]
        set records [dict get $layout records]
        install_record_map $records

        set tmp_path [unique_tmp_pdb]
        set plot_tmp_path $tmp_path
        write_plot_pdb $tmp_path $records

        mol new $tmp_path type pdb autobonds off filebonds off waitfor all
        set plot_molid [molinfo top get id]
        set summary_radius [string trim [dict get $opts summary_radius]]
        if {$summary_radius eq ""} {
            set summary_radius [expr {double([dict get $opts radius]) * 1.45}]
        }
        configure_plot_molecule $plot_molid $records $min_val $max_val $palette [dict get $opts radius] $summary_radius
        draw_axes $plot_molid $layout $metric_label $min_val $max_val $folder

        if {[dict get $opts pick]} {
            install_pick_trace
        }

        if {![catch {file delete $tmp_path}]} {set plot_tmp_path ""}

        set result [dict create \
            molid $plot_molid \
            atoms [llength $records] \
            rows [dict get $layout rows] \
            columns [dict get $layout columns] \
            summary [dict get $layout summary] \
            summary_points [llength [dict get $layout summary_records]] \
            csv [dict get $matrix csv] \
            folder $folder \
            metric_label $metric_label \
            min $min_val \
            max $max_val \
            palette $palette \
            pick [dict get $opts pick]]

        ::RMSXFlipbookTimeline::state_set viewer_plot_molid $plot_molid
        puts [format {RMSX Flipbook Timeline: viewer plot loaded %d pickable plot points from %s} [llength $records] [file tail [dict get $matrix csv]]]
        return $result
    }
}
