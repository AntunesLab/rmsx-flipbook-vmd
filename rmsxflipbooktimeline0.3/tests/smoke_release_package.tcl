################################################################################
# RMSX/Flipbook Timeline 0.2 release-surface smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX/Flipbook Timeline release smoke failed: $message"
    exit 1
}

set plugin_parent $::env(RMSX_TEST_REPO)
set plugin_dir [file join $plugin_parent rmsxflipbooktimeline0.3]
if {![file isdirectory $plugin_dir]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

if {[package provide rmsxflipbooktimeline] ne "0.3"} {
    smoke_fail "expected package version 0.2, got [package provide rmsxflipbooktimeline]"
}

foreach command {
    rmsxflipbooktimeline
    rmsxflipbooktimeline_dashboard
    rmsxflipbooktimeline_classic
    rmsxflipbooktimeline_about
    rmsxflipbooktimeline_citation
} {
    if {[info commands $command] eq ""} {
        smoke_fail "public launcher command missing: $command"
    }
}

if {[string first "::RMSXFlipbookTimeline::show_dashboard" [info body rmsxflipbooktimeline]] < 0} {
    smoke_fail "default rmsxflipbooktimeline command should open the dashboard"
}

if {![info exists ::env(RMSXFLIPBOOKTIMELINEDIR)]} {
    smoke_fail "pkgIndex should set RMSXFLIPBOOKTIMELINEDIR"
}

if {[file normalize $::env(RMSXFLIPBOOKTIMELINEDIR)] ne [file normalize $plugin_dir]} {
    smoke_fail "RMSXFLIPBOOKTIMELINEDIR does not point at plugin dir: $::env(RMSXFLIPBOOKTIMELINEDIR)"
}

if {[::RMSXFlipbookTimeline::package_root] ne $plugin_dir} {
    smoke_fail "package_root did not report plugin dir"
}

set about [rmsxflipbooktimeline_about]
foreach key {package version root help_url citation experimental_features} {
    if {![dict exists $about $key]} {
        smoke_fail "about dict missing key: $key"
    }
}

if {[dict get $about package] ne "rmsxflipbooktimeline" || [dict get $about version] ne "0.3"} {
    smoke_fail "about dict has wrong package/version: $about"
}

if {[string first "10.1038/s41598-026-39869-7" [rmsxflipbooktimeline_citation]] < 0} {
    smoke_fail "citation command is missing DOI"
}

foreach filename {
    INSTALL.md
    USER_GUIDE.md
    DEVELOPER_NOTES.md
    MAINTAINER_PACKET.md
    CITATION.cff
} {
    if {![file exists [file join $plugin_dir $filename]]} {
        smoke_fail "release document missing: $filename"
    }
}

set fp [open [file join $plugin_dir INSTALL.md] r]
set install_text [read $fp]
close $fp
foreach needle {
    VMDPLUGINPATH
    "plugins/noarch/tcl/rmsxflipbooktimeline0.3"
    "Analysis/RMSX and Flipbook Timeline"
} {
    if {[string first $needle $install_text] < 0} {
        smoke_fail "INSTALL.md missing release install/menu text: $needle"
    }
}

set fp [open [file join $plugin_dir CITATION.cff] r]
set citation_cff [read $fp]
close $fp
if {[string first "10.1038/s41598-026-39869-7" $citation_cff] < 0} {
    smoke_fail "CITATION.cff missing DOI"
}

if {[::RMSXFlipbookTimeline::experimental_enabled]} {
    smoke_fail "experimental features should be disabled by default"
}

if {[info commands ::RMSXFlipbookTimeline::ViewerPlot::show] ne ""} {
    smoke_fail "experimental viewer plot module should not be sourced by default"
}

if {[info commands ::RMSXFlipbookTimeline::AngleOverlay::apply] ne ""} {
    smoke_fail "experimental phi/psi overlay module should not be sourced by default"
}

if {![catch {::RMSXFlipbookTimeline::show_viewer_plot} err] || [string first "experimental" $err] < 0} {
    smoke_fail "viewer plot should report an experimental-feature error by default"
}

if {![catch {::RMSXFlipbookTimeline::apply_ramachandran_overlay 0} err] || [string first "experimental" $err] < 0} {
    smoke_fail "phi/psi overlay should report an experimental-feature error by default"
}

if {[catch {source [file join $plugin_dir gui dashboard_window.tcl]} err]} {
    smoke_fail "dashboard source failed: $err"
}

set metrics [::RMSXFlipbookTimeline::Dashboard::metric_values]
foreach metric {
    RMSX
    Shift-Map
    lDDT
    rmsd
    rmsf
    displacement
    displacement_velocity
    secondary_structure
    native_contacts
    sasa
    phi
    psi
    delta_phi
    delta_psi
    hbonds
    salt_bridges
    inter_selection_contacts
} {
    if {[lsearch -exact $metrics $metric] < 0} {
        smoke_fail "release metric missing: $metric"
    }
}

foreach metric {
    cross_correlation
    x
    y
    z
    user
    user2
    user3
    user4
    user_field
    residue_function
    selection_empty
    test_free_selection
    rmsd_tool
} {
    if {[lsearch -exact $metrics $metric] >= 0} {
        smoke_fail "experimental metric should be hidden by default: $metric"
    }
}

if {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::metric_groups] Fields] >= 0} {
    smoke_fail "Fields group should be hidden when experimental metrics are disabled"
}

puts "RMSX/Flipbook Timeline release smoke passed"
if {[info commands quit] ne ""} {
    quit
}
exit 0
