################################################################################
# RMSX Flipbook Timeline hotkey-style control smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline hotkey smoke failed: $message"
    exit 1
}

proc first_user_value {molid} {
    set sel [atomselect $molid "index 0"]
    try {
        set values [$sel get user]
        return [lindex $values 0]
    } finally {
        catch {$sel delete}
    }
}

proc rep_name_and_thickness {molid} {
    set representation [molinfo $molid get "{representation 0}"]
    if {[llength $representation] == 1 && [llength [lindex $representation 0]] > 1} {
        set representation [lindex $representation 0]
    }
    return [list [lindex $representation 0] [lindex $representation 1]]
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

set folder [file join $workspace_root outputs native-rmsx-1ubq-9 chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "Expected 9-slice native smoke folder is missing: $folder"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $folder \
        palette viridis \
        rep NewTube \
        res 16 \
        thick 0.30 \
        spacing 40.0 \
        color_min 0.0 \
        color_max 10.0 \
        view_preset current \
        write_manifest 0
} load_result]} {
    smoke_fail "load_folder failed: $load_result"
}

set molids [dict get $load_result molids]
set first_molid [lindex $molids 0]

if {[catch {::RMSXFlipbookTimeline::install_hotkeys} hotkey_result]} {
    smoke_fail "install_hotkeys failed: $hotkey_result"
}
if {[llength [dict get $hotkey_result keys]] == 0} {
    smoke_fail "No hotkeys were registered: $hotkey_result"
}

if {[catch {::RMSXFlipbookTimeline::adjust_spacing 2.0} spacing_result]} {
    smoke_fail "adjust_spacing failed: $spacing_result"
}
if {[dict get $spacing_result spacing] != 42.0} {
    smoke_fail "Expected spacing 42.0 after adjustment, got $spacing_result"
}

if {[catch {::RMSXFlipbookTimeline::adjust_thickness 0.05} thick_result]} {
    smoke_fail "adjust_thickness failed: $thick_result"
}
if {abs([dict get $thick_result thick] - 0.35) > 0.0001} {
    smoke_fail "Expected thickness 0.35 after adjustment, got $thick_result"
}
set rep_info [rep_name_and_thickness $first_molid]
if {[lindex $rep_info 0] ne "NewTube"} {
    smoke_fail "Expected NewTube rep after thickness adjustment, got $rep_info"
}

if {[catch {::RMSXFlipbookTimeline::toggle_color_method} color_result]} {
    smoke_fail "toggle_color_method failed: $color_result"
}
if {[dict get $color_result color_method] ne "Beta"} {
    smoke_fail "Expected color method Beta after toggle, got $color_result"
}
set color_method [molinfo $first_molid get "{color 0}"]
if {$color_method ne "Beta"} {
    smoke_fail "Expected VMD representation color Beta, got $color_method"
}

if {[catch {::RMSXFlipbookTimeline::adjust_color_min 0.5} min_result]} {
    smoke_fail "adjust_color_min failed: $min_result"
}
if {[::RMSXFlipbookTimeline::state_get color_min] != 0.5} {
    smoke_fail "Expected color_min 0.5"
}
if {[catch {::RMSXFlipbookTimeline::adjust_color_max 0.5} max_result]} {
    smoke_fail "adjust_color_max failed: $max_result"
}
if {[::RMSXFlipbookTimeline::state_get color_max] != 10.5} {
    smoke_fail "Expected color_max 10.5"
}

set before_user [first_user_value $first_molid]
if {[catch {::RMSXFlipbookTimeline::adjust_user_offset 0.2} offset_result]} {
    smoke_fail "adjust_user_offset failed: $offset_result"
}
set after_user [first_user_value $first_molid]
if {$before_user eq $after_user} {
    smoke_fail "Expected user field to change after user offset adjustment"
}
if {[dict get $offset_result assigned_atoms] <= 0} {
    smoke_fail "Expected user offset adjustment to reassign atoms"
}

if {[catch {::RMSXFlipbookTimeline::rotate_flipbook z 5} rotate_result]} {
    smoke_fail "rotate_flipbook failed: $rotate_result"
}
if {[dict get $rotate_result rotated] != [llength $molids]} {
    smoke_fail "Expected all loaded flipbook molecules to rotate, got $rotate_result"
}

puts "RMSX Flipbook Timeline hotkey smoke passed"
quit
