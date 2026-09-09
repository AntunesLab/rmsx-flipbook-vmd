# SPDX-License-Identifier: MIT
# Source from .vmdrc / vmd.rc after adding this package's parent to auto_path.
set rmsx_registration_root [file dirname [info script]]
set rmsx_registration_fp [open [file join $rmsx_registration_root VERSION] r]
set rmsx_registration_version [string trim [read $rmsx_registration_fp]]
close $rmsx_registration_fp
package require -exact rmsxflipbooktimeline $rmsx_registration_version
if {![info exists ::RMSXFlipbookTimeline::menu_registered]} {
    if {[info commands vmd_install_extension] ne ""} {
        vmd_install_extension rmsxflipbooktimeline rmsxflipbooktimeline \
            "Analysis/RMSX and Flipbook Timeline"
        set ::RMSXFlipbookTimeline::menu_registered 1
    } elseif {[info commands menu] ne ""} {
        menu tk register rmsxflipbooktimeline rmsxflipbooktimeline \
            "Analysis/RMSX and Flipbook Timeline"
        set ::RMSXFlipbookTimeline::menu_registered 1
    } else {
        error "RMSX menu registration requires a graphical VMD session"
    }
}
unset rmsx_registration_root rmsx_registration_fp rmsx_registration_version
