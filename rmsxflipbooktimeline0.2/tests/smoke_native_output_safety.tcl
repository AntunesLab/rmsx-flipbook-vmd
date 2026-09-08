################################################################################
# RMSX Flipbook Timeline native output directory safety smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline native output safety smoke failed: $message"
    exit 1
}

proc assert_true {condition message} {
    if {!$condition} {
        smoke_fail $message
    }
}

proc assert_contains {haystack needle message} {
    if {[string first $needle $haystack] < 0} {
        smoke_fail "$message: expected '$needle' in '$haystack'"
    }
}

proc write_empty_file {path} {
    set fp [open $path w]
    close $fp
}

proc run_smoke {} {
    global auto_path
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

    set ns ::RMSXFlipbookTimeline::NativeAnalysis
    set base [file normalize [file join $workspace_root outputs native-output-safety-smoke]]
    catch {file delete -force $base}
    file mkdir $base

    set input_dir [file join $base inputs]
    file mkdir $input_dir
    set topology [file join $input_dir prot.pdb]
    set trajectory [file join $input_dir traj.dcd]
    write_empty_file $topology
    write_empty_file $trajectory

    set reason [${ns}::output_dir_safety_reason $input_dir $topology $trajectory]
    assert_contains $reason "same directory as the input file" "input directory was not flagged as unsafe"

    set reason [${ns}::output_dir_safety_reason $base $topology $trajectory]
    assert_contains $reason "contains the input file" "parent directory was not flagged as unsafe"

    set managed [file join $base managed]
    file mkdir [file join $managed chain_A_rmsx]
    file mkdir [file join $managed chain_B_lddtmap]
    file mkdir [file join $managed combined]
    write_empty_file [file join $managed .DS_Store]
    assert_true [${ns}::is_rmsx_managed_output_dir $managed] "managed layout was not recognized"

    set legacy_managed [file join $base legacy-managed]
    file mkdir [file join $legacy_managed chain_A_rmsx]
    file mkdir [file join $legacy_managed chain_B_rmsx]
    file mkdir [file join $legacy_managed combined]
    write_empty_file [file join $legacy_managed .rmsx_output_dir]
    assert_true [${ns}::is_rmsx_managed_output_dir $legacy_managed] "original RMSX sentinel layout was not recognized"

    set unmanaged [file join $base unmanaged]
    file mkdir [file join $unmanaged chain_A_rmsx]
    file mkdir [file join $unmanaged notes]
    write_empty_file [file join $unmanaged results.txt]
    assert_true [expr {![${ns}::is_rmsx_managed_output_dir $unmanaged]}] "unmanaged layout was incorrectly accepted"

    if {![catch {
        ${ns}::prepare_managed_output_dir \
            $unmanaged \
            -overwrite 1 \
            -verbose 0 \
            -topology_file $topology \
            -trajectory_file $trajectory
    } err]} {
        smoke_fail "prepare_managed_output_dir accepted unmanaged output folder"
    }
    assert_contains $err "does not look like an RMSX-managed output directory" "unmanaged refusal message was unclear"
    assert_contains $err "- notes/" "unmanaged refusal preview omitted notes/"
    assert_contains $err "- results.txt" "unmanaged refusal preview omitted results.txt"

    set prep_result [${ns}::prepare_managed_output_dir \
        $managed \
        -overwrite 1 \
        -verbose 0 \
        -topology_file $topology \
        -trajectory_file $trajectory]
    set sentinel [file join $managed [${ns}::output_sentinel_name]]
    assert_true [file isfile $sentinel] "sentinel was not written after managed clear"
    set remaining [lmap path [${ns}::output_dir_entries $managed] {file tail $path}]
    assert_true [expr {[llength $remaining] == 1 && [lindex $remaining 0] eq [${ns}::output_sentinel_name]}] "managed clear left unexpected entries: $remaining"
    assert_true [expr {[dict get $prep_result sentinel] eq $sentinel}] "prepare result did not report sentinel path"

    set legacy_prep [${ns}::prepare_managed_output_dir \
        $legacy_managed \
        -overwrite 1 \
        -verbose 0 \
        -topology_file $topology \
        -trajectory_file $trajectory]
    assert_true [file isfile [dict get $legacy_prep sentinel]] "timeline sentinel was not written after clearing original RMSX-managed output"
    set legacy_remaining [lmap path [${ns}::output_dir_entries $legacy_managed] {file tail $path}]
    assert_true [expr {[llength $legacy_remaining] == 1 && [lindex $legacy_remaining 0] eq [${ns}::output_sentinel_name]}] "legacy managed clear left unexpected entries: $legacy_remaining"

    set empty_existing [file join $base empty-existing]
    file mkdir $empty_existing
    ${ns}::prepare_managed_output_dir \
        $empty_existing \
        -overwrite 0 \
        -verbose 0 \
        -topology_file $topology \
        -trajectory_file $trajectory
    assert_true [file isfile [file join $empty_existing [${ns}::output_sentinel_name]]] "empty existing folder did not receive sentinel"

    file mkdir [file join $empty_existing chain_A_rmsx]
    if {![catch {
        ${ns}::prepare_managed_output_dir \
            $empty_existing \
            -overwrite 0 \
            -verbose 0 \
            -topology_file $topology \
            -trajectory_file $trajectory
    } err]} {
        smoke_fail "prepare_managed_output_dir accepted existing managed contents without overwrite"
    }
    assert_contains $err "Pass -overwrite 1" "existing managed output error did not request overwrite"

    catch {file delete -force $base}
    return ""
}

run_smoke
puts "RMSX Flipbook Timeline native output safety smoke passed"
quit
