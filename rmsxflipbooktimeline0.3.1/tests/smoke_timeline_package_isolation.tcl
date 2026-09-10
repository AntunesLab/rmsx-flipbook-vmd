# The active package must coexist with an already loaded Timeline namespace.
namespace eval ::timeline { variable sentinel "existing Timeline state" }
proc ::timeline::sentinel_command {} { return "existing Timeline command" }
set before [info commands ::timeline::*]
lappend auto_path $::env(RMSX_TEST_REPO)
package require -exact rmsxflipbooktimeline 0.3.1
if {$::timeline::sentinel ne "existing Timeline state" || [::timeline::sentinel_command] ne "existing Timeline command"} {
    error "Existing Timeline state changed"
}
if {[info commands ::timeline::*] ne $before} { error "RMSX leaked commands into Timeline" }
if {[namespace exists ::RMSXFlipbook]} { error "Legacy RMSX package was loaded implicitly" }
foreach command {calculate_timeline show_timeline_dataset read_timeline_tml write_timeline_tml} {
    if {[info commands ::RMSXFlipbookTimeline::$command] eq ""} { error "Missing $command" }
}
puts "RMSX Flipbook Timeline package isolation smoke passed"
exit 0
