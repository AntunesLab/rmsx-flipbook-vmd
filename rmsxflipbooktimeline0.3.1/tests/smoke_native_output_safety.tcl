# Compatibility helpers must never delete occupied output directories.
lappend auto_path $::env(RMSX_TEST_REPO)
package require -exact rmsxflipbooktimeline 0.3.1
set ns ::RMSXFlipbookTimeline::NativeAnalysis
set base [file join $::env(RMSX_TEST_WORKDIR) outputs safety]
file mkdir [file join $base inputs]
set topology [file join $base inputs protein.pdb]
set trajectory [file join $base inputs trajectory.dcd]
foreach path [list $topology $trajectory] { set fp [open $path w]; puts -nonewline $fp "input sentinel"; close $fp }
foreach target [list $base [file dirname $topology]] {
    if {[${ns}::output_dir_safety_reason $target $topology $trajectory] eq ""} { error "Input ancestor must be unsafe" }
}
foreach layout {arbitrary legacy shape_only} {
    set dir [file join $base $layout]
    file mkdir [file join $dir chain_A_rmsx]
    set keep [file join $dir chain_A_rmsx slice_1_first_frame.pdb]
    set fp [open $keep w]; puts -nonewline $fp "precious original bytes"; close $fp
    if {$layout eq "legacy"} { set fp [open [file join $dir .rmsx_output_dir] w]; puts $fp rmsx; close $fp }
    if {$layout eq "arbitrary"} { set fp [open [file join $dir notes.txt] w]; puts $fp notes; close $fp }
    foreach overwrite {0 1} {
        if {![catch {${ns}::prepare_managed_output_dir $dir -overwrite $overwrite -topology $topology -trajectory $trajectory} err]} {
            error "Occupied legacy helper target accepted: $layout overwrite=$overwrite"
        }
        set fp [open $keep r]; set bytes [read $fp]; close $fp
        if {$bytes ne "precious original bytes"} { error "Refused preparation changed data" }
        if {$layout eq "arbitrary" && ![file exists [file join $dir notes.txt]]} { error "Notes deleted" }
        if {$layout eq "legacy" && ![file exists [file join $dir .rmsx_output_dir]]} { error "Legacy sentinel deleted" }
    }
}
set fresh [file join $base fresh]
${ns}::prepare_managed_output_dir $fresh -overwrite 0 -topology $topology -trajectory $trajectory
if {![file isdirectory $fresh]} { error "Fresh output was not created" }
puts "RMSX Flipbook Timeline native output safety smoke passed"
exit 0
