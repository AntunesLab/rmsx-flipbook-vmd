# Registration must not silently substitute a previously loaded package.
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set root $::env(RMSX_TEST_PACKAGE)
proc vmd_install_extension {args} {incr ::registrations}
set registrations 0
source -encoding utf-8 [file join $root register.tcl]
source -encoding utf-8 [file join $root register.tcl]
assert {$registrations == 1} "Repeat registration duplicated the menu entry"
assert {[file normalize [::RMSXFlipbookTimeline::package_root]] eq [file normalize $root]} "Loaded another package location"
set fp [open [file join $root VERSION] r]
set expected [string trim [read $fp]]
close $fp
assert {[package provide rmsxflipbooktimeline] eq $expected} "Ignored VERSION authority"
assert {[dict get [::RMSXFlipbookTimeline::about] build_id] eq [::RMSXFlipbookTimeline::build_id]} "Inconsistent build identity"
set child [interp create]
try {
    $child eval {package provide rmsxflipbooktimeline 0.2}
    set failed [catch {$child eval [list source -encoding utf-8 [file join $root register.tcl]]} message]
    assert {$failed && [string first "fresh VMD session" $message] >= 0} "Old loaded package was silently reused"
    assert {[$child eval {package provide rmsxflipbooktimeline}] eq "0.2"} "Failed registration mutated the old package"
} finally {interp delete $child}
puts "Build identity and registration smoke passed"
