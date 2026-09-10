################################################################################
# RMSX Flipbook Timeline native render export smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline render export smoke failed: $message"
    exit 1
}

proc png_u32_be {data index} {
    binary scan [string range $data $index [expr {$index + 3}]] c4 bytes
    set value 0
    foreach byte $bytes {
        set value [expr {($value << 8) | (($byte + 256) % 256)}]
    }
    return $value
}

proc read_test_png_rgba {path} {
    set fp [open $path r]
    fconfigure $fp -translation binary -encoding binary
    set data [read $fp]
    close $fp

    if {[string range $data 0 7] ne "\x89PNG\r\n\x1a\n"} {
        smoke_fail "test PNG has invalid signature"
    }
    set pos 8
    set width 0
    set height 0
    set color_type -1
    set idat ""
    set data_len [string length $data]
    while {$pos + 12 <= $data_len} {
        set length [png_u32_be $data $pos]
        incr pos 4
        set type [string range $data $pos [expr {$pos + 3}]]
        incr pos 4
        set payload [string range $data $pos [expr {$pos + $length - 1}]]
        incr pos $length
        incr pos 4
        if {$type eq "IHDR"} {
            set width [png_u32_be $payload 0]
            set height [png_u32_be $payload 4]
            binary scan [string index $payload 9] c color_type
            set color_type [expr {($color_type + 256) % 256}]
        } elseif {$type eq "IDAT"} {
            append idat $payload
        } elseif {$type eq "IEND"} {
            break
        }
    }
    if {$width <= 0 || $height <= 0 || $color_type != 6} {
        smoke_fail "test PNG is not RGBA: ${width}x${height} type=$color_type"
    }
    set raw [zlib decompress $idat]
    set row_bytes [expr {$width * 4}]
    set pixels {}
    set pos 0
    for {set y 0} {$y < $height} {incr y} {
        binary scan [string index $raw $pos] c filter
        set filter [expr {($filter + 256) % 256}]
        incr pos
        if {$filter != 0} {
            smoke_fail "test PNG used unexpected filter $filter"
        }
        binary scan [string range $raw $pos [expr {$pos + $row_bytes - 1}]] c* bytes
        incr pos $row_bytes
        for {set x 0} {$x < $width} {incr x} {
            set index [expr {$x * 4}]
            set r [expr {([lindex $bytes $index] + 256) % 256}]
            set g [expr {([lindex $bytes [expr {$index + 1}]] + 256) % 256}]
            set b [expr {([lindex $bytes [expr {$index + 2}]] + 256) % 256}]
            set a [expr {([lindex $bytes [expr {$index + 3}]] + 256) % 256}]
            lappend pixels [list $r $g $b $a]
        }
    }
    return [dict create width $width height $height pixels $pixels]
}

proc run_smoke {} {
global auto_path

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir $::env(RMSX_TEST_PACKAGE)
    set plugin_parent $::env(RMSX_TEST_REPO)
    set workspace_root $::env(RMSX_TEST_WORKDIR)
} else {
    set workspace_root $::env(RMSX_TEST_WORKDIR)
    set plugin_parent $::env(RMSX_TEST_REPO)
}

lappend auto_path $plugin_parent
if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

set converter_dir [file join $workspace_root outputs native-render-smoke]
file mkdir $converter_dir
set tiny_tga [file join $converter_dir tiny_source.tga]
set tiny_png [file join $converter_dir tiny_transparent.png]
catch {file delete $tiny_tga $tiny_png}
set fp [open $tiny_tga w]
fconfigure $fp -translation binary -encoding binary
puts -nonewline $fp [binary format c* {
    0 0 2
    0 0 0 0 0
    0 0 0 0
    2 0 1 0
    24 32
    255 255 255
    0 0 255
}]
close $fp
if {[catch {
    ::RMSXFlipbookTimeline::Render::convert_tga_to_png \
        $tiny_tga \
        $tiny_png \
        transparent_background 1 \
        background white
} png_result]} {
    smoke_fail "transparent PNG conversion failed: $png_result"
}
if {![file exists $tiny_png] || [file size $tiny_png] <= 0} {
    smoke_fail "transparent PNG conversion did not write output"
}
set fp [open $tiny_png r]
fconfigure $fp -translation binary -encoding binary
set png_header [read $fp 8]
close $fp
if {$png_header ne "\x89PNG\r\n\x1a\n"} {
    smoke_fail "transparent PNG output has invalid signature"
}

