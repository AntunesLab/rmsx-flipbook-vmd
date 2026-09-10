# Optional unpacked-source reviewer entry. The one-file demo calls Reviewer::launch directly.
namespace eval ::RMSXReviewerStart {
    proc start {repo {work ""} {example single}} {
        if {![package vsatisfies [info patchlevel] 8.6]} {error "RMSX needs VMD with Tcl 8.6. This VMD uses Tcl [info patchlevel]."}
        set repo [file normalize $repo]
        set candidates [glob -nocomplain -types f -directory $repo rmsxflipbooktimeline*/VERSION]
        if {[llength $candidates] != 1} {error "Expected one RMSX package in $repo"}
        set package_dir [file dirname [lindex $candidates 0]]
        set fp [open [file join $package_dir VERSION] r]
        try {set version [string trim [read $fp]]} finally {close $fp}
        if {[package provide rmsxflipbooktimeline] ne "" &&
            ([package provide rmsxflipbooktimeline] ne $version || ![info exists ::RMSXFlipbookTimeline::basedir] || [file normalize $::RMSXFlipbookTimeline::basedir] ne $package_dir)} {
            error "Another RMSX package is already loaded. Start a fresh VMD session to review this build."
        }
        if {[lsearch -exact $::auto_path $package_dir] < 0} {set ::auto_path [linsert $::auto_path 0 $package_dir]}
        set expected_build source-checkout
        if {[file isfile [file join $package_dir BUILD_ID]]} {
            set fp [open [file join $package_dir BUILD_ID] r]
            try {set expected_build [string trim [read $fp]]} finally {close $fp}
            if {![regexp {^[0-9a-f]{64}$} $expected_build]} {error "Invalid RMSX build fingerprint"}
        }
        # Tcl may already have indexed another copy of this exact version.
        apply {{dir} {source -encoding utf-8 [file join $dir pkgIndex.tcl]}} $package_dir
        package require -exact rmsxflipbooktimeline $version
        if {[info commands ::RMSXFlipbookTimeline::package_root] eq "" ||
            [info commands ::RMSXFlipbookTimeline::build_id] eq "" ||
            [file normalize [::RMSXFlipbookTimeline::package_root]] ne $package_dir ||
            [::RMSXFlipbookTimeline::build_id] ne $expected_build} {
            error "The loaded RMSX package does not match the selected reviewer checkout. Start a fresh VMD session."
        }
        if {[info commands ::RMSXFlipbookTimeline::Reviewer::launch] eq ""} {source -encoding utf-8 [file join $package_dir gui reviewer.tcl]}
        if {$::RMSXFlipbookTimeline::Reviewer::active} {return [::RMSXFlipbookTimeline::Reviewer::reopen [::RMSXFlipbookTimeline::build_id]]}
        if {$work eq ""} {
            set fp [file tempfile work rmsx-review-]
            close $fp
            file delete $work
            file mkdir $work
            try {file copy [file join $repo fixtures] [file join $work fixtures]} on error {message options} {
                file delete -force $work
                return -options $options $message
            }
        }
        return [::RMSXFlipbookTimeline::Reviewer::launch $work [::RMSXFlipbookTimeline::build_id] $example]
    }
}
if {![info exists ::RMSX_REVIEWER_START_LIBRARY_ONLY]} {
    ::RMSXReviewerStart::start [file dirname [file dirname [file normalize [info script]]]]
}
