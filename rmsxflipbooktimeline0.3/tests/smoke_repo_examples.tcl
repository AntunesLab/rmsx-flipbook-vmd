################################################################################
# RMSX Flipbook Timeline repo example smoke test
#
# Runs representative precomputed examples from downloads/rmsx/AntunesLab-rmsx.
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline repo example smoke failed: $message"
    exit 1
}

set plugin_parent $::env(RMSX_TEST_REPO)
if {![file isdirectory [file join $plugin_parent rmsxflipbooktimeline0.3]]} {
    smoke_fail "plugin directory not found under $plugin_parent"
}
lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.3} err]} {
    smoke_fail "package require failed: $err"
}

set examples {
    {fixtures/upstream/rmsx_demo_outputs/protease/combined viridis 9 0}
    {fixtures/upstream/rmsx_demo_outputs/protease_mask_example/combined magma 9 1}
    {fixtures/upstream/rmsx_demo_outputs/mask_multi_chain/combined turbo 9 1}
}

foreach example $examples {
    lassign $example folder palette expected_files expect_mask
    if {![file isdirectory $folder]} {
        smoke_fail "example folder missing: $folder"
    }

    puts "RMSX Flipbook Timeline repo example: $folder"
    if {[catch {::RMSXFlipbookTimeline::load_folder $folder palette $palette write_manifest 1} result]} {
        smoke_fail "load failed for $folder: $result"
    }

    if {[dict get $result files] != $expected_files} {
        smoke_fail "expected $expected_files files for $folder, got [dict get $result files]"
    }
    if {[dict get $result molecules] != $expected_files} {
        smoke_fail "expected $expected_files molecules for $folder, got [dict get $result molecules]"
    }
    if {$expect_mask && [dict get $result masked_residues] <= 0} {
        smoke_fail "expected masked residues for $folder"
    }
    if {![file exists [dict get $result manifest]]} {
        smoke_fail "manifest missing for $folder"
    }

    puts "RMSX Flipbook Timeline repo example passed: $folder"
}

puts "RMSX Flipbook Timeline repo examples smoke passed"
quit
