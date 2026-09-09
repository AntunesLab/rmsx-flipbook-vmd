################################################################################
# RMSX Flipbook Timeline live matrix plot window
################################################################################

namespace eval ::RMSXFlipbookTimeline::TimelinePlot {
    variable window ".rmsxflipbooktimeline_timeline_plot"
    variable canvas ""
    variable scrubber ""
    variable scrub_var 0
    variable scrub_syncing 0
    variable status_var ""
    variable current_dataset {}
    variable current_palette viridis
    variable current_scale_min 0.0
    variable current_scale_max 1.0
    variable neighborhood_enabled_var 0
    variable neighborhood_window_var 4
    variable neighborhood_step_var 1
    variable neighborhood_summary_var "Nearby frames off"
    variable record_by_tag
    variable highlight_reps {}
    variable trace_installed 0
    variable selected_record {}
    variable candidate_serial 0

    array set record_by_tag {}

    proc clear {{destroy_window 1}} {
        variable window
        variable canvas
        variable scrubber
        variable scrub_var
        variable scrub_syncing
        variable current_dataset
        variable selected_record
        clear_structure_highlight
        if {[info commands ::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear] ne ""} {
            catch {::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear}
        }
        remove_pick_trace
        if {$destroy_window && [info commands winfo] ne "" && [winfo exists $window]} {
            catch {destroy $window}
        }
        set canvas ""
        set scrubber ""
        set scrub_var 0
        set scrub_syncing 0
        set current_dataset {}
        set selected_record {}
        catch {array unset ::RMSXFlipbookTimeline::TimelinePlot::record_by_tag}
        array set ::RMSXFlipbookTimeline::TimelinePlot::record_by_tag {}
        return 1
    }

    proc remove_pick_trace {} {
        variable trace_installed
        if {$trace_installed} {
            catch {trace remove variable ::vmd_pick_atom write ::RMSXFlipbookTimeline::TimelinePlot::pick_callback}
            catch {trace vdelete ::vmd_pick_atom w ::RMSXFlipbookTimeline::TimelinePlot::pick_callback}
            set trace_installed 0
        }
    }

    proc install_pick_trace {} {
        variable trace_installed
        if {!$trace_installed} {
            trace add variable ::vmd_pick_atom write ::RMSXFlipbookTimeline::TimelinePlot::pick_callback
            set trace_installed 1
        }
    }

    proc clamp {value min_val max_val} {
        if {$value < $min_val} {return $min_val}
        if {$value > $max_val} {return $max_val}
        return $value
    }

    proc hex_to_rgb {hex} {
        set clean [string trimleft [string trim $hex] "#"]
        if {[string length $clean] != 6} {
            return {128 128 128}
        }
        scan $clean "%2x%2x%2x" r g b
        return [list $r $g $b]
    }

    proc rgb_to_hex {r g b} {
        foreach channel {r g b} {
            set value [set $channel]
            if {$value < 0} {set value 0}
            if {$value > 255} {set value 255}
            set $channel [expr {int(round($value))}]
        }
        return [format "#%02x%02x%02x" $r $g $b]
    }

    proc blend_color {start end t} {
        set t [clamp $t 0.0 1.0]
        lassign [hex_to_rgb $start] r0 g0 b0
        lassign [hex_to_rgb $end] r1 g1 b1
        return [rgb_to_hex \
            [expr {$r0 + (($r1 - $r0) * $t)}] \
            [expr {$g0 + (($g1 - $g0) * $t)}] \
            [expr {$b0 + (($b1 - $b0) * $t)}]]
    }

    proc fraction_color {value min_val max_val} {
        if {$max_val <= $min_val} {
            set t 0.0
        } else {
            set t [expr {(double($value) - double($min_val)) / (double($max_val) - double($min_val))}]
        }
        return [blend_color "#f3f4f6" "#2563eb" $t]
    }

    proc diverging_color {value min_val max_val} {
        set bound [expr {max(abs(double($min_val)), abs(double($max_val)))}]
        if {$bound <= 0.0} {
            set bound 1.0
        }
        set v [clamp [expr {double($value) / $bound}] -1.0 1.0]
        if {$v < 0.0} {
            return [blend_color "#2563eb" "#f7f7f7" [expr {$v + 1.0}]]
        }
        return [blend_color "#f7f7f7" "#d73027" $v]
    }

    proc struct_color {value} {
        switch -- $value {
            H {return "#d95f02"}
            G {return "#e7298a"}
            I {return "#e31a1c"}
            E {return "#1b9e77"}
            B {return "#a6d854"}
            T {return "#7570b3"}
            C {return "#f0f0f0"}
            default {return "#777777"}
        }
    }

    proc default_secondary_categories {} {
        return [list \
            [dict create value H label "H alpha helix" color "#d95f02"] \
            [dict create value G label "G 3-10 helix" color "#e7298a"] \
            [dict create value I label "I pi helix" color "#e31a1c"] \
            [dict create value E label "E beta strand" color "#1b9e77"] \
            [dict create value B label "B beta bridge" color "#a6d854"] \
            [dict create value T label "T turn" color "#7570b3"] \
            [dict create value C label "C coil" color "#f0f0f0"]]
    }

    proc default_binary_categories {} {
        return [list \
            [dict create value 0 label "0 inactive" color "#f3f4f6"] \
            [dict create value 1 label "1 active" color "#2563eb"]]
    }

    proc dataset_value_kind {dataset} {
        if {$dataset ne {} && [dict exists $dataset value_kind]} {
            return [string tolower [string trim [dict get $dataset value_kind]]]
        }
        return continuous
    }

    proc dataset_categories {dataset} {
        if {$dataset eq {}} {
            return {}
        }
        if {[dict exists $dataset categories] && [llength [dict get $dataset categories]] > 0} {
            return [dict get $dataset categories]
        }
        set kind [dataset_value_kind $dataset]
        set label [expr {[dict exists $dataset value_label] ? [string tolower [string trim [dict get $dataset value_label]]] : ""}]
        if {$kind eq "categorical" || $label in {struct structure secondary_structure}} {
            return [default_secondary_categories]
        }
        if {$kind eq "binary"} {
            return [default_binary_categories]
        }
        return {}
    }

    proc category_matches {category_value value} {
        set category_value [string trim $category_value]
        set value [string trim $value]
        if {[::RMSXFlipbookTimeline::Matrix::is_numeric $category_value] && [::RMSXFlipbookTimeline::Matrix::is_numeric $value]} {
            return [expr {abs(double($category_value) - double($value)) < 1.0e-9}]
        }
        return [expr {$category_value eq $value}]
    }

    proc category_color {dataset value} {
        set categories [dataset_categories $dataset]
        foreach category $categories {
            if {[category_matches [dict get $category value] $value]} {
                return [dict get $category color]
            }
        }
        if {[dataset_value_kind $dataset] eq "binary" && [::RMSXFlipbookTimeline::Matrix::is_numeric $value]} {
            if {$value >= 0.5} {
                return "#2563eb"
            }
            return "#f3f4f6"
        }
        return [struct_color $value]
    }

    proc cell_color {value min_val max_val palette {dataset {}}} {
        if {[llength [dataset_categories $dataset]] > 0} {
            return [category_color $dataset $value]
        }
        if {[::RMSXFlipbookTimeline::Matrix::is_numeric $value]} {
            set kind [dataset_value_kind $dataset]
            if {$kind eq "fraction"} {
                return [fraction_color $value $min_val $max_val]
            }
            if {$kind eq "diverging" || $kind eq "correlation"} {
                return [diverging_color $value $min_val $max_val]
            }
            return [::RMSXFlipbookTimeline::NativeAnalysis::heatmap_color $value $min_val $max_val $palette]
        }
        return [struct_color $value]
    }

    proc mask_hatch_segments {record} {
        set x0 [dict get $record x0]
        set y0 [dict get $record y0]
        set x1 [dict get $record x1]
        set y1 [dict get $record y1]
        set w [expr {$x1 - $x0}]
        set h [expr {$y1 - $y0}]
        if {$w <= 0.0 || $h <= 0.0} {
            return {}
        }

        set inset [expr {min(0.8, max(0.0, min($w, $h) / 4.0))}]
        set sx0 [expr {$x0 + $inset}]
        set sx1 [expr {$x1 - $inset}]
        set y_bottom [expr {$y1 - $inset}]
        set y_top [expr {$y0 + $inset}]
        if {$sx1 <= $sx0 || $y_bottom <= $y_top} {
            return [list [list $x0 $y1 $x1 $y0]]
        }

        if {$h < 5.0 || $w < 18.0} {
            return [list [list $sx0 $y_bottom $sx1 $y_top]]
        }

        set segments {}
        set stripe_step [expr {max(6.0, min(10.0, $h * 1.35))}]
        set length [expr {max(5.0, min(16.0, $h * 2.2))}]
        set sx $sx0
        while {$sx < $sx1} {
            set ex [expr {$sx + $length}]
            if {$ex > $sx1} {
                set ex $sx1
            }
            set ey [expr {$y_bottom - ($ex - $sx)}]
            if {$ey < $y_top} {
                set ey $y_top
                set ex [expr {$sx + ($y_bottom - $ey)}]
            }
            if {$ex > $sx + 1.0} {
                lappend segments [list $sx $y_bottom $ex $ey]
            }
            set sx [expr {$sx + $stripe_step}]
        }
        return $segments
    }

