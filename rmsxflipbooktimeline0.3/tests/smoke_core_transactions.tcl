set package_dir [file dirname [file dirname [file normalize [info script]]]]
lappend auto_path $package_dir
package require rmsxflipbooktimeline 0.3
proc assert {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc write_text {path text} {set f [open $path w]; try {puts -nonewline $f $text} finally {close $f}}
proc read_text {path} {set f [open $path r]; try {return [read $f]} finally {close $f}}
proc writer_ok {text path} {write_text $path $text; return $path}
proc writer_fail {path} {write_text $path partial; error "injected writer failure"}
set temporary_channel [file tempfile root]
close $temporary_channel
file delete $root
set root [file normalize $root]
file mkdir $root
try {
    set target [file join $root result]
    set txn [::RMSXFlipbookTimeline::OutputTxn::begin $target]
    write_text [file join [dict get $txn stage] data.csv] original
    ::RMSXFlipbookTimeline::OutputTxn::commit $txn
    assert {[::RMSXFlipbookTimeline::OutputTxn::verify_owned $target] ne ""} "Published result lacks ownership"
    assert {[catch {::RMSXFlipbookTimeline::OutputTxn::begin $target}]} "Occupied target accepted without overwrite"

    set txn [::RMSXFlipbookTimeline::OutputTxn::begin $target -overwrite 1]
    write_text [file join [dict get $txn stage] data.csv] partial
    ::RMSXFlipbookTimeline::OutputTxn::abort $txn
    assert {[read_text [file join $target data.csv]] eq "original"} "Abort changed previous bytes"
    assert {![file exists [dict get $txn stage]]} "Abort leaked staging directory"

    # Inject a publication failure after the previous result has been moved aside.
    set txn [::RMSXFlipbookTimeline::OutputTxn::begin $target -overwrite 1]
    write_text [file join [dict get $txn stage] data.csv] replacement
    set ::fail_stage [dict get $txn stage]
    rename ::file ::real_file
    proc ::file {args} {
        if {[lindex $args 0] eq "rename" && [lindex $args 1] eq $::fail_stage} {error "injected rename failure"}
        return [::real_file {*}$args]
    }
    try {
        assert {[catch {::RMSXFlipbookTimeline::OutputTxn::commit $txn}]} "Injected publication failure did not fail"
    } finally {rename ::file {}; rename ::real_file ::file; unset ::fail_stage}
    ::RMSXFlipbookTimeline::OutputTxn::abort $txn
    assert {[read_text [file join $target data.csv]] eq "original"} "Failed commit did not restore previous bytes"

    set txn [::RMSXFlipbookTimeline::OutputTxn::begin $target -overwrite 1]
    write_text [file join [dict get $txn stage] data.csv] replacement
    ::RMSXFlipbookTimeline::OutputTxn::commit $txn
    assert {[read_text [file join $target data.csv]] eq "replacement"} "Commit did not publish replacement"
    assert {[read_text [file join [dict get $txn backup] data.csv]] eq "original"} "Commit did not preserve previous result backup"

    write_text [file join $target user-notes.txt] private
    assert {[catch {::RMSXFlipbookTimeline::OutputTxn::begin $target -overwrite 1}]} "Added user file was accepted for replacement"
    assert {[read_text [file join $target user-notes.txt]] eq "private"} "Ownership check changed added user file"
    set legacy [file join $root legacy]
    file mkdir [file join $legacy chain_notes]
    write_text [file join $legacy .rmsx_output_dir] managed_by=rmsx
    assert {[catch {::RMSXFlipbookTimeline::OutputTxn::begin $legacy -overwrite 1}]} "Legacy directory shape falsely proved ownership"

    set dest [file join $root exported.svg]
    write_text $dest original-export
    assert {[catch {::RMSXFlipbookTimeline::OutputTxn::atomic_write $dest writer_fail}]} "Failing writer reported success"
    assert {[read_text $dest] eq "original-export"} "Failed export replaced original"
    assert {[::RMSXFlipbookTimeline::OutputTxn::atomic_write $dest [list writer_ok complete-export]] eq $dest} "Atomic writer returned temporary path"
    assert {[read_text $dest] eq "complete-export"} "Atomic writer failed"
    set directory_dest [file join $root directory-export]
    file mkdir $directory_dest
    write_text [file join $directory_dest keep.txt] keep
    assert {[catch {::RMSXFlipbookTimeline::OutputTxn::atomic_write $directory_dest [list writer_ok bad]}]} "Directory export destination accepted"
    assert {[read_text [file join $directory_dest keep.txt]] eq "keep"} "Directory export destination was changed"
    if {$::tcl_platform(platform) eq "unix"} {
        set link [file join $root linked-export]
        file link -symbolic $link $dest
        assert {[catch {::RMSXFlipbookTimeline::OutputTxn::atomic_write $link [list writer_ok bad]}]} "Symlink export destination accepted"
        assert {[read_text $dest] eq "complete-export"} "Symlink export changed its target"
    }

    # An all-chain transaction can legitimately modify sealed children during
    # global masking; publication reseals them and rewrites nested provenance.
    set outer [::RMSXFlipbookTimeline::OutputTxn::begin [file join $root combined]]
    set child_target [file join [dict get $outer stage] chain_A]
    set child [::RMSXFlipbookTimeline::OutputTxn::begin $child_target]
    write_text [file join [dict get $child stage] data.csv] before-mask
    ::RMSXFlipbookTimeline::OutputTxn::commit $child [dict create csv [file join $child_target data.csv]]
    write_text [file join $child_target data.csv] after-mask
    ::RMSXFlipbookTimeline::OutputTxn::commit $outer
    set final_child [file join [dict get $outer target] chain_A]
    set metadata [::RMSXFlipbookTimeline::OutputTxn::verify_owned $final_child]
    assert {[dict get $metadata csv] eq [file join $final_child data.csv]} "Nested provenance retained a staging path"
    assert {[read_text [file join $final_child data.csv]] eq "after-mask"} "Combined publication lost global mask changes"

    set input [file join $root input.pdb]
    write_text $input input
    proc cancelled_kernel {top trajectory directory args} {
        write_text [file join $directory partial.csv] incomplete
        return -code error -errorcode {RMSXFLIPBOOK CANCELLED} "cancel requested"
    }
    set cancelled_target [file join $root cancelled]
    assert {[catch {::RMSXFlipbookTimeline::NativeAnalysis::transactional_run cancelled_kernel $input $input $cancelled_target} message options]} "Cancellation did not propagate"
    assert {[dict get $options -errorcode] eq {RMSXFLIPBOOK CANCELLED}} "Cancellation lost structured error code"
    assert {![file exists $cancelled_target]} "Cancellation published incomplete output"
    assert {[llength [glob -nocomplain -directory $root .rmsx-txn-*]] == 0} "Completed operations leaked stages/journals"

    # Simulate process interruption in the rename gap; the next begin restores
    # the previous result and retains the incomplete staging folder for review.
    set recover_target [dict get $outer target]
    set interrupted [::RMSXFlipbookTimeline::OutputTxn::begin $recover_target -overwrite 1]
    write_text [file join [dict get $interrupted stage] unfinished.csv] partial
    file rename $recover_target [dict get $interrupted backup]
    dict unset ::RMSXFlipbookTimeline::OutputTxn::active [dict get $interrupted id]
    set next [::RMSXFlipbookTimeline::OutputTxn::begin $recover_target -overwrite 1]
    assert {[read_text [file join $recover_target chain_A data.csv]] eq "after-mask"} "Interrupted replacement recovery did not restore previous data"
    assert {[file exists [file join [dict get $interrupted stage] unfinished.csv]]} "Recovery deleted interrupted data"
    ::RMSXFlipbookTimeline::OutputTxn::abort $next
    puts "RMSX core transactions smoke passed"
} finally {file delete -force $root}
