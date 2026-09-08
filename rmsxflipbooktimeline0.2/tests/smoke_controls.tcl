################################################################################
# RMSX Flipbook Timeline controls smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline controls smoke failed: $message"
    exit 1
}

proc molecule_center {molid} {
    set sel [atomselect $molid "all"]
    try {
        return [measure center $sel]
    } finally {
        catch {$sel delete}
    }
}

proc assert_centered_layout {molids spacing} {
    set count [llength $molids]
    if {$count == 0} {
        smoke_fail "expected molecules for centered layout check"
    }

    set first_x ""
    set last_x ""
    foreach molid $molids {
        set center [molecule_center $molid]
        if {$first_x eq ""} {
            set first_x [lindex $center 0]
        }
        set last_x [lindex $center 0]
    }

    set bounds_center [row_bounds_center $molids]
    if {abs([lindex $bounds_center 1]) > 0.05 || abs([lindex $bounds_center 2]) > 0.05} {
        smoke_fail "expected centered row vertical/depth bounds, got $bounds_center"
    }

    if {$count > 1} {
        set expected_span [expr {($count - 1) * $spacing}]
        set observed_span [expr {$last_x - $first_x}]
        if {abs($observed_span - $expected_span) > 0.1} {
            smoke_fail "expected centered row span $expected_span, got $observed_span"
        }
    }
}

proc vector_close {a b tolerance} {
    if {[llength $a] != [llength $b]} {
        return 0
    }
    for {set i 0} {$i < [llength $a]} {incr i} {
        if {abs([lindex $a $i] - [lindex $b $i]) > $tolerance} {
            return 0
        }
    }
    return 1
}

proc assert_row_anchor_matches_bounds {molids} {
    set bounds [::RMSXFlipbookTimeline::Style::row_bounds $molids]
    if {$bounds eq ""} {
        smoke_fail "expected row bounds for view anchor check"
    }

    set expected {}
    for {set i 0} {$i < 3} {incr i} {
        lappend expected [expr {([lindex [dict get $bounds min] $i] + [lindex [dict get $bounds max] $i]) / 2.0}]
    }

    set anchor [::RMSXFlipbookTimeline::Style::create_row_view_anchor]
    if {$anchor eq ""} {
        smoke_fail "expected row view anchor molecule"
    }

    set center [molecule_center $anchor]
    ::RMSXFlipbookTimeline::Style::delete_row_view_anchor $anchor
    if {![vector_close $center $expected 0.05]} {
        smoke_fail "expected row view anchor center $expected, got $center"
    }
}

proc row_bounds_center {molids} {
    set bounds [::RMSXFlipbookTimeline::Style::row_bounds $molids]
    if {$bounds eq ""} {
        smoke_fail "expected row bounds center"
    }
    set center {}
    for {set i 0} {$i < 3} {incr i} {
        lappend center [expr {([lindex [dict get $bounds min] $i] + [lindex [dict get $bounds max] $i]) / 2.0}]
    }
    return $center
}

proc assert_row_nudge_moves_all {molids} {
    set before [row_bounds_center $molids]
    set result [::RMSXFlipbookTimeline::nudge_flipbook_row y 5.0]
    if {[dict get $result moved] != [llength $molids]} {
        smoke_fail "expected row nudge to move [llength $molids] molecules, got $result"
    }
    set after [row_bounds_center $molids]
    set expected [list [lindex $before 0] [expr {[lindex $before 1] + 5.0}] [lindex $before 2]]
    if {![vector_close $after $expected 0.05]} {
        smoke_fail "expected row nudge center $expected, got $after"
    }
    ::RMSXFlipbookTimeline::nudge_flipbook_row y -5.0
    set restored [row_bounds_center $molids]
    if {![vector_close $restored $before 0.05]} {
        smoke_fail "expected row nudge restore $before, got $restored"
    }
}

proc assert_even_slice_view_anchor {folder} {
    set files [lsort -dictionary [glob -nocomplain -directory $folder "slice_*_first_frame.pdb"]]
    if {[llength $files] < 4} {
        smoke_fail "expected at least four slice files for even-anchor smoke"
    }

    ::RMSXFlipbookTimeline::reset 1
    set molids [::RMSXFlipbookTimeline::Loader::load_pdb_files [lrange $files 0 3]]
    ::RMSXFlipbookTimeline::state_set molids $molids
    set offsets [::RMSXFlipbookTimeline::Layout::set_grid_spacing $molids 40.0]
    ::RMSXFlipbookTimeline::state_set layout_offsets $offsets
    assert_centered_layout $molids 40.0
    assert_row_anchor_matches_bounds $molids
    ::RMSXFlipbookTimeline::reset 1
}

