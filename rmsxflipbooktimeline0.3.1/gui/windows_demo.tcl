# Windows VMD may read modulation from its C runtime's startup environment,
# independently of Tcl's later env writes. Start an explicitly requested demo
# in a new process; never restart, terminate or rewrite the original session.
namespace eval ::RMSXFlipbookTimeline::Reviewer::Windows {
    variable ready 0
    variable pending {}
    variable poll_id ""
    variable message "Windows: residue thickness needs a fresh VMD session."
    if {$::tcl_platform(platform) eq "windows" &&
        [info exists ::env(RMSX_REVIEWER_THICKNESS_BUILD)] &&
        $::env(RMSX_REVIEWER_THICKNESS_BUILD) eq [::RMSXFlipbookTimeline::build_id]} {
        set ready 1
        foreach key {VMDMODULATERIBBON VMDMODULATENEWTUBE VMDMODULATENEWCARTOON} {
            if {![info exists ::env($key)] || $::env($key) ne "user"} {set ready 0}
        }
    }
    proc needed {} {variable ready; return [expr {$::tcl_platform(platform) eq "windows" && !$ready}]}
    proc mount {header} {
        variable pending; variable poll_id
        if {![needed] || [winfo exists $header.windows]} {return}
        ttk::frame $header.windows
        ttk::button $header.windows.open -text "Open fresh VMD" -style RMSX.TButton \
            -command ::RMSXFlipbookTimeline::Reviewer::Windows::open_demo
        ttk::label $header.windows.note -textvariable ::RMSXFlipbookTimeline::Reviewer::Windows::message \
            -font TkSmallCaptionFont -wraplength 400 -justify left
        grid $header.windows.open -row 0 -column 0 -sticky w -padx {0 6}
        grid $header.windows.note -row 0 -column 1 -sticky ew
        grid columnconfigure $header.windows 1 -weight 1
        grid $header.windows -row 3 -column 0 -columnspan 2 -sticky ew -pady {4 0}
        if {$pending ne {} && $poll_id eq ""} {set poll_id [after 200 [namespace current]::poll]}
    }
    proc detach {} {
        variable poll_id
        if {$poll_id ne ""} {after cancel $poll_id; set poll_id ""}
    }
    proc spawn {executable startup identity} {
        set command [file join $::env(SystemRoot) System32 cmd.exe]
        if {![file isfile $command] || ![file isfile $executable] || ![file isfile $startup]} {
            error "Cannot locate Windows command processor, VMD, or demo startup file"
        }
        set launch_dir [file dirname $startup]
        set batch [file join $launch_dir rmsx-launch.cmd]
        set body {@echo off
start "RMSX / Flipbook" "%RMSX_REVIEWER_VMD%" -dispdev win -startup "%RMSX_REVIEWER_RC%" -e "%RMSX_REVIEWER_SCRIPT%"
}
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write $batch [list ::RMSXFlipbookTimeline::Reviewer::write_text $body]
        set previous_dir [pwd]
        set previous {}
        set settings [dict create RMSX_REVIEWER_VMD $executable RMSX_REVIEWER_SCRIPT $startup \
            RMSX_REVIEWER_RC [file join [file dirname $startup] empty.vmdrc] \
            RMSX_REVIEWER_THICKNESS_BUILD $identity VMDMODULATERIBBON user \
            VMDMODULATENEWTUBE user VMDMODULATENEWCARTOON user]
        dict for {key value} $settings {
            dict set previous $key [list [info exists ::env($key)] [expr {[info exists ::env($key)] ? $::env($key) : ""}]]
            set ::env($key) $value
        }
        try {
            # Tcl's Windows exec quotes arguments for the C runtime; cmd has
            # different quote rules. Keep its command argument a fixed ASCII
            # basename, and keep all variable paths in the child environment.
            # No Tk events run during this brief, restored directory change.
            cd $launch_dir
            exec -- $command /d /v:off /c rmsx-launch.cmd
        } finally {
            cd $previous_dir
            dict for {key saved} $previous {
                if {[lindex $saved 0]} {set ::env($key) [lindex $saved 1]} else {unset -nocomplain ::env($key)}
            }
        }
    }
    proc write_startup {package_dir workspace identity example path} {
        set script "# Generated RMSX demo launcher; paths are Tcl list elements.\n"
        # Keep the -e file ASCII even when a Windows profile contains Unicode;
        # every maintained source file is subsequently sourced as UTF-8.
        set encoded [binary encode base64 -maxlen 0 [encoding convertto utf-8 [list $package_dir $workspace $identity $example]]]
        append script [format {set ::RMSX_REVIEW_CHILD_CONFIG [encoding convertfrom utf-8 [binary decode base64 %s]]} $encoded] "\n"
        append script {
set code [catch {
    lassign $::RMSX_REVIEW_CHILD_CONFIG package_dir workspace identity example
    source -encoding utf-8 [file join $package_dir pkgIndex.tcl]
    package require -exact rmsxflipbooktimeline [string trim [read [set fp [open [file join $package_dir VERSION] r]]]]
    close $fp
    if {[::RMSXFlipbookTimeline::build_id] ne $identity} {error "Reviewer build changed; reopen the downloaded file"}
    source -encoding utf-8 [file join $package_dir gui reviewer.tcl]
    if {!$::RMSXFlipbookTimeline::Reviewer::Windows::ready} {error "Windows thickness startup settings were not inherited"}
    ::RMSXFlipbookTimeline::Reviewer::launch $workspace $identity $example
    after 100 [list ::RMSXFlipbookTimeline::Reviewer::Windows::child_ready $workspace $identity]
} message options]
if {$code} {
    set fp [open [file join [lindex $::RMSX_REVIEW_CHILD_CONFIG 1] startup-result.tcldict] w]
    fconfigure $fp -encoding utf-8
    puts $fp [dict create status FAIL detail $message pid [pid]]
    close $fp
    puts stderr "RMSX fresh-session startup failed: $message"
}
}
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write $path [list ::RMSXFlipbookTimeline::Reviewer::write_text $script]
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write [file join $workspace empty.vmdrc] [list ::RMSXFlipbookTimeline::Reviewer::write_text {# Isolated reviewer session; original profile is unchanged.}]
    }
    proc child_ready {workspace identity} {
        if {[::RMSXFlipbookTimeline::Operation::running]} {after 100 [list [namespace current]::child_ready $workspace $identity]; return}
        set current [::RMSXFlipbookTimeline::Results::get]
        set status [expr {$current ne {} && [dict exists $current reviewer_preview] ? "READY" : "FAIL"}]
        set record [dict create status $status build $identity pid [pid] detail $::RMSXFlipbookTimeline::Dashboard::status_text]
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write [file join $workspace startup-result.tcldict] \
            [list ::RMSXFlipbookTimeline::Reviewer::write_text $record]
    }
    proc open_demo {} {
        variable pending; variable message; variable poll_id
        if {![needed] || $pending ne {} || [::RMSXFlipbookTimeline::Operation::running]} {return}
        set workspace ""
        set spawned 0
        try {
            set fp [file tempfile workspace rmsx-windows-demo-]
            close $fp
            file delete $workspace
            file mkdir $workspace
            set owner [open [file join $workspace OWNER.tcldict] w]
            puts $owner [dict create owner RMSXWindowsDemo build $::RMSXFlipbookTimeline::Reviewer::build pid [pid]]
            close $owner
            file copy [file join $::RMSXFlipbookTimeline::Reviewer::workspace fixtures] [file join $workspace fixtures]
            set startup [file join $workspace start.tcl]
            write_startup $::RMSXFlipbookTimeline::basedir $workspace \
                $::RMSXFlipbookTimeline::Reviewer::build $::RMSXFlipbookTimeline::Reviewer::example $startup
            set spawned 1
            spawn [info nameofexecutable] $startup $::RMSXFlipbookTimeline::Reviewer::build
            set pending [dict create workspace $workspace started [clock milliseconds]]
            set message "Opening thickness-enabled VMD; this session stays open."
            set poll_id [after 200 [namespace current]::poll]
        } on error {failure options} {
            if {!$spawned && $workspace ne "" && [file exists $workspace]} {catch {file delete -force $workspace}}
            set message "Could not open fresh VMD: $failure"
            ::RMSXFlipbookTimeline::Dashboard::set_status $message
        }
    }
    proc poll {} {
        variable pending; variable poll_id; variable message
        set poll_id ""
        if {$pending eq {}} {return}
        set path [file join [dict get $pending workspace] startup-result.tcldict]
        if {[file isfile $path]} {
            if {[catch {
                set fp [open $path r]; fconfigure $fp -encoding utf-8
                try {set receipt [read $fp]} finally {close $fp}
                if {[dict get $receipt status] ne "READY" || [dict get $receipt build] ne $::RMSXFlipbookTimeline::Reviewer::build} {error [dict get $receipt detail]}
                set message "Thickness-enabled demo is open in a separate VMD session."
            } failure]} {set message "Fresh VMD startup failed: $failure"}
            set pending {}
        } elseif {[clock milliseconds]-[dict get $pending started] > 30000} {
            set message "VMD has not confirmed startup. Check its new window; original session retained."
            set pending {}
        } else {set poll_id [after 200 [namespace current]::poll]}
    }
}
