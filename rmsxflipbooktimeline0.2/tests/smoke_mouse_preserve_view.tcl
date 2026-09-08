################################################################################
# RMSX Flipbook Timeline mouse install should preserve the current view
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline mouse preserve-view smoke failed: $message"
    flush stdout
    exit 1
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

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
    set workspace_root [file dirname $plugin_parent]
} else {
    set workspace_root [pwd]
    set plugin_parent [file normalize [file join $workspace_root workspace_plugins]]
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

set view_matrix [transaxis x 90]
set display_delta [transaxis y 15]
set coordinate_delta [::RMSXFlipbookTimeline::Style::display_delta_to_coordinate_delta \
    $view_matrix \
    $display_delta]
set point {2.0 3.0 4.0}
set expected_display [coordtrans [transmult $display_delta $view_matrix] $point]
set actual_display [coordtrans [transmult $view_matrix $coordinate_delta] $point]
if {![vector_close $actual_display $expected_display]} {
    smoke_fail "display-axis coordinate delta mismatch: expected=$expected_display actual=$actual_display"
}

set folder [file join $workspace_root outputs native-rmsx-slice-size-smoke chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "Expected slice-size smoke folder is missing: $folder"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $folder \
        palette viridis \
        rep NewTube \
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
set expected_matrix [transaxis x 90]
molinfo $first_molid set rotate_matrix [list $expected_matrix]
set before [normalize_matrix [molinfo $first_molid get rotate_matrix]]

if {[catch {::RMSXFlipbookTimeline::install_mouse_rotation coords 2.0} install_result]} {
    smoke_fail "install_mouse_rotation failed: $install_result"
}
if {![dict get $install_result enabled]} {
    smoke_fail "mouse rotation did not enable: $install_result"
}

set after [normalize_matrix [molinfo $first_molid get rotate_matrix]]
if {$after ne $before} {
    smoke_fail "install_mouse_rotation changed rotate_matrix: before=$before after=$after"
}

puts "RMSX Flipbook Timeline mouse preserve-view smoke passed"
flush stdout
quit
