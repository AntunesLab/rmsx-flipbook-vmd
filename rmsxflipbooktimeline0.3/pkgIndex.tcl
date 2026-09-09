# RMSX/Flipbook Timeline package index; VERSION is the version authority.
if {![package vsatisfies [package provide Tcl] 8.6]} { return }
set fp [open [file join $dir VERSION] r]
set version [string trim [read $fp]]
close $fp
package ifneeded rmsxflipbooktimeline $version [list apply {{dir} {
    set ::env(RMSXFLIPBOOKTIMELINEDIR) $dir
    source -encoding utf-8 [file join $dir rmsxflipbooktimeline.tcl]
}} $dir]
