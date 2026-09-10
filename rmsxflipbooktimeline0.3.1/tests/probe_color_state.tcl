proc probe_fail {message} {
    puts "RMSX Flipbook Timeline color probe failed: $message"
    exit 1
}

proc range_of {values} {
    set sorted [lsort -real $values]
    return [list [lindex $sorted 0] [lindex $sorted end]]
}

proc collect_field_range {molids field} {
    set values {}
    foreach molid $molids {
        set sel [atomselect $molid all]
        set values [concat $values [$sel get $field]]
        $sel delete
    }
    return [range_of $values]
}

proc run_probe {} {
    global argc argv auto_path

    set plugin_parent $::env(RMSX_TEST_REPO)
    lappend auto_path $plugin_parent
    package require rmsxflipbooktimeline 0.3

    if {$argc < 1} {
        probe_fail "Usage: probe_color_state.tcl <folder> \[palette\]"
    }
    set folder [lindex $argv 0]
    set palette "viridis"
    if {$argc >= 2} {
        set palette [lindex $argv 1]
    }

    if {[catch {::RMSXFlipbookTimeline::load_folder $folder palette $palette write_manifest 0} result]} {
        probe_fail "load_folder failed: $result"
    }

    set molids [dict get $result molids]
    set molid [lindex $molids 0]
    set color [molinfo $molid get "{color 0}"]
    set representation [molinfo $molid get "{representation 0}"]
    set user_range [collect_field_range $molids user]
    set user2_range [collect_field_range $molids user2]

    puts "probe result=$result"
    puts "probe molid=$molid reps=[molinfo $molid get numreps]"
    puts "probe rep0 representation=$representation"
    puts "probe rep0 color=$color"
    puts "probe user range=$user_range"
    puts "probe user2 range=$user2_range"

    if {$color ne "User2"} {
        probe_fail "expected rep0 color User2, got $color"
    }
    if {[lindex $user2_range 0] == [lindex $user2_range 1]} {
        probe_fail "user2 field is not varying"
    }

    puts "RMSX Flipbook Timeline color probe passed"
}

run_probe
quit
