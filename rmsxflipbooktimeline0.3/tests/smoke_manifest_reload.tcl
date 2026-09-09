################################################################################
# RMSX Flipbook Timeline manifest reload smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline manifest reload smoke failed: $message"
    exit 1
}

proc assert_equal {label actual expected} {
    if {$actual ne $expected} {
        smoke_fail "$label: expected '$expected', got '$actual'"
    }
}

proc assert_close {label actual expected {tolerance 0.0001}} {
    if {abs($actual - $expected) > $tolerance} {
        smoke_fail "$label: expected $expected, got $actual"
    }
}

proc rep_name {molid} {
    set representation [molinfo $molid get "{representation 0}"]
    if {[llength $representation] == 1 && [llength [lindex $representation 0]] > 1} {
        set representation [lindex $representation 0]
    }
    return [lindex $representation 0]
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

if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.3]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

set folder [file join $workspace_root outputs native-rmsx-1ubq-9 chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "Expected 9-slice native smoke folder is missing: $folder"
}

set manifest_name "rmsx_flipbook_timeline_manifest_reload_smoke.tcldict"
set manifest_path [file join $folder $manifest_name]
if {[catch {file delete $manifest_path} err]} {
    smoke_fail "could not clean old manifest: $err"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $folder \
        quality Fast \
        palette magma \
        rep Lines \
        res 16 \
        thick 0.22 \
        spacing 37.5 \
        color_min 1.25 \
        color_max 8.75 \
        apply_mask 0 \
        mask_opacity 0.44 \
        view_preset current \
        write_manifest 1 \
        manifest_name $manifest_name
} load_result]} {
    smoke_fail "initial load_folder failed: $load_result"
}

if {![file exists $manifest_path]} {
    smoke_fail "manifest was not written: $manifest_path"
}

if {[catch {::RMSXFlipbookTimeline::reset 1} err]} {
    smoke_fail "reset failed before manifest reload: $err"
}
if {[catch {display depthcue on} err]} {
    smoke_fail "could not enable depthcue before manifest reload: $err"
}

if {[catch {::RMSXFlipbookTimeline::load_manifest $manifest_path view_preset current} reload_result]} {
    smoke_fail "load_manifest failed: $reload_result"
}

assert_equal "loaded manifest path" [dict get $reload_result manifest_loaded] [file normalize $manifest_path]
assert_equal "manifest reload explicit view" [dict get $reload_result view_preset] current
assert_equal "state manifest path" [::RMSXFlipbookTimeline::state_get manifest_path] [file normalize $manifest_path]
assert_equal "palette" [::RMSXFlipbookTimeline::state_get palette] magma
assert_equal "representation state" [::RMSXFlipbookTimeline::state_get rep] Lines
assert_equal "spacing mode" [::RMSXFlipbookTimeline::state_get spacing_mode] manual
assert_close "spacing" [::RMSXFlipbookTimeline::state_get spacing] 37.5
assert_close "color_min" [::RMSXFlipbookTimeline::state_get color_min] 1.25
assert_close "color_max" [::RMSXFlipbookTimeline::state_get color_max] 8.75
assert_equal "apply_mask" [::RMSXFlipbookTimeline::state_get apply_mask] 0
assert_close "mask_opacity" [::RMSXFlipbookTimeline::state_get mask_opacity] 0.44

set molids [dict get $reload_result molids]
if {[llength $molids] != 9} {
    smoke_fail "expected 9 molecules after manifest reload, got [llength $molids]"
}
assert_equal "representation on first molecule" [rep_name [lindex $molids 0]] Lines

if {[display get depthcue] ne "off"} {
    smoke_fail "expected depthcue off after manifest reload"
}

if {[catch {file delete $manifest_path} err]} {
    smoke_fail "could not clean manifest: $err"
}
puts "RMSX Flipbook Timeline manifest reload smoke passed"
quit
