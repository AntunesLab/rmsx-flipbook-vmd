################################################################################
# RMSX Flipbook Timeline mask transparency
################################################################################

namespace eval ::RMSXFlipbookTimeline::Mask {
    proc truthy {value} {
        set lowered [string tolower [string trim $value]]
        return [expr {$lowered eq "1" || $lowered eq "true" || $lowered eq "yes" || $lowered eq "y" || $lowered eq "on"}]
    }

    proc load_mask_clauses {mask_file} {
        if {$mask_file eq "" || ![file exists $mask_file]} {
            return [dict create clauses {} count 0]
        }

        array unset chain_residues
        set count 0
        set fp [open $mask_file r]
        gets $fp header

        while {[gets $fp line] >= 0} {
            set trimmed [string trim $line]
            if {$trimmed eq ""} {
                continue
            }

            set fields [split $trimmed ","]
            if {[llength $fields] < 3} {
                continue
            }

            set residue_id [string trim [lindex $fields 0]]
            set chain_id [string trim [lindex $fields 1]]
            set masked_flag [string trim [lindex $fields 2]]

            if {$residue_id eq "" || ![truthy $masked_flag]} {
                continue
            }

            if {[info exists chain_residues($chain_id)]} {
                lappend chain_residues($chain_id) $residue_id
            } else {
                set chain_residues($chain_id) [list $residue_id]
            }
            incr count
        }
        close $fp

        set clauses {}
        foreach chain_id [lsort [array names chain_residues]] {
            set residue_ids [lsort -integer -unique $chain_residues($chain_id)]
            if {[llength $residue_ids] == 0} {
                continue
            }

            set residue_clause [join $residue_ids " "]
            if {$chain_id eq ""} {
                lappend clauses "resid $residue_clause"
            } else {
                lappend clauses "((chain $chain_id and resid $residue_clause) or (segid $chain_id and resid $residue_clause))"
            }
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
        catch {display depthsort on}
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

        set mask_data [load_mask_clauses $mask_file]
        set clauses [dict get $mask_data clauses]
        set masked_count [dict get $mask_data count]

        if {[llength $clauses] == 0} {
            puts "RMSX Flipbook Timeline: mask file has no masked residues"
            return [dict create masked_residues 0 reps_added 0]
        }

        set mask_selection [join $clauses " or "]
        set material [dict get $opts material]
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
