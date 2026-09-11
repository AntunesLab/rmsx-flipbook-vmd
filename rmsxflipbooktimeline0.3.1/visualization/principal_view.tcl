# Display-only principal axes. Raw trajectories, metrics and saved calculations
# are never aligned by this module; only owned flipbook copies are positioned.
namespace eval ::RMSXFlipbookTimeline::PrincipalView {
    proc axes {points {reference {}}} {
        set count [llength $points]
        if {!$count} {error "No atoms for principal-axis orientation"}
        set center {0.0 0.0 0.0}
        foreach p $points {for {set i 0} {$i<3} {incr i} {lset center $i [expr {[lindex $center $i]+[lindex $p $i]/double($count)}]}}
        set a {{0.0 0.0 0.0} {0.0 0.0 0.0} {0.0 0.0 0.0}}
        foreach p $points {
            for {set i 0} {$i<3} {incr i} {
                for {set j 0} {$j<3} {incr j} {
                    lset a $i $j [expr {[lindex $a $i $j]+([lindex $p $i]-[lindex $center $i])*([lindex $p $j]-[lindex $center $j])/double($count)}]
                }
            }
        }
        set v {{1.0 0.0 0.0} {0.0 1.0 0.0} {0.0 0.0 1.0}}
        # Symmetric 3x3 Jacobi eigensolver; largest covariance eigenvalue is
        # the longest geometric axis. Eigenvectors are columns of v.
        for {set iteration 0} {$iteration<40} {incr iteration} {
            set p 0;set q 1;set largest 0.0
            foreach {i j} {0 1 0 2 1 2} {if {abs([lindex $a $i $j])>$largest} {set p $i;set q $j;set largest [expr {abs([lindex $a $i $j])}]}}
            set scale [expr {max(1.0,abs([lindex $a 0 0])+abs([lindex $a 1 1])+abs([lindex $a 2 2]))}]
            if {$largest < 1e-12*$scale} {break}
            set app [lindex $a $p $p];set aqq [lindex $a $q $q];set apq [lindex $a $p $q]
            set angle [expr {0.5*atan2(2.0*$apq,$aqq-$app)}]
            set c [expr {cos($angle)}];set s [expr {sin($angle)}]
            for {set k 0} {$k<3} {incr k} {
                if {$k!=$p && $k!=$q} {
                    set akp [lindex $a $k $p];set akq [lindex $a $k $q]
                    set np [expr {$c*$akp-$s*$akq}];set nq [expr {$s*$akp+$c*$akq}]
                    lset a $k $p $np;lset a $p $k $np;lset a $k $q $nq;lset a $q $k $nq
                }
                set vkp [lindex $v $k $p];set vkq [lindex $v $k $q]
                lset v $k $p [expr {$c*$vkp-$s*$vkq}];lset v $k $q [expr {$s*$vkp+$c*$vkq}]
            }
            lset a $p $p [expr {$c*$c*$app-2*$s*$c*$apq+$s*$s*$aqq}]
            lset a $q $q [expr {$s*$s*$app+2*$s*$c*$apq+$c*$c*$aqq}]
            lset a $p $q 0.0;lset a $q $p 0.0
        }
        set pairs {}
        for {set i 0} {$i<3} {incr i} {lappend pairs [list [lindex $a $i $i] [list [lindex $v 0 $i] [lindex $v 1 $i] [lindex $v 2 $i]]]}
        set pairs [lsort -decreasing -real -index 0 $pairs]
        set basis {};set index 0
        foreach pair $pairs {
            set axis [lindex $pair 1];set dot 0.0
            if {$reference ne {}} {
                foreach x $axis y [lindex $reference $index] {set dot [expr {$dot+$x*$y}]}
            } else {
                set largest 0.0
                foreach x $axis {if {abs($x)>$largest} {set largest [expr {abs($x)}];set dot $x}}
            }
            if {$dot<0} {set axis [lmap x $axis {expr {-$x}}]}
            lappend basis $axis;incr index
        }
        # Longest axis points along screen Y; second axis spans screen X.
        set x [lindex $basis 1];set y [lindex $basis 0]
        set z [list [expr {[lindex $x 1]*[lindex $y 2]-[lindex $x 2]*[lindex $y 1]}] \
            [expr {[lindex $x 2]*[lindex $y 0]-[lindex $x 0]*[lindex $y 2]}] \
            [expr {[lindex $x 0]*[lindex $y 1]-[lindex $x 1]*[lindex $y 0]}]]
        return [dict create center $center axes $basis eigenvalues [lmap p $pairs {lindex $p 0}] \
            matrix [list [concat $x 0.0] [concat $y 0.0] [concat $z 0.0] {0.0 0.0 0.0 1.0}]]
    }
    proc padding {} {
        set factor 1.0
        if {[::RMSXFlipbookTimeline::state_get rep] in {NewCartoon NewRibbons Ribbon}} {set factor 7.0}
        return [expr {max(1.0,$factor*abs([::RMSXFlipbookTimeline::state_get thick 0.3])*10.0*max(1.0,[::RMSXFlipbookTimeline::state_get aspect 1.0]))}]
    }
    proc arrange {ids spacing {offsets {}}} {
        ::RMSXFlipbookTimeline::Layout::undo_offsets $ids $offsets
        set result {};set index 0;set count [llength $ids]
        foreach id $ids {
            set selection [atomselect $id all]
            try {
                lassign [measure center $selection] x y z
                set offset [list [expr {($index-0.5*($count-1))*$spacing-$x}] [expr {-$y}] [expr {-$z}]]
                $selection moveby $offset;lappend result $offset;incr index
            } finally {$selection delete}
        }
        return $result
    }
    proc fit {ids} {
        if {![llength $ids]} {return}
        lassign [display get size] width height
        if {$width<=0 || $height<=0} {return}
        # VMD OpenGLRenderer's orthographic extents are +/-0.25*display height.
        set full_height [expr {0.5*[display get height]}]
        set full_width [expr {$full_height*$width/double($height)}]
        set bounds [::RMSXFlipbookTimeline::Render::center_projected $ids]
        set maxscale 0.0
        foreach id $ids {
            set matrix [::RMSXFlipbookTimeline::Style::normalize_matrix [molinfo $id get scale_matrix]]
            set maxscale [expr {max($maxscale,abs([lindex $matrix 0 0]),abs([lindex $matrix 1 1]),abs([lindex $matrix 2 2]))}]
        }
        set pad [expr {[padding]*$maxscale}]
        set factor [expr {min(0.9*$full_width/([dict get $bounds width]+2*$pad),0.9*$full_height/([dict get $bounds height]+2*$pad))}]
        ::RMSXFlipbookTimeline::Render::scale_projected $ids $factor
        ::RMSXFlipbookTimeline::state_set principal_fit_size [list $width $height]
        return [dict create factor $factor display_size [list $width $height]]
    }
    proc apply {} {
        set ids [::RMSXFlipbookTimeline::state_get molids {}]
        if {![llength $ids]} {return {}}
        # A flick can leave VMD spinning between events. A newly requested
        # default/reset view must settle, without changing the mouse mode or
        # disabling the user's ability to spin the result again afterward.
        if {[info commands mouse] ne ""} {mouse stoprotation}
        ::RMSXFlipbookTimeline::Layout::undo_offsets $ids [::RMSXFlipbookTimeline::state_get layout_offsets {}]
        set reference {};set orientations {};set maxwidth 0.0
        foreach id $ids {
            ::RMSXFlipbookTimeline::Operation::checkpoint [dict create stage loading \
                current [llength $orientations] total [llength $ids] \
                message "Orienting slice [expr {[llength $orientations]+1}] of [llength $ids]…"]
            set selection [atomselect $id {(protein and name CA) or (nucleic and name P)}]
            try {
                if {[$selection num]<3} {$selection delete;set selection [atomselect $id all]}
                set axis [axes [$selection get {x y z}] $reference]
                if {$reference eq {}} {set reference [dict get $axis axes]}
            } finally {$selection delete}
            set selection [atomselect $id all]
            try {
                set center [measure center $selection]
                $selection moveby [vecscale -1 $center]
                $selection move [dict get $axis matrix]
                $selection moveby $center
                lassign [measure minmax $selection] lo hi
                set maxwidth [expr {max($maxwidth,[lindex $hi 0]-[lindex $lo 0])}]
            } finally {$selection delete}
            lappend orientations [dict create molid $id eigenvalues [dict get $axis eigenvalues]]
            foreach key {center_matrix rotate_matrix scale_matrix global_matrix} {
                ::RMSXFlipbookTimeline::Style::set_molecule_matrix $id $key [dict create $key [transidentity]]
            }
        }
        set spacing [expr {$maxwidth*1.08+2*[padding]}]
        if {[::RMSXFlipbookTimeline::state_get spacing_mode auto] eq "manual"} {set spacing [::RMSXFlipbookTimeline::state_get spacing $spacing]}
        ::RMSXFlipbookTimeline::state_set layout_offsets [arrange $ids $spacing]
        ::RMSXFlipbookTimeline::state_set spacing $spacing
        ::RMSXFlipbookTimeline::state_set view_preset principal
        ::RMSXFlipbookTimeline::state_set principal_axis_orientation [dict create method geometric_covariance longest_axis screen_y secondary_axis screen_x scope whole_slice orientations $orientations]
        ::RMSXFlipbookTimeline::Scene::apply projection Orthographic
        fit $ids
        ::RMSXFlipbookTimeline::Style::center_row_top_molecule
        display update
        return $ids
    }
}
