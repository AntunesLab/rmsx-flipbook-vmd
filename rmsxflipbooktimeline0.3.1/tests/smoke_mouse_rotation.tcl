################################################################################
# RMSX Flipbook Timeline mouse-rotation prototype smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline mouse rotation smoke failed: $message"
    flush stdout
    exit 1
}

proc first_atom_coords {molid} {
    set sel [atomselect $molid "index 0"]
    try {
        return [lindex [$sel get {x y z}] 0]
    } finally {
        catch {$sel delete}
    }
}

proc molecule_center {molid} {
    return [::RMSXFlipbookTimeline::Hotkeys::molecule_center $molid]
}

proc matrices_equal {a b} {
    return [expr {$a eq $b}]
}

proc vector_close {a b {tol 0.0001}} {
    if {[llength $a] != [llength $b]} {
        return 0
    }
    foreach av $a bv $b {
        if {abs(double($av) - double($bv)) > $tol} {
            return 0
        }
    }
    return 1
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

proc local_display_center {molid} {
    set center [::RMSXFlipbookTimeline::Hotkeys::molecule_center $molid]
    set global [normalize_matrix [molinfo $molid get global_matrix]]
    set rotate [normalize_matrix [molinfo $molid get rotate_matrix]]
    set scale [normalize_matrix [molinfo $molid get scale_matrix]]
    set center_matrix [normalize_matrix [molinfo $molid get center_matrix]]
    set transform [transmult $global $rotate $scale $center_matrix]
    return [coordtrans $transform $center]
}

proc assert_spread {molids label} {
    if {[llength $molids] < 2} {
        return
    }

    set first [local_display_center [lindex $molids 0]]
    set last [local_display_center [lindex $molids end]]
    set distance [vecdist $first $last]
    if {$distance < 0.1} {
        smoke_fail "$label display centers collapsed: first=$first last=$last distance=$distance"
    }
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir $::env(RMSX_TEST_PACKAGE)
    set plugin_parent $::env(RMSX_TEST_REPO)
    set workspace_root $::env(RMSX_TEST_WORKDIR)
} else {
    set workspace_root $::env(RMSX_TEST_WORKDIR)
    set plugin_parent $::env(RMSX_TEST_REPO)
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

set folder [file join $workspace_root outputs native-rmsx-slice-size-smoke chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "Expected slice-size smoke folder is missing: $folder"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $folder \
        palette viridis \
        rep [::RMSXFlipbookTimeline::Style::default_rep] \
        res 16 \
        thick 0.30 \
        spacing 40.0 \
        view_preset current \
        write_manifest 0
} load_result]} {
    smoke_fail "load_folder failed: $load_result"
}

set molids [dict get $load_result molids]
set first_molid [lindex $molids 0]
set first_before_coords [first_atom_coords $first_molid]
set first_before_center [molecule_center $first_molid]
assert_spread $molids "loaded"

set first_view_matrix_before [transaxis x 90]
molinfo $first_molid set rotate_matrix [list $first_view_matrix_before]
set first_view_matrix_before [normalize_matrix [molinfo $first_molid get rotate_matrix]]

if {[catch {::RMSXFlipbookTimeline::install_mouse_rotation} install_result]} {
    smoke_fail "install_mouse_rotation failed: $install_result"
}
if {![dict get $install_result enabled]} {
    smoke_fail "mouse rotation prototype did not enable: $install_result"
}
if {[dict get $install_result mode] ne "coords"} {
    smoke_fail "expected default mouse rotation mode coords, got $install_result"
}
if {[dict get $install_result sensitivity] <= 1.0} {
    smoke_fail "expected default mouse rotation sensitivity to be greater than 1, got $install_result"
}
assert_spread $molids "after mouse rotation install"
set first_view_matrix_after [normalize_matrix [molinfo $first_molid get rotate_matrix]]
if {$first_view_matrix_after ne $first_view_matrix_before} {
    smoke_fail "mouse rotation install changed the existing display view"
}

rotate z by 7
assert_spread $molids "after z rotation"

set status [::RMSXFlipbookTimeline::mouse_rotation_status]
if {[dict get $status intercepted] < 1} {
    smoke_fail "rotate command was not intercepted: $status"
}
set last_result [dict get $status last_result]
if {[dict get $last_result rotated] != [llength $molids]} {
    smoke_fail "expected all molecules to receive display rotation, got $last_result"
}
if {[dict get $last_result axis] ne "z"} {
    smoke_fail "expected z-axis rotation, got $last_result"
}
if {[dict get $last_result mode] ne "coords"} {
    smoke_fail "expected coords rotation result, got $last_result"
}
if {abs([dict get $last_result angle] - 14.0) > 0.001} {
    smoke_fail "expected sensitivity-scaled 14 degree rotation, got $last_result"
}

set first_after_coords [first_atom_coords $first_molid]
if {$first_before_coords eq $first_after_coords} {
    smoke_fail "mouse rotation prototype did not rotate atom coordinates in coords mode"
}
set first_after_center [molecule_center $first_molid]
if {![vector_close $first_before_center $first_after_center 0.01]} {
    smoke_fail "mouse rotation prototype translated molecule center: before=$first_before_center after=$first_after_center"
}

molinfo $first_molid set fixed 1
set fixed_before_coords [first_atom_coords $first_molid]
set fixed_before_center [molecule_center $first_molid]
rotate y by 3
set fixed_after_coords [first_atom_coords $first_molid]
set fixed_after_center [molecule_center $first_molid]
if {![molinfo $first_molid get fixed]} {
    smoke_fail "fixed molecule was not restored after display rotation"
}
if {$fixed_before_coords eq $fixed_after_coords} {
    smoke_fail "fixed molecule did not receive prototype coordinate rotation"
}
if {![vector_close $fixed_before_center $fixed_after_center 0.01]} {
    smoke_fail "fixed molecule center shifted during coordinate rotation: before=$fixed_before_center after=$fixed_after_center"
}

if {[catch {::RMSXFlipbookTimeline::mouse_rotation_burst 3 y 1.0} burst_result]} {
    smoke_fail "mouse_rotation_burst failed: $burst_result"
}
if {[dict get $burst_result burst_count] != 3} {
    smoke_fail "expected 3 burst rotations, got $burst_result"
}
if {[dict get $burst_result intercepted] < 3} {
    smoke_fail "burst rotations were not intercepted: $burst_result"
}
if {[string first "enabled=" [::RMSXFlipbookTimeline::mouse_rotation_format_status $burst_result]] < 0} {
    smoke_fail "formatted mouse rotation status did not include enabled field"
}

if {[catch {::RMSXFlipbookTimeline::uninstall_mouse_rotation} uninstall_result]} {
    smoke_fail "uninstall_mouse_rotation failed: $uninstall_result"
}
if {[dict get $uninstall_result enabled]} {
    smoke_fail "mouse rotation prototype did not disable: $uninstall_result"
}

puts "RMSX Flipbook Timeline mouse rotation smoke passed"
flush stdout
quit
