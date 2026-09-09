################################################################################
# RMSX Flipbook Timeline neighborhood VMD smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline neighborhood VMD smoke failed: $message"
    flush stdout
    catch {::RMSXFlipbookTimeline::clear_timeline_neighborhood}
    catch {mol delete all}
    exit 1
}

proc assert_loaded {molid label} {
    if {[lsearch -exact [molinfo list] $molid] == -1} {
        smoke_fail "$label molecule was not loaded: $molid"
    }
}

proc mol_drawn {molid} {
    set drawn 1
    catch {set drawn [molinfo $molid get drawn]}
    return [expr {$drawn ? 1 : 0}]
}

proc run_smoke {} {
    global auto_path env

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

    set topology [file join $workspace_root fixtures upstream test_files 1UBQ.pdb]
    set trajectory [file join $workspace_root fixtures upstream test_files mon_sys.dcd]
    if {![file exists $topology]} {
        smoke_fail "topology missing: $topology"
    }
    if {![file exists $trajectory]} {
        smoke_fail "trajectory missing: $trajectory"
    }

    if {[catch {
        set molid [mol new $topology type pdb waitfor all]
        mol addfile $trajectory type dcd first 0 last 4 step 1 waitfor all molid $molid
        set guard_molid [mol new $topology type pdb waitfor all]
        set stale_flipbook_molid [mol new $topology type pdb waitfor all]
    } err]} {
        smoke_fail "could not load test trajectory: $err"
    }

    molinfo $molid set frame 4
    mol top $guard_molid

    if {[catch {
        set dataset [::RMSXFlipbookTimeline::calculate_timeline \
            $molid \
            displacement \
            selection protein \
            first_frame 0 \
            last_frame 4]
    } err]} {
        smoke_fail "could not calculate displacement dataset: $err"
    }

    ::RMSXFlipbookTimeline::state_set molids [list $stale_flipbook_molid]
    mol off $molid
    mol on $guard_molid
    mol on $stale_flipbook_molid
    set focused_molids [::RMSXFlipbookTimeline::TimelinePlot::focus_live_matrix_scene $dataset]
    if {[lsearch -exact $focused_molids $molid] == -1} {
        smoke_fail "live matrix scene did not focus the source trajectory molecule"
    }
    if {[mol_drawn $molid] != 1} {
        smoke_fail "source trajectory should be visible before a Timeline cell is selected"
    }
    if {[mol_drawn $stale_flipbook_molid] != 0} {
        smoke_fail "stale flipbook molecule should be hidden before a Timeline cell is selected"
    }
    if {[mol_drawn $guard_molid] != 1} {
        smoke_fail "unrelated user molecule should not be hidden by live matrix scene focus"
    }

    ::RMSXFlipbookTimeline::state_set timeline_neighborhood_enabled 1
    ::RMSXFlipbookTimeline::state_set timeline_neighborhood_window 2
    ::RMSXFlipbookTimeline::state_set timeline_neighborhood_step 1
    set env(VMDMODULATERIBBON) user
    set env(VMDMODULATENEWTUBE) user
    set env(VMDMODULATENEWCARTOON) user

    if {[catch {
        ::RMSXFlipbookTimeline::show_timeline_dataset $dataset draw 0 pick 0 palette viridis scale_min 0 scale_max 5
        ::RMSXFlipbookTimeline::select_timeline_cell 0 2
    } err]} {
        smoke_fail "timeline neighborhood selection failed: $err"
    }

    set status [::RMSXFlipbookTimeline::timeline_neighborhood_status]
    if {[dict get $status enabled] != 1} {
        smoke_fail "neighborhood did not enable: $status"
    }
    if {[dict get $status created] != 5 || [dict get $status frames] ne {0 1 2 3 4}} {
        smoke_fail "expected five neighborhood snapshots around frame 2, got $status"
    }
    if {[molinfo $molid get frame] != 2} {
        smoke_fail "source molecule should remain on selected frame 2, got [molinfo $molid get frame]"
    }
    if {[molinfo $guard_molid get frame] != 0} {
        smoke_fail "guard molecule frame changed to [molinfo $guard_molid get frame]"
    }
    if {[mol_drawn $molid] != 0 || [mol_drawn $guard_molid] != 0} {
        smoke_fail "source and guard molecules should be hidden while neighborhood frames are focused"
    }
    if {[dict get $status color_style] ne "continuous"} {
        smoke_fail "expected continuous matrix coloring for displacement, got $status"
    }
    if {[dict get $status colored_rows] <= 0} {
        smoke_fail "expected matrix values to be assigned to snapshot rows, got $status"
    }
    set expected_snapshot_atoms [molinfo $molid get numatoms]
    if {[dict get $status context_atoms] != $expected_snapshot_atoms} {
        smoke_fail "neighborhood snapshots should include the full matrix residue structures, got $status"
    }
    foreach name {VMDMODULATERIBBON VMDMODULATENEWTUBE VMDMODULATENEWCARTOON} {
        if {![info exists env($name)] || $env($name) ne "user"} {
            smoke_fail "continuous neighborhood should use normal Flipbook geometry modulation while active, but $name is missing or not user"
        }
    }

    set temp_molids [dict get $status molids]
    set expected_top [lindex $temp_molids [expr {int(([llength $temp_molids] - 1) / 2)}]]
    if {[molinfo top] != $expected_top} {
        smoke_fail "center neighborhood molecule should be top while focused, got [molinfo top], expected $expected_top"
    }
    set active_state_molids [::RMSXFlipbookTimeline::state_get molids {}]
    foreach temp_molid $temp_molids {
        assert_loaded $temp_molid "temporary neighborhood"
        if {[mol_drawn $temp_molid] != 1} {
            smoke_fail "temporary neighborhood molecule should be visible while focused: $temp_molid"
        }
        if {[molinfo $temp_molid get numreps] < 2} {
            smoke_fail "temporary neighborhood molecule lacks highlight rep: $temp_molid"
        }
        if {[lsearch -exact $active_state_molids $temp_molid] == -1} {
            smoke_fail "temporary neighborhood molecule should be active Flipbook state while focused: $temp_molid"
        }
        if {[molinfo $temp_molid get numatoms] != $expected_snapshot_atoms} {
            smoke_fail "temporary neighborhood molecule should include the full matrix residue structures, got [molinfo $temp_molid get numatoms] atoms"
        }
    }
    set sidechain_sel [atomselect [lindex $temp_molids 0] "resid 1 and not backbone and not hydrogen"]
    set sidechain_count [$sidechain_sel num]
    $sidechain_sel delete
    if {$sidechain_count <= 0} {
        smoke_fail "temporary neighborhood should include selected residue sidechain context"
    }

    set temp_files [dict get $status files]
    foreach path $temp_files {
        if {![file exists $path]} {
            smoke_fail "temporary PDB should exist before clear: $path"
        }
    }

    if {[catch {::RMSXFlipbookTimeline::select_timeline_slice 3} err]} {
        smoke_fail "timeline column scrub failed: $err"
    }
    foreach temp_molid $temp_molids {
        if {[lsearch -exact [molinfo list] $temp_molid] != -1} {
            smoke_fail "temporary neighborhood molecule should clear on column scrub: $temp_molid"
        }
    }
    foreach path $temp_files {
        if {[file exists $path]} {
            smoke_fail "temporary PDB should clear on column scrub: $path"
        }
    }
    if {[molinfo $molid get frame] != 3} {
        smoke_fail "source molecule should move to scrubbed frame 3, got [molinfo $molid get frame]"
    }
    if {[mol_drawn $molid] != 1 || [mol_drawn $guard_molid] != 1} {
        smoke_fail "source and guard molecules should be restored after column scrub clears neighborhood"
    }
    if {[molinfo top] != $molid} {
        smoke_fail "source molecule should be top again after scrub clears neighborhood, got [molinfo top]"
    }
    foreach name {VMDMODULATERIBBON VMDMODULATENEWTUBE VMDMODULATENEWCARTOON} {
        if {![info exists env($name)] || $env($name) ne "user"} {
            smoke_fail "geometry modulation env should restore after clear, but $name is missing or not user"
        }
    }
    foreach temp_molid $temp_molids {
        if {[lsearch -exact [::RMSXFlipbookTimeline::state_get molids {}] $temp_molid] != -1} {
            smoke_fail "temporary neighborhood molecule should be removed from active state after scrub clear: $temp_molid"
        }
    }

    if {[catch {::RMSXFlipbookTimeline::select_timeline_cell 0 2} err]} {
        smoke_fail "timeline neighborhood re-selection failed: $err"
    }
    set status [::RMSXFlipbookTimeline::timeline_neighborhood_status]
    set temp_molids [dict get $status molids]
    set temp_files [dict get $status files]

    if {[catch {::RMSXFlipbookTimeline::clear_timeline_neighborhood} err]} {
        smoke_fail "clear_timeline_neighborhood failed: $err"
    }
    foreach temp_molid $temp_molids {
        if {[lsearch -exact [molinfo list] $temp_molid] != -1} {
            smoke_fail "temporary neighborhood molecule was not deleted: $temp_molid"
        }
    }
    foreach path $temp_files {
        if {[file exists $path]} {
            smoke_fail "temporary PDB was not deleted: $path"
        }
    }
    if {[mol_drawn $molid] != 1 || [mol_drawn $guard_molid] != 1} {
        smoke_fail "source and guard molecules should be restored after clear"
    }
    foreach temp_molid $temp_molids {
        if {[lsearch -exact [::RMSXFlipbookTimeline::state_get molids {}] $temp_molid] != -1} {
            smoke_fail "temporary neighborhood molecule should be removed from active state after clear: $temp_molid"
        }
    }

    if {[catch {
        set ss_dataset [::RMSXFlipbookTimeline::calculate_timeline \
            $molid \
            secondary_structure \
            selection protein \
            first_frame 0 \
            last_frame 4]
        ::RMSXFlipbookTimeline::show_timeline_dataset $ss_dataset draw 0 pick 0 palette viridis scale_min 0 scale_max 1
        ::RMSXFlipbookTimeline::select_timeline_cell 0 2
    } err]} {
        smoke_fail "categorical neighborhood selection failed: $err"
    }
    set status [::RMSXFlipbookTimeline::timeline_neighborhood_status]
    if {[dict get $status color_style] ne "categorical"} {
        smoke_fail "secondary-structure neighborhood should use categorical coloring, got $status"
    }
    if {[dict get $status colored_category_reps] <= 0} {
        smoke_fail "secondary-structure neighborhood should create category-colored reps, got $status"
    }
    set expected_snapshot_atoms [molinfo $molid get numatoms]
    if {[dict get $status context_atoms] != $expected_snapshot_atoms} {
        smoke_fail "categorical neighborhood snapshots should include the full matrix residue structures, got $status"
    }
    set temp_molids [dict get $status molids]
    if {[catch {::RMSXFlipbookTimeline::clear_timeline_neighborhood} err]} {
        smoke_fail "categorical clear_timeline_neighborhood failed: $err"
    }
    foreach temp_molid $temp_molids {
        if {[lsearch -exact [molinfo list] $temp_molid] != -1} {
            smoke_fail "categorical temporary neighborhood molecule was not deleted: $temp_molid"
        }
    }

    catch {mol delete all}
    puts "RMSX Flipbook Timeline neighborhood VMD smoke passed."
}

if {[catch {run_smoke} err]} {
    smoke_fail $err
}
exit 0
