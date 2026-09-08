################################################################################
# Side-effect cleanup registry.
################################################################################

namespace eval ::RMSXFlipbookTimeline::Effects {
    variable cleanup_actions
    array set cleanup_actions {}

    proc register {key script} {
        variable cleanup_actions
        set cleanup_actions($key) $script
        return $key
    }

    proc unregister {key} {
        variable cleanup_actions
        catch {unset cleanup_actions($key)}
        return 1
    }

    proc cleanup_all {} {
        variable cleanup_actions
        set errors {}
        foreach key [lsort [array names cleanup_actions]] {
            set script $cleanup_actions($key)
            if {[catch {uplevel #0 $script} err]} {
                lappend errors "$key: $err"
            }
        }
        if {[llength $errors] > 0} {
            error "Cleanup had errors: [join $errors {; }]"
        }
        return 1
    }
}
