# Tcl package index for RMSX/Flipbook Timeline 0.2.

package ifneeded rmsxflipbooktimeline 0.2 [list apply {{dir} {
    set ::env(RMSXFLIPBOOKTIMELINEDIR) $dir
    source [file join $dir rmsxflipbooktimeline.tcl]
}} $dir]
