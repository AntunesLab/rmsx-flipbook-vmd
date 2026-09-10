# Shared launcher: normal dashboard or the same portable reviewer runtime.
if {$::env(RMSX_LAUNCH_DEMO) ne ""} {
    set ::RMSX_REVIEWER_START_LIBRARY_ONLY 1
    try {source -encoding utf-8 [file join $::env(RMSX_LAUNCH_REPO) scripts reviewer_start.tcl]} finally {unset ::RMSX_REVIEWER_START_LIBRARY_ONLY}
    ::RMSXReviewerStart::start $::env(RMSX_LAUNCH_REPO) $::env(RMSX_LAUNCH_WORK) $::env(RMSX_LAUNCH_DEMO)
} else {
    lappend auto_path $::env(RMSX_LAUNCH_REPO)
    source -encoding utf-8 [file join $::env(RMSX_LAUNCH_PACKAGE) register.tcl]
    rmsxflipbooktimeline
}
