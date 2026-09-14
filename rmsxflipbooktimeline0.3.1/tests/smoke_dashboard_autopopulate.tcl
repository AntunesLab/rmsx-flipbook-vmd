proc expect {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
source -encoding utf-8 [file join $::env(RMSX_TEST_PACKAGE) rmsxflipbooktimeline.tcl]
source -encoding utf-8 [file join $::env(RMSX_TEST_PACKAGE) gui dashboard_window.tcl]
set fixture [file join $::env(RMSX_TEST_REPO) fixtures upstream test_files]
set inputdir [file join [pwd] {simulation α with spaces}]
file mkdir $inputdir
set pdb [file join $inputdir protein.pdb]
set dcd [file join $inputdir simulation.dcd]
file copy [file join $fixture protease_backbone.pdb] $pdb
file copy [file join $fixture short_protease_backbone.dcd] $dcd
expect {[::RMSXFlipbookTimeline::Dashboard::loaded_simulation_inputs] eq {}} "Empty session was selected"
set m [mol new $pdb waitfor all]
expect {[::RMSXFlipbookTimeline::Dashboard::loaded_simulation_inputs] eq {}} "Static structure was selected"
mol addfile $dcd waitfor all molid $m
set ids [molinfo list]
set frame [molinfo $m get frame]
puts "Native loader metadata: [molinfo $m get {filename filetype}]"
set w [::RMSXFlipbookTimeline::Dashboard::show]
expect {[winfo exists $w]} "Dashboard did not open"
expect {$::RMSXFlipbookTimeline::Dashboard::native_topology eq $pdb} "Topology did not autopopulate"
expect {$::RMSXFlipbookTimeline::Dashboard::native_trajectory eq $dcd} "Trajectory did not autopopulate"
expect {$::RMSXFlipbookTimeline::Dashboard::native_chain eq "all"} "Multichain selection should be all"
expect {[dict size $::RMSXFlipbookTimeline::Dashboard::native_chain_groups] == 2} "Chain groups missing"
expect {[::RMSXFlipbookTimeline::Dashboard::dashboard_molid] == $m} "Live molecule identity not pinned"
expect {$::RMSXFlipbookTimeline::Dashboard::native_output eq $inputdir} "Missing default output parent"
expect {[molinfo list] eq $ids && [molinfo $m get frame] == $frame} "Detection changed loaded molecules or frame"
set ::RMSXFlipbookTimeline::Dashboard::native_topology custom.pdb
::RMSXFlipbookTimeline::Dashboard::close_window
::RMSXFlipbookTimeline::Dashboard::show
expect {$::RMSXFlipbookTimeline::Dashboard::native_topology eq "custom.pdb"} "Reopening overwrote explicit input"
set second [mol new $pdb waitfor all]
mol addfile $dcd waitfor all molid $second
expect {[::RMSXFlipbookTimeline::Dashboard::loaded_simulation_inputs] eq {}} "Multiple simulations were guessed"
::RMSXFlipbookTimeline::state_set molids [list $second]
expect {[dict get [::RMSXFlipbookTimeline::Dashboard::loaded_simulation_inputs] molid] == $m} "Plugin-owned molecules were not excluded"
::RMSXFlipbookTimeline::state_set molids {}
mol delete $second
file rename $dcd ${dcd}.hidden
expect {[::RMSXFlipbookTimeline::Dashboard::loaded_simulation_inputs] eq {}} "Missing file was accepted"
file rename ${dcd}.hidden $dcd
mol addfile $dcd waitfor all molid $m
expect {[::RMSXFlipbookTimeline::Dashboard::loaded_simulation_inputs] eq {}} "Concatenated trajectories silently truncated"
mol delete $m
set one [mol new [file join $fixture 1UBQ.pdb] waitfor all]
mol addfile [file join $fixture mon_sys.dcd] waitfor all molid $one
set ::RMSXFlipbookTimeline::Dashboard::native_topology ""
set ::RMSXFlipbookTimeline::Dashboard::native_trajectory ""
expect {[::RMSXFlipbookTimeline::Dashboard::adopt_loaded_simulation] == 1} "Single-chain input not adopted"
expect {$::RMSXFlipbookTimeline::Dashboard::native_chain eq "7"} "Single group not selected"
expect {$::RMSXFlipbookTimeline::Dashboard::native_output eq $inputdir} "Existing output choice overwritten"
::RMSXFlipbookTimeline::Dashboard::close_window
mol delete $one
puts "Loaded simulation autopopulation passed"
