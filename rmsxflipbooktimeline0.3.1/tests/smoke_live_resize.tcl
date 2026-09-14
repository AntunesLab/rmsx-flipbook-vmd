# Inspect the live OpenGL framebuffer, not the independent Tachyon renderer.
lappend auto_path $::env(RMSX_TEST_REPO)
package require rmsxflipbooktimeline
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set folder [file join $::env(RMSX_TEST_WORKDIR) fixtures seed_outputs native-rmsx-1ubq-9 chain_7_rmsx]
::RMSXFlipbookTimeline::load_folder $folder view_preset rmsx palette viridis
::RMSXFlipbookTimeline::show_dashboard
color Display Background white
axes location Off
::RMSXFlipbookTimeline::Scene::resize_display 900 700
set ids [::RMSXFlipbookTimeline::state_get molids]
::RMSXFlipbookTimeline::PrincipalView::fit $ids
for {set warmup 0} {$warmup < 5} {incr warmup} {update; display update ui; after 20}
set views [::RMSXFlipbookTimeline::Style::capture_view_matrices $ids]
set root [file join $::env(RMSX_TEST_WORKDIR) outputs]
set reference_images {}
foreach mode {Normal GLSL} {
    if {[display get rendermode] ne $mode} {display rendermode $mode}
    assert {[display get rendermode] eq $mode} "Required live mode unavailable: $mode"
    for {set cycle 0} {$cycle < 3} {incr cycle} {
        set i 0
        foreach dims {{900 700} {640 161} {900 700} {640 85} {900 700}} {
            incr i
            ::RMSXFlipbookTimeline::Scene::resize_display {*}$dims
            assert {[::RMSXFlipbookTimeline::Style::capture_view_matrices $ids] eq $views} "Auto-fit changed matrices during native resize"
            display update
            set path [file join $root live-$mode-$cycle-$i.tga]
            render snapshot $path
            set b [::RMSXFlipbookTimeline::Render::tga_content_bounds $path]
            set area [expr {[dict get $b width]*[dict get $b height]}]
            assert {[dict get $b nonbackground_samples] > 20 && [dict get $b nonbackground_samples] < 0.5*$area} "Corrupt/empty live framebuffer: $b"
            assert {[dict get $b x0] > 0 && [dict get $b y0] > 0 && [dict get $b x1] < [dict get $b width]-1 && [dict get $b y1] < [dict get $b height]-1} "Live framebuffer has edge streaks or clipping: $b"
            ::RMSXFlipbookTimeline::Render::convert_tga_to_png $path [file rootname $path].png
            set f [open [file rootname $path].png rb]
            try {set image [read $f]} finally {close $f}
            set key [list $mode [dict get $b width] [dict get $b height]]
            if {[dict exists $reference_images $key]} {
                assert {$image eq [dict get $reference_images $key]} "Repeated resize changed the live image at $key"
            } else {dict set reference_images $key $image}
        }
    }
}
assert {!$::RMSXFlipbookTimeline::Scene::resizing && [display update status]} "Resize retained its drawing guard"
puts "Live resize framebuffer regression passed"
quit
