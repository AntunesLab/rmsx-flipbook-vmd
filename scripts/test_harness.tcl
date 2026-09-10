# Each invocation runs in a disposable working directory created by run_tests.py.
package require Tcl 8.6
fconfigure stdout -encoding utf-8
fconfigure stderr -encoding utf-8
namespace eval ::TestHarness {
    variable finished 0
    variable runtime_environment {}
    proc collect_environment {} {
        set environment [dict create os $::tcl_platform(os) os_version $::tcl_platform(osVersion) \
            machine $::tcl_platform(machine) tcl [info patchlevel] tk unavailable \
            vmd unavailable vmd_arch unavailable executable [info nameofexecutable] \
            graphics_mode headless windowing unavailable display_width unavailable display_height unavailable \
            graphics_driver unknown]
        if {[info commands vmdinfo] ne ""} {
            dict set environment vmd [vmdinfo version]
            dict set environment vmd_arch [vmdinfo arch]
        }
        if {[package provide Tk] ne ""} {dict set environment tk [package provide Tk]}
        if {$::env(RMSX_TEST_GUI) eq "1" && [info commands winfo] ne "" && [winfo exists .]} {
            dict set environment graphics_mode gui
            dict set environment windowing [tk windowingsystem]
            if {![catch {display get size} size] && [llength $size] == 2} {
                dict set environment display_width [lindex $size 0]
                dict set environment display_height [lindex $size 1]
            }
        }
        return $environment
    }
    proc json_string {value} {
        set mapping [list \\ \\\\ \" \\\" \n \\n \r \\r \t \\t]
        for {set code 0} {$code < 32} {incr code} {
            if {$code ni {9 10 13}} {lappend mapping [format %c $code] [format {\u%04x} $code]}
        }
        return \"[string map $mapping $value]\"
    }
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
        variable runtime_environment
        if {$finished} { return }
        set finished 1
        if {$runtime_environment eq {}} {set runtime_environment [collect_environment]}
        set fields {}
        dict for {key value} $runtime_environment {lappend fields "[json_string $key]:[json_string $value]"}
        set fp [open "$::env(RMSX_TEST_RESULT).environment.json" w]
        fconfigure $fp -encoding utf-8 -translation lf
        puts $fp [format {{"schema":1,"status":%s,"environment":{%s}}} [json_string $status] [join $fields ,]]
        close $fp
        set fp [open $::env(RMSX_TEST_RESULT) w]
        fconfigure $fp -encoding utf-8 -translation lf
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
    set ::TestHarness::runtime_environment [::TestHarness::collect_environment]
    source -encoding utf-8 $::env(RMSX_TEST_SCRIPT)
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
