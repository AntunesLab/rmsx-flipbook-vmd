# Actual pixels distinguish selection feedback from the scientific palette.
lappend auto_path $::env(RMSX_TEST_PACKAGE)
package require rmsxflipbooktimeline
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc red_pixels {path} {
    set fp [open $path rb]
    try {set data [read $fp]} finally {close $fp}
    assert {[::RMSXFlipbookTimeline::Render::byte_value $data 2] == 2} "Expected native uncompressed TGA"
    set width [::RMSXFlipbookTimeline::Render::word_le $data 12]
    set channels [expr {[::RMSXFlipbookTimeline::Render::byte_value $data 16]/8}]
    set start [expr {18+[::RMSXFlipbookTimeline::Render::byte_value $data 0]}]
    binary scan [string range $data $start end] cu* bytes
    set count 0; set xmin $width; set xmax -1; set pixel 0
    if {$channels == 3} {set fields {b g r}} elseif {$channels == 4} {set fields {b g r a}} else {error "Unsupported TGA channels"}
    foreach $fields $bytes {
        if {$r > 150 && $r > $g+70 && $r > $b+70} {
            incr count
            set x [expr {$pixel%$width}]
            set xmin [expr {min($xmin,$x)}]; set xmax [expr {max($xmax,$x)}]
        }
        incr pixel
    }
    return [dict create count $count xmin $xmin xmax $xmax width $width]
}
proc changed_pixels {before after} {
    set fp [open $before rb]; try {set a [read $fp]} finally {close $fp}
    set fp [open $after rb]; try {set b [read $fp]} finally {close $fp}
    set width [::RMSXFlipbookTimeline::Render::word_le $a 12]
    set start [expr {18+[::RMSXFlipbookTimeline::Render::byte_value $a 0]}]
    assert {[string range $a 12 17] eq [string range $b 12 17]} "Render dimensions changed"
    binary scan [string range $a $start end] cu* aa
    binary scan [string range $b $start end] cu* bb
    set channels [expr {[::RMSXFlipbookTimeline::Render::byte_value $a 16]/8}]
    set count 0; set xmin $width; set xmax -1; set offset 0
    foreach av $aa bv $bb {
        if {$offset % $channels == 0} {set changed 0}
        if {abs($av-$bv) > 20} {set changed 1}
        if {$offset % $channels == $channels-1 && $changed} {
            incr count
            set x [expr {($offset/$channels)%$width}]
            set xmin [expr {min($xmin,$x)}]; set xmax [expr {max($xmax,$x)}]
        }
        incr offset
    }
    return [dict create count $count xmin $xmin xmax $xmax width $width]
}
set root $::env(RMSX_TEST_WORKDIR)
display resize 1600 720
::RMSXFlipbookTimeline::load_folder [file join $root fixtures seed_outputs reviewer-protease-9 combined] palette viridis view_preset principal
set ids [::RMSXFlipbookTimeline::state_get molids]
assert {[llength $ids] == 9} "Expected all nine slices"
set scene [::RMSXFlipbookTimeline::Scene::snapshot]
set original_reps [lmap id $ids {molinfo $id get numreps}]
set values {}
foreach id $ids {set sel [atomselect $id all]; try {lappend values [$sel get user2]} finally {$sel delete}}
try {
    display resize 1600 720
    color Display Background white
    axes location Off
    stage location Off
    set path [file join $root outputs no-selection.tga]
    ::RMSXFlipbookTimeline::Render::render_to_tga [dict create method TachyonInternal background white] $path 1600 720
    # Calibrate the actual rendered row, including Retina/X11 dimensions,
    # before testing selection. The old reset camera cropped off other slices.
    set bounds [::RMSXFlipbookTimeline::Render::tga_content_bounds $path white]
    set factor [expr {min(0.85*[dict get $bounds width]/([dict get $bounds x1]-[dict get $bounds x0]+1.0),0.85*[dict get $bounds height]/([dict get $bounds y1]-[dict get $bounds y0]+1.0))}]
    ::RMSXFlipbookTimeline::Render::scale_projected $ids $factor
    set bounds [::RMSXFlipbookTimeline::Render::render_to_tga [dict create method TachyonInternal background white] $path 1600 720]
    assert {[dict get $bounds x0] >= 2 && [dict get $bounds y0] >= 2 && [dict get $bounds x1] < [dict get $bounds width]-2 && [dict get $bounds y1] < [dict get $bounds height]-2} "Nine-slice test row is clipped"
    assert {[dict get [red_pixels $path] count] == 0} "Fixture palette is not a clean selection contrast control"
    set baseline $path
    foreach {chain slice} {A 2 B 4} {
        set mid [lindex $ids $slice]
        set selector [atomselect $mid "chain $chain and resid 17"]
        try {set residues [lsort -unique [$selector get residue]]} finally {$selector delete}
        assert {[llength $residues] == 1} "${chain}:17 is ambiguous"
        set exact "residue [lindex $residues 0]"
        foreach id $ids {if {$id != $mid} {mol off $id}}
        set target_bounds [::RMSXFlipbookTimeline::Render::render_to_tga [dict create method TachyonInternal background white] [file join $root outputs ${chain}-target-only.tga] 1600 720]
        foreach id $ids {mol on $id}
        foreach ns {::RMSXFlipbookTimeline::PlotWindow ::RMSXFlipbookTimeline::TimelinePlot} {
            ${ns}::add_highlight_rep $mid $exact
            set path [file join $root outputs ${chain}-[namespace tail $ns]-selected.tga]
            ::RMSXFlipbookTimeline::Render::render_to_tga [dict create method TachyonInternal background white] $path 1600 720
            assert {[dict get [red_pixels $path] count] == 0} "Selection introduced red outside Viridis"
            set repid [expr {[molinfo $mid get numreps]-1}]
            assert {[molinfo $mid get [list [list color $repid]]] eq [molinfo $mid get {{color 0}}]} "Selection changed color method"
            assert {[mol scaleminmax $mid $repid] eq [mol scaleminmax $mid 0]} "Selection changed metric scale"
            set pixels [changed_pixels $baseline $path]
            assert {[dict get $pixels count] >= 25} "Selection does not stand out in the nine-slice molecular image: $pixels"
            assert {[dict get $pixels xmin] >= [dict get $target_bounds x0]-10 && [dict get $pixels xmax] <= [dict get $target_bounds x1]+10} "Highlight escaped the selected slice: $pixels; target=$target_bounds"
            puts "${chain}:17 [namespace tail $ns] selection pixels: $pixels"
            ${ns}::clear_structure_highlight
            assert {[lmap id $ids {molinfo $id get numreps}] eq $original_reps} "Clearing selection removed unrelated representations"
        }
    }
    foreach ns {::RMSXFlipbookTimeline::PlotWindow ::RMSXFlipbookTimeline::TimelinePlot} {
        ${ns}::add_highlight_rep [lindex $ids 0] "resid 25 to 26"
        assert {[lmap id $ids {molinfo $id get numreps}] eq $original_reps} "Masked selection added opaque spheres"
    }
    set after {}
    foreach id $ids {set sel [atomselect $id all]; try {lappend after [$sel get user2]} finally {$sel delete}}
    assert {$after eq $values} "Selection changed scientific metric values"
} finally {
    ::RMSXFlipbookTimeline::PlotWindow::clear_structure_highlight
    ::RMSXFlipbookTimeline::TimelinePlot::clear_structure_highlight
    ::RMSXFlipbookTimeline::Scene::restore_snapshot $scene
}
puts "Nine-slice highlight visibility smoke passed"
quit