    proc draw_mask_hatch {canvas record tags} {
        set hatch_tags [concat $tags [list mask_hatch]]
        foreach segment [mask_hatch_segments $record] {
            lassign $segment x0 y0 x1 y1
            $canvas create line $x0 $y0 $x1 $y1 \
                -fill "#f8fafc" \
                -width 3 \
                -tags $hatch_tags
            $canvas create line $x0 $y0 $x1 $y1 \
                -fill "#111827" \
                -width 1 \
                -tags $hatch_tags
        }
    }

    proc write_svg_mask_hatch {fp record} {
        foreach segment [mask_hatch_segments $record] {
            lassign $segment x0 y0 x1 y1
            puts $fp [format {<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" stroke="#f8fafc" stroke-width="2.2" opacity="0.9"/>} \
                $x0 $y0 $x1 $y1]
            puts $fp [format {<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" stroke="#111827" stroke-width="0.8" opacity="0.75"/>} \
                $x0 $y0 $x1 $y1]
        }
    }

    proc color_scale_range {dataset opts} {
        set min_text [string trim [dict get $opts scale_min]]
        set max_text [string trim [dict get $opts scale_max]]
        if {$min_text eq "" && $max_text eq ""} {
            return [list [dict get $dataset min] [dict get $dataset max]]
        }
        if {$min_text eq "" || $max_text eq ""} {
            error "Timeline color scale needs both scale_min and scale_max"
        }
        if {![string is double -strict $min_text] || ![string is double -strict $max_text]} {
            error "Timeline color scale bounds must be numeric"
        }
        set min_val [expr {double($min_text)}]
        set max_val [expr {double($max_text)}]
        if {$max_val <= $min_val} {
            error "Timeline color scale maximum must be greater than minimum"
        }
        return [list $min_val $max_val]
    }

    proc timeline_controls_for_dataset {dataset} {
        set source_type ""
        if {[dict exists $dataset source_type]} {
            set source_type [string tolower [string trim [dict get $dataset source_type]]]
        }
        return [expr {$source_type eq "live_trajectory"}]
    }

    proc ensure_window {width height title args} {
        variable window
        variable canvas
        variable scrubber
        set defaults [dict create controls 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set show_controls [expr {[dict get $opts controls] ? 1 : 0}]
        package require Tk
        if {[winfo exists $window]} {
            destroy $window
        }
        toplevel $window
        wm title $window $title
        set chrome_h [expr {$show_controls ? 128 : 44}]
        set canvas_max_h [expr {$show_controls ? 780 : 880}]
        set window_max_h [expr {$show_controls ? 900 : 940}]
        set window_w [expr {min($width + 28, 1220)}]
        set window_h [expr {min(max($height + $chrome_h, 680), $window_max_h)}]
        wm geometry $window [format "%dx%d" $window_w $window_h]
        wm minsize $window [expr {min($window_w, 900)}] [expr {$show_controls ? 560 : 640}]

        set outer [ttk::frame $window.outer -padding 8]
        grid $outer -row 0 -column 0 -sticky nsew
        grid rowconfigure $window 0 -weight 1
        grid columnconfigure $window 0 -weight 1
        grid rowconfigure $outer 0 -weight 1
        grid columnconfigure $outer 0 -weight 1

        set canvas $outer.canvas
        canvas $canvas \
            -background white \
            -width [expr {min($width, 1160)}] \
            -height [expr {min($height, $canvas_max_h)}] \
            -scrollregion [list 0 0 $width $height]
        ttk::scrollbar $outer.xbar -orient horizontal -command [list $canvas xview]
        ttk::scrollbar $outer.ybar -orient vertical -command [list $canvas yview]
        $canvas configure -xscrollcommand [list $outer.xbar set] -yscrollcommand [list $outer.ybar set]
        grid $canvas -row 0 -column 0 -sticky nsew
        grid $outer.ybar -row 0 -column 1 -sticky ns
        grid $outer.xbar -row 1 -column 0 -sticky ew
        set scrubber ""
        if {$show_controls} {
            set scrubber_frame [ttk::frame $outer.scrubber_frame]
            set scrubber $scrubber_frame.scale
            ttk::label $scrubber_frame.label -text "Frame"
            ttk::scale $scrubber \
                -orient horizontal \
                -from 0 \
                -to 0 \
                -variable ::RMSXFlipbookTimeline::TimelinePlot::scrub_var \
                -command ::RMSXFlipbookTimeline::TimelinePlot::scrub_to_value
            grid columnconfigure $scrubber_frame 1 -weight 1
            grid $scrubber_frame.label -row 0 -column 0 -sticky w -padx {0 8}
            grid $scrubber -row 0 -column 1 -sticky ew
            grid $scrubber_frame -row 2 -column 0 -columnspan 2 -sticky ew -pady {8 0}
            set neighborhood_frame [ttk::frame $outer.neighborhood_frame]
            ttk::checkbutton $neighborhood_frame.enabled \
                -text "Nearby frames" \
                -variable ::RMSXFlipbookTimeline::TimelinePlot::neighborhood_enabled_var \
                -command ::RMSXFlipbookTimeline::TimelinePlot::toggle_neighborhood
            ttk::label $neighborhood_frame.window_label -text "+/-"
            ttk::entry $neighborhood_frame.window -width 4 -textvariable ::RMSXFlipbookTimeline::TimelinePlot::neighborhood_window_var
            ttk::label $neighborhood_frame.step_label -text "Step"
            ttk::entry $neighborhood_frame.step -width 4 -textvariable ::RMSXFlipbookTimeline::TimelinePlot::neighborhood_step_var
            ttk::button $neighborhood_frame.apply -text "Apply" -command ::RMSXFlipbookTimeline::TimelinePlot::refresh_neighborhood_from_selection
            ttk::button $neighborhood_frame.clear -text "Clear" -command ::RMSXFlipbookTimeline::TimelinePlot::clear_neighborhood
            ttk::label $neighborhood_frame.summary -textvariable ::RMSXFlipbookTimeline::TimelinePlot::neighborhood_summary_var -anchor w
            grid columnconfigure $neighborhood_frame 8 -weight 1
            grid $neighborhood_frame.enabled -row 0 -column 0 -sticky w -padx {0 12}
            grid $neighborhood_frame.window_label -row 0 -column 1 -sticky w -padx {0 4}
            grid $neighborhood_frame.window -row 0 -column 2 -sticky w -padx {0 12}
            grid $neighborhood_frame.step_label -row 0 -column 3 -sticky w -padx {0 4}
            grid $neighborhood_frame.step -row 0 -column 4 -sticky w -padx {0 12}
            grid $neighborhood_frame.apply -row 0 -column 5 -sticky w -padx {0 8}
            grid $neighborhood_frame.clear -row 0 -column 6 -sticky w -padx {0 12}
            grid $neighborhood_frame.summary -row 0 -column 8 -sticky ew
            grid $neighborhood_frame -row 3 -column 0 -columnspan 2 -sticky ew -pady {8 0}
            ttk::label $outer.status -textvariable ::RMSXFlipbookTimeline::TimelinePlot::status_var -anchor w
            grid $outer.status -row 4 -column 0 -columnspan 2 -sticky ew -pady {8 0}
        }
        bind $window <Destroy> [list ::RMSXFlipbookTimeline::TimelinePlot::window_destroyed $window %W]
        return $canvas
    }

    proc window_destroyed {expected actual} {
        variable window
        if {$actual eq $expected && $window eq $expected} {on_window_destroy}
    }

    proc on_window_destroy {} {
        variable canvas
        clear_structure_highlight
        if {[info commands ::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear] ne ""} {
            catch {::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear}
        }
        remove_pick_trace
        set canvas ""
    }

    proc sync_neighborhood_controls_from_state {} {
        variable neighborhood_enabled_var
        variable neighborhood_window_var
        variable neighborhood_step_var
        variable neighborhood_summary_var
        set neighborhood_enabled_var [::RMSXFlipbookTimeline::state_get timeline_neighborhood_enabled 0]
        set neighborhood_window_var [::RMSXFlipbookTimeline::state_get timeline_neighborhood_window 4]
        set neighborhood_step_var [::RMSXFlipbookTimeline::state_get timeline_neighborhood_step 1]
        if {$neighborhood_enabled_var} {
            set neighborhood_summary_var "Click a heatmap cell to open nearby frames."
        } else {
            set neighborhood_summary_var "Nearby frames off"
        }
    }

    proc persist_neighborhood_controls {} {
        variable neighborhood_enabled_var
        variable neighborhood_window_var
        variable neighborhood_step_var
        set enabled [expr {$neighborhood_enabled_var ? 1 : 0}]
        set window [string trim $neighborhood_window_var]
        set step [string trim $neighborhood_step_var]
        if {![string is integer -strict $window] || int($window) < 0} {
            error "Neighborhood window must be a non-negative integer"
        }
        if {![string is integer -strict $step] || int($step) < 1} {
            error "Neighborhood step must be a positive integer"
        }
        set window [expr {int($window)}]
        set step [expr {int($step)}]
        set neighborhood_window_var $window
        set neighborhood_step_var $step
        ::RMSXFlipbookTimeline::state_set timeline_neighborhood_enabled $enabled
        ::RMSXFlipbookTimeline::state_set timeline_neighborhood_window $window
        ::RMSXFlipbookTimeline::state_set timeline_neighborhood_step $step
        return [dict create enabled $enabled window $window step $step]
    }

    proc set_neighborhood_summary_from_status {status} {
        variable neighborhood_summary_var
        if {$status eq {} || ![dict exists $status message]} {
            set neighborhood_summary_var ""
            return
        }
        set neighborhood_summary_var [dict get $status message]
    }

    proc clear_neighborhood {} {
        variable neighborhood_enabled_var
        if {[info commands ::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear] ne ""} {
            set status [::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear]
            set_neighborhood_summary_from_status $status
        }
        return ""
    }

    proc toggle_neighborhood {} {
        variable neighborhood_enabled_var
        variable neighborhood_summary_var
        if {[catch {persist_neighborhood_controls} err]} {
            set neighborhood_enabled_var [::RMSXFlipbookTimeline::state_get timeline_neighborhood_enabled 0]
            set neighborhood_summary_var $err
            return ""
        }
        if {!$neighborhood_enabled_var} {
            clear_neighborhood
            set neighborhood_summary_var "Nearby frames off"
            return ""
        }
        refresh_neighborhood_from_selection
        return ""
    }

    proc refresh_neighborhood_from_selection {} {
        variable current_dataset
        variable selected_record
        variable current_palette
        variable current_scale_min
        variable current_scale_max
        variable neighborhood_summary_var
        if {[catch {persist_neighborhood_controls} err]} {
            set neighborhood_summary_var $err
            return [dict create enabled 0 created 0 message $err]
        }
        if {![::RMSXFlipbookTimeline::state_get timeline_neighborhood_enabled 0]} {
            set neighborhood_summary_var "Nearby frames off"
            return [dict create enabled 0 created 0 message "Nearby frames off"]
        }
        if {$current_dataset eq {} || $selected_record eq {} || ![dict exists $selected_record row] || ![dict exists $selected_record column]} {
            set neighborhood_summary_var "Click a heatmap cell to open nearby frames."
            return [dict create enabled 0 created 0 message $neighborhood_summary_var]
        }
        if {[catch {
            ::RMSXFlipbookTimeline::NeighborhoodFlipbook::show_for_selection \
                $current_dataset \
                $selected_record \
                palette $current_palette \
                scale_min $current_scale_min \
                scale_max $current_scale_max
        } status]} {
            set neighborhood_summary_var "Timeline neighborhood failed: $status"
            return [dict create enabled 0 created 0 message $neighborhood_summary_var]
        }
        set_neighborhood_summary_from_status $status
        return $status
    }

    proc build_layout {dataset args} {
        set defaults [dict create width 980 scale_mode fit threshold_min "" threshold_max "" scale_min "" scale_max ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set rows [llength [dict get $dataset rows]]
        set cols [llength [dict get $dataset columns]]
        if {$rows <= 0 || $cols <= 0} {
            error "Cannot draw empty Timeline dataset"
        }
        set left 130.0
        set right 36.0
        set top 84.0
        set threshold_h 54.0
        set heat_top [expr {$top + $threshold_h + 34.0}]
        set width [expr {double([dict get $opts width])}]
        set plot_w [expr {$width - $left - $right}]
        if {$plot_w < 300.0} {set plot_w 300.0}
        set cell_w [clamp [expr {$plot_w / double($cols)}] 8.0 82.0]
        set scale_mode [string tolower [dict get $opts scale_mode]]
        if {$scale_mode eq "every_residue" || $scale_mode eq "every_res"} {
            set cell_h 15.0
        } else {
            set cell_h [clamp [expr {560.0 / double($rows)}] 4.0 18.0]
        }
        set heat_h [expr {$cell_h * $rows}]
        set plot_w [expr {$cell_w * $cols}]
        set canvas_w [expr {int(ceil($left + $plot_w + $right))}]
        set canvas_h [expr {int(ceil($heat_top + $heat_h + 76.0))}]
        set records {}
        set id 0
        for {set col 0} {$col < $cols} {incr col} {
            for {set row 0} {$row < $rows} {incr row} {
                set x0 [expr {$left + ($col * $cell_w)}]
                set y0 [expr {$heat_top + ($row * $cell_h)}]
                lappend records [dict create \
                    id $id \
                    tag "timeline_rec_$id" \
                    row $row \
                    column $col \
                    x0 $x0 \
                    y0 $y0 \
                    x1 [expr {$x0 + $cell_w}] \
                    y1 [expr {$y0 + $cell_h}] \
                    center_x [expr {$x0 + ($cell_w / 2.0)}] \
                    center_y [expr {$y0 + ($cell_h / 2.0)}]]
                incr id
            }
        }
        return [dict create \
            records $records \
            rows $rows \
            columns $cols \
            canvas_width $canvas_w \
            canvas_height $canvas_h \
            left $left \
            right $right \
            top $top \
            threshold_h $threshold_h \
            threshold_y0 [expr {$top + 22.0}] \
            threshold_y1 [expr {$top + $threshold_h}] \
            heat_top $heat_top \
            heat_bottom [expr {$heat_top + $heat_h}] \
            plot_width $plot_w \
            cell_width $cell_w \
            cell_height $cell_h \
            threshold_min [dict get $opts threshold_min] \
            threshold_max [dict get $opts threshold_max] \
            scale_min [dict get $opts scale_min] \
            scale_max [dict get $opts scale_max]]
    }

    proc install_record_map {records} {
        variable record_by_tag
        catch {array unset record_by_tag}
        array set record_by_tag {}
        foreach record $records {
            set record_by_tag([dict get $record tag]) $record
        }
    }

    proc draw_threshold_graph {dataset layout} {
        variable canvas
        set min_value [string trim [dict get $layout threshold_min]]
        set max_value [string trim [dict get $layout threshold_max]]
        if {$min_value eq "" || $max_value eq ""} {
            return
        }
        set counts [::RMSXFlipbookTimeline::Matrix::threshold_counts $dataset $min_value $max_value]
        set max_count [lindex [lsort -integer $counts] end]
        if {$max_count <= 0} {set max_count 1}
        set y0 [dict get $layout threshold_y0]
        set y1 [dict get $layout threshold_y1]
        set left [dict get $layout left]
        set cell_w [dict get $layout cell_width]
        $canvas create text $left [expr {$y0 - 14}] -anchor w -font TkHeadingFont -fill "#333333" -text "Threshold count ($min_value to $max_value)"
        $canvas create line $left $y1 [expr {$left + [dict get $layout plot_width]}] $y1 -fill "#333333"
        for {set col 0} {$col < [llength $counts]} {incr col} {
            set count [lindex $counts $col]
            set x0 [expr {$left + ($col * $cell_w)}]
            set x1 [expr {$x0 + $cell_w}]
            set bar_y [expr {$y1 - (($y1 - $y0) * ($count / double($max_count)))}]
            $canvas create rectangle $x0 $bar_y $x1 $y1 -outline "" -fill "#ef6f6c"
        }
    }

    proc draw {dataset layout palette} {
        variable canvas
        $canvas delete all
        set left [dict get $layout left]
        set heat_top [dict get $layout heat_top]
        set heat_bottom [dict get $layout heat_bottom]
        set plot_w [dict get $layout plot_width]
        lassign [color_scale_range $dataset $layout] min_val max_val

        $canvas create text $left 24 -anchor w -font TkHeadingFont -fill "#222222" -text [dict get $dataset title]
        $canvas create text [expr {$left + $plot_w}] 24 -anchor e -font TkDefaultFont -fill "#555555" -text [dict get $dataset value_label]
        draw_threshold_graph $dataset $layout

        foreach record [dict get $layout records] {
            set row [dict get $record row]
            set col [dict get $record column]
            set tag [dict get $record tag]
            set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row $col]
            $canvas create rectangle \
                [dict get $record x0] [dict get $record y0] \
                [dict get $record x1] [dict get $record y1] \
                -outline "" \
                -fill [cell_color $value $min_val $max_val $palette $dataset] \
                -tags [list pickable heat_cell $tag]
            if {[::RMSXFlipbookTimeline::Matrix::row_masked $dataset $row]} {
                draw_mask_hatch $canvas $record [list pickable heat_cell $tag]
            }
        }
        $canvas create rectangle $left $heat_top [expr {$left + $plot_w}] $heat_bottom -outline "#333333"

        set rows [dict get $dataset rows]
        set row_step [expr {max(1, int(ceil([llength $rows] / 18.0)))}]
        for {set row 0} {$row < [llength $rows]} {incr row $row_step} {
            set y [expr {$heat_top + ($row * [dict get $layout cell_height]) + ([dict get $layout cell_height] / 2.0)}]
            $canvas create text [expr {$left - 8}] $y -anchor e -font TkSmallCaptionFont -fill "#444444" -text [::RMSXFlipbookTimeline::Matrix::row_label [lindex $rows $row]]
        }

        set columns [dict get $dataset columns]
        set col_step [expr {max(1, int(ceil([llength $columns] / 12.0)))}]
        for {set col 0} {$col < [llength $columns]} {incr col $col_step} {
            set x [expr {$left + ($col * [dict get $layout cell_width]) + ([dict get $layout cell_width] / 2.0)}]
            $canvas create text $x [expr {$heat_bottom + 8}] -anchor n -font TkSmallCaptionFont -fill "#444444" -text [::RMSXFlipbookTimeline::Matrix::column_label [lindex $columns $col]]
        }

        draw_legend $canvas $left [expr {$heat_bottom + 38}] $plot_w 12 $min_val $max_val $palette [dict get $dataset value_label] $dataset
        $canvas bind pickable <Button-1> {::RMSXFlipbookTimeline::TimelinePlot::pick_current}
        $canvas bind pickable <B1-Motion> {::RMSXFlipbookTimeline::TimelinePlot::hover_current}
        $canvas bind pickable <Motion> {::RMSXFlipbookTimeline::TimelinePlot::hover_current}
        ::RMSXFlipbookTimeline::Navigation::attach $canvas [dict get $layout records] [list ::RMSXFlipbookTimeline::TimelinePlot::select_on_canvas $canvas $dataset] [list ::RMSXFlipbookTimeline::TimelinePlot::clear_on_canvas $canvas]
    }

    proc draw_category_legend {canvas x y w h categories label} {
        set count [llength $categories]
        if {$count <= 0} {
            return
        }
        $canvas create text $x [expr {$y - 6}] -anchor sw -font TkHeadingFont -fill "#555555" -text $label
        set item_w [expr {$w / double($count)}]
        for {set i 0} {$i < $count} {incr i} {
            set category [lindex $categories $i]
            set x0 [expr {$x + ($i * $item_w)}]
            set swatch_w [expr {min(18.0, max(10.0, $item_w - 8.0))}]
            $canvas create rectangle $x0 $y [expr {$x0 + $swatch_w}] [expr {$y + $h}] \
                -outline "#555555" \
                -fill [dict get $category color]
            $canvas create text [expr {$x0 + $swatch_w + 4.0}] [expr {$y + ($h / 2.0)}] \
                -anchor w \
                -font TkSmallCaptionFont \
                -fill "#555555" \
                -text [dict get $category label]
        }
    }

    proc draw_legend {canvas x y w h min_val max_val palette label {dataset {}}} {
        set categories [dataset_categories $dataset]
        if {[llength $categories] > 0} {
            draw_category_legend $canvas $x $y $w $h $categories $label
            return
        }
        set steps 80
        for {set i 0} {$i < $steps} {incr i} {
            set t [expr {$i / double($steps - 1)}]
            set value [expr {$min_val + (($max_val - $min_val) * $t)}]
            set x0 [expr {$x + ($i * ($w / double($steps)))}]
            set x1 [expr {$x + (($i + 1) * ($w / double($steps)))}]
            $canvas create rectangle $x0 $y $x1 [expr {$y + $h}] -outline "" -fill [cell_color $value $min_val $max_val $palette $dataset]
        }
        $canvas create rectangle $x $y [expr {$x + $w}] [expr {$y + $h}] -outline "#444444"
        $canvas create text $x [expr {$y + $h + 5}] -anchor nw -font TkSmallCaptionFont -fill "#555555" -text [format "%.3g" $min_val]
        $canvas create text [expr {$x + $w}] [expr {$y + $h + 5}] -anchor ne -font TkSmallCaptionFont -fill "#555555" -text [format "%.3g" $max_val]
        $canvas create text [expr {$x + ($w / 2.0)}] [expr {$y + $h + 5}] -anchor n -font TkSmallCaptionFont -fill "#555555" -text $label
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

    proc clear_canvas_highlight {} {
        variable canvas
        if {$canvas ne "" && [info commands winfo] ne "" && [winfo exists $canvas]} {
            catch {$canvas delete selection_highlight}
            catch {$canvas delete column_highlight}
        }
    }

    proc clear_structure_highlight {} {
        variable highlight_reps
        foreach item $highlight_reps {
            set molid [lindex $item 0]
            set repid [lindex $item 1]
            if {[info commands molinfo] ne "" && [lsearch -exact [molinfo list] $molid] != -1} {
                catch {mol delrep $repid $molid}
            }
        }
        set highlight_reps {}
    }

    proc add_highlight_rep {molid selection} {
        variable highlight_reps
        if {$selection eq "" || [info commands molinfo] eq "" || [lsearch -exact [molinfo list] $molid] == -1} {
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

    proc column_target_molid {dataset column} {
        if {[dict exists $column slice_molid] && [string trim [dict get $column slice_molid]] ne ""} {
            return [dict get $column slice_molid]
        }
        if {[dict exists $column molid] && [string trim [dict get $column molid]] ne ""} {
            return [dict get $column molid]
        }
        if {[dict exists $dataset molid] && [string trim [dict get $dataset molid]] ne ""} {
            return [dict get $dataset molid]
        }
        return ""
    }

    proc molid_is_loaded {molid} {
        return [expr {$molid ne "" && [info commands molinfo] ne "" && [lsearch -exact [molinfo list] $molid] != -1}]
    }

    proc dataset_source_molids {dataset} {
        set source_type ""
        if {[dict exists $dataset source_type]} {
            set source_type [string tolower [string trim [dict get $dataset source_type]]]
        }
        if {$source_type ne "live_trajectory"} {
            return {}
        }

        set molids {}
        if {[dict exists $dataset molid] && [molid_is_loaded [dict get $dataset molid]]} {
            lappend molids [dict get $dataset molid]
        }
        foreach column [dict get $dataset columns] {
            set molid [column_target_molid $dataset $column]
            if {[molid_is_loaded $molid] && [lsearch -exact $molids $molid] == -1} {
                lappend molids $molid
            }
        }
        return $molids
    }

    proc focus_live_matrix_scene {dataset} {
        if {[info commands molinfo] eq ""} {
            return {}
        }
        set source_molids [dataset_source_molids $dataset]
        if {[llength $source_molids] == 0} {
            return {}
        }

        set stale_flipbook_molids [::RMSXFlipbookTimeline::state_get molids {}]
        foreach molid [molinfo list] {
            if {[lsearch -exact $source_molids $molid] != -1} {
                catch {mol on $molid}
            } elseif {[lsearch -exact $stale_flipbook_molids $molid] != -1} {
                catch {mol off $molid}
            }
        }

        set first_molid [lindex $source_molids 0]
        if {[molid_is_loaded $first_molid]} {
            set columns [dict get $dataset columns]
            if {[llength $columns] > 0} {
                set first_column [lindex $columns 0]
                set frame 0
                if {[dict exists $first_column frame]} {
                    set frame [dict get $first_column frame]
                } elseif {[dict exists $first_column representative_frame]} {
                    set frame [dict get $first_column representative_frame]
                }
                catch {molinfo $first_molid set frame $frame}
            }
            catch {mol top $first_molid}
        }
        catch {display update}
        return $source_molids
    }

    proc dataset_column_for_molid {dataset molid} {
        set columns [dict get $dataset columns]
        for {set i 0} {$i < [llength $columns]} {incr i} {
            set column [lindex $columns $i]
            if {[column_target_molid $dataset $column] eq $molid} {
                return $i
            }
        }
        return -1
    }

    proc draw_canvas_selection {record} {
        variable canvas
        if {$canvas eq "" || [info commands winfo] eq "" || ![winfo exists $canvas]} {
            return
        }
        set x0 [dict get $record x0]
        set y0 [dict get $record y0]
        set x1 [dict get $record x1]
        set y1 [dict get $record y1]
        set cx [dict get $record center_x]
        set cy [dict get $record center_y]
        $canvas create rectangle $x0 $y0 $x1 $y1 -outline "#facc15" -width 3 -tags selection_highlight
        $canvas create line $x0 $cy $x1 $cy -fill "#facc15" -width 2 -tags selection_highlight
        $canvas create line $cx $y0 $cx $y1 -fill "#facc15" -width 2 -tags selection_highlight
    }

    proc draw_column_selection {column_index} {
        variable canvas
        variable current_dataset
        if {$canvas eq "" || [info commands winfo] eq "" || ![winfo exists $canvas] || $current_dataset eq {}} {
            return
        }
        set have_record 0
        set x0 0
        set x1 0
        set y0 0
        set y1 0
        foreach {_ record} [array get ::RMSXFlipbookTimeline::TimelinePlot::record_by_tag] {
            if {[dict get $record column] == $column_index} {
                if {!$have_record} {
                    set x0 [dict get $record x0]
                    set x1 [dict get $record x1]
                    set y0 [dict get $record y0]
                    set y1 [dict get $record y1]
                    set have_record 1
                } else {
                    if {[dict get $record y0] < $y0} {set y0 [dict get $record y0]}
                    if {[dict get $record y1] > $y1} {set y1 [dict get $record y1]}
                }
            }
        }
        if {!$have_record} {
            return
        }
        $canvas create rectangle $x0 $y0 $x1 $y1 -outline "#2563eb" -width 3 -tags column_highlight
    }

    proc sync_scrubber {column} {
        variable scrubber
        variable scrub_var
        variable scrub_syncing
        set scrub_var [expr {int($column)}]
        if {$scrubber ne "" && [info commands winfo] ne "" && [winfo exists $scrubber]} {
            set scrub_syncing 1
            catch {$scrubber set $scrub_var}
            set scrub_syncing 0
        }
    }

    proc configure_scrubber {columns} {
        variable scrubber
        variable scrub_var
        variable scrub_syncing
        set scrub_var 0
        if {$scrubber ne "" && [info commands winfo] ne "" && [winfo exists $scrubber]} {
            set max_column [expr {max(0, int($columns) - 1)}]
            $scrubber configure -from 0 -to $max_column
            set scrub_syncing 1
            catch {$scrubber set 0}
            set scrub_syncing 0
        }
    }

    proc status_for_record {dataset record} {
        set row [lindex [dict get $dataset rows] [dict get $record row]]
        set column [lindex [dict get $dataset columns] [dict get $record column]]
        set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset [dict get $record row] [dict get $record column]]
        set target_label frame
        if {[dict exists $column target_type] && [dict get $column target_type] eq "slice"} {
            set target_label slice
        }
        return [format {%s, %s %s, value %s} \
            [::RMSXFlipbookTimeline::Matrix::row_label $row] \
            $target_label \
            [::RMSXFlipbookTimeline::Matrix::column_label $column] \
            $value]
    }

    proc same_cell_record {a b} {
        if {$a eq {} || $b eq {} || ![dict exists $a row] || ![dict exists $a column] || ![dict exists $b row] || ![dict exists $b column]} {
            return 0
        }
        return [expr {[dict get $a row] == [dict get $b row] && [dict get $a column] == [dict get $b column]}]
    }

    proc select_on_canvas {target dataset record} {
        variable canvas; variable current_dataset; variable selected_record
        set old_canvas $canvas; set old_dataset $current_dataset
        set canvas $target; set current_dataset $dataset; set selected_record {}
        try {return [select_record $record]} finally {set canvas $old_canvas; set current_dataset $old_dataset}
    }
    proc clear_on_canvas {target} {
        variable canvas; variable selected_record
        set old_canvas $canvas; set canvas $target
        try {clear_canvas_highlight; clear_structure_highlight; set selected_record {}} finally {set canvas $old_canvas}
    }

    proc row_selection {row molid} {
        if {[dict exists $row resid]} {return [::RMSXFlipbookTimeline::ResidueIdentity::selection $row $molid]}
        if {[dict exists $row selection] && [dict get $row selection] ne ""} {return [dict get $row selection]}
        error "Timeline row has no residue identity or selection"
    }

    proc select_record {record} {
        variable current_dataset
        variable selected_record
        variable status_var
        variable neighborhood_summary_var
        if {$current_dataset eq {}} {
            error "No Timeline dataset is loaded"
        }
        if {[same_cell_record $selected_record $record]} {
            return [dict merge $record [dict create message $status_var unchanged 1]]
        }
        clear_canvas_highlight
        clear_structure_highlight
        set selected_record $record
        draw_canvas_selection $record
        sync_scrubber [dict get $record column]

        set row [lindex [dict get $current_dataset rows] [dict get $record row]]
        set column [lindex [dict get $current_dataset columns] [dict get $record column]]
        set molid [column_target_molid $current_dataset $column]
        if {[molid_is_loaded $molid]} {
            if {[dict exists $column frame]} {
                set frame [dict get $column frame]
                mol top $molid
                if {[catch {molinfo $molid set frame $frame}]} {
                    catch {animate goto $frame}
                }
            } else {
                mol top $molid
            }
            add_highlight_rep $molid [row_selection $row $molid]
            if {[info commands winfo] ne ""} {
                catch {display update}
            }
        }
        set status_var [status_for_record $current_dataset $record]
        if {[::RMSXFlipbookTimeline::state_get timeline_neighborhood_enabled 0]} {
            set neighborhood_status [refresh_neighborhood_from_selection]
            if {[dict exists $neighborhood_status message]} {
                set neighborhood_summary_var [dict get $neighborhood_status message]
            }
        }
        puts "RMSX Flipbook Timeline: $status_var"
        return [dict merge $record [dict create message $status_var]]
    }

    proc select_column {column} {
        variable current_dataset
        variable selected_record
        variable status_var
        variable neighborhood_summary_var
        if {$current_dataset eq {}} {
            error "No Timeline dataset is loaded"
        }
        set column_index [expr {int($column)}]
        set columns [dict get $current_dataset columns]
        if {$column_index < 0 || $column_index >= [llength $columns]} {
            error "Timeline column not found: $column_index"
        }
        clear_canvas_highlight
        clear_structure_highlight
        if {[::RMSXFlipbookTimeline::state_get timeline_neighborhood_enabled 0]} {
            clear_neighborhood
            set neighborhood_summary_var "Click a heatmap cell to open nearby frames."
        }
        set selected_record [dict create kind column column $column_index]
        draw_column_selection $column_index
        sync_scrubber $column_index

        set column_data [lindex $columns $column_index]
        set molid [column_target_molid $current_dataset $column_data]
        if {[molid_is_loaded $molid]} {
            mol top $molid
            if {[dict exists $column_data frame]} {
                set frame [dict get $column_data frame]
                if {[catch {molinfo $molid set frame $frame}]} {
                    catch {animate goto $frame}
                }
            }
        }
        set target_type ""
        if {[dict exists $column_data target_type]} {
            set target_type [dict get $column_data target_type]
        }
        set status_label "Frame"
        if {$target_type eq "slice"} {
            set status_label "Slice"
        }
        set status_var "$status_label [::RMSXFlipbookTimeline::Matrix::column_label $column_data]"
        puts "RMSX Flipbook Timeline: $status_var"
        set result [dict create \
            kind column \
            column $column_index \
            target_type $target_type \
            frame [expr {[dict exists $column_data frame] ? [dict get $column_data frame] : $column_index}] \
            message $status_var]
        if {[dict exists $column_data slice_file]} {
            dict set result slice_file [dict get $column_data slice_file]
        }
        if {$molid ne ""} {
            dict set result molid $molid
        }
        return $result
    }

    proc scrub_to_value {value} {
        variable current_dataset
        variable scrub_syncing
        if {$scrub_syncing} {
            return ""
        }
        if {$current_dataset eq {}} {
            return
        }
        set column [expr {int(round(double($value)))}]
        catch {select_column $column}
        return ""
    }

    proc pick_current {} {
        set record [record_from_current]
        if {$record eq ""} {
            return
        }
        return [select_record $record]
    }

    proc hover_current {} {
        variable current_dataset
        variable status_var
        set record [record_from_current]
        if {$record eq "" || $current_dataset eq {}} {
            return
        }
        set status_var [status_for_record $current_dataset $record]
    }

    proc select_cell {row column} {
        variable record_by_tag
        foreach {_ record} [array get record_by_tag] {
            if {[dict get $record row] == $row && [dict get $record column] == $column} {
                return [select_record $record]
            }
        }
        error "Timeline cell not found: row=$row column=$column"
    }

    proc select_slice {column} {
        return [select_column [expr {int($column)}]]
    }

    proc pick_callback {name element op} {
        variable current_dataset
        global vmd_pick_atom vmd_pick_mol
        if {$current_dataset eq {} || ![info exists vmd_pick_mol] || ![info exists vmd_pick_atom]} {
            return
        }
        set molid $vmd_pick_mol
        set col_index [dataset_column_for_molid $current_dataset $molid]
        if {$col_index < 0} {
            return
        }
        set row_index -1
        set rows [dict get $current_dataset rows]
        set matches {}
        for {set i 0} {$i < [llength $rows]} {incr i} {
            set row [lindex $rows $i]
            set selection [row_selection $row $molid]
            set sel [atomselect $molid "($selection) and index $vmd_pick_atom"]
            try {if {[$sel num] > 0} {lappend matches $i}} finally {$sel delete}
        }
        # Free selections may overlap: do not silently choose a different row.
        if {[llength $matches] != 1} {return}
        set row_index [lindex $matches 0]
        set column [lindex [dict get $current_dataset columns] $col_index]
        if {[dict exists $column frame]} {
            set frame [molinfo $molid get frame]
            set columns [dict get $current_dataset columns]
            for {set i 0} {$i < [llength $columns]} {incr i} {
                if {[dict exists [lindex $columns $i] frame] && [dict get [lindex $columns $i] frame] == $frame} {
                    set col_index $i
                    break
                }
            }
        }
        return [select_cell $row_index $col_index]
    }

    proc show {dataset args} {
        variable window
        variable canvas
        variable current_dataset
        variable current_palette
        variable current_scale_min
        variable current_scale_max
        variable selected_record
        variable status_var
        variable candidate_serial
        set defaults [dict create palette "" width 980 scale_mode fit threshold_min "" threshold_max "" scale_min "" scale_max "" draw 1 pick 1 title "" controls auto]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        # Validate all data/layout inputs before replacing any view state.
        set dataset [::RMSXFlipbookTimeline::Matrix::validate $dataset]
        foreach key {title value_label unit row_count column_count} {if {![dict exists $dataset $key]} {error "Timeline dataset is missing '$key'"}}
        set palette [string trim [dict get $opts palette]]
        if {$palette eq ""} {set palette [::RMSXFlipbookTimeline::state_get palette viridis]}
        set layout [build_layout $dataset width [dict get $opts width] scale_mode [dict get $opts scale_mode] threshold_min [dict get $opts threshold_min] threshold_max [dict get $opts threshold_max] scale_min [dict get $opts scale_min] scale_max [dict get $opts scale_max]]
        lassign [color_scale_range $dataset $layout] scale_min scale_max
        set snapshot [::RMSXFlipbookTimeline::ViewState::capture ::RMSXFlipbookTimeline::TimelinePlot]
        set old_state [::RMSXFlipbookTimeline::state_dict]
        set old_window $window
        set staged_window ""
        set drawn 0
        try {
            set current_dataset $dataset
            set selected_record {}
            set current_scale_min $scale_min
            set current_scale_max $scale_max
            set current_palette $palette
            # Preserve the user's neighborhood preference through activation.
            # Selection later persists these controls back into shared state.
            sync_neighborhood_controls_from_state
            if {[dict get $opts draw]} {
                package require Tk
                set controls [dict get $opts controls]
                if {[string tolower [string trim $controls]] eq "auto"} {set controls [timeline_controls_for_dataset $dataset]}
                set controls [expr {$controls ? 1 : 0}]
                set title [string trim [dict get $opts title]]
                if {$title eq ""} {set title "RMSX Flipbook Timeline"}
                set window .rmsxflipbooktimeline_timeline_plot
                if {[winfo exists $window]} {set window ".rmsxflipbooktimeline_timeline_candidate[incr candidate_serial]"}
                set staged_window $window
                set canvas [ensure_window [dict get $layout canvas_width] [dict get $layout canvas_height] $title controls $controls]
                wm withdraw $window
                draw $dataset $layout $palette
                if {$controls} {
                    configure_scrubber [dict get $dataset column_count]
                    set status_var "Use arrow keys or click a heatmap cell to select a frame and residue."
                } else {set status_var ""}
                set drawn 1
            } else {set canvas ""}
            install_record_map [dict get $layout records]
            if {[dict get $opts pick]} {install_pick_trace} else {remove_pick_trace}
        } on error {message options} {
            if {$staged_window ne "" && [info commands winfo] ne "" && [winfo exists $staged_window]} {
                bind $staged_window <Destroy> {}
                destroy $staged_window
            }
            ::RMSXFlipbookTimeline::ViewState::restore $snapshot
            ::RMSXFlipbookTimeline::state_replace $old_state
            return -options $options $message
        }
        # All potentially failing preparation/drawing has passed. Publish once.
        clear_structure_highlight
        if {[info commands ::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear] ne ""} {catch {::RMSXFlipbookTimeline::NeighborhoodFlipbook::clear}}
        ::RMSXFlipbookTimeline::state_set current_timeline_dataset $dataset
        ::RMSXFlipbookTimeline::publish_matrix_result $dataset $opts
        if {$drawn} {
            focus_live_matrix_scene $dataset
            wm deiconify $window
            if {$old_window ne $window && [winfo exists $old_window]} {destroy $old_window}
        } elseif {[info commands winfo] ne "" && [winfo exists $old_window]} {
            bind $old_window <Destroy> {}
            destroy $old_window
        }
        return [dict create rows [dict get $dataset row_count] columns [dict get $dataset column_count] min $scale_min max $scale_max drawn $drawn dataset $dataset]
    }

    proc show_live {molid metric args} {
        set dataset [::RMSXFlipbookTimeline::TimelineAnalysis::calculate $molid $metric {*}$args]
        set defaults [dict create \
            selection all \
            column_mode frames \
            slicing_mode slices \
            slices "" \
            slice_size "" \
            slice_aggregation auto \
            slice_representative first]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        dict set dataset provenance selection [dict get $opts selection]
        # calculate resolves top once; preserve that concrete source identity.
        if {[dict exists $dataset molid]} {dict set dataset provenance molid [dict get $dataset molid]}
        set column_mode [string tolower [string trim [dict get $opts column_mode]]]
        if {$column_mode in {slice slices}} {
            set dataset [::RMSXFlipbookTimeline::Matrix::aggregate_to_slices \
                $dataset \
                slicing_mode [dict get $opts slicing_mode] \
                slices [dict get $opts slices] \
                slice_size [dict get $opts slice_size] \
                aggregation [dict get $opts slice_aggregation] \
                representative [dict get $opts slice_representative]]
        }
        return [show $dataset {*}$args]
    }

    proc show_tml {filename args} {
        set dataset [::RMSXFlipbookTimeline::TimelineIO::read_tml $filename {*}$args]
        return [show $dataset {*}$args]
    }

    proc show_rmsx_csv {filename args} {
        set dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_csv $filename {*}$args]
        return [show $dataset {*}$args]
    }

    proc show_rmsx_folder {folder args} {
        set dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder $folder {*}$args]
        return [show $dataset {*}$args]
    }

    proc current_dataset {} {
        variable current_dataset
        return $current_dataset
    }

    proc selected_record {} {
        variable selected_record
        return $selected_record
    }

    proc filter_current {min_value max_value frame_start frame_end frames_required args} {
        set dataset [current_dataset]
        if {$dataset eq {}} {
            error "No Timeline dataset is loaded"
        }
        set filtered [::RMSXFlipbookTimeline::Matrix::filter_rows $dataset $min_value $max_value $frame_start $frame_end $frames_required]
        return [show $filtered {*}$args]
    }

    proc copy_current_to_user {{field user2}} {
        set dataset [current_dataset]
        if {$dataset eq {}} {
            error "No Timeline dataset is loaded"
        }
        return [::RMSXFlipbookTimeline::Matrix::copy_to_user $dataset $field]
    }

    proc write_current_tml {filename} {
        set dataset [current_dataset]
        if {$dataset eq {}} {
            error "No Timeline dataset is loaded"
        }
        return [::RMSXFlipbookTimeline::TimelineIO::write_tml $dataset $filename]
    }

    proc svg_escape {text} {
        return [::RMSXFlipbookTimeline::NativeAnalysis::xml_escape $text]
    }

    proc svg_text {fp x y anchor size weight fill text args} {
        set defaults [dict create rotate ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set transform ""
        if {[string trim [dict get $opts rotate]] ne ""} {
            set transform [format { transform="rotate(%s %.3f %.3f)"} [dict get $opts rotate] $x $y]
        }
        puts $fp [format {<text x="%.3f" y="%.3f" text-anchor="%s" font-family="Helvetica, Arial, sans-serif" font-size="%d" font-weight="%s" fill="%s"%s>%s</text>} \
            $x \
            $y \
            $anchor \
            $size \
            $weight \
            $fill \
            $transform \
            [svg_escape $text]]
    }

    proc write_svg_threshold_graph {fp dataset layout} {
        set min_value [string trim [dict get $layout threshold_min]]
        set max_value [string trim [dict get $layout threshold_max]]
        if {$min_value eq "" || $max_value eq ""} {
            return
        }
        set counts [::RMSXFlipbookTimeline::Matrix::threshold_counts $dataset $min_value $max_value]
        if {[llength $counts] == 0} {
            return
        }
        set max_count [lindex [lsort -integer $counts] end]
        if {$max_count <= 0} {
            set max_count 1
        }
        set y0 [dict get $layout threshold_y0]
        set y1 [dict get $layout threshold_y1]
        set left [dict get $layout left]
        set cell_w [dict get $layout cell_width]
        set plot_w [dict get $layout plot_width]
        svg_text $fp $left [expr {$y0 - 14.0}] start 9 700 "#333333" "Threshold count ($min_value to $max_value)"
        puts $fp [format {<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" stroke="#333333" stroke-width="1"/>} \
            $left $y1 [expr {$left + $plot_w}] $y1]
        for {set col 0} {$col < [llength $counts]} {incr col} {
            set count [lindex $counts $col]
            set x0 [expr {$left + ($col * $cell_w)}]
            set bar_y [expr {$y1 - (($y1 - $y0) * ($count / double($max_count)))}]
            puts $fp [format {<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="#ef6f6c"/>} \
                $x0 \
                $bar_y \
                $cell_w \
                [expr {$y1 - $bar_y}]]
        }
    }

    proc write_svg_category_legend {fp x y w h categories label} {
        set count [llength $categories]
        if {$count <= 0} {
            return
        }
        svg_text $fp $x [expr {$y - 6.0}] start 8 700 "#555555" $label
        set item_w [expr {$w / double($count)}]
        for {set i 0} {$i < $count} {incr i} {
            set category [lindex $categories $i]
            set x0 [expr {$x + ($i * $item_w)}]
            set swatch_w [expr {min(18.0, max(10.0, $item_w - 8.0))}]
            puts $fp [format {<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="%s" stroke="#555555" stroke-width="1"/>} \
                $x0 \
                $y \
                $swatch_w \
                $h \
                [dict get $category color]]
            svg_text $fp [expr {$x0 + $swatch_w + 4.0}] [expr {$y + $h - 2.0}] start 7 400 "#555555" [dict get $category label]
        }
    }

    proc write_svg_legend {fp x y w h min_val max_val palette label {dataset {}}} {
        set categories [dataset_categories $dataset]
        if {[llength $categories] > 0} {
            write_svg_category_legend $fp $x $y $w $h $categories $label
            return
        }
        set steps 80
        for {set i 0} {$i < $steps} {incr i} {
            set t [expr {$i / double($steps - 1)}]
            set value [expr {$min_val + (($max_val - $min_val) * $t)}]
            set x0 [expr {$x + ($i * ($w / double($steps)))}]
            set rect_w [expr {$w / double($steps)}]
            puts $fp [format {<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="%s"/>} \
                $x0 \
                $y \
                $rect_w \
                $h \
                [cell_color $value $min_val $max_val $palette $dataset]]
        }
        puts $fp [format {<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="none" stroke="#444444" stroke-width="1"/>} $x $y $w $h]
        svg_text $fp $x [expr {$y + $h + 15.0}] start 8 400 "#555555" [format "%.3g" $min_val]
        svg_text $fp [expr {$x + $w}] [expr {$y + $h + 15.0}] end 8 400 "#555555" [format "%.3g" $max_val]
        svg_text $fp [expr {$x + ($w / 2.0)}] [expr {$y + $h + 15.0}] middle 8 400 "#555555" $label
    }

    proc png_rect {image x0 y0 x1 y1 color} {
        set ix0 [expr {int(floor($x0))}]
        set iy0 [expr {int(floor($y0))}]
        set ix1 [expr {int(ceil($x1))}]
        set iy1 [expr {int(ceil($y1))}]
        if {$ix1 <= $ix0 || $iy1 <= $iy0} {
            return
        }
        $image put $color -to $ix0 $iy0 $ix1 $iy1
    }

    proc png_line {image x0 y0 x1 y1 color {thickness 1}} {
        set x0 [expr {int(round($x0))}]
        set y0 [expr {int(round($y0))}]
        set x1 [expr {int(round($x1))}]
        set y1 [expr {int(round($y1))}]
        set dx [expr {abs($x1 - $x0)}]
        set sx [expr {$x0 < $x1 ? 1 : -1}]
        set dy [expr {-abs($y1 - $y0)}]
        set sy [expr {$y0 < $y1 ? 1 : -1}]
        set err [expr {$dx + $dy}]
        set radius [expr {max(0, int(floor($thickness / 2.0)))}]

        while {1} {
            png_rect $image \
                [expr {$x0 - $radius}] \
                [expr {$y0 - $radius}] \
                [expr {$x0 + $radius + 1}] \
                [expr {$y0 + $radius + 1}] \
                $color
            if {$x0 == $x1 && $y0 == $y1} {
                break
            }
            set e2 [expr {2 * $err}]
            if {$e2 >= $dy} {
                set err [expr {$err + $dy}]
                incr x0 $sx
            }
            if {$e2 <= $dx} {
                set err [expr {$err + $dx}]
                incr y0 $sy
            }
        }
    }

    proc png_mask_hatch {image record} {
        foreach segment [mask_hatch_segments $record] {
            lassign $segment x0 y0 x1 y1
            png_line $image $x0 $y0 $x1 $y1 "#f8fafc" 3
            png_line $image $x0 $y0 $x1 $y1 "#111827" 1
        }
    }

    proc png_border {image x y w h color {line_width 1}} {
        png_rect $image $x $y [expr {$x + $w}] [expr {$y + $line_width}] $color
        png_rect $image $x [expr {$y + $h - $line_width}] [expr {$x + $w}] [expr {$y + $h}] $color
        png_rect $image $x $y [expr {$x + $line_width}] [expr {$y + $h}] $color
        png_rect $image [expr {$x + $w - $line_width}] $y [expr {$x + $w}] [expr {$y + $h}] $color
    }

    proc png_font_pattern {char} {
        switch -- [string toupper $char] {
            A {return {01110 10001 10001 11111 10001 10001 10001}}
            B {return {11110 10001 10001 11110 10001 10001 11110}}
            C {return {01111 10000 10000 10000 10000 10000 01111}}
            D {return {11110 10001 10001 10001 10001 10001 11110}}
            E {return {11111 10000 10000 11110 10000 10000 11111}}
            F {return {11111 10000 10000 11110 10000 10000 10000}}
            G {return {01111 10000 10000 10111 10001 10001 01111}}
            H {return {10001 10001 10001 11111 10001 10001 10001}}
            I {return {11111 00100 00100 00100 00100 00100 11111}}
            J {return {00111 00010 00010 00010 10010 10010 01100}}
            K {return {10001 10010 10100 11000 10100 10010 10001}}
            L {return {10000 10000 10000 10000 10000 10000 11111}}
            M {return {10001 11011 10101 10101 10001 10001 10001}}
            N {return {10001 11001 10101 10011 10001 10001 10001}}
            O {return {01110 10001 10001 10001 10001 10001 01110}}
            P {return {11110 10001 10001 11110 10000 10000 10000}}
            Q {return {01110 10001 10001 10001 10101 10010 01101}}
            R {return {11110 10001 10001 11110 10100 10010 10001}}
            S {return {01111 10000 10000 01110 00001 00001 11110}}
            T {return {11111 00100 00100 00100 00100 00100 00100}}
            U {return {10001 10001 10001 10001 10001 10001 01110}}
            V {return {10001 10001 10001 10001 10001 01010 00100}}
            W {return {10001 10001 10001 10101 10101 10101 01010}}
            X {return {10001 10001 01010 00100 01010 10001 10001}}
            Y {return {10001 10001 01010 00100 00100 00100 00100}}
            Z {return {11111 00001 00010 00100 01000 10000 11111}}
            0 {return {01110 10001 10011 10101 11001 10001 01110}}
            1 {return {00100 01100 00100 00100 00100 00100 01110}}
            2 {return {01110 10001 00001 00010 00100 01000 11111}}
            3 {return {11110 00001 00001 01110 00001 00001 11110}}
            4 {return {00010 00110 01010 10010 11111 00010 00010}}
            5 {return {11111 10000 10000 11110 00001 00001 11110}}
            6 {return {01110 10000 10000 11110 10001 10001 01110}}
            7 {return {11111 00001 00010 00100 01000 01000 01000}}
            8 {return {01110 10001 10001 01110 10001 10001 01110}}
            9 {return {01110 10001 10001 01111 00001 00001 01110}}
            ":" {return {00000 00100 00100 00000 00100 00100 00000}}
            "." {return {00000 00000 00000 00000 00000 01100 01100}}
            "," {return {00000 00000 00000 00000 01100 00100 01000}}
            "-" {return {00000 00000 00000 11111 00000 00000 00000}}
            "_" {return {00000 00000 00000 00000 00000 00000 11111}}
            "/" {return {00001 00010 00010 00100 01000 01000 10000}}
            "(" {return {00010 00100 01000 01000 01000 00100 00010}}
            ")" {return {01000 00100 00010 00010 00010 00100 01000}}
            "+" {return {00000 00100 00100 11111 00100 00100 00000}}
            default {return {11111 00001 00010 00100 00000 00100 00100}}
        }
    }

    proc png_text_size {text scale} {
        set char_count [string length $text]
        if {$char_count <= 0} {
            return {0 0}
        }
        set width [expr {($char_count * 5 * $scale) + (($char_count - 1) * $scale)}]
        set height [expr {7 * $scale}]
        return [list $width $height]
    }

    proc png_text {image x y anchor scale color text} {
        set text [string toupper $text]
        lassign [png_text_size $text $scale] text_w text_h
        switch -- $anchor {
            n {
                set x [expr {$x - ($text_w / 2.0)}]
            }
            e {
                set x [expr {$x - $text_w}]
                set y [expr {$y - ($text_h / 2.0)}]
            }
            ne {
                set x [expr {$x - $text_w}]
            }
            w {
                set y [expr {$y - ($text_h / 2.0)}]
            }
            center -
            middle {
                set x [expr {$x - ($text_w / 2.0)}]
                set y [expr {$y - ($text_h / 2.0)}]
            }
        }

        set cursor_x $x
        foreach char [split $text ""] {
            if {$char ne " "} {
                set pattern [png_font_pattern $char]
                for {set row 0} {$row < [llength $pattern]} {incr row} {
                    set bits [lindex $pattern $row]
                    for {set col 0} {$col < [string length $bits]} {incr col} {
                        if {[string index $bits $col] eq "1"} {
                            set px [expr {$cursor_x + ($col * $scale)}]
                            set py [expr {$y + ($row * $scale)}]
                            png_rect $image $px $py [expr {$px + $scale}] [expr {$py + $scale}] $color
                        }
                    }
                }
            }
            set cursor_x [expr {$cursor_x + (6 * $scale)}]
        }
    }

    proc png_threshold_graph {image dataset layout} {
        set min_value [string trim [dict get $layout threshold_min]]
        set max_value [string trim [dict get $layout threshold_max]]
        if {$min_value eq "" || $max_value eq ""} {
            return
        }
        set counts [::RMSXFlipbookTimeline::Matrix::threshold_counts $dataset $min_value $max_value]
        if {[llength $counts] == 0} {
            return
        }
        set max_count [lindex [lsort -integer $counts] end]
        if {$max_count <= 0} {
            set max_count 1
        }
        set y0 [dict get $layout threshold_y0]
        set y1 [dict get $layout threshold_y1]
        set left [dict get $layout left]
        set cell_w [dict get $layout cell_width]
        set plot_w [dict get $layout plot_width]
        png_text $image $left [expr {$y0 - 22.0}] nw 1 "#333333" "Threshold count ($min_value to $max_value)"
        png_rect $image $left $y1 [expr {$left + $plot_w}] [expr {$y1 + 1}] "#333333"
        for {set col 0} {$col < [llength $counts]} {incr col} {
            set count [lindex $counts $col]
            set x0 [expr {$left + ($col * $cell_w)}]
            set bar_y [expr {$y1 - (($y1 - $y0) * ($count / double($max_count)))}]
            png_rect $image $x0 $bar_y [expr {$x0 + $cell_w}] $y1 "#ef6f6c"
        }
    }

    proc png_category_legend {image x y w h categories label} {
        set count [llength $categories]
        if {$count <= 0} {
            return
        }
        png_text $image $x [expr {$y - 8.0}] w 1 "#555555" $label
        set item_w [expr {$w / double($count)}]
        for {set i 0} {$i < $count} {incr i} {
            set category [lindex $categories $i]
            set x0 [expr {$x + ($i * $item_w)}]
            set swatch_w [expr {min(18.0, max(10.0, $item_w - 8.0))}]
            png_rect $image $x0 $y [expr {$x0 + $swatch_w}] [expr {$y + $h}] [dict get $category color]
            png_border $image $x0 $y $swatch_w $h "#555555" 1
            png_text $image [expr {$x0 + $swatch_w + 4.0}] [expr {$y + ($h / 2.0)}] w 1 "#555555" [dict get $category label]
        }
    }

    proc png_legend {image x y w h min_val max_val palette label {dataset {}}} {
        set categories [dataset_categories $dataset]
        if {[llength $categories] > 0} {
            png_category_legend $image $x $y $w $h $categories $label
            return
        }
        set steps 80
        for {set i 0} {$i < $steps} {incr i} {
            set t [expr {$i / double($steps - 1)}]
            set value [expr {$min_val + (($max_val - $min_val) * $t)}]
            set x0 [expr {$x + ($i * ($w / double($steps)))}]
            set x1 [expr {$x + (($i + 1) * ($w / double($steps)))}]
            png_rect $image $x0 $y $x1 [expr {$y + $h}] [cell_color $value $min_val $max_val $palette $dataset]
        }
        png_border $image $x $y $w $h "#444444" 1
        png_text $image $x [expr {$y + $h + 8.0}] nw 1 "#555555" [format "%.3g" $min_val]
        png_text $image [expr {$x + $w}] [expr {$y + $h + 8.0}] ne 1 "#555555" [format "%.3g" $max_val]
        png_text $image [expr {$x + ($w / 2.0)}] [expr {$y + $h + 8.0}] n 1 "#555555" $label
    }

    proc write_svg {dataset filename args} {
        return [::RMSXFlipbookTimeline::OutputTxn::atomic_write $filename [list ::RMSXFlipbookTimeline::TimelinePlot::write_svg_payload $dataset $args]]
    }
    proc write_svg_payload {dataset args filename} {
        return [write_svg_impl $dataset $filename {*}$args]
    }
    proc write_svg_impl {dataset filename args} {
        set defaults [dict create palette "" width 980 scale_mode fit threshold_min "" threshold_max "" scale_min "" scale_max ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set palette [string trim [dict get $opts palette]]
        if {$palette eq ""} {
            set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        }
        set dataset [::RMSXFlipbookTimeline::Matrix::validate $dataset]
        set layout [build_layout $dataset \
            width [dict get $opts width] \
            scale_mode [dict get $opts scale_mode] \
            threshold_min [dict get $opts threshold_min] \
            threshold_max [dict get $opts threshold_max] \
            scale_min [dict get $opts scale_min] \
            scale_max [dict get $opts scale_max]]
        set fp [open $filename w]
        fconfigure $fp -encoding utf-8 -translation lf
        try {
            puts $fp [format {<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">} \
                [dict get $layout canvas_width] [dict get $layout canvas_height] [dict get $layout canvas_width] [dict get $layout canvas_height]]
            puts $fp "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>"
            set left [dict get $layout left]
            set heat_top [dict get $layout heat_top]
            set heat_bottom [dict get $layout heat_bottom]
            set plot_w [dict get $layout plot_width]
            svg_text $fp $left 24 start 14 700 "#222222" [dict get $dataset title]
            svg_text $fp [expr {$left + $plot_w}] 24 end 10 400 "#555555" [dict get $dataset value_label]
            write_svg_threshold_graph $fp $dataset $layout
            lassign [color_scale_range $dataset $layout] min_val max_val
            foreach record [dict get $layout records] {
                set row [dict get $record row]
                set col [dict get $record column]
                set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row $col]
                puts $fp [format {<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="%s"/>} \
                    [dict get $record x0] \
                    [dict get $record y0] \
                    [expr {[dict get $record x1] - [dict get $record x0]}] \
                    [expr {[dict get $record y1] - [dict get $record y0]}] \
                    [cell_color $value $min_val $max_val $palette $dataset]]
                if {[::RMSXFlipbookTimeline::Matrix::row_masked $dataset $row]} {
                    write_svg_mask_hatch $fp $record
                }
            }
            puts $fp [format {<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="none" stroke="#333333" stroke-width="1"/>} \
                $left \
                $heat_top \
                $plot_w \
                [expr {$heat_bottom - $heat_top}]]

            set rows [dict get $dataset rows]
            set row_step [expr {max(1, int(ceil([llength $rows] / 18.0)))}]
            for {set row 0} {$row < [llength $rows]} {incr row $row_step} {
                set y [expr {$heat_top + ($row * [dict get $layout cell_height]) + ([dict get $layout cell_height] / 2.0) + 3.0}]
                svg_text $fp [expr {$left - 8.0}] $y end 8 400 "#444444" [::RMSXFlipbookTimeline::Matrix::row_label [lindex $rows $row]]
            }

            set columns [dict get $dataset columns]
            set col_step [expr {max(1, int(ceil([llength $columns] / 12.0)))}]
            for {set col 0} {$col < [llength $columns]} {incr col $col_step} {
                set x [expr {$left + ($col * [dict get $layout cell_width]) + ([dict get $layout cell_width] / 2.0)}]
                svg_text $fp $x [expr {$heat_bottom + 18.0}] middle 8 400 "#444444" [::RMSXFlipbookTimeline::Matrix::column_label [lindex $columns $col]]
            }

            write_svg_legend $fp $left [expr {$heat_bottom + 38.0}] $plot_w 12 $min_val $max_val $palette [dict get $dataset value_label] $dataset
            puts $fp "</svg>"
        } finally {
            catch {close $fp}
        }
        return [file normalize $filename]
    }

    proc write_png {dataset filename args} {
        return [::RMSXFlipbookTimeline::OutputTxn::atomic_write $filename [list ::RMSXFlipbookTimeline::TimelinePlot::write_png_payload $dataset $args]]
    }
    proc write_png_payload {dataset args filename} {
        return [write_png_impl $dataset $filename {*}$args]
    }
    proc write_png_impl {dataset filename args} {
        set defaults [dict create palette "" width 980 scale_mode fit threshold_min "" threshold_max "" scale_min "" scale_max ""]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        set palette [string trim [dict get $opts palette]]
        if {$palette eq ""} {
            set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        }
        package require Tk
        set dataset [::RMSXFlipbookTimeline::Matrix::validate $dataset]
        set layout [build_layout \
            $dataset \
            width [dict get $opts width] \
            scale_mode [dict get $opts scale_mode] \
            threshold_min [dict get $opts threshold_min] \
            threshold_max [dict get $opts threshold_max] \
            scale_min [dict get $opts scale_min] \
            scale_max [dict get $opts scale_max]]
        set width [dict get $layout canvas_width]
        set height [dict get $layout canvas_height]
        set image [image create photo -width $width -height $height]
        try {
            $image put white -to 0 0 $width $height
            set left [dict get $layout left]
            set heat_top [dict get $layout heat_top]
            set heat_bottom [dict get $layout heat_bottom]
            set plot_w [dict get $layout plot_width]
            png_text $image $left 18 nw 2 "#222222" [dict get $dataset title]
            png_text $image [expr {$left + $plot_w}] 18 ne 1 "#555555" [dict get $dataset value_label]
            png_threshold_graph $image $dataset $layout
            lassign [color_scale_range $dataset $layout] min_val max_val
            foreach record [dict get $layout records] {
                set row [dict get $record row]
                set col [dict get $record column]
                set value [::RMSXFlipbookTimeline::Matrix::cell_value $dataset $row $col]
                set color [cell_color $value $min_val $max_val $palette $dataset]
                set x0 [expr {int(floor([dict get $record x0]))}]
                set y0 [expr {int(floor([dict get $record y0]))}]
                set x1 [expr {int(ceil([dict get $record x1]))}]
                set y1 [expr {int(ceil([dict get $record y1]))}]
                $image put $color -to $x0 $y0 $x1 $y1
                if {[::RMSXFlipbookTimeline::Matrix::row_masked $dataset $row]} {
                    png_mask_hatch $image $record
                }
            }
            png_border $image $left $heat_top $plot_w [expr {$heat_bottom - $heat_top}] "#333333" 1

            set rows [dict get $dataset rows]
            set row_step [expr {max(1, int(ceil([llength $rows] / 18.0)))}]
            for {set row 0} {$row < [llength $rows]} {incr row $row_step} {
                set y [expr {$heat_top + ($row * [dict get $layout cell_height]) + ([dict get $layout cell_height] / 2.0)}]
                png_text $image [expr {$left - 8.0}] $y e 1 "#444444" [::RMSXFlipbookTimeline::Matrix::row_label [lindex $rows $row]]
            }

            set columns [dict get $dataset columns]
            set col_step [expr {max(1, int(ceil([llength $columns] / 12.0)))}]
            for {set col 0} {$col < [llength $columns]} {incr col $col_step} {
                set x [expr {$left + ($col * [dict get $layout cell_width]) + ([dict get $layout cell_width] / 2.0)}]
                png_text $image $x [expr {$heat_bottom + 8.0}] n 1 "#444444" [::RMSXFlipbookTimeline::Matrix::column_label [lindex $columns $col]]
            }

            png_legend $image $left [expr {$heat_bottom + 38.0}] $plot_w 12 $min_val $max_val $palette [dict get $dataset value_label] $dataset
            $image write $filename -format png
        } finally {
            catch {image delete $image}
        }
        return [file normalize $filename]
    }

    proc write_current_svg {filename args} {
        set dataset [current_dataset]
        if {$dataset eq {}} {
            error "No Timeline dataset is loaded"
        }
        return [write_svg $dataset $filename {*}$args]
    }

    proc write_current_png {filename args} {
        set dataset [current_dataset]
        if {$dataset eq {}} {
            error "No Timeline dataset is loaded"
        }
        return [write_png $dataset $filename {*}$args]
    }
}
