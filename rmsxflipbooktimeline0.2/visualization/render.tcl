################################################################################
# RMSX Flipbook Timeline scene rendering
################################################################################

namespace eval ::RMSXFlipbookTimeline::Render {
    proc truthy {value} {
        set lowered [string tolower [string trim $value]]
        return [expr {$lowered in {1 true yes y on}}]
    }

    proc default_output_path {folder palette output_name} {
        set cleaned [string trim $output_name]
        if {$cleaned eq ""} {
            set cleaned [format "rmsx_%s.tga" [string tolower [string trim $palette]]]
        }
        if {[file pathtype $cleaned] eq "absolute"} {
            return [file normalize $cleaned]
        }
        return [file normalize [file join [file normalize $folder] $cleaned]]
    }

    proc image_format_for_path {path} {
        set ext [string tolower [file extension $path]]
        if {$ext eq "" || $ext eq ".tga"} {
            return tga
        }
        if {$ext eq ".png"} {
            return png
        }
        if {$ext in {.jpg .jpeg}} {
            return jpeg
        }
        error "Unsupported image extension '$ext'. Use .tga, .png, .jpg, or .jpeg."
    }

    proc render_source_path {out_path format} {
        if {$format eq "tga"} {
            return $out_path
        }
        set root [file rootname $out_path]
        if {$root eq ""} {
            set root $out_path
        }
        return [file normalize "${root}_render_source.tga"]
    }

    proc render_methods {} {
        if {[catch {render list} methods]} {
            return {}
        }
        return $methods
    }

    proc configure_scene {opts} {
        set width [expr {int([dict get $opts width])}]
        set height [expr {int([dict get $opts height])}]
        if {$width > 0 && $height > 0} {
            catch {display resize $width $height}
        }

        catch {display projection Orthographic}
        catch {axes location Off}
        catch {stage location Off}
        catch {color Display Background [dict get $opts background]}

        if {[truthy [dict get $opts shadows]]} {
            catch {display shadows on}
        } else {
            catch {display shadows off}
        }
        if {[truthy [dict get $opts ambient_occlusion]]} {
            catch {display ambientocclusion on}
        } else {
            catch {display ambientocclusion off}
        }
        set view_preset [string trim [dict get $opts view_preset]]
        set applied_view_preset current
        if {$view_preset ne "" && [string tolower $view_preset] ne "current"} {
            set applied_view_preset [::RMSXFlipbookTimeline::Style::apply_view_preset $view_preset]
        } elseif {[truthy [dict get $opts reset_view]]} {
            set applied_view_preset [::RMSXFlipbookTimeline::Style::apply_view_preset rmsx]
        } else {
            set applied_view_preset [::RMSXFlipbookTimeline::Style::apply_view_preset current]
        }
        if {[truthy [dict get $opts reset_view]] && $applied_view_preset eq "current"} {
            catch {display resetview}
            set applied_view_preset reset
        }
        if {[truthy [dict get $opts depthcue]]} {
            catch {display depthcue on}
        } else {
            catch {display depthcue off}
        }
        catch {display update}
        return $applied_view_preset
    }

    proc byte_value {data index} {
        binary scan [string index $data $index] c value
        return [expr {($value + 256) % 256}]
    }

    proc word_le {data index} {
        return [expr {[byte_value $data $index] | ([byte_value $data [expr {$index + 1}]] << 8)}]
    }

