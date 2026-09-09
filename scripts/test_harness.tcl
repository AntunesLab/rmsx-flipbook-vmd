# Each invocation runs in a disposable working directory created by run_tests.py.
package require Tcl 8.6
namespace eval ::TestHarness {
    variable finished 0
    # Numerical baseline files predate full residue identity. Project by header
    # only for legacy numerical assertions; identity_v2 tests validate the full
    # schema and reject collisions separately.
    proc legacy_numeric_rows {rows} {
        if {[lrange [lindex $rows 0] 0 4] ne {ResidueID ChainID SegID InsertionCode ResidueOrdinal}} {
            return $rows
        }
        set projected [list [concat {ResidueID ChainID} [lrange [lindex $rows 0] 5 end]]]
        foreach row [lrange $rows 1 end] {
            set chain [lindex $row 1]
            if {$chain eq "" || $chain eq "X"} { set chain [lindex $row 2] }
            lappend projected [concat [list [lindex $row 0] $chain] [lrange $row 5 end]]
        }
        return $projected
    }
    proc finish {status {detail ""}} {
        variable finished
        if {$finished} { return }
        set finished 1
        set fp [open $::env(RMSX_TEST_RESULT) w]
        puts $fp $status
        puts $fp [dict create detail $detail tcl [info patchlevel] \
            vmd [expr {[info commands vmdinfo] ne "" ? [vmdinfo version] : "none"}]]
        close $fp
        puts "RMSX_TEST_RESULT $status $detail"
        flush stdout
    }
}
rename exit ::TestHarness::native_exit
proc exit {{code 0}} {
    ::TestHarness::finish [expr {$code == 0 ? "PASS" : "FAIL"}] "exit $code"
    ::TestHarness::native_exit $code
}
if {[info commands quit] ne ""} {
    rename quit ::TestHarness::native_quit
    proc quit {} {
        ::TestHarness::finish PASS
        ::TestHarness::native_quit
    }
} else {
    proc quit {} { exit 0 }
}
proc bgerror {message} {
    ::TestHarness::finish FAIL $message
    exit 1
}
set argv [split $::env(RMSX_TEST_ARGS) \n]
if {$::env(RMSX_TEST_ARGS) eq ""} { set argv {} }
set argc [llength $argv]
if {[catch {
    cd $::env(RMSX_TEST_WORKDIR)
    if {$::env(RMSX_TEST_GUI) eq "1"} {
        package require Tk 8.6
        if {![winfo exists .]} { error "A real Tk display is required" }
    }
    source $::env(RMSX_TEST_SCRIPT)
} message options]} {
    ::TestHarness::finish FAIL "$message\n[dict get $options -errorinfo]"
    if {[info commands ::TestHarness::native_quit] ne ""} {
        ::TestHarness::native_quit
    } else { ::TestHarness::native_exit 1 }
} else {
    # Scripts using `after ... quit` need the event loop before final reporting.
    if {$::env(RMSX_TEST_ASYNC) eq "1"} {
        # Only the test may signal completion. The Python deadline fails hangs.
        vwait ::TestHarness::finished
    } else {
        ::TestHarness::finish PASS
        if {[info commands ::TestHarness::native_quit] ne ""} {
            ::TestHarness::native_quit
        } else { ::TestHarness::native_exit 0 }
    }
}