set alpha_zero_tga [file join $converter_dir alpha_zero_source.tga]
set alpha_zero_png [file join $converter_dir alpha_zero_transparent.png]
catch {file delete $alpha_zero_tga $alpha_zero_png}
set fp [open $alpha_zero_tga w]
fconfigure $fp -translation binary -encoding binary
puts -nonewline $fp [binary format c* {
    0 0 2
    0 0 0 0 0
    0 0 0 0
    2 0 1 0
    32 32
    255 255 255 0
    0 0 255 0
}]
close $fp
set alpha_result [::RMSXFlipbookTimeline::Render::convert_tga_to_png \
    $alpha_zero_tga \
    $alpha_zero_png \
    transparent_background 1 \
    background white]
if {[dict get $alpha_result used_source_alpha]} {
    smoke_fail "all-zero TGA alpha channel should be ignored: $alpha_result"
}
set decoded [read_test_png_rgba $alpha_zero_png]
set pixels [dict get $decoded pixels]
if {[lindex [lindex $pixels 0] 3] != 0} {
    smoke_fail "white background pixel should be transparent after color-keying: $pixels"
}
if {[lindex [lindex $pixels 1] 3] != 255} {
    smoke_fail "foreground pixel should remain opaque when source alpha is all zero: $pixels"
}

set folder [file join $workspace_root outputs native-rmsx-1ubq-9 chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "Expected 9-slice native smoke folder is missing: $folder"
}

if {[catch {
    ::RMSXFlipbookTimeline::load_folder \
        $folder \
        palette viridis \
        rep Lines \
        quality Fast \
        write_manifest 0 \
        apply_mask 0
} load_result]} {
    smoke_fail "load_folder failed: $load_result"
}

set output_dir [file join $workspace_root outputs native-render-smoke]
file mkdir $output_dir
set output_path [file join $output_dir rmsx_render_smoke.tga]
catch {file delete $output_path}

set dry_result [::RMSXFlipbookTimeline::render_flipbook_image \
    -output_name $output_path \
    -method TachyonInternal \
    -width 800 \
    -height 450 \
    -dry_run 1 \
    -reset_view 1]

if {[dict get $dry_result rendered] || ![dict get $dry_result dry_run]} {
    smoke_fail "dry-run render metadata was unexpected: $dry_result"
}
if {[dict get $dry_result image] ne [file normalize $output_path]} {
    smoke_fail "dry-run render resolved unexpected path: $dry_result"
}
if {[dict get $dry_result method] ne "TachyonInternal"} {
    smoke_fail "dry-run render used unexpected method: $dry_result"
}
if {[dict get $dry_result molecules] != 9} {
    smoke_fail "dry-run render result should include 9 molecules: $dry_result"
}
if {[dict get $dry_result view_preset] ne "rmsx"} {
    smoke_fail "dry-run render should use rmsx view preset: $dry_result"
}

set png_output_path [file join $output_dir rmsx_render_smoke.png]
set png_dry_result [::RMSXFlipbookTimeline::render_flipbook_image \
    -output_name $png_output_path \
    -method TachyonInternal \
    -width 800 \
    -height 450 \
    -dry_run 1 \
    -transparent_background 1 \
    -reset_view 1]
if {[dict get $png_dry_result format] ne "png"} {
    smoke_fail "PNG dry-run render should infer png format: $png_dry_result"
}
if {![dict get $png_dry_result transparent_background]} {
    smoke_fail "PNG dry-run render should preserve transparent background flag: $png_dry_result"
}
if {[file extension [dict get $png_dry_result render_image]] ne ".tga"} {
    smoke_fail "PNG dry-run render should use a TGA source render: $png_dry_result"
}

puts "RMSX Flipbook Timeline render export metadata smoke passed"
puts "Rendering image: [dict get $dry_result image]"
flush stdout

::RMSXFlipbookTimeline::render_flipbook_image \
    -output_name $output_path \
    -method TachyonInternal \
    -width 800 \
    -height 450 \
    -reset_view 1
}

run_smoke
quit
