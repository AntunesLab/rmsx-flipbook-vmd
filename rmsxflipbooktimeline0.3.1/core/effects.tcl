# Scoped, reverse-order ownership. No VMD dependency at package load.
namespace eval ::RMSXFlipbookTimeline::Effects {
    variable actions {}
    variable order {}
    proc register {key script {scope result} {once 0}} {
        variable actions; variable order
        if {![dict exists $actions $key]} {lappend order $key}
        dict set actions $key [dict create script $script scope $scope once $once]
        return $key
    }
    proc unregister {key} {
        variable actions; variable order
        dict unset actions $key
        set i [lsearch -exact $order $key]
        if {$i >= 0} {set order [lreplace $order $i $i]}
        return 1
    }
    proc cleanup_all {{scopes {operation result window input scene}}} {
        variable actions; variable order
        set errors {}
        foreach key [lreverse $order] {
            if {![dict exists $actions $key]} {continue}
            set action [dict get $actions $key]
            if {[lsearch -exact $scopes [dict get $action scope]] < 0} {continue}
            if {[catch {uplevel #0 [dict get $action script]} message options]} {
                lappend errors [dict create resource $key scope [dict get $action scope] message $message]
            } elseif {[dict get $action once]} {unregister $key}
        }
        if {[llength $errors]} {return -code error -errorcode {RMSXFLIPBOOK CLEANUP} $errors}
        return 1
    }
}
# Scene leases survive closing the panel. Remove releases them. Only change a
# property that can be read; restore it only if it still has our last value.
namespace eval ::RMSXFlipbookTimeline::Scene {
    variable leases {}
    variable properties [dict create \
        projection {{display get projection} {display projection}} \
        size {{display get size} {display resize}} \
        depthcue {{display get depthcue} {display depthcue}} \
        shadows {{display get shadows} {display shadows}} \
        ambientocclusion {{display get ambientocclusion} {display ambientocclusion}} \
        axes {{axes location} {axes location}} \
        stage {{stage location} {stage location}} \
        background {{colorinfo category Display Background} {color Display Background}} \
        palette {{colorinfo scale method} {color scale method}}]
    proc read {key} {
        variable properties
        return [uplevel #0 [lindex [dict get $properties $key] 0]]
    }
    proc write {key value} {
        variable properties
        set command [lindex [dict get $properties $key] 1]
        if {$key eq "size"} {lappend command {*}$value} else {lappend command $value}
        return [uplevel #0 $command]
    }
    proc apply {key value} {
        variable leases
        if {[catch {read $key} before]} {return 0}
        if {![dict exists $leases $key]} {dict set leases $key [dict create before $before last $before]}
        write $key $value
        dict set leases $key last [read $key]
        return 1
    }
    proc apply_environment {key value} {
        variable leases
        set tag "env:$key"
        if {![dict exists $leases $tag]} {
            set exists [info exists ::env($key)]
            dict set leases $tag [dict create before [expr {$exists ? $::env($key) : ""}] existed $exists last $value]
        }
        set ::env($key) $value
        dict set leases $tag last $value
        dict set leases $tag last_existed 1
    }
    proc unset_environment {key} {
        variable leases
        set tag "env:$key"
        if {![dict exists $leases $tag]} {
            set exists [info exists ::env($key)]
            dict set leases $tag [dict create before [expr {$exists ? $::env($key) : ""}] existed $exists last ""]
        }
        unset -nocomplain ::env($key)
        dict set leases $tag last_existed 0
    }
    proc release_environment {names} {
        variable leases
        foreach name $names {
            set tag "env:$name"
            if {![dict exists $leases $tag]} {continue}
            set item [dict get $leases $tag]
            set last_existed [expr {[dict exists $item last_existed] ? [dict get $item last_existed] : 1}]
            if {[info exists ::env($name)] == $last_existed && (!$last_existed || $::env($name) eq [dict get $item last])} {
                if {[dict get $item existed]} {set ::env($name) [dict get $item before]} else {unset -nocomplain ::env($name)}
            }
            dict unset leases $tag
        }
    }
    proc restore {} {
        variable leases
        set errors {}
        foreach key [dict keys $leases] {
            set item [dict get $leases $key]
            if {[string match env:* $key]} {
                set name [string range $key 4 end]
                release_environment [list $name]
                continue
            } elseif {![catch {read $key} current] && $current eq [dict get $item last]} {
                if {[catch {write $key [dict get $item before]} message]} {lappend errors "$key: $message"; continue}
            }
            dict unset leases $key
        }
        if {[llength $errors]} {error [join $errors {; }]}
        return 1
    }
    proc snapshot {} {
        variable properties; variable leases
        set values {}
        foreach key [dict keys $properties] {if {![catch {read $key} value]} {dict set values $key $value}}
        set result [dict create values $values leases $leases environment {} views {} visibility {}]
        foreach name {VMDMODULATERIBBON VMDMODULATENEWTUBE VMDMODULATENEWCARTOON} {
            dict set result environment $name [list [info exists ::env($name)] [expr {[info exists ::env($name)] ? $::env($name) : ""}]]
        }
        if {[info commands molinfo] ne ""} {
            catch {dict set result top [molinfo top]}
            set ids [molinfo list]
            if {[info commands ::RMSXFlipbookTimeline::Style::capture_view_matrices] ne ""} {
                dict set result views [::RMSXFlipbookTimeline::Style::capture_view_matrices $ids]
            }
            foreach id $ids {if {![catch {molinfo $id get drawn} drawn]} {dict set result visibility $id $drawn}}
        }
        return $result
    }
    proc restore_snapshot {snapshot} {
        variable leases
        set errors {}
        dict for {key value} [dict get $snapshot values] {
            if {[catch {write $key $value} message]} {lappend errors "$key: $message"}
        }
        foreach item [dict get $snapshot views] {
            foreach key {center_matrix global_matrix scale_matrix rotate_matrix} {
                if {[catch {::RMSXFlipbookTimeline::Style::set_molecule_matrix [dict get $item molid] $key $item} message]} {lappend errors $message}
            }
        }
        if {[info commands molinfo] ne ""} {
            dict for {id drawn} [dict get $snapshot visibility] {
                if {[lsearch -exact [molinfo list] $id] >= 0} {catch {molinfo $id set drawn $drawn}}
            }
            if {[dict exists $snapshot top] && [lsearch -exact [molinfo list] [dict get $snapshot top]] >= 0} {catch {mol top [dict get $snapshot top]}}
        }
        dict for {name pair} [dict get $snapshot environment] {
            if {[lindex $pair 0]} {set ::env($name) [lindex $pair 1]} else {catch {unset ::env($name)}}
        }
        set leases [dict get $snapshot leases]
        if {[llength $errors]} {error [join $errors {; }]}
        return 1
    }
}
