# Recoverable publication of plugin-owned results. Never source metadata as Tcl.
namespace eval ::RMSXFlipbookTimeline::OutputTxn {
    variable active {}
    variable counter 0
    variable manifest_name .rmsx_output_manifest.tcldict

    proc within {parent child} {
        set a [file split [file normalize $parent]]
        set b [file split [file normalize $child]]
        if {[llength $b] < [llength $a]} {return 0}
        return [expr {[lrange $b 0 [expr {[llength $a]-1}]] eq $a}]
    }
    proc entries {directory} {
        set out {}
        foreach pattern {* .*} {
            foreach path [glob -nocomplain -directory $directory $pattern] {
                if {[file tail $path] ni {. ..}} {lappend out $path}
            }
        }
        return [lsort -unique $out]
    }
    proc read_dict {path} {
        set f [open $path r]
        try {set data [read $f]} finally {close $f}
        if {[catch {dict size $data}]} {error "Invalid RMSX metadata: $path"}
        return $data
    }
    proc write_dict {path data} {
        set f [open $path {WRONLY CREAT EXCL}]
        try {puts $f $data; flush $f} finally {close $f}
    }
    proc digest {path} {
        set f [open $path rb]
        set crc 0
        set size 0
        try {
            while {![eof $f]} {
                set chunk [read $f 65536]
                incr size [string length $chunk]
                set crc [zlib crc32 $chunk $crc]
            }
        } finally {close $f}
        return [list $size $crc]
    }
    proc inventory {directory {root ""}} {
        variable manifest_name
        if {$root eq ""} {set root $directory}
        set found {}
        foreach path [entries $directory] {
            if {$directory eq $root && [file tail $path] eq $manifest_name} {continue}
            file lstat $path st
            if {$st(type) eq "link"} {error "Result contains a symbolic link: $path"}
            set relative [string range $path [expr {[string length $root]+1}] end]
            if {$st(type) eq "directory"} {
                dict set found $relative directory
                set found [dict merge $found [inventory $path $root]]
            } elseif {$st(type) eq "file"} {
                dict set found $relative [digest $path]
            } else {error "Unsupported result entry: $path"}
        }
        return $found
    }
    proc verify_owned {directory} {
        variable manifest_name
        set path [file join $directory $manifest_name]
        if {![file isfile $path]} {error "Existing output is not a verified RMSX result. Choose a new output folder: $directory"}
        set data [read_dict $path]
        foreach key {schema owner complete files} {
            if {![dict exists $data $key]} {error "Incomplete result ownership metadata: $path"}
        }
        if {[dict get $data schema] != 2 || [dict get $data owner] ne "rmsxflipbooktimeline" || ![dict get $data complete]} {
            error "Unrecognized or incomplete RMSX result: $directory"
        }
        set actual [inventory $directory]
        set expected [dict get $data files]
        if {[lsort [dict keys $actual]] ne [lsort [dict keys $expected]]} {
            error "Output contains added or removed files; preserve it and choose a new output folder: $directory"
        }
        dict for {name value} $expected {
            if {[dict get $actual $name] ne $value} {error "Output file has changed; preserve it and choose a new output folder: $name"}
        }
        return $data
    }
    proc target_state {target} {
        if {![file exists $target]} {return absent}
        if {![file isdirectory $target]} {error "Output path is not a directory: $target"}
        if {![llength [entries $target]]} {return empty}
        return [list owned [verify_owned $target]]
    }
    proc begin {target args} {
        variable counter
        variable active
        set opts [dict create overwrite 0 inputs {}]
        if {[llength $args] % 2} {error "Transaction options must be key/value pairs"}
        foreach {key value} $args {
            set key [string trimleft $key -]
            if {![dict exists $opts $key]} {error "Unknown transaction option: $key"}
            dict set opts $key $value
        }
        # Inspect the supplied path before normalize follows symlinks.
        if {![catch {file lstat $target st}] && $st(type) eq "link"} {error "Output directory must not be a symbolic link: $target"}
        set target [file normalize $target]
        if {$target eq [file dirname $target] || $target eq [file normalize ~] || $target eq [file normalize [pwd]]} {
            error "Choose a dedicated RMSX output directory: $target"
        }
        foreach input [dict get $opts inputs] {
            if {[within $target $input]} {error "Output must not contain an input file: $input"}
        }
        # Recover only journals for this target, and never disturb a live transaction.
        foreach journal [glob -nocomplain -directory [file dirname $target] .rmsx-txn-*.journal] {
            if {[catch {read_dict $journal} pending] || ![dict exists $pending target] || [dict get $pending target] ne $target} {continue}
            if {[dict exists $pending id] && [dict exists $active [dict get $pending id]]} {error "An analysis is already publishing to this folder: $target"}
            recover $journal
            file rename $journal "${journal}.recovered"
        }
        if {[file exists $target]} {
            if {![file isdirectory $target]} {error "Output path is not a directory: $target"}
            if {[llength [entries $target]]} {
                if {![dict get $opts overwrite]} {error "Output already exists; choose a new run folder or explicitly replace a verified result: $target"}
                verify_owned $target
            }
        }
        file mkdir [file dirname $target]
        set id "[pid]-[clock clicks]-[incr counter]"
        set prefix [file join [file dirname $target] ".rmsx-txn-$id"]
        set txn [dict create id $id target $target stage ${prefix}.stage backup ${target}.rmsx-previous-$id journal ${prefix}.journal prior_state [target_state $target]]
        write_dict [dict get $txn journal] [dict merge $txn [dict create owner rmsxflipbooktimeline schema 1]]
        try {file mkdir [dict get $txn stage]} on error {message options} {
            file delete [dict get $txn journal]
            return -options $options $message
        }
        dict set active $id $txn
        return $txn
    }
    proc assert_active {txn} {
        variable active
        if {![dict exists $active [dict get $txn id]] || [dict get $active [dict get $txn id]] ne $txn} {
            error "Unknown or completed RMSX output transaction"
        }
    }
    proc seal_children {directory from to} {
        variable manifest_name
        foreach child [entries $directory] {
            if {![file isdirectory $child]} {continue}
            seal_children $child $from $to
            set path [file join $child $manifest_name]
            if {![file isfile $path]} {continue}
            set metadata [read_dict $path]
            if {![dict exists $metadata owner] || [dict get $metadata owner] ne "rmsxflipbooktimeline"} {error "Unrecognized nested result metadata: $path"}
            set metadata [rewrite_paths $metadata $from $to]
            dict set metadata files [inventory $child]
            file delete $path
            write_dict $path $metadata
        }
    }
    proc commit {txn {metadata {}}} {
        variable active
        variable manifest_name
        assert_active $txn
        set target [dict get $txn target]
        set stage [dict get $txn stage]
        set backup [dict get $txn backup]
        inventory $stage
        seal_children $stage $stage $target
        set manifest [dict merge $metadata [dict create schema 2 owner rmsxflipbooktimeline complete 1 run_id [dict get $txn id] files [inventory $stage]]]
        set mf [file join $stage $manifest_name]
        if {[file exists $mf]} {file delete $mf}
        write_dict $mf $manifest
        set moved_old 0
        try {
            if {[target_state $target] ne [dict get $txn prior_state]} {error "Output changed while analysis was running; the previous result was preserved: $target"}
            if {[file exists $target]} {
                file rename $target $backup
                set moved_old 1
            }
            file rename $stage $target
        } on error {message options} {
            if {$moved_old && ![file exists $target] && [file exists $backup]} {file rename $backup $target}
            return -options $options $message
        }
        # A successful replacement retains the old result as a recoverable sibling.
        if {$moved_old && ![llength [entries $backup]]} {catch {file delete $backup}}
        catch {file delete [dict get $txn journal]}
        dict unset active [dict get $txn id]
        return $target
    }
    proc abort {txn} {
        variable active
        if {![dict exists $active [dict get $txn id]]} {return}
        assert_active $txn
        set target [dict get $txn target]
        set backup [dict get $txn backup]
        if {![file exists $target] && [file exists $backup]} {
            if {[llength [entries $backup]]} {verify_owned $backup}
            file rename $backup $target
        }
        if {[file exists [dict get $txn stage]]} {file delete -force [dict get $txn stage]}
        if {[file exists [dict get $txn journal]]} {file delete [dict get $txn journal]}
        dict unset active [dict get $txn id]
    }
    proc recover {journal} {
        set txn [read_dict $journal]
        foreach key {id target stage backup journal owner schema} {
            if {![dict exists $txn $key]} {error "Invalid transaction journal: $journal"}
        }
        if {[dict get $txn owner] ne "rmsxflipbooktimeline" || [dict get $txn schema] != 1} {error "Unknown transaction journal: $journal"}
        if {![regexp {^[0-9]+-[0-9]+-[0-9]+$} [dict get $txn id]]} {error "Invalid transaction identity: $journal"}
        set target [file normalize [dict get $txn target]]
        set prefix [file join [file dirname $target] ".rmsx-txn-[dict get $txn id]"]
        if {[dict get $txn stage] ne "${prefix}.stage" || [dict get $txn journal] ne "${prefix}.journal" || [file normalize $journal] ne "${prefix}.journal" || [dict get $txn backup] ne "${target}.rmsx-previous-[dict get $txn id]"} {error "Invalid transaction paths: $journal"}
        set backup [dict get $txn backup]
        if {![file exists $target] && [file exists $backup]} {
            if {[llength [entries $backup]]} {verify_owned $backup}
            file rename $backup $target
        }
        # Retain unfinished staged output for inspection; recovery never recursively deletes it.
        return [dict create target $target stage [dict get $txn stage] backup $backup recovered 1]
    }
    proc atomic_write {filename writer_prefix} {
        variable counter
        if {![catch {file lstat $filename st}] && $st(type) ne "file"} {error "Export destination must be a regular file, not a directory or symbolic link: $filename"}
        set filename [file normalize $filename]
        set before [expr {[file exists $filename] ? [digest $filename] : "absent"}]
        file mkdir [file dirname $filename]
        set tmp "${filename}.rmsx-writing-[pid]-[clock clicks]-[incr counter]"
        set backup "${tmp}.previous"
        set moved 0
        try {
            set result [uplevel #0 [list {*}$writer_prefix $tmp]]
            if {![file isfile $tmp]} {error "Writer did not produce the requested file: $filename"}
            if {![catch {file lstat $filename st}] && $st(type) ne "file"} {error "Export destination changed while writing: $filename"}
            set now [expr {[file exists $filename] ? [digest $filename] : "absent"}]
            if {$now ne $before} {error "Export destination changed while writing; the existing file was preserved: $filename"}
            if {[file exists $filename]} {file rename $filename $backup; set moved 1}
            try {file rename $tmp $filename} on error {message options} {
                if {$moved} {file rename $backup $filename; set moved 0}
                return -options $options $message
            }
            if {$moved} {catch {file delete $backup}}
            return [rewrite_paths $result $tmp $filename]
        } finally {
            if {[file exists $tmp]} {file delete $tmp}
        }
    }
    proc rewrite_paths {value from to} {
        if {$value eq $from} {return $to}
        if {[string first "${from}/" $value] == 0} {return "${to}[string range $value [string length $from] end]"}
        if {[catch {llength $value} n] || $n < 2} {return $value}
        set out {}
        set changed 0
        foreach item $value {
            set next [rewrite_paths $item $from $to]
            if {$next ne $item} {set changed 1}
            lappend out $next
        }
        return [expr {$changed ? $out : $value}]
    }
}