    proc parse_rgb_color {color_name} {
        set color [string tolower [string trim $color_name]]
        switch -- $color {
            white { return {255 255 255} }
            black { return {0 0 0} }
            gray -
            grey { return {128 128 128} }
            default {
                if {[regexp {^#([0-9a-f]{6})$} $color _ hex]} {
                    scan [string range $hex 0 1] %x r
                    scan [string range $hex 2 3] %x g
                    scan [string range $hex 4 5] %x b
                    return [list $r $g $b]
                }
            }
        }
        return {255 255 255}
    }

    proc color_matches_background {r g b background tolerance} {
        lassign $background br bg bb
        return [expr {abs($r - $br) <= $tolerance \
            && abs($g - $bg) <= $tolerance \
            && abs($b - $bb) <= $tolerance}]
    }

    proc pack_u32_be {value} {
        set v [expr {wide($value) & 0xffffffff}]
        return [binary format cccc \
            [expr {($v >> 24) & 255}] \
            [expr {($v >> 16) & 255}] \
            [expr {($v >> 8) & 255}] \
            [expr {$v & 255}]]
    }

    proc png_chunk {type data} {
        set payload "${type}${data}"
        set crc [zlib crc32 $payload]
        return "[pack_u32_be [string length $data]]${payload}[pack_u32_be $crc]"
    }

    proc write_png_rgba {path width height rgba_scanlines} {
        set ihdr "[pack_u32_be $width][pack_u32_be $height][binary format ccccc 8 6 0 0 0]"
        set png "\x89PNG\r\n\x1a\n"
        append png [png_chunk IHDR $ihdr]
        append png [png_chunk IDAT [zlib deflate $rgba_scanlines]]
        append png [png_chunk IEND ""]

        set fp [open $path w]
        fconfigure $fp -translation binary -encoding binary
        puts -nonewline $fp $png
        close $fp
    }

    proc convert_tga_to_png {tga_path png_path args} {
        set defaults [dict create \
            transparent_background 0 \
            background white \
            transparency_tolerance 2 \
            overwrite 1]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        if {[file exists $png_path] && ![truthy [dict get $opts overwrite]]} {
            error "PNG image already exists: $png_path"
        }

        set fp [open $tga_path r]
        fconfigure $fp -translation binary -encoding binary
        set data [read $fp]
        close $fp

        if {[string length $data] < 18} {
            error "TGA image is too short: $tga_path"
        }

        set id_len [byte_value $data 0]
        set cmap_type [byte_value $data 1]
        set image_type [byte_value $data 2]
        set width [word_le $data 12]
        set height [word_le $data 14]
        set depth [byte_value $data 16]
        set descriptor [byte_value $data 17]
        if {$cmap_type != 0} {
            error "Color-mapped TGA images are not supported for PNG conversion"
        }
        if {$image_type != 2} {
            error "Only uncompressed true-color TGA images are supported for PNG conversion"
        }
        if {$width <= 0 || $height <= 0} {
            error "TGA image has invalid dimensions: ${width}x${height}"
        }
        if {$depth ni {24 32}} {
            error "Only 24-bit and 32-bit TGA images are supported for PNG conversion"
        }

        set pixel_bytes [expr {$depth / 8}]
        set data_start [expr {18 + $id_len}]
        set expected [expr {$data_start + ($width * $height * $pixel_bytes)}]
        if {[string length $data] < $expected} {
            error "TGA image data is incomplete: $tga_path"
        }

        set top_origin [expr {($descriptor & 0x20) != 0}]
        set right_origin [expr {($descriptor & 0x10) != 0}]
        set transparent [truthy [dict get $opts transparent_background]]
        set background [parse_rgb_color [dict get $opts background]]
        set tolerance [expr {int([dict get $opts transparency_tolerance])}]
        set source_alpha_nonzero 0
        set source_alpha_not_255 0
        if {$pixel_bytes == 4} {
            for {set offset [expr {$data_start + 3}]} {$offset < $expected} {incr offset 4} {
                set alpha [byte_value $data $offset]
                if {$alpha != 0} {
                    incr source_alpha_nonzero
                }
                if {$alpha != 255} {
                    incr source_alpha_not_255
                }
            }
        }
        set use_source_alpha [expr {$pixel_bytes == 4 && $source_alpha_nonzero > 0 && !$transparent}]
        set scanlines ""

        for {set y 0} {$y < $height} {incr y} {
            set file_y [expr {$top_origin ? $y : ($height - 1 - $y)}]
            set row_start [expr {$data_start + ($file_y * $width * $pixel_bytes)}]
            set row_end [expr {$row_start + ($width * $pixel_bytes) - 1}]
            binary scan [string range $data $row_start $row_end] c* row_bytes
            set line [binary format c 0]
            for {set x 0} {$x < $width} {incr x} {
                set file_x [expr {$right_origin ? ($width - 1 - $x) : $x}]
                set index [expr {$file_x * $pixel_bytes}]
                set b [expr {([lindex $row_bytes $index] + 256) % 256}]
                set g [expr {([lindex $row_bytes [expr {$index + 1}]] + 256) % 256}]
                set r [expr {([lindex $row_bytes [expr {$index + 2}]] + 256) % 256}]
                if {$use_source_alpha} {
                    set a [expr {([lindex $row_bytes [expr {$index + 3}]] + 256) % 256}]
                } else {
                    set a 255
                }
                if {$transparent && [color_matches_background $r $g $b $background $tolerance]} {
                    set a 0
                }
                append line [binary format cccc $r $g $b $a]
            }
            append scanlines $line
        }

        write_png_rgba $png_path $width $height $scanlines
        return [dict create \
            image $png_path \
            width $width \
            height $height \
            transparent $transparent \
            source_alpha [expr {$pixel_bytes == 4}] \
            source_alpha_nonzero $source_alpha_nonzero \
            source_alpha_not_255 $source_alpha_not_255 \
            used_source_alpha $use_source_alpha]
    }

    proc convert_tga_with_sips {tga_path out_path format overwrite} {
        if {[file exists $out_path] && ![truthy $overwrite]} {
            error "Converted image already exists: $out_path"
        }
        set converter [auto_execok sips]
        if {$converter eq ""} {
            error "JPEG export needs macOS sips, but it was not found"
        }
        set sips_format [expr {$format eq "jpeg" ? "jpeg" : $format}]
        if {[catch {exec $converter -s format $sips_format $tga_path --out $out_path} result]} {
            error "sips conversion failed: $result"
        }
        return [dict create image $out_path converter $converter format $format]
    }

    proc render_current {args} {
        set defaults [dict create \
            output_name "" \
            method TachyonInternal \
            width 2000 \
            height 1000 \
            background white \
            shadows 1 \
            ambient_occlusion 1 \
            depthcue 0 \
            reset_view 0 \
            view_preset rmsx \
            overwrite 1 \
            transparent_background 0 \
            transparency_tolerance 2 \
            keep_source_tga 0 \
            dry_run 0]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set molids [::RMSXFlipbookTimeline::state_get molids {}]
        if {[llength $molids] == 0} {
            error "No RMSX flipbook molecules are loaded"
        }

        set folder [::RMSXFlipbookTimeline::state_get source_folder ""]
        if {$folder eq ""} {
            set folder [pwd]
        }
        set palette [::RMSXFlipbookTimeline::state_get palette viridis]
        set out_path [default_output_path $folder $palette [dict get $opts output_name]]
        set format [image_format_for_path $out_path]
        set render_path [render_source_path $out_path $format]
        set out_dir [file dirname $out_path]
        if {![file isdirectory $out_dir]} {
            file mkdir $out_dir
        }
        set render_dir [file dirname $render_path]
        if {![file isdirectory $render_dir]} {
            file mkdir $render_dir
        }
        if {[file exists $out_path] && ![truthy [dict get $opts overwrite]]} {
            error "Rendered image already exists: $out_path"
        }

        set method [string trim [dict get $opts method]]
        if {$method eq ""} {
            set method TachyonInternal
        }
        set methods [render_methods]
        if {[llength $methods] > 0 && [lsearch -exact $methods $method] == -1} {
            error "VMD render method '$method' is not available. Available methods: [join $methods {, }]"
        }

        set applied_view_preset [configure_scene $opts]
        set command [list render $method $render_path]
        if {[truthy [dict get $opts dry_run]]} {
            return [dict create \
                image $out_path \
                render_image $render_path \
                format $format \
                method $method \
                command $command \
                view_preset $applied_view_preset \
                rendered 0 \
                dry_run 1 \
                exists [file exists $out_path] \
                bytes [expr {[file exists $out_path] ? [file size $out_path] : 0}] \
                converted 0 \
                transparent_background [expr {[truthy [dict get $opts transparent_background]] && $format eq "png"}] \
                molecules [llength $molids] \
                folder [file normalize $folder]]
        }

        if {[file exists $render_path]} {
            file delete $render_path
        }
        if {$format ne "tga" && [file exists $out_path]} {
            file delete $out_path
        }
        puts [format {RMSX Flipbook Timeline: rendering %d molecules to %s with %s} [llength $molids] $render_path $method]
        render $method $render_path

        set render_exists [file exists $render_path]
        set render_bytes [expr {$render_exists ? [file size $render_path] : 0}]
        if {!$render_exists || $render_bytes <= 0} {
            error "Render command completed but no source image was written: $render_path"
        }

        set converted 0
        set conversion {}
        if {$format eq "png"} {
            set conversion [convert_tga_to_png \
                $render_path \
                $out_path \
                transparent_background [dict get $opts transparent_background] \
                background [dict get $opts background] \
                transparency_tolerance [dict get $opts transparency_tolerance] \
                overwrite [dict get $opts overwrite]]
            set converted 1
        } elseif {$format eq "jpeg"} {
            set conversion [convert_tga_with_sips \
                $render_path \
                $out_path \
                jpeg \
                [dict get $opts overwrite]]
            set converted 1
        }

        if {$format ne "tga" && ![truthy [dict get $opts keep_source_tga]]} {
            catch {file delete $render_path}
        }

        set exists [file exists $out_path]
        set bytes [expr {$exists ? [file size $out_path] : 0}]
        if {!$exists || $bytes <= 0} {
            error "Render command completed but no final image was written: $out_path"
        }

        return [dict create \
            image $out_path \
            render_image $render_path \
            format $format \
            method $method \
            command $command \
            view_preset $applied_view_preset \
            rendered 1 \
            dry_run 0 \
            exists $exists \
            bytes $bytes \
            source_bytes $render_bytes \
            converted $converted \
            conversion $conversion \
            transparent_background [expr {[truthy [dict get $opts transparent_background]] && $format eq "png"}] \
            molecules [llength $molids] \
            folder [file normalize $folder]]
    }
}
