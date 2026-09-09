lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set folder [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files 1UBQ_rmsx chain_7_rmsx]
::RMSXFlipbookTimeline::load_folder $folder
set before [::RMSXFlipbookTimeline::Scene::snapshot]
set path [file join $::env(RMSX_TEST_WORKDIR) outputs figure.svg]
set result [::RMSXFlipbookTimeline::write_flipbook_figure $path -width 900]
assert {[file size [dict get $result png]] > 1000} "Missing molecular PNG"
set fp [open [dict get $result svg] r]; set svg [read $fp]; close $fp
assert {[string first {data:image/png;base64,} $svg] >= 0} "Figure SVG has an external image dependency"
assert {[string first {<text} $svg] >= 0 && [string first {Slice 1} $svg] >= 0} "Figure labels are not editable SVG text"
assert {[string first {<metadata>} $svg] >= 0} "Figure missing provenance"
set after [::RMSXFlipbookTimeline::Scene::snapshot]
assert {[dict get $after values] eq [dict get $before values]} "Export changed display properties"
assert {[dict get $after views] eq [dict get $before views]} "Export changed camera"
assert {[dict get $after visibility] eq [dict get $before visibility]} "Export changed molecule visibility"
set target [file join $::env(RMSX_TEST_WORKDIR) outputs preserve.png]
set fp [open $target w]; puts -nonewline $fp ORIGINAL; close $fp
rename ::RMSXFlipbookTimeline::Render::render_payload ::RMSXFlipbookTimeline::Render::saved_payload
proc ::RMSXFlipbookTimeline::Render::render_payload {options ids path} {set fp [open $path w]; puts $fp INCOMPLETE; close $fp; error injected}
try {
    assert {[catch {::RMSXFlipbookTimeline::render_flipbook_image -output_name $target -overwrite 1}]} "Renderer failure disappeared"
} finally {
    rename ::RMSXFlipbookTimeline::Render::render_payload {}
    rename ::RMSXFlipbookTimeline::Render::saved_payload ::RMSXFlipbookTimeline::Render::render_payload
}
set fp [open $target r]; set original [read $fp]; close $fp
assert {$original eq "ORIGINAL"} "Failed render replaced old file"
set dry [file join $::env(RMSX_TEST_WORKDIR) nonexistent nested image.png]
::RMSXFlipbookTimeline::render_flipbook_image -output_name $dry -dry_run 1
assert {![file exists [file dirname $dry]]} "Dry run created directories"
puts "Figure export v0.3 smoke passed"
quit