proc assert_depthcue_off {label} {
    if {[catch {display get depthcue} depthcue]} {
        smoke_fail "could not query depthcue after $label: $depthcue"
    }
    if {$depthcue ne "off"} {
        smoke_fail "expected depthcue off after $label, got $depthcue"
    }
}

set plugin_parent [file normalize [file join [pwd] workspace_plugins]]
if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.2]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}
lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

if {$argc < 1} {
    smoke_fail "Usage: smoke_controls.tcl <rmsx-output-folder>"
}

set folder [lindex $argv 0]
catch {display depthcue on}
if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $folder \
        quality Fast \
        palette magma \
        rep NewTube \
        res 16 \
        thick 0.22 \
        spacing 30.0 \
        color_min 1.0 \
        color_max 9.0 \
        mask_opacity 0.20 \
        view_preset current \
        write_manifest 1
} result]} {
    smoke_fail "load_folder failed: $result"
}
assert_depthcue_off "load_folder"

if {[::RMSXFlipbookTimeline::state_get spacing_mode] ne "manual"} {
    smoke_fail "expected manual spacing mode after explicit spacing"
}
if {[::RMSXFlipbookTimeline::state_get spacing] != 30.0} {
    smoke_fail "expected spacing 30.0"
}

catch {display depthcue on}
if {[catch {
    ::RMSXFlipbookTimeline::apply_settings \
        quality Balanced \
        palette viridis \
        rep NewTube \
        res 24 \
        thick 0.28 \
        spacing 40.0 \
        color_min 0.0 \
        color_max 10.0 \
        write_manifest 1
} apply_result]} {
    smoke_fail "apply_settings failed: $apply_result"
}
assert_depthcue_off "apply_settings"

set molid [lindex [dict get $apply_result molids] 0]
set representation [molinfo $molid get "{representation 0}"]
set color_method [molinfo $molid get "{color 0}"]
if {[llength $representation] == 1 && [llength [lindex $representation 0]] > 1} {
    set representation [lindex $representation 0]
}

if {[lindex $representation 0] ne "NewTube"} {
    smoke_fail "expected NewTube rep, got $representation"
}
if {[lindex $representation 2] != 24} {
    smoke_fail "expected rep resolution 24, got $representation"
}
if {$color_method ne "User2"} {
    smoke_fail "expected User2 color method, got $color_method"
}
if {[::RMSXFlipbookTimeline::state_get spacing] != 40.0} {
    smoke_fail "expected spacing 40.0 after apply"
}

assert_centered_layout [dict get $apply_result molids] 40.0
set expected_top [lindex [dict get $apply_result molids] [expr {int(([llength [dict get $apply_result molids]] - 1) / 2)}]]
set centered_top [::RMSXFlipbookTimeline::Style::center_row_top_molecule]
if {$centered_top ne $expected_top || [molinfo top] ne $expected_top} {
    smoke_fail "expected centered view top molecule $expected_top, got helper=$centered_top top=[molinfo top]"
}

set diagnostics [::RMSXFlipbookTimeline::flipbook_view_diagnostics]
if {![dict exists $diagnostics count] || [dict get $diagnostics count] != [llength [dict get $apply_result molids]]} {
    smoke_fail "view diagnostics did not report loaded row: $diagnostics"
}
assert_row_nudge_moves_all [dict get $apply_result molids]

set manifest [::RMSXFlipbookTimeline::state_get manifest_path ""]
if {$manifest eq "" || ![file exists $manifest]} {
    smoke_fail "manifest was not written"
}

if {[catch {
    set payload [::RMSXFlipbookTimeline::Manifest::read $manifest]
    if {[dict get $payload schema_version] != 1} {
        error "manifest schema_version missing"
    }
    if {[dict get $payload settings res] != 24} {
        error "manifest settings res was not updated"
    }
    if {[dict get $payload layout spacing] != 40.0} {
        error "manifest layout spacing was not updated"
    }
    if {[dict get $payload source slice_count] < 1} {
        error "manifest source slice_count missing"
    }
} err]} {
    smoke_fail $err
}

assert_even_slice_view_anchor $folder

puts "RMSX Flipbook Timeline controls smoke passed"
quit
