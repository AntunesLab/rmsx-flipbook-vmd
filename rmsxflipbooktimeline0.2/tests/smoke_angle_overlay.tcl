################################################################################
# RMSX Flipbook Timeline phi/psi overlay smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline phi/psi overlay smoke failed: $message"
    exit 1
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
} else {
    set plugin_parent [file normalize [file join [pwd] workspace_plugins]]
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

proc assert_equal {label actual expected} {
    if {$actual ne $expected} {
        smoke_fail "$label: expected '$expected', got '$actual'"
    }
}

set rows [list \
    [dict create index 0 atom_index 10 residue 0 resid 1 resname ALA chain A segid A label "A:1 ALA" selection "same residue as index 10"] \
    [dict create index 1 atom_index 11 residue 1 resid 2 resname GLY chain A segid A label "A:2 GLY" selection "same residue as index 11"] \
    [dict create index 2 atom_index 12 residue 2 resid 3 resname SER chain A segid A label "A:3 SER" selection "same residue as index 12"] \
    [dict create index 3 atom_index 13 residue 3 resid 4 resname THR chain A segid A label "A:4 THR" selection "same residue as index 13"]]
set columns [list \
    [dict create index 0 frame 4 label slice_1 target_type slice representative_frame 4] \
    [dict create index 1 frame 8 label slice_2 target_type slice representative_frame 8]]

set phi [::RMSXFlipbookTimeline::Matrix::create \
    title phi \
    value_label phi \
    unit deg \
    source_type test \
    row_mode residue \
    column_mode slice \
    rows $rows \
    columns $columns \
    values [list \
        {0 -60 -120 60} \
        {0 -60 50 170}]]

set psi [::RMSXFlipbookTimeline::Matrix::create \
    title psi \
    value_label psi \
    unit deg \
    source_type test \
    row_mode residue \
    column_mode slice \
    rows $rows \
    columns $columns \
    values [list \
        {-45 140 60 0} \
        {170 0 0 0}]]

set regions [::RMSXFlipbookTimeline::build_ramachandran_dataset_from_angles $phi $psi]
assert_equal "row count" [dict get $regions row_count] 3
assert_equal "column count" [dict get $regions column_count] 2
assert_equal "value kind" [dict get $regions value_kind] categorical
assert_equal "row mode" [dict get $regions row_mode] residue_transition
assert_equal "first row label" [dict get [lindex [dict get $regions rows] 0] label] A:1-2
assert_equal "first row selection" [dict get [lindex [dict get $regions rows] 0] selection] "same residue as (index 10 11)"

set expected_values [list \
    {alpha beta left} \
    {beta left other}]
assert_equal "region values" [dict get $regions values] $expected_values

set shown [::RMSXFlipbookTimeline::show_timeline_dataset $regions draw 0 pick 0]
assert_equal "headless draw rows" [dict get $shown rows] 3
assert_equal "headless draw columns" [dict get $shown columns] 2

array set ::mock_coords {
    10 {0.0 0.0 0.0}
    11 {1.0 0.0 0.0}
    12 {2.0 0.0 0.0}
    13 {3.0 0.0 0.0}
}
set ::mock_selection_count 0
set ::mock_graphics {}

proc atomselect {molid selection args} {
    global mock_selection_count mock_selection_index
    incr mock_selection_count
    set command ::mock_atomselect_$mock_selection_count
    set index ""
    regexp {index ([0-9]+)} $selection _ index
    set mock_selection_index($command) $index
    proc $command {method args} {
        global mock_selection_index mock_coords
        set self [lindex [info level 0] 0]
        set index $mock_selection_index($self)
        switch -- $method {
            num {
                return [expr {[info exists mock_coords($index)] ? 1 : 0}]
            }
            get {
                set property [lindex $args 0]
                if {$property eq "x y z"} {
                    return [list $mock_coords($index)]
                }
                return {}
            }
            delete {
                catch {unset mock_selection_index($self)}
                rename $self ""
                return
            }
            default {
                return
            }
        }
    }
    return $command
}

proc graphics {molid subcommand args} {
    global mock_graphics
    switch -- $subcommand {
        color {
            return ""
        }
        cylinder {
            lappend mock_graphics [list $molid $args]
            return [llength $mock_graphics]
        }
        delete {
            return ""
        }
        default {
            return ""
        }
    }
}

set draw_result [::RMSXFlipbookTimeline::AngleOverlay::draw_dataset $regions molids {100 101} radius 0.25]
assert_equal "drawn segment count" [dict get $draw_result drawn] 6
assert_equal "graphics segment count" [llength $::mock_graphics] 6

if {![::RMSXFlipbookTimeline::clear_angle_overlay]} {
    smoke_fail "clear angle overlay returned false"
}

puts "RMSX Flipbook Timeline phi/psi overlay smoke passed"
if {[info commands quit] ne ""} {
    quit
}
exit 0
