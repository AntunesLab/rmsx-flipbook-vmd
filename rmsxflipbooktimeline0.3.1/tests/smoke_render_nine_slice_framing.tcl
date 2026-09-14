# Native CPU rendering: this does not qualify Tk or OpenGL capture.
lappend auto_path $::env(RMSX_TEST_PACKAGE)
package require rmsxflipbooktimeline
source -encoding utf-8 [file join $::env(RMSX_TEST_PACKAGE) gui reviewer.tcl]
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
assert {"TachyonInternal" in [::RMSXFlipbookTimeline::Render::render_methods]} "Native Tachyon CPU renderer is required for the framing check"
# Silhouette fitting must avoid expensive lighting without downgrading exports.
rename ::RMSXFlipbookTimeline::Render::render_to_tga ::RMSXFlipbookTimeline::Render::lighting_original_render
proc ::RMSXFlipbookTimeline::Render::render_to_tga {options path width height} {
    set proof [string match *.proof.tga $path]
    foreach {key option} {shadows shadows ambientocclusion ambient_occlusion} {
        set actual [truthy [::RMSXFlipbookTimeline::Scene::read $key]]
        set expected [expr {$proof ? 0 : [truthy [dict get $options $option]]}]
        assert {$actual == $expected} "Incorrect $key during proof=$proof"
    }
    return [lighting_original_render $options $path $width $height]
}
set root $::env(RMSX_TEST_WORKDIR)
foreach kind {single multi} {
    set spec [::RMSXFlipbookTimeline::Reviewer::example_spec $root $kind]
    set options [list -num_slices 9 -start_frame [dict get $spec first] -end_frame [dict get $spec last] -time_known 0 -mask_selection [dict get $spec mask] -verbose 0 -cleanup 1]
    if {$kind eq "single"} {
        lappend options -chain 7
        set method ::RMSXFlipbookTimeline::run_native_analysis
    } else {set method ::RMSXFlipbookTimeline::run_native_all_chain_analysis}
    set analysis [$method [dict get $spec topology] [dict get $spec trajectory] [file join $root outputs ${kind}-analysis] {*}$options]
    ::RMSXFlipbookTimeline::load_folder [dict get $analysis output_dir] palette viridis view_preset rmsx
    set rotated [::RMSXFlipbookTimeline::rotate_flipbook y 15]
    assert {[dict get $rotated rotated] == 9} "The public in-place rotation omitted a slice"
    set before [::RMSXFlipbookTimeline::Scene::snapshot]
    set state_before [::RMSXFlipbookTimeline::state_dict]
    set current [::RMSXFlipbookTimeline::Results::get]
    assert {[llength [dict get $current molids]] == 9} "The fixture must display all nine structures"
    # In-place rotation gives each slice a separate global translation. Export
    # fitting must scale that spacing along with the protein, without altering
    # the orientation or relative proportions of the projected arrangement.
    ::RMSXFlipbookTimeline::MouseRotate::apply_display_rotation y 15
    set ids [dict get $current molids]
    set projected_before [::RMSXFlipbookTimeline::Render::center_projected $ids]
    ::RMSXFlipbookTimeline::Render::scale_projected $ids 1.5
    set projected_after [::RMSXFlipbookTimeline::Render::projected_bounds $ids]
    foreach dimension {width height} {
        set ratio [expr {[dict get $projected_after $dimension]/[dict get $projected_before $dimension]}]
        assert {abs($ratio-1.5) < 0.0001} "Fitting after in-place rotation did not uniformly scale $dimension: ratio=$ratio"
    }
    ::RMSXFlipbookTimeline::Scene::restore_snapshot $before
    set image [::RMSXFlipbookTimeline::render_flipbook_image \
        -output_name [file join $root outputs ${kind}-nine-slice.png] \
        -method TachyonInternal -width 2400 -height auto -background white \
        -view_preset current -framing fit]
    assert {[dict get $image width] == 2400 && [dict get $image height] < 240 && [dict get $image molecules] == 9} "The nine-slice horizontal layout changed"
    set pixels [dict get $image pixel_bounds]
    set fraction [expr {([dict get $pixels x1]-[dict get $pixels x0]+1.0)/[dict get $image width]}]
    set vertical_fraction [expr {([dict get $pixels y1]-[dict get $pixels y0]+1.0)/[dict get $image height]}]
    # The rendered representation, not merely atom bounds, should occupy about
    # 90% of this wide strip. Previously an 80px proof-height clamp changed its
    # aspect ratio and left approximately 19-26% empty space on each side.
    assert {$fraction > 0.80 && max($fraction,$vertical_fraction) > 0.84 && max($fraction,$vertical_fraction) < 0.96} "Incorrect $kind molecular framing: horizontal occupancy=$fraction, bounds=$pixels"
    assert {[dict get $pixels x0] > 2 && [dict get $pixels y0] > 2 && [dict get $pixels x1] < [dict get $image width]-2 && [dict get $pixels y1] < [dict get $image height]-2} "The molecular render touches an image edge"
    assert {[dict get $pixels nonbackground_samples] > 1000} "The molecular render has insufficient meaningful pixels"
    set fp [open [dict get $image image] rb]
    try {set signature [read $fp 8]} finally {close $fp}
    assert {[binary encode hex $signature] eq "89504e470d0a1a0a"} "Native conversion did not produce a PNG"
    assert {[::RMSXFlipbookTimeline::Scene::snapshot] eq $before} "CPU export changed the camera, display, visibility, or top molecule"
    assert {[::RMSXFlipbookTimeline::state_dict] eq $state_before && [::RMSXFlipbookTimeline::Results::get] eq $current} "CPU export changed the current result"
    assert {$::RMSXFlipbookTimeline::Render::active == 0} "CPU export retained the refresh guard"
    puts "Native CPU framing $kind: size=[dict get $image width]x[dict get $image height] occupancy=$fraction bounds=$pixels"
}
# A failure after the initial proof must remove every temporary image and
# restore the view while preserving an existing destination.
set failed_path [file join $root outputs preserve.png]
set fp [open $failed_path w]; puts -nonewline $fp ORIGINAL; close $fp
set ::framing_render_calls 0
rename ::RMSXFlipbookTimeline::Render::render_to_tga ::RMSXFlipbookTimeline::Render::framing_original_render
proc ::RMSXFlipbookTimeline::Render::render_to_tga {args} {
    if {[incr ::framing_render_calls] == 2} {error "Injected failure after initial fit proof"}
    return [framing_original_render {*}$args]
}
try {
    assert {[catch {::RMSXFlipbookTimeline::render_flipbook_image -output_name $failed_path -width 2400 -overwrite 1} message] && $message eq "Injected failure after initial fit proof"} "The injected fit failure was not reported"
} finally {
    rename ::RMSXFlipbookTimeline::Render::render_to_tga {}
    rename ::RMSXFlipbookTimeline::Render::framing_original_render ::RMSXFlipbookTimeline::Render::render_to_tga
}
assert {[::RMSXFlipbookTimeline::Scene::snapshot] eq $before && [::RMSXFlipbookTimeline::state_dict] eq $state_before && [::RMSXFlipbookTimeline::Results::get] eq $current} "Failed fit did not restore the scene and result"
assert {$::RMSXFlipbookTimeline::Render::active == 0 && ![llength [glob -nocomplain ${failed_path}.rmsx-writing-*]]} "Failed fit retained a refresh guard or temporary image"
set fp [open $failed_path r]; set original [read $fp]; close $fp
assert {$original eq "ORIGINAL"} "Failed fit replaced the previous destination"
::RMSXFlipbookTimeline::reset
puts "Nine-slice native CPU framing smoke passed; GUI/OpenGL not qualified"
quit
