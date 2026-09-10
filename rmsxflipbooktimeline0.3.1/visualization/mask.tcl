################################################################################
# RMSX Flipbook Timeline mask transparency
################################################################################

namespace eval ::RMSXFlipbookTimeline::Mask {
    proc truthy {value} {
        set lowered [string tolower [string trim $value]]
        return [expr {$lowered eq "1" || $lowered eq "true" || $lowered eq "yes" || $lowered eq "y" || $lowered eq "on"}]
    }

    proc load_mask_clauses {mask_file {molid ""}} {
        if {$mask_file eq "" || ![file exists $mask_file]} {return [dict create clauses {} count 0]}
        set clauses {}; set count 0
        foreach record [::RMSXFlipbookTimeline::NativeAnalysis::read_mask_metadata_file $mask_file] {
            if {![dict get $record masked]} {continue}
            lappend clauses "([::RMSXFlipbookTimeline::ResidueIdentity::selection $record $molid])"
            incr count
        }
        return [dict create clauses $clauses count $count]
    }

    proc configure_material {material opacity} {
        catch {material change opacity $material $opacity}
        catch {material change ambient $material 0.35}
        catch {material change diffuse $material 0.55}
        catch {material change specular $material 0.05}
        catch {material change shininess $material 0.03}
        catch {material change mirror $material 0.00}
        # Do not change depth sorting: VMD does not expose a portable getter.
    }

    variable owned_materials {}
    proc owned_material {opacity} {
        variable owned_materials
        if {![string is double -strict $opacity] || $opacity < 0 || $opacity > 1} {error "Mask opacity must be between 0 and 1"}
        set key [format %.4f $opacity]
        if {[dict exists $owned_materials $key] && [lsearch -exact [material list] [dict get $owned_materials $key]] >= 0} {return [dict get $owned_materials $key]}
        set base [format "RMSXFlipbook_Mask_%04d" [expr {int(round($opacity*1000))}]]
        set name $base; set index 0
        while {[lsearch -exact [material list] $name] >= 0} {set name "${base}_[incr index]"}
        material add $name copy Transparent
        dict set owned_materials $key $name
        ::RMSXFlipbookTimeline::Effects::register "material:$name" [list material delete $name] scene 1
        return $name
    }

    proc apply {molids mask_file args} {
        set defaults [dict create \
            opacity 0.30 \
            material Transparent \
            color_min 0.0 \
            color_max 10.0 \
            marker 1 \
            marker_style {VDW 0.45 12} \
            marker_color 4 \
            marker_material AOChalky]
        set opts [::RMSXFlipbookTimeline::parse_kv_options $defaults {*}$args]

        set mask_data [load_mask_clauses $mask_file [lindex $molids 0]]
        set clauses [dict get $mask_data clauses]
        set masked_count [dict get $mask_data count]

        if {[llength $clauses] == 0} {
            puts "RMSX Flipbook Timeline: mask file has no masked residues"
            return [dict create masked_residues 0 reps_added 0]
        }

        set mask_selection [join $clauses " or "]
        set material [owned_material [dict get $opts opacity]]
        configure_material $material [dict get $opts opacity]

        set transparent_reps_added 0
        set marker_reps_added 0
        set marker_enabled [truthy [dict get $opts marker]]
        foreach molid $molids {
            if {[lsearch -exact [molinfo list] $molid] == -1} {
                continue
            }
            if {[molinfo $molid get numreps] < 1} {
                continue
            }

            set local_mask [load_mask_clauses $mask_file $molid]
            set mask_selection [join [dict get $local_mask clauses] " or "]
            set current_style [molinfo $molid get "{representation 0}"]
            set current_selection [molinfo $molid get "{selection 0}"]
            set current_color [molinfo $molid get "{color 0}"]

            mol modselect 0 $molid "($current_selection) and not ($mask_selection)"
            mol addrep $molid
            set repid [expr {[molinfo $molid get numreps] - 1}]

            mol modselect $repid $molid "($current_selection) and ($mask_selection)"
            eval "mol modstyle $repid $molid $current_style"
            mol modcolor $repid $molid $current_color
            mol scaleminmax $molid $repid [dict get $opts color_min] [dict get $opts color_max]
            mol modmaterial $repid $molid $material
            incr transparent_reps_added

            if {$marker_enabled} {
                mol addrep $molid
                set marker_repid [expr {[molinfo $molid get numreps] - 1}]
                mol modselect $marker_repid $molid "($current_selection) and ($mask_selection)"
                if {[catch {
                    mol modstyle $marker_repid $molid {*}[dict get $opts marker_style]
                }]} {
                    catch {mol modstyle $marker_repid $molid VDW 0.45 12}
                }
                mol modcolor $marker_repid $molid ColorID [dict get $opts marker_color]
                catch {mol modmaterial $marker_repid $molid [dict get $opts marker_material]}
                catch {mol selupdate $marker_repid $molid off}
                incr marker_reps_added
            }
        }

        set reps_added [expr {$transparent_reps_added + $marker_reps_added}]
        puts [format {RMSX Flipbook Timeline: applied mask transparency to %d residues across %d molecules; marker reps=%d} \
            $masked_count [llength $molids] $marker_reps_added]
        return [dict create \
            masked_residues $masked_count \
            reps_added $reps_added \
            transparent_reps_added $transparent_reps_added \
            marker_reps_added $marker_reps_added]
    }
}
