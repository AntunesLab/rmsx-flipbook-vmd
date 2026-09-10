# Shared exploration controls. Dataset snapshots belong to individual canvases;
# transient selections, representations and replay timers never own source data.
namespace eval ::RMSXFlipbookTimeline::HeatmapTools {
    variable views {}
    variable messages
    variable expanded
    proc state {canvas} {variable views; if {[dict exists $views $canvas]} {return [dict get $views $canvas]}; return {}}
    proc valid {canvas} {
        variable views
        if {![dict exists $views $canvas] || ![winfo exists $canvas]} {return 0}
        set generation [dict get $views $canvas generation]
        set current [::RMSXFlipbookTimeline::Results::get]
        return [expr {$generation ne "" && $current ne {} && [dict get $current id] eq $generation}]
    }
    proc allowed {canvas} {return [expr {[valid $canvas] && ![::RMSXFlipbookTimeline::Operation::running]}]}
    proc attach {canvas dataset} {
        variable views
        ::RMSXFlipbookTimeline::Matrix::validate $dataset
        if {![winfo exists $canvas]} {return}
        set old [state $canvas]
        set same [expr {$old ne {} && [dict get $old dataset] eq $dataset}]
        if {!$same && $old ne {}} {detach $canvas}
        if {!$same} {
            dict set views $canvas [dict create dataset $dataset generation "" event {} pinned {} reps {} replay {} drag {} panel ""]
        } else {stop $canvas}
        set labels {}; set index 0
        foreach row [dict get $dataset rows] {dict set labels $index [::RMSXFlipbookTimeline::Matrix::row_label $row]; incr index}
        ::RMSXFlipbookTimeline::Navigation::row_labels $canvas $labels
        foreach {event command} {Shift-Button-1 brush_begin Shift-B1-Motion brush_move Shift-ButtonRelease-1 brush_end} {
            set script "[list ::RMSXFlipbookTimeline::HeatmapTools::$command $canvas %x %y %s]; break"
            bind $canvas <$event> $script
            $canvas bind pickable <$event> $script
        }
        bind $canvas <Destroy> +[list ::RMSXFlipbookTimeline::HeatmapTools::destroyed $canvas %W]
        ::RMSXFlipbookTimeline::Effects::register [list heatmap_tools $canvas] [list ::RMSXFlipbookTimeline::HeatmapTools::release $canvas] window
        geometry_changed $canvas
    }
    proc activate {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return}
        set current [::RMSXFlipbookTimeline::Results::get]
        dict set views $canvas generation ""
        if {$current ne {} && [dict exists $current dataset] && [dict get $current dataset] eq [dict get $views $canvas dataset]} {
            dict set views $canvas generation [dict get $current id]
        }
        controls_state $canvas
    }
    proc result_changed {} {
        variable views
        foreach canvas [dict keys $views] {
            if {[dict get $views $canvas generation] ne "" && ![valid $canvas]} {release $canvas; controls_state $canvas}
        }
    }
    proc stop_all {} {variable views; foreach canvas [dict keys $views] {stop $canvas}}
    proc destroyed {canvas actual} {if {$canvas eq $actual} {detach $canvas}}
    proc detach {canvas} {
        variable views; variable messages; variable expanded
        if {![dict exists $views $canvas]} {return}
        release $canvas
        catch {::RMSXFlipbookTimeline::ThresholdControls::detach $canvas}
        dict unset views $canvas
        catch {::RMSXFlipbookTimeline::Effects::unregister [list heatmap_tools $canvas]}
        unset -nocomplain messages($canvas) expanded($canvas)
    }
    proc release {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return}
        stop $canvas
        clear_reps $canvas
        dict set views $canvas event {}; dict set views $canvas pinned {}; dict set views $canvas drag {}
        if {[winfo exists $canvas]} {$canvas delete event_selection; $canvas delete pinned_selection}
        catch {::RMSXFlipbookTimeline::ThresholdControls::detach $canvas}
    }
    proc status {canvas text} {variable messages; set messages($canvas) $text}
    proc mount {parent canvas} {
        variable views; variable messages; variable expanded
        if {![dict exists $views $canvas]} {return ""}
        set panel $parent.explore
        set was_expanded [expr {[info exists expanded($canvas)] ? $expanded($canvas) : 0}]
        set threshold_state [::RMSXFlipbookTimeline::ThresholdControls::state $canvas]
        if {[winfo exists $panel]} {
            # A staged replacement shares its parent with the previous canvas.
            foreach other [dict keys $views] {
                if {$other ne $canvas && [dict get $views $other panel] eq $panel} {
                    catch {::RMSXFlipbookTimeline::ThresholdControls::detach $other}
                    dict set views $other panel ""
                }
            }
            destroy $panel
        }
        ttk::frame $panel
        dict set views $canvas panel $panel
        set expanded($canvas) $was_expanded
        set bar [ttk::frame $panel.bar]
        foreach {name text command} [list play {Play event} [list play $canvas] stop Stop [list stop $canvas] pin {Pin rows} [list pin $canvas] clear Clear [list clear_event $canvas]] {
            ttk::button $bar.$name -text $text -command [list ::RMSXFlipbookTimeline::HeatmapTools::invoke $canvas {*}$command]
            pack $bar.$name -side left -padx {0 4}
        }
        ttk::checkbutton $bar.more -text {Tools…} -variable ::RMSXFlipbookTimeline::HeatmapTools::expanded($canvas) -command [list ::RMSXFlipbookTimeline::HeatmapTools::toggle $canvas]
        pack $bar.more -side right
        pack $bar -fill x
        set detail [ttk::frame $panel.detail]
        # Keep a usable matrix visible when tools are expanded in a short window.
        canvas $detail.viewport -height 200 -width 1 -highlightthickness 0
        ttk::scrollbar $detail.scroll -orient vertical -command [list $detail.viewport yview]
        $detail.viewport configure -yscrollcommand [list $detail.scroll set]
        set content [ttk::frame $detail.content]
        $detail.viewport create window 0 0 -anchor nw -window $content -tags content
        grid $detail.viewport -row 0 -column 0 -sticky nsew
        grid $detail.scroll -row 0 -column 1 -sticky ns
        grid columnconfigure $detail 0 -weight 1
        bind $detail.viewport <Configure> [list ::RMSXFlipbookTimeline::HeatmapTools::detail_geometry $canvas]
        bind $content <Configure> [list ::RMSXFlipbookTimeline::HeatmapTools::detail_geometry $canvas]
        bind $detail.viewport <MouseWheel> "[list ::RMSXFlipbookTimeline::HeatmapTools::detail_scroll $detail.viewport %D]; break"
        set zoom [ttk::frame $content.zoom]
        set index 0
        foreach {name text command} [list fit {Fit all} [list fit $canvas] every {Every residue} [list every_residue $canvas] xm {Time −} [list zoom $canvas 0.8 1] xp {Time +} [list zoom $canvas 1.25 1] ym {Rows −} [list zoom $canvas 1 0.8] yp {Rows +} [list zoom $canvas 1 1.25]] {
            ttk::button $zoom.$name -text $text -command [list ::RMSXFlipbookTimeline::HeatmapTools::zoom_command $canvas {*}$command]
            grid $zoom.$name -row [expr {$index/3}] -column [expr {$index%3}] -sticky ew -padx {0 3} -pady 1
            incr index
        }
        foreach column {0 1 2} {grid columnconfigure $zoom $column -weight 1}
        pack $zoom -fill x -pady {4 2}
        ttk::label $content.hint -text {Shift-drag selects an event; Ctrl+Shift adds rows. Right-drag zooms. Escape clears.} -wraplength 520 -font TkSmallCaptionFont
        pack $content.hint -fill x
        set thresholds [::RMSXFlipbookTimeline::ThresholdControls::attach $content $canvas [dict get $views $canvas dataset]]
        pack $thresholds -fill x -pady {4 0}
        if {$threshold_state ne {}} {
            ::RMSXFlipbookTimeline::ThresholdControls::set_options $canvas [dict get $threshold_state options]
            if {[dict get $threshold_state expanded]} {::RMSXFlipbookTimeline::ThresholdControls::toggle $canvas}
        }
        ttk::label $panel.status -textvariable ::RMSXFlipbookTimeline::HeatmapTools::messages($canvas) -wraplength 520 -font TkSmallCaptionFont -anchor w
        pack $panel.status -fill x -pady {2 0}
        if {$was_expanded} {toggle $canvas}
        status $canvas {Shift-drag: select event · Right-drag: zoom}
        controls_state $canvas
        return $panel
    }
    proc detail_geometry {canvas} {
        set view [state $canvas]
        if {$view eq {}} {return}
        set detail [dict get $view panel].detail
        if {![winfo exists $detail.viewport]} {return}
        set width [winfo width $detail.viewport]
        $detail.viewport itemconfigure content -width $width
        set requested [winfo reqheight $detail.content]
        set limit [expr {max(150,min(320,int([winfo height [winfo toplevel $canvas]]*0.35)))}]
        set height [expr {max(1,min($requested,$limit))}]
        if {[$detail.viewport cget -height] != $height} {$detail.viewport configure -height $height}
        $detail.viewport configure -scrollregion [list 0 0 $width $requested]
    }
    proc detail_scroll {viewport delta} {
        if {$delta != 0} {$viewport yview scroll [expr {$delta > 0 ? -3 : 3}] units}
    }
    proc invoke {canvas command args} {
        if {[catch {uplevel #0 [list ::RMSXFlipbookTimeline::HeatmapTools::$command {*}$args]} message]} {status $canvas $message}
    }
    proc zoom_command {canvas command args} {
        if {![allowed $canvas]} {return}
        if {[catch {uplevel #0 [list ::RMSXFlipbookTimeline::Navigation::$command {*}$args]} message]} {status $canvas $message}
    }
    proc toggle {canvas} {
        variable views; variable expanded
        set panel [dict get $views $canvas panel]
        if {$expanded($canvas)} {pack $panel.detail -after $panel.bar -fill x} else {pack forget $panel.detail}
    }
    proc controls_state {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return}
        set panel [dict get $views $canvas panel]
        if {$panel eq "" || ![winfo exists $panel]} {return}
        set active [allowed $canvas]
        set replay [dict get $views $canvas replay]
        set event [dict get $views $canvas event]
        set mode [replay_mode [dict get $views $canvas dataset]]
        $panel.bar.play configure -text [expr {$mode eq "windows" ? "Play windows" : "Play event"}] -state [expr {$active && $event ne {} && $mode ne "unavailable" && $replay eq {} ? "normal" : "disabled"}]
        $panel.bar.stop configure -state [expr {$replay ne {} ? "normal" : "disabled"}]
        $panel.bar.pin configure -text [expr {[llength [dict get $views $canvas pinned]] ? "Unpin rows" : "Pin rows"}] -state [expr {$active ? "normal" : "disabled"}]
        $panel.bar.clear configure -state [expr {$active ? "normal" : "disabled"}]
        if {!$active} {status $canvas {This view is inactive. Select the current result to explore it.}}
    }
    proc cells {canvas} {
        if {[dict exists $::RMSXFlipbookTimeline::Navigation::views $canvas cells]} {return [dict get $::RMSXFlipbookTimeline::Navigation::views $canvas cells]}
        return {}
    }
    proc coordinate_at {canvas x y} {
        lassign [::RMSXFlipbookTimeline::Navigation::to_model $canvas [$canvas canvasx $x] [$canvas canvasy $y]] x y
        set best {}; set distance Inf
        dict for {coordinate record} [cells $canvas] {
            set dx [expr {max([dict get $record x0]-$x,0.0,$x-[dict get $record x1])}]
            set dy [expr {max([dict get $record y0]-$y,0.0,$y-[dict get $record y1])}]
            set d [expr {$dx*$dx+$dy*$dy}]
            if {$d < $distance} {set best $coordinate; set distance $d}
        }
        return $best
    }
    proc brush_begin {canvas x y modifiers} {
        variable views
        if {![allowed $canvas]} {return}
        set coordinate [coordinate_at $canvas $x $y]
        if {$coordinate eq {}} {return}
        stop $canvas
        dict set views $canvas drag [dict create anchor $coordinate add [expr {($modifiers & 4) != 0}] previous [dict get $views $canvas event]]
        brush_move $canvas $x $y $modifiers
    }
    proc brush_move {canvas x y modifiers} {
        variable views
        if {![allowed $canvas] || [dict get $views $canvas drag] eq {}} {return}
        set drag [dict get $views $canvas drag]
        set coordinate [coordinate_at $canvas $x $y]
        if {$coordinate eq {}} {return}
        set event [range_event [cells $canvas] [dict get $drag anchor] $coordinate]
        if {[dict get $drag add] && [dict get $drag previous] ne {}} {
            dict set event rows [lsort -integer -unique [concat [dict get $event rows] [dict get $drag previous rows]]]
        }
        set_event $canvas $event
    }
    proc brush_end {canvas x y modifiers} {
        variable views
        brush_move $canvas $x $y $modifiers
        if {[dict exists $views $canvas]} {dict set views $canvas drag {}}
    }
    proc range_event {cells first last} {
        if {![dict exists $cells $first] || ![dict exists $cells $last]} {return {}}
        set a [dict get $cells $first]; set b [dict get $cells $last]
        set lo [expr {min([dict get $a y0],[dict get $b y0])}]
        set hi [expr {max([dict get $a y1],[dict get $b y1])}]
        set c0 [expr {min([lindex $first 1],[lindex $last 1])}]
        set c1 [expr {max([lindex $first 1],[lindex $last 1])}]
        set rows {}; set columns {}
        dict for {coordinate rec} $cells {
            lassign $coordinate row col
            if {[dict get $rec y0] >= $lo-0.01 && [dict get $rec y1] <= $hi+0.01} {lappend rows $row}
            if {$col >= $c0 && $col <= $c1} {lappend columns $col}
        }
        return [dict create rows [lsort -integer -unique $rows] columns [lsort -integer -unique $columns]]
    }
    proc set_event {canvas event} {
        variable views
        if {![allowed $canvas]} {return {}}
        dict set views $canvas event $event
        draw_marks $canvas
        if {$event ne {}} {
            set ds [dict get $views $canvas dataset]
            set cols [dict get $ds columns]
            set labels [list [::RMSXFlipbookTimeline::Matrix::column_label [lindex $cols [lindex [dict get $event columns] 0]]] [::RMSXFlipbookTimeline::Matrix::column_label [lindex $cols [lindex [dict get $event columns] end]]]]
            status $canvas "[llength [dict get $event rows]] rows · columns [join $labels { – }]"
            ::RMSXFlipbookTimeline::Results::update [dict create selected_event $event]
        }
        controls_state $canvas
        return $event
    }
    proc clear_event {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return}
        stop $canvas; clear_reps $canvas
        dict set views $canvas event {}; dict set views $canvas pinned {}; dict set views $canvas drag {}
        draw_marks $canvas
        if {[valid $canvas]} {::RMSXFlipbookTimeline::Results::update [dict create selected_event {} pinned_rows {}]}
        status $canvas {Selection and pins cleared.}
        controls_state $canvas
    }
    proc geometry_changed {canvas} {
        if {[state $canvas] eq {}} {return}
        draw_marks $canvas
        catch {::RMSXFlipbookTimeline::ThresholdControls::refresh $canvas}
    }
    proc draw_marks {canvas} {
        variable views
        if {![dict exists $views $canvas] || ![winfo exists $canvas]} {return}
        $canvas delete event_selection; $canvas delete pinned_selection
        foreach kind {event pinned} {
            set value [dict get $views $canvas $kind]
            if {$value eq {}} {continue}
            if {$kind eq "event"} {set rows [dict get $value rows]; set columns [dict get $value columns]} else {set rows $value; set columns {}}
            set boxes {}
            dict for {coordinate rec} [cells $canvas] {
                lassign $coordinate row col
                if {[lsearch -exact $rows $row] < 0 || ($columns ne {} && [lsearch -exact $columns $col] < 0)} {continue}
                if {![dict exists $boxes $row]} {dict set boxes $row [list [dict get $rec x0] [dict get $rec y0] [dict get $rec x1] [dict get $rec y1]]} else {
                    lassign [dict get $boxes $row] x0 y0 x1 y1
                    dict set boxes $row [list [expr {min($x0,[dict get $rec x0])}] $y0 [expr {max($x1,[dict get $rec x1])}] $y1]
                }
            }
            dict for {row box} $boxes {
                lassign $box x0 y0 x1 y1
                lassign [::RMSXFlipbookTimeline::Navigation::to_canvas $canvas $x0 $y0] x0 y0
                lassign [::RMSXFlipbookTimeline::Navigation::to_canvas $canvas $x1 $y1] x1 y1
                $canvas create rectangle $x0 $y0 $x1 $y1 -outline [expr {$kind eq "event" ? "#2563eb" : "#b45309"}] -width 2 -tags ${kind}_selection
            }
        }
    }
    proc selection_changed {canvas coordinate} {
        catch {::RMSXFlipbookTimeline::ThresholdControls::sync_selection $canvas}
        controls_state $canvas
    }
    proc loaded {id} {return [expr {$id ne "" && [info commands molinfo] ne "" && [lsearch -exact [molinfo list] $id] >= 0}]}
    proc target_ids {dataset} {
        set ids {}
        foreach column [dict get $dataset columns] {
            foreach key {slice_molid molid} {if {[dict exists $column $key] && [loaded [dict get $column $key]]} {lappend ids [dict get $column $key]; break}}
        }
        if {[dict exists $dataset molid] && [loaded [dict get $dataset molid]]} {lappend ids [dict get $dataset molid]}
        return [lsort -integer -unique $ids]
    }
    proc selection_for_rows {dataset rows molid} {
        set selections {}
        foreach index $rows {
            set row [lindex [dict get $dataset rows] $index]
            if {[dict exists $row resid]} {set selection [::RMSXFlipbookTimeline::ResidueIdentity::selection $row $molid]} elseif {[dict exists $row selection]} {set selection [dict get $row selection]} else {error "Row has no validated structure selection"}
            set sel [atomselect $molid $selection]
            try {if {[$sel num] == 0} {error "Selected row is absent from molecule $molid"}} finally {$sel delete}
            lappend selections "($selection)"
        }
        return [join $selections { or }]
    }
    proc add_rep {molid selection color} {
        mol addrep $molid
        set index [expr {[molinfo $molid get numreps]-1}]
        set name [mol repname $molid $index]
        try {
            mol modselect $index $molid $selection
            mol modstyle $index $molid VDW 0.65 12
            mol modcolor $index $molid ColorID $color
            mol modmaterial $index $molid Opaque
        } on error {message options} {catch {mol delrep $index $molid}; return -options $options $message}
        return [list $molid $name]
    }
    proc delete_reps {reps} {
        foreach rep [lreverse $reps] {
            lassign $rep id name
            if {[loaded $id] && ![catch {mol repindex $id $name} index] && $index >= 0} {mol delrep $index $id}
        }
    }
    proc clear_reps {canvas} {
        variable views
        if {![dict exists $views $canvas]} {return}
        delete_reps [dict get $views $canvas reps]
        dict set views $canvas reps {}
    }
    proc pin {canvas} {
        variable views
        if {![allowed $canvas]} {return}
        if {[llength [dict get $views $canvas pinned]]} {
            clear_reps $canvas; dict set views $canvas pinned {}
            ::RMSXFlipbookTimeline::Results::update [dict create pinned_rows {}]
            draw_marks $canvas; controls_state $canvas; return {}
        }
        set event [dict get $views $canvas event]; set rows {}
        if {$event ne {}} {set rows [dict get $event rows]} elseif {[dict exists $::RMSXFlipbookTimeline::Navigation::views $canvas selected] && [llength [dict get $::RMSXFlipbookTimeline::Navigation::views $canvas selected]] == 2} {
            set rows [list [lindex [dict get $::RMSXFlipbookTimeline::Navigation::views $canvas selected] 0]]
        }
        if {$rows eq {}} {error "Select a cell or Shift-drag an event before pinning rows."}
        set ds [dict get $views $canvas dataset]; set ids [target_ids $ds]
        if {$ids eq {}} {error "Structure linking is unavailable for this dataset."}
        # Resolve every selection before adding a representation to any molecule.
        set selections {}; foreach id $ids {dict set selections $id [selection_for_rows $ds $rows $id]}
        set reps {}
        try {dict for {id selection} $selections {lappend reps [add_rep $id $selection 4]}} on error {message options} {delete_reps $reps; return -options $options $message}
        dict set views $canvas reps $reps; dict set views $canvas pinned $rows
        ::RMSXFlipbookTimeline::Results::update [dict create pinned_rows $rows]
        draw_marks $canvas; controls_state $canvas
        status $canvas "Pinned [llength $rows] rows on [llength $ids] structures."
        display update
        return $reps
    }
    proc replay_mode {dataset} {
        set columns [dict get $dataset columns]
        if {[llength $columns] == 0} {return unavailable}
        foreach column $columns {if {[dict exists $column slice_molid] && [loaded [dict get $column slice_molid]]} {return windows}}
        if {[dict exists $dataset molid] && [loaded [dict get $dataset molid]]} {return frames}
        foreach column $columns {if {[dict exists $column molid] && [loaded [dict get $column molid]] && [dict exists $column frame]} {return frames}}
        return unavailable
    }
    proc replay_steps {dataset event} {
        set mode [replay_mode $dataset]; set steps {}
        foreach index [dict get $event columns] {
            set column [lindex [dict get $dataset columns] $index]
            if {$mode eq "windows"} {
                if {![dict exists $column slice_molid] || ![loaded [dict get $column slice_molid]]} {error "A selected window structure is no longer available."}
                lappend steps [dict create column $index molid [dict get $column slice_molid] frame ""]
            } elseif {$mode eq "frames"} {
                set id [expr {[dict exists $column molid] ? [dict get $column molid] : [dict get $dataset molid]}]
                if {![loaded $id]} {error "Source molecule is no longer available."}
                if {[dict exists $column frame_start] && [dict exists $column frame_end]} {set first [dict get $column frame_start]; set last [dict get $column frame_end]} elseif {[dict exists $column frame]} {set first [dict get $column frame]; set last $first} else {error "No verified frame mapping for this column."}
                if {$first < 0 || $last < $first || $last >= [molinfo $id get numframes]} {error "Selected frame interval is outside the source trajectory."}
                for {set frame $first} {$frame <= $last} {incr frame} {lappend steps [dict create column $index molid $id frame $frame]}
            } else {error "Event replay needs a linked live trajectory or loaded window structures."}
        }
        return $steps
    }
    proc play {canvas {delay 100}} {
        variable views
        if {![allowed $canvas]} {return}
        stop_all
        set event [dict get $views $canvas event]
        if {$event eq {}} {error "Shift-drag over rows and time to select an event first."}
        if {![string is integer -strict $delay] || $delay < 20 || $delay > 2000} {error "Replay interval must be 20–2000 milliseconds."}
        set ds [dict get $views $canvas dataset]; set steps [replay_steps $ds $event]
        set saved {}; set selections {}
        foreach step $steps {
            set id [dict get $step molid]
            if {![dict exists $saved $id]} {dict set saved $id [dict create before [molinfo $id get frame] last ""]; dict set selections $id [selection_for_rows $ds [dict get $event rows] $id]}
        }
        dict set views $canvas replay [dict create steps $steps position 0 delay $delay timer "" saved $saved top [molinfo top] last_top "" reps {} selections $selections]
        tick $canvas
        controls_state $canvas
        return [llength $steps]
    }
    proc tick {canvas} {
        variable views
        if {![dict exists $views $canvas] || [dict get $views $canvas replay] eq {}} {return}
        if {![allowed $canvas]} {stop $canvas; return}
        set replay [dict get $views $canvas replay]
        dict set views $canvas replay timer ""
        set position [dict get $replay position]
        if {$position >= [llength [dict get $replay steps]]} {stop $canvas; status $canvas {Event playback complete.}; return}
        set step [lindex [dict get $replay steps] $position]; set id [dict get $step molid]
        if {![loaded $id]} {stop $canvas; status $canvas {Playback stopped: source molecule was removed.}; return}
        dict for {mid item} [dict get $replay saved] {
            if {[loaded $mid] && [dict get $item last] ne "" && [molinfo $mid get frame] != [dict get $item last]} {stop $canvas; status $canvas {Playback stopped after the frame was changed.}; return}
        }
        if {[dict get $replay last_top] ne "" && [molinfo top] ne [dict get $replay last_top]} {
            stop $canvas; status $canvas {Playback stopped after the top molecule was changed.}; return
        }
        if {[catch {
            delete_reps [dict get $replay reps]
            dict set views $canvas replay reps {}
            set row [lindex [dict get $views $canvas event rows] 0]
            ::RMSXFlipbookTimeline::Navigation::choose $canvas [list $row [dict get $step column]]
            # Replay owns its multi-row representation. Remove the ordinary
            # single-cell structure highlight created by the selection callback.
            uplevel #0 [dict get $::RMSXFlipbookTimeline::Navigation::views $canvas clear]
            if {[dict get $step frame] ne ""} {molinfo $id set frame [dict get $step frame]}
            dict set views $canvas replay saved $id last [molinfo $id get frame]
            dict set views $canvas replay last_top [molinfo top]
            dict set views $canvas replay reps [list [add_rep $id [dict get $replay selections $id] 0]]
            display update
        } message options]} {stop $canvas; status $canvas "Playback stopped: $message"; return}
        dict set views $canvas replay position [expr {$position+1}]
        dict set views $canvas replay timer [after [dict get $replay delay] [list ::RMSXFlipbookTimeline::HeatmapTools::tick $canvas]]
    }
    proc stop {canvas} {
        variable views
        if {![dict exists $views $canvas] || [dict get $views $canvas replay] eq {}} {return}
        set replay [dict get $views $canvas replay]
        dict set views $canvas replay {}
        if {[dict get $replay timer] ne ""} {after cancel [dict get $replay timer]}
        delete_reps [dict get $replay reps]
        if {[winfo exists $canvas]} {
            $canvas delete keyboard_selection
            if {[dict exists $::RMSXFlipbookTimeline::Navigation::views $canvas]} {
                dict set ::RMSXFlipbookTimeline::Navigation::views $canvas selected {}
            }
        }
        if {[valid $canvas]} {::RMSXFlipbookTimeline::Results::update [dict create selected_cell {}]}
        dict for {id item} [dict get $replay saved] {
            if {[loaded $id] && [dict get $item last] ne "" && [molinfo $id get frame] == [dict get $item last]} {molinfo $id set frame [dict get $item before]}
        }
        if {[loaded [dict get $replay top]] && [molinfo top] eq [dict get $replay last_top]} {mol top [dict get $replay top]}
        controls_state $canvas
    }
}
