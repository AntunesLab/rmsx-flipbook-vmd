# Standalone graphical launch with an optional disposable demonstration dataset.
lappend auto_path $::env(RMSX_LAUNCH_REPO)
source [file join $::env(RMSX_LAUNCH_PACKAGE) register.tcl]
if {$::env(RMSX_LAUNCH_DEMO) ne ""} {
    set work $::env(RMSX_LAUNCH_WORK)
    set single [expr {$::env(RMSX_LAUNCH_DEMO) eq "single"}]
    set topology [expr {$single ? "1UBQ.pdb" : "protease_backbone.pdb"}]
    set trajectory [expr {$single ? "mon_sys.dcd" : "short_protease_backbone.dcd"}]
    set folder [expr {$single ? "native-rmsx-1ubq-9/chain_7_rmsx" : "native-rmsx-real-multichain-protease/combined"}]
    foreach {key value} [list \
        source_folder [file join $work fixtures seed_outputs $folder] \
        native_topology [file join $work fixtures upstream test_files $topology] \
        native_trajectory [file join $work fixtures upstream test_files $trajectory] \
        native_output [file join $work new-analysis] \
        native_chain [expr {$single ? "7" : "all"}] \
        native_slices 9 native_start 0 native_end -1 native_metric RMSX \
        native_time_step 0.04888821] {
        ::RMSXFlipbookTimeline::state_set $key $value
    }
}
rmsxflipbooktimeline
