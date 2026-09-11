################################################################################
# RMSX Flipbook Timeline scene rendering
################################################################################

namespace eval ::RMSXFlipbookTimeline::Render {
    variable active 0
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
            ::RMSXFlipbookTimeline::Scene::resize_display $width $height
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
        append png [png_chunk IDAT [zlib compress $rgba_scanlines]]
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

    proc data_value {record key default} {
        if {[dict exists $record $key]} {return [dict get $record $key]}
        return $default
    }
    proc capabilities {} {
        set methods [render_methods]
        return [dict create methods $methods png [expr {[lsearch -exact $methods TachyonInternal] >= 0}] \
            jpeg [expr {[auto_execok sips] ne ""}] figure [expr {[lsearch -exact $methods TachyonInternal] >= 0}]]
    }
    proc result_molids {} {
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current ne {}} {set ids [data_value $current molids {}]} else {set ids [::RMSXFlipbookTimeline::state_get molids {}]}
        set available {}
        foreach id $ids {if {[lsearch -exact [molinfo list] $id] >= 0} {lappend available $id}}
        if {![llength $available]} {error "The current result has no available 3D structures"}
        if {[llength $available] != [llength $ids]} {error "Some structures from the current result were deleted. Reload the saved result before 3D export; its matrix remains available."}
        return $available
    }
    proc projected_bounds {ids} {
        set first 1; set centers {}
        foreach id $ids {
            set transform [transidentity]
            foreach key {global_matrix scale_matrix rotate_matrix center_matrix} {
                set transform [transmult $transform [::RMSXFlipbookTimeline::Style::normalize_matrix [molinfo $id get $key]]]
            }
            set selection [atomselect $id all]
            try {
                set local_first 1
                foreach xyz [$selection get {x y z}] {
                    lassign [coordtrans $transform $xyz] x y z
                    if {$first} {set xmin $x; set xmax $x; set ymin $y; set ymax $y; set first 0}
                    set xmin [expr {min($xmin,$x)}]; set xmax [expr {max($xmax,$x)}]
                    set ymin [expr {min($ymin,$y)}]; set ymax [expr {max($ymax,$y)}]
                    if {$local_first} {set lx0 $x; set lx1 $x; set ly0 $y; set ly1 $y; set local_first 0}
                    set lx0 [expr {min($lx0,$x)}]; set lx1 [expr {max($lx1,$x)}]
                    set ly0 [expr {min($ly0,$y)}]; set ly1 [expr {max($ly1,$y)}]
                }
                if {!$local_first} {lappend centers [list [expr {($lx0+$lx1)/2.0}] [expr {($ly0+$ly1)/2.0}]]}
            } finally {$selection delete}
        }
        if {$first} {error "No atoms to frame"}
        return [dict create xmin $xmin xmax $xmax ymin $ymin ymax $ymax centers $centers \
            width [expr {max(0.001,$xmax-$xmin)}] height [expr {max(0.001,$ymax-$ymin)}]]
    }
    proc center_projected {ids} {
        set bounds [projected_bounds $ids]
        set dx [expr {-([dict get $bounds xmin]+[dict get $bounds xmax])/2.0}]
        set dy [expr {-([dict get $bounds ymin]+[dict get $bounds ymax])/2.0}]
        foreach id $ids {
            set matrix [::RMSXFlipbookTimeline::Style::normalize_matrix [molinfo $id get global_matrix]]
            set transformed [transmult [transoffset [list $dx $dy 0.0]] $matrix]
            ::RMSXFlipbookTimeline::Style::set_molecule_matrix $id global_matrix [dict create global_matrix $transformed]
        }
        return [projected_bounds $ids]
    }
    proc scale_projected {ids factor} {
        foreach id $ids {
            set matrix [::RMSXFlipbookTimeline::Style::normalize_matrix [molinfo $id get scale_matrix]]
            set transformed [transmult [list [list $factor 0 0 0] [list 0 $factor 0 0] [list 0 0 $factor 0] {0 0 0 1}] $matrix]
            ::RMSXFlipbookTimeline::Style::set_molecule_matrix $id scale_matrix [dict create scale_matrix $transformed]
            # VMD's global_matrix setter accepts translation, not scaling.
            # Scale those translations too, so in-place rotation pivots and
            # inter-slice spacing follow the same scene-wide fit as the atoms.
            set global [::RMSXFlipbookTimeline::Style::normalize_matrix [molinfo $id get global_matrix]]
            for {set axis 0} {$axis < 3} {incr axis} {
                lset global $axis 3 [expr {$factor*[lindex $global $axis 3]}]
            }
            ::RMSXFlipbookTimeline::Style::set_molecule_matrix $id global_matrix [dict create global_matrix $global]
        }
        center_projected $ids
    }
    proc tga_content_bounds {path {background white}} {
        set fp [open $path rb]
        try {set data [read $fp]} finally {close $fp}
        if {[string length $data] < 18 || [byte_value $data 2] != 2} {error "Expected an uncompressed true-color TGA render"}
        set width [word_le $data 12]; set height [word_le $data 14]
        set channels [expr {[byte_value $data 16]/8}]
        if {$channels ni {3 4} || $width < 1 || $height < 1} {error "Unsupported TGA dimensions or pixel format"}
        set start [expr {18+[byte_value $data 0]}]
        if {[string length $data] < $start+$width*$height*$channels} {error "Truncated TGA render"}
        lassign [parse_rgb_color $background] br bg bb
        set x0 $width; set x1 -1; set y0 $height; set y1 -1; set pixels 0
        set top_origin [expr {([byte_value $data 17]&32)!=0}]
        set stride [expr {max(1,int($width/900))}]
        for {set y 0} {$y < $height} {incr y $stride} {
            set file_y [expr {$top_origin ? $y : $height-1-$y}]
            for {set x 0} {$x < $width} {incr x $stride} {
                set offset [expr {$start+($file_y*$width+$x)*$channels}]
                binary scan [string range $data $offset [expr {$offset+2}]] cu3 pixel
                lassign $pixel b g r
                if {abs($r-$br)>3 || abs($g-$bg)>3 || abs($b-$bb)>3} {
                    set x0 [expr {min($x0,$x)}]; set x1 [expr {max($x1,$x)}]
                    set y0 [expr {min($y0,$y)}]; set y1 [expr {max($y1,$y)}]
                    incr pixels
                }
            }
        }
        if {$pixels < 4} {error "Renderer produced a blank image; use a verified windowed VMD renderer"}
        return [dict create width $width height $height x0 $x0 x1 $x1 y0 $y0 y1 $y1 nonbackground_samples $pixels]
    }
    proc render_to_tga {options path width height} {
        ::RMSXFlipbookTimeline::Scene::resize_display $width $height
        display update
        render [dict get $options method] $path
        if {![file isfile $path]} {error "VMD renderer did not create an image"}
        return [tga_content_bounds $path [dict get $options background]]
    }
    proc verify_residue_thickness {molid directory {checkpoint ""}} {
        set snapshot [::RMSXFlipbookTimeline::Scene::snapshot]
        set selection [atomselect $molid all]
        set original [$selection get user]
        set representation [lindex [molinfo $molid get {{representation 0}}] 0]
        set pixels {}
        try {
            foreach id [molinfo list] {mol off $id}
            mol on $molid
            mol top $molid
            display resetview
            display projection Orthographic
            color Display Background white
            axes location Off
            stage location Off
            foreach value {1 8} {
                if {$checkpoint ne ""} {uplevel #0 [list {*}$checkpoint [dict create stage writing message "Checking residue thickness ($value)…"]]}
                $selection set user $value
                mol modstyle 0 $molid {*}$representation
                set path [file join $directory thickness-$value.tga]
                set image [render_to_tga [dict create method TachyonInternal background white] $path 600 500]
                convert_tga_to_png $path [file rootname $path].png
                lappend pixels [dict get $image nonbackground_samples]
            }
            lassign $pixels low high
            if {$high < 1.5*$low} {
                error "Native residue thickness did not respond to user=1 versus user=8 ($pixels pixels). On Windows, use Open fresh VMD to enable thickness before startup."
            }
            return [dict create low_pixels $low high_pixels $high representation $representation]
        } finally {
            $selection set user $original
            $selection delete
            mol modstyle 0 $molid {*}$representation
            ::RMSXFlipbookTimeline::Scene::restore_snapshot $snapshot
        }
    }
    proc render_payload {options ids path} {
        set snapshot [::RMSXFlipbookTimeline::Scene::snapshot]
        set state_before [::RMSXFlipbookTimeline::state_dict]
        set tga "${path}.tga"; set proof "${path}.proof.tga"
        variable active
        incr active
        try {
            foreach id [molinfo list] {molinfo $id set drawn [expr {[lsearch -exact $ids $id] >= 0}]}
            ::RMSXFlipbookTimeline::state_set molids $ids
            foreach {key value} [list axes Off stage Off background [dict get $options background] \
                shadows [expr {[dict get $options shadows] ? "on" : "off"}] \
                ambientocclusion [expr {[dict get $options ambient_occlusion] ? "on" : "off"}] depthcue off] {
                ::RMSXFlipbookTimeline::Scene::apply $key $value
            }
            if {[dict get $options framing] eq "fit"} {::RMSXFlipbookTimeline::Scene::apply projection Orthographic}
            set preset [dict get $options view_preset]
            if {$preset ne "current"} {::RMSXFlipbookTimeline::Style::apply_view_preset $preset}
            set bounds [projected_bounds $ids]
            set width [dict get $options width]; set height [dict get $options height]
            if {$height eq "auto"} {
                if {[dict get $options framing] eq "current" && [dict exists $snapshot values size]} {
                    lassign [dict get $snapshot values size] old_width old_height
                    set height [expr {max(160,int(round($width*double($old_height)/max(1,$old_width))))}]
                } else {set height [expr {max(160,int(ceil($width*[dict get $bounds height]/[dict get $bounds width])))}]}
            }
            if {$height > 8192} {set width [expr {max(160,int($width*8192.0/$height))}]; set height 8192}
            if {[dict get $options framing] eq "fit"} {
                set bounds [center_projected $ids]
                # Fit with the final aspect ratio. A height-only minimum makes
                # wide flipbooks shrink when the proof is scaled to the export.
                set proof_scale [expr {min(1.0,max(min(640,$width)/double($width),min(80,$height)/double($height)))}]
                set proof_width [expr {max(1,int(round($width*$proof_scale)))}]
                set proof_height [expr {max(1,int(round($height*$proof_scale)))}]
                for {set attempt 0} {$attempt < 2} {incr attempt} {
                    set pixels [render_to_tga $options $proof $proof_width $proof_height]
                    set content_width [expr {[dict get $pixels x1]-[dict get $pixels x0]+1.0}]
                    set content_height [expr {[dict get $pixels y1]-[dict get $pixels y0]+1.0}]
                    set factor [expr {min(0.90*$proof_width/$content_width,0.90*$proof_height/$content_height)}]
                    scale_projected $ids $factor
                    # A newly loaded result can begin only a few pixels tall.
                    # Refine once after enlarging it, instead of preserving
                    # that initial silhouette's large quantization error.
                    if {$content_width >= 200 && $content_height >= 20} {break}
                }
                set bounds [projected_bounds $ids]
            }
            set pixels [render_to_tga $options $tga $width $height]
            if {[dict get $options framing] eq "fit" && ([dict get $pixels x0] < 2 || [dict get $pixels y0] < 2 || [dict get $pixels x1] >= $width-2 || [dict get $pixels y1] >= $height-2)} {
                error "Rendered structures touch the image edge; select Current view or adjust the view before exporting"
            }
            set format [dict get $options format]
            if {$format eq "png"} {
                convert_tga_to_png $tga $path transparent_background [dict get $options transparent_background] \
                    background [dict get $options background] transparency_tolerance [dict get $options transparency_tolerance] overwrite 1
            } elseif {$format eq "jpeg"} {
                convert_tga_with_sips $tga $path jpeg 1
            } else {file copy -force $tga $path}
            return [dict create image $path format $format width $width height $height method [dict get $options method] \
                framing [dict get $options framing] view_preset $preset projected_bounds $bounds pixel_bounds $pixels \
                rendered 1 exists 1 bytes [file size $path] molecules [llength $ids] \
                converted [expr {$format ne "tga"}] transparent_background [expr {$format eq "png" && [dict get $options transparent_background]}]]
        } finally {
            try {
                catch {file delete $tga}; catch {file delete $proof}
                ::RMSXFlipbookTimeline::state_replace $state_before
                ::RMSXFlipbookTimeline::Scene::restore_snapshot $snapshot
            } finally {incr active -1}
        }
    }
    proc render_current {args} {
        set defaults [dict create output_name "" method TachyonInternal width 2400 height auto background white \
            shadows 1 ambient_occlusion 1 depthcue 0 reset_view 0 view_preset current framing fit overwrite 0 \
            transparent_background 0 transparency_tolerance 2 keep_source_tga 0 dry_run 0]
        set options [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]
        if {[dict get $options framing] ni {fit current}} {error "Framing must be fit or current"}
        set width [dict get $options width]; set height [dict get $options height]
        if {![string is integer -strict $width] || $width < 64 || $width > 8192} {error "Image width must be between 64 and 8192 pixels"}
        if {$height ne "auto" && (![string is integer -strict $height] || $height < 64 || $height > 8192)} {error "Image height must be auto or between 64 and 8192 pixels"}
        if {[truthy [dict get $options reset_view]] && [dict get $options view_preset] eq "current"} {dict set options view_preset rmsx}
        set ids [result_molids]
        set result [::RMSXFlipbookTimeline::Results::get]
        set folder [data_value $result folder [::RMSXFlipbookTimeline::state_get source_folder [pwd]]]
        set path [default_output_path $folder [::RMSXFlipbookTimeline::state_get palette viridis] [dict get $options output_name]]
        dict set options format [image_format_for_path $path]
        if {[file exists $path] && ![dict get $options overwrite]} {error "Image exists; choose a new name or explicitly enable overwrite: $path"}
        if {[lsearch -exact [render_methods] [dict get $options method]] < 0} {error "Renderer [dict get $options method] is unavailable in this VMD build"}
        if {[dict get $options dry_run]} {return [dict create image $path format [dict get $options format] rendered 0 dry_run 1 molecules [llength $ids] view_preset [dict get $options view_preset] transparent_background [dict get $options transparent_background] render_image [render_source_path $path [dict get $options format]] method [dict get $options method] command [list render [dict get $options method] $path] options $options]}
        set result [::RMSXFlipbookTimeline::OutputTxn::atomic_write $path [list ::RMSXFlipbookTimeline::Render::render_payload $options $ids]]
        return [dict merge $result [dict create folder $folder dry_run 0 render_image $path]]
    }
    proc xml {text} {return [::RMSXFlipbookTimeline::NativeAnalysis::xml_escape $text]}
    proc legend_color {fraction palette} {
        if {[info commands colorinfo] ne "" && ![catch {
            set first [colorinfo num]
            set last [expr {[colorinfo max]-1}]
            set index [expr {$first+int(round($fraction*($last-$first)))}]
            lassign [colorinfo rgb $index] r g b
            set rgb [format {#%02x%02x%02x} [expr {int(round(255*$r))}] [expr {int(round(255*$g))}] [expr {int(round(255*$b))}]]
        }]} {return $rgb}
        return [::RMSXFlipbookTimeline::NativeAnalysis::heatmap_color $fraction 0.0 1.0 $palette]
    }
    proc figure_svg {image_result result png filename} {
        set fp [open $png rb]
        try {set encoded [binary encode base64 -maxlen 0 [read $fp]]} finally {close $fp}
        set width [dict get $image_result width]; set height [dict get $image_result height]
        set scale [expr {min(1.0,1200.0/$width)}]
        set w [expr {int(ceil($width*$scale))}]; set h [expr {int(ceil($height*$scale))}]
        set margin 32; set top 80
        set dataset [data_value $result dataset {}]
        set metric [data_value $result metric [data_value $dataset value_label RMSX]]
        if {[string tolower $metric] in {lddt lddt_map 1-lddt}} {set metric 1-lDDT}
        set units [data_value $result units [data_value $dataset unit ""]]
        if {$metric eq "1-lDDT"} {set units unitless}
        if {$units eq ""} {set units {units not recorded}}
        set title [data_value $result label "RMSX / Flipbook"]
        set settings [data_value $result display_settings [::RMSXFlipbookTimeline::display_record]]
        set palette [data_value $settings palette viridis]
        # VMD's active palette is global; read it to describe the rendered image.
        catch {set palette [colorinfo scale method]}
        set lo [data_value $settings color_min 0.0]; set hi [data_value $settings color_max 10.0]
        set ids [data_value $result molids {}]
        if {[llength $ids]} {
            catch {
                set actual_range [mol scaleminmax [lindex $ids 0] 0]
                if {[llength $actual_range] == 2 && [string is double -strict [lindex $actual_range 0]] && [string is double -strict [lindex $actual_range 1]]} {lassign $actual_range lo hi}
                dict set settings color_method [lindex [lindex [molinfo [lindex $ids 0] get [list [list color 0]]] 0] 0]
            }
        }
        set norm_lo [data_value $settings norm_min 0.0]; set norm_hi [data_value $settings norm_max 10.0]
        if {[data_value $settings color_method User2] eq "User2"} {
            set raw_lo [data_value $settings raw_min 0.0]; set raw_hi [data_value $settings raw_max 1.0]
            if {$norm_hi > $norm_lo} {
                set range [expr {$raw_hi-$raw_lo}]
                set lo [expr {$raw_lo+($lo-$norm_lo)/($norm_hi-$norm_lo)*$range}]
                set hi [expr {$raw_lo+($hi-$norm_lo)/($norm_hi-$norm_lo)*$range}]
            } else {set lo $raw_lo; set hi $raw_hi}
        }
        set labels {}; set columns [data_value $dataset columns {}]
        set n [dict get $image_result molecules]
        for {set i 0} {$i < $n} {incr i} {
            set label "Slice [expr {$i+1}]"
            set detail ""
            if {$i < [llength $columns]} {
                set column [lindex $columns $i]
                if {[dict exists $column time] && [dict exists $column time_unit]} {
                    set detail "[dict get $column time] [dict get $column time_unit]"
                } elseif {[dict exists $column frame_start] && [dict exists $column frame_end]} {
                    set detail "frames [dict get $column frame_start]–[dict get $column frame_end]"
                } elseif {[dict exists $column frame]} {set detail "frame [dict get $column frame]"}
            }
            lappend labels [list $label $detail]
        }
        set label_cols [expr {max(1,min($n,int($w/130)))}]
        set label_rows [expr {int(ceil(double($n)/$label_cols))}]
        set legend_y [expr {$top+$h+36+$label_rows*40}]
        set canvas_h [expr {$legend_y+100}]
        set fp [open $filename w]
        fconfigure $fp -encoding utf-8 -translation lf
        try {
            puts $fp [format {<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%d" height="%d" viewBox="0 0 %d %d">} [expr {$w+2*$margin}] $canvas_h [expr {$w+2*$margin}] $canvas_h]
            puts $fp {<rect width="100%" height="100%" fill="white"/>}
            puts $fp [format {<text x="32" y="30" font-family="sans-serif" font-size="20" font-weight="600">%s</text>} [xml $title]]
            puts $fp [format {<text x="32" y="55" font-family="sans-serif" font-size="14">%s · %s · %d slices</text>} [xml $metric] [xml $units] $n]
            puts $fp [format {<image x="32" y="%d" width="%d" height="%d" xlink:href="data:image/png;base64,%s"/>} $top $w $h $encoded]
            set i 0
            foreach item $labels {
                lassign $item label detail
                set x [expr {$margin+($i%$label_cols)*double($w)/$label_cols}]
                set y [expr {$top+$h+24+int($i/$label_cols)*40}]
                puts $fp [format {<text x="%.2f" y="%d" font-family="sans-serif" font-size="12">%s</text>} $x $y [xml $label]]
                if {$detail ne ""} {
                    puts $fp [format {<text x="%.2f" y="%d" font-family="sans-serif" font-size="12">%s</text>} $x [expr {$y+16}] [xml $detail]]
                }
                incr i
            }
            for {set i 0} {$i < 100} {incr i} {
                set value [expr {$lo+($hi-$lo)*$i/99.0}]
                set color [legend_color [expr {$i/99.0}] $palette]
                puts $fp [format {<rect x="%.2f" y="%d" width="%.2f" height="14" fill="%s"/>} [expr {$margin+$i*$w/100.0}] $legend_y [expr {$w/100.0+0.1}] $color]
            }
            puts $fp [format {<text x="32" y="%d" font-family="sans-serif" font-size="12">%.4g %s</text>} [expr {$legend_y+32}] $lo [xml $units]]
            puts $fp [format {<text x="%d" y="%d" text-anchor="end" font-family="sans-serif" font-size="12">%.4g %s</text>} [expr {$w+$margin}] [expr {$legend_y+32}] $hi [xml $units]]
            puts $fp [format {<text x="32" y="%d" font-family="sans-serif" font-size="11">%s</text>} [expr {$legend_y+58}] [xml "[expr {[data_value $result masked_residues 0] > 0 ? {Masked residues: translucent. } : {}}]RMSX/Flipbook $::RMSXFlipbookTimeline::version"]]
            puts $fp "<metadata>[xml [dict create method $metric units $units result $result render $image_result]]</metadata>"
            puts $fp {</svg>}
        } finally {close $fp}
    }
    proc write_figure {filename args} {
        set options [::RMSXFlipbookTimeline::parse_kv_options [dict create overwrite 0 width 2400 view_preset current framing fit] {*}$args]
        set base [file rootname [file normalize $filename]]
        set png "${base}.png"; set svg "${base}.svg"
        foreach path [list $png $svg] {
            if {[file exists $path] && ![file isfile $path]} {error "Figure destination is not a file: $path"}
            if {![catch {file type $path} type] && $type eq "link"} {error "Figure destination cannot be a symbolic link: $path"}
            if {[file exists $path] && ![dict get $options overwrite]} {error "Figure output exists: $path"}
        }
        file mkdir [file dirname $base]
        set stage "${base}.figure-[pid]-[clock clicks]"
        file mkdir $stage
        set installed {}; set backups {}; set cleanup_stage 1
        try {
            set image [render_current -output_name [file join $stage figure.png] -width [dict get $options width] \
                -view_preset [dict get $options view_preset] -framing [dict get $options framing]]
            figure_svg $image [::RMSXFlipbookTimeline::Results::get] [file join $stage figure.png] [file join $stage figure.svg]
            foreach from [list [file join $stage figure.png] [file join $stage figure.svg]] to [list $png $svg] {
                if {[file exists $to]} {set backup [file join $stage "old-[file tail $to]"]; file rename $to $backup; dict set backups $to $backup}
                file rename $from $to
                lappend installed $to
            }
            return [dict create png $png svg $svg image $png width [dict get $image width] height [dict get $image height]]
        } on error {message error_options} {
            foreach path $installed {catch {file delete $path}}
            dict for {to backup} $backups {
                if {[file exists $backup] && [catch {file rename $backup $to} restore_error]} {
                    set cleanup_stage 0
                    append message "\nPrevious file preserved at $backup; restoration failed: $restore_error"
                }
            }
            return -options $error_options $message
        } finally {if {$cleanup_stage} {file delete -force $stage}}
    }

}
