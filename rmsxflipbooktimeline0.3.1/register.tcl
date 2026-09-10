# SPDX-License-Identifier: MIT
# Source from .vmdrc / vmd.rc after adding this package's parent to auto_path.
set rmsx_registration_root [file dirname [info script]]
set rmsx_registration_fp [open [file join $rmsx_registration_root VERSION] r]
set rmsx_registration_version [string trim [read $rmsx_registration_fp]]
close $rmsx_registration_fp
if {[package provide rmsxflipbooktimeline] ne ""} {
    if {[package provide rmsxflipbooktimeline] ne $rmsx_registration_version ||
        ![info exists ::RMSXFlipbookTimeline::basedir] ||
        [file normalize $::RMSXFlipbookTimeline::basedir] ne [file normalize $rmsx_registration_root]} {
        unset rmsx_registration_root rmsx_registration_fp rmsx_registration_version
        error "A different RMSX/Flipbook build is already loaded. Open a fresh VMD session before loading this package."
    }
}
# Select this exact package, even when another installed copy is on auto_path.
set rmsx_registration_dir $rmsx_registration_root
apply {{dir} {source -encoding utf-8 [file join $dir pkgIndex.tcl]}} $rmsx_registration_dir
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
unset rmsx_registration_root rmsx_registration_fp rmsx_registration_version rmsx_registration_dir
