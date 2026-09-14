lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set folder [file join $::env(RMSX_TEST_WORKDIR) fixtures upstream test_files 1UBQ_rmsx chain_7_rmsx]
::RMSXFlipbookTimeline::load_folder $folder
set before [::RMSXFlipbookTimeline::Scene::snapshot]
set path [file join $::env(RMSX_TEST_WORKDIR) outputs figure.svg]
set result [::RMSXFlipbookTimeline::write_flipbook_figure $path -width 900]
assert {$::RMSXFlipbookTimeline::Render::active == 0} "Successful export retained refresh guard"
assert {[file size [dict get $result png]] > 1000} "Missing molecular PNG"
set fp [open [dict get $result svg] r]; set svg [read $fp]; close $fp
assert {[string first {data:image/png;base64,} $svg] >= 0} "Figure SVG has an external image dependency"
assert {[string first {<text} $svg] >= 0 && [string first {Slice 1} $svg] >= 0} "Figure labels are not editable SVG text"
assert {[string first {<metadata>} $svg] >= 0} "Figure missing provenance"
set after [::RMSXFlipbookTimeline::Scene::snapshot]
assert {[dict get $after values] eq [dict get $before values]} "Export changed display properties"
assert {[dict get $after views] eq [dict get $before views]} "Export changed camera"
assert {[dict get $after visibility] eq [dict get $before visibility]} "Export changed molecule visibility"
# VMD's bundled Tachyon can render a different raster size without touching
# the native window. Fail on any resize attempt, including restoration.
rename ::RMSXFlipbookTimeline::Scene::resize_display ::RMSXFlipbookTimeline::Scene::qa_resize_display
proc ::RMSXFlipbookTimeline::Scene::resize_display {args} {error "Offscreen export attempted native resize"}
try {
    foreach width {900 1200} {
        set offscreen [::RMSXFlipbookTimeline::write_flipbook_figure \
            [file join $::env(RMSX_TEST_WORKDIR) outputs offscreen-$width.svg] \
            -method Tachyon -width $width -ambient_occlusion 0 -shadows 0]
        assert {[dict get $offscreen width] == $width} "Offscreen raster width was ignored"
        set after [::RMSXFlipbookTimeline::Scene::snapshot]
        foreach key {values views visibility} {
            assert {[dict get $after $key] eq [dict get $before $key]} "Offscreen export changed $key"
        }
    }
    rename ::RMSXFlipbookTimeline::Render::bundled_tachyon ::RMSXFlipbookTimeline::Render::qa_bundled_tachyon
    proc ::RMSXFlipbookTimeline::Render::bundled_tachyon {} {error "Injected missing bundled renderer"}
    try {
        assert {[catch {::RMSXFlipbookTimeline::write_flipbook_figure \
            [file join $::env(RMSX_TEST_WORKDIR) outputs offscreen-missing.svg] -method Tachyon} message]} "Missing renderer succeeded"
        assert {[string match *Injected* $message] && ![string match *resize* $message]} "Missing renderer attempted a native resize"
    } finally {
        rename ::RMSXFlipbookTimeline::Render::bundled_tachyon {}
        rename ::RMSXFlipbookTimeline::Render::qa_bundled_tachyon ::RMSXFlipbookTimeline::Render::bundled_tachyon
    }
} finally {
    rename ::RMSXFlipbookTimeline::Scene::resize_display {}
    rename ::RMSXFlipbookTimeline::Scene::qa_resize_display ::RMSXFlipbookTimeline::Scene::resize_display
}
# An exception after export framing begins must release the refresh guard too.
rename ::RMSXFlipbookTimeline::Render::render_to_tga ::RMSXFlipbookTimeline::Render::qa_render_to_tga
proc ::RMSXFlipbookTimeline::Render::render_to_tga {args} {error "Injected renderer failure"}
try {
    assert {[catch {::RMSXFlipbookTimeline::write_flipbook_figure [file join $::env(RMSX_TEST_WORKDIR) outputs failed.svg]}]} "Injected renderer failure was swallowed"
} finally {
    rename ::RMSXFlipbookTimeline::Render::render_to_tga {}
    rename ::RMSXFlipbookTimeline::Render::qa_render_to_tga ::RMSXFlipbookTimeline::Render::render_to_tga
}
assert {$::RMSXFlipbookTimeline::Render::active == 0} "Failed export retained refresh guard"
assert {[dict get [::RMSXFlipbookTimeline::Scene::snapshot] views] eq [dict get $before views]} "Failed export retained temporary camera"
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
set ids [::RMSXFlipbookTimeline::Render::result_molids]
mol delete [lindex $ids end]
set incomplete [file join $::env(RMSX_TEST_WORKDIR) outputs incomplete.svg]
assert {[catch {::RMSXFlipbookTimeline::write_flipbook_figure $incomplete} message]} "Export silently omitted a deleted result structure"
assert {![file exists $incomplete]} "Incomplete structure export published a figure"
assert {[dict exists [::RMSXFlipbookTimeline::Results::get] dataset]} "Deleting a structure discarded its matrix snapshot"
puts "Figure export v0.3 smoke passed"
quit
