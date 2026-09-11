# Optional reviewer controls. Normal package use has no demo UI or file writes.
namespace eval ::RMSXFlipbookTimeline::Reviewer {
    variable workspace ""
    variable build ""
    variable active 0
    variable example single
    variable note ""
    variable report {}
    variable report_path ""
    variable queued ""
    variable background_errors {}

    proc require {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
    proc example_spec {root kind} {
        if {$kind ni {single multi}} {error "Reviewer example must be single or multi"}
        set input [file join $root fixtures upstream test_files]
        if {$kind eq "single"} {
            set spec [dict create name Ubiquitin topology [file join $input 1UBQ.pdb] trajectory [file join $input mon_sys.dcd] chain 7 first 0 last 314 total_frames 316 slices 9 span 35 mask {} rows 76 preview [file join $root fixtures seed_outputs native-rmsx-1ubq-9 chain_7_rmsx]]
        } else {
            set spec [dict create name Protease topology [file join $input protease_backbone.pdb] trajectory [file join $input short_protease_backbone.dcd] chain all first 0 last 26 total_frames 27 slices 9 span 3 mask {resid 25:26} rows 196 preview [file join $root fixtures seed_outputs reviewer-protease-9 combined]]
        }
        dict set spec output [file join $root outputs]
        return $spec
    }
    proc preview_dataset {dataset spec} {
        ::RMSXFlipbookTimeline::Matrix::validate $dataset
        require {[dict get $dataset column_count] == [dict get $spec slices] && [dict get $dataset row_count] == [dict get $spec rows]} "Precomputed reviewer matrix has unexpected dimensions"
        set columns {}; set index 0
        foreach column [dict get $dataset columns] {
            require {[dict exists $column slice_number] && [dict get $column slice_number] == $index+1} "Precomputed reviewer slices are missing or reordered"
            set first [expr {[dict get $spec first]+$index*[dict get $spec span]}]
            set last [expr {$first+[dict get $spec span]-1}]
            require {$last <= [dict get $spec last]} "Precomputed reviewer window exceeds the verified frame range"
            foreach key {time time_end time_unit frame} {catch {dict unset column $key}}
            dict set column frame_start $first
            dict set column frame_end $last
            dict set column label "Frames $first–$last"
            lappend columns $column
            incr index
        }
        dict set dataset columns $columns
        dict set dataset provenance reviewer_frame_mapping [dict create source bundled_fixture_recipe verified_by smoke_reviewer_preview_frames time_known 0 first_frame [dict get $spec first] last_frame [dict get $spec last] slice_size [dict get $spec span]]
        return [::RMSXFlipbookTimeline::Matrix::validate $dataset]
    }
    proc preflight {root} {
        require {[package vsatisfies [info patchlevel] 8.6]} "Reviewer needs VMD with Tcl 8.6"
        foreach command {molinfo atomselect measure mol render display} {require {[info commands ::$command] ne ""} "Reviewer requires VMD command: $command"}
        package require Tk 8.6
        require {[winfo exists .]} "Reviewer needs a graphical VMD session"
        foreach kind {single multi} {
            set spec [example_spec $root $kind]
            foreach key {topology trajectory} {require {[file isfile [dict get $spec $key]]} "Reviewer input is missing: [dict get $spec $key]"}
        }
        set out [file join $root outputs]
        file mkdir $out
        set fp [file tempfile probe [file join $out writable-]]
        try {puts $fp reviewer; flush $fp} finally {close $fp; file delete $probe}
        set data [dict create plugin $::RMSXFlipbookTimeline::version build [::RMSXFlipbookTimeline::build_id] vmd [vmdinfo version] tcl [info patchlevel] tk [package provide Tk] os $::tcl_platform(os) os_version $::tcl_platform(osVersion) machine $::tcl_platform(machine) executable [info nameofexecutable] graphics_mode gui graphics_driver unknown display_width unavailable display_height unavailable windowing [tk windowingsystem] renderers [::RMSXFlipbookTimeline::Render::render_methods] qualification {This VMD session only; no other platform is qualified. OpenGL appearance requires visual review.}]
        catch {dict set data vmd_arch [vmdinfo arch]}
        if {![catch {display get size} size] && [llength $size] == 2} {
            dict set data display_width [lindex $size 0]
            dict set data display_height [lindex $size 1]
        }
        return $data
    }
    proc launch {root identity {initial single}} {
        variable workspace; variable build; variable active; variable example; variable report
        set root [file normalize $root]
        if {$active} {
            require {$identity eq $build} "A different RMSX review build is loaded. Start a fresh VMD session."
            return [::RMSXFlipbookTimeline::show_dashboard]
        }
        require {$identity eq [::RMSXFlipbookTimeline::build_id]} "Loaded plugin does not match this reviewer build. Start a fresh VMD session."
        example_spec $root $initial
        # Remember the verified runtime location before fallible UI/preflight
        # work, so reloading the same review file can retry a partial launch.
        set workspace $root; set build $identity; set example $initial
        set checked [preflight $root]
        set active 1
        set report [dict create status READY environment $checked checks {}]
        try {
            set window [::RMSXFlipbookTimeline::show_dashboard]
            source -encoding utf-8 [file join $::RMSXFlipbookTimeline::basedir register.tcl]
            mount
        } on error {message options} {
            set active 0
            detach
            return -options $options $message
        }
        if {[::RMSXFlipbookTimeline::Results::get] eq {}} {select_example $initial} else {
            ::RMSXFlipbookTimeline::Dashboard::set_status "Existing result retained. Single and Multi open the reviewer examples."
        }
        return $window
    }
    proc reopen {identity} {
        variable workspace; variable active
        require {$workspace ne ""} "Reviewer session is not initialized. Reopen the unpacked reviewer file."
        return [launch $workspace $identity]
    }
    proc detach {} {
        ::RMSXFlipbookTimeline::Reviewer::Windows::detach
        catch {trace remove variable ::RMSXFlipbookTimeline::Results::current write ::RMSXFlipbookTimeline::Reviewer::result_changed}
        variable queued
        if {$queued ne ""} {catch {after cancel $queued}; set queued ""}
    }
    proc mount {} {
        variable active
        if {!$active || [info commands winfo] eq ""} {return}
        set top $::RMSXFlipbookTimeline::Dashboard::top
        if {![winfo exists $top.header]} {return}
        set bar $top.header.reviewer
        if {![winfo exists $bar]} {
            ttk::frame $bar
            foreach {name label command} {
                single Single {::RMSXFlipbookTimeline::Reviewer::select_example single}
                multi Multi {::RMSXFlipbookTimeline::Reviewer::select_example multi}
                check {Quick Check} ::RMSXFlipbookTimeline::Reviewer::quick_check
                report {Save report…} ::RMSXFlipbookTimeline::Reviewer::save_report
            } {
                ttk::button $bar.$name -text $label -command $command -style RMSX.TButton
                pack $bar.$name -side left -padx {0 4}
            }
            ttk::label $top.header.reviewer_note -textvariable ::RMSXFlipbookTimeline::Reviewer::note -font TkSmallCaptionFont -wraplength 580 -justify left
            grid $bar -row 1 -column 0 -columnspan 2 -sticky w -pady {5 0}
            grid $top.header.reviewer_note -row 2 -column 0 -columnspan 2 -sticky ew -pady {3 0}
            bind $top.header.reviewer_note <Configure> {::RMSXFlipbookTimeline::Dashboard::resize_label_wrap %W %w 160 4}
        }
        catch {trace remove variable ::RMSXFlipbookTimeline::Results::current write ::RMSXFlipbookTimeline::Reviewer::result_changed}
        trace add variable ::RMSXFlipbookTimeline::Results::current write ::RMSXFlipbookTimeline::Reviewer::result_changed
        ::RMSXFlipbookTimeline::Effects::register reviewer_input ::RMSXFlipbookTimeline::Reviewer::detach input
        ::RMSXFlipbookTimeline::Reviewer::Windows::mount $top.header
        result_changed
    }
    proc result_changed {args} {
        variable note
        set current [::RMSXFlipbookTimeline::Results::get]
        if {$current ne {} && [dict exists $current reviewer_preview] && [dict get $current reviewer_preview]} {
            set note "Precomputed preview • Run recalculates from the bundled trajectory."
        } else {set note "Reviewer examples • frame labels • outputs stay in this local workspace."}
    }
    proc enqueue {kind command} {
        variable queued
        if {[::RMSXFlipbookTimeline::Operation::running] || $queued ne ""} {return}
        ::RMSXFlipbookTimeline::Operation::begin $kind
        set queued [after 25 [list ::RMSXFlipbookTimeline::Reviewer::execute $command]]
        return [dict get [::RMSXFlipbookTimeline::Operation::get] id]
    }
    proc execute {command} {
        variable queued
        set queued ""
        ::RMSXFlipbookTimeline::Dashboard::execute_operation $command
        mount
        if {$command eq "::RMSXFlipbookTimeline::Reviewer::_quick_check"} {
            variable report; variable report_path
            ::RMSXFlipbookTimeline::Dashboard::set_status "Quick Check [dict get $report status]. Report: $report_path"
        }
    }
    proc select_example {kind} {
        variable workspace
        example_spec $workspace $kind
        return [enqueue reviewer_preview [list ::RMSXFlipbookTimeline::Reviewer::_example $kind]]
    }
    proc configure_example {kind} {
        variable workspace; variable example
        set spec [example_spec $workspace $kind]
        foreach {name value} [list source_type new_analysis native_topology [dict get $spec topology] native_trajectory [dict get $spec trajectory] native_output [dict get $spec output] native_chain [dict get $spec chain] native_start [dict get $spec first] native_end [dict get $spec last] native_slices 9 native_slice_size [dict get $spec span] native_slicing_mode slices native_metric RMSX timeline_metric RMSX palette viridis native_mask_selection [dict get $spec mask] native_time_step {} native_total_time_ns {} native_total_frames [dict get $spec total_frames] native_detected_total_frames [dict get $spec total_frames] native_analysis_type protein native_log_transform 0] {
            set ::RMSXFlipbookTimeline::Dashboard::$name $value
            ::RMSXFlipbookTimeline::state_set $name $value
        }
        set ::RMSXFlipbookTimeline::Dashboard::native_chain_groups {}
        set ::RMSXFlipbookTimeline::Dashboard::native_chain_groups_topology ""
        set ::RMSXFlipbookTimeline::Dashboard::end_display [dict get $spec last]
        if {$::RMSXFlipbookTimeline::Dashboard::native_frame_count_after ne ""} {
            catch {after cancel $::RMSXFlipbookTimeline::Dashboard::native_frame_count_after}
            set ::RMSXFlipbookTimeline::Dashboard::native_frame_count_after ""
        }
        foreach name {native_detected_time_step_ps native_detected_total_time_ns native_time_estimate_source} {
            set ::RMSXFlipbookTimeline::Dashboard::$name ""
            ::RMSXFlipbookTimeline::state_set $name ""
        }
        set ::RMSXFlipbookTimeline::Dashboard::native_frame_count_key [::RMSXFlipbookTimeline::Dashboard::current_native_frame_count_key]
        set example $kind
        ::RMSXFlipbookTimeline::Dashboard::persist_common_state
        return $spec
    }
    proc _example {kind} {
        ::RMSXFlipbookTimeline::Operation::checkpoint [dict create stage loading message "Opening precomputed $kind preview…"]
        set spec [configure_example $kind]
        set metadata [dict create reviewer_preview 1 label {RMSX · precomputed preview} source_paths [list [dict get $spec topology] [dict get $spec trajectory]] time_known 0 frame_first [dict get $spec first] frame_last [dict get $spec last]]
        dict set metadata dataset [preview_dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder [dict get $spec preview]] $spec]
        set loaded [::RMSXFlipbookTimeline::Dashboard::load_folder_with_view [dict get $spec preview] $metadata]
        set ::RMSXFlipbookTimeline::Dashboard::folder [dict get $spec preview]
        ::RMSXFlipbookTimeline::Dashboard::refresh_dashboard
        foreach id [::RMSXFlipbookTimeline::state_get molids {}] {mol on $id}
        catch {display update}
        ::RMSXFlipbookTimeline::Dashboard::set_status "Precomputed [dict get $spec name] preview loaded. Run uses nine [dict get $spec span]-frame windows."
        return $loaded
    }
    proc run_fresh {} {
        return [enqueue reviewer_fresh ::RMSXFlipbookTimeline::Reviewer::_fresh]
    }
    proc _fresh {} {
        set visibility {}
        set old_owned [::RMSXFlipbookTimeline::state_get molids {}]
        foreach id [molinfo list] {if {[lsearch -exact $old_owned $id] < 0} {dict set visibility $id [molinfo $id get drawn]}}
        try {return [::RMSXFlipbookTimeline::Dashboard::_run_native_metric]} finally {
            dict for {id drawn} $visibility {if {[lsearch -exact [molinfo list] $id] >= 0} {molinfo $id set drawn $drawn}}
        }
    }
    proc record {name status detail} {
        variable report
        dict lappend report checks [dict create name $name status $status detail $detail]
        write_report
    }
    proc report_text {} {
        variable report; variable build
        set text "RMSX reviewer Quick Check\nBuild: $build\n"
        append text "Status: [dict get $report status]\nScope: this VMD session only; this is not cross-platform release qualification.\n\n"
        if {[dict exists $report environment]} {dict for {key value} [dict get $report environment] {append text "$key: $value\n"}}
        append text "\n"
        foreach check [dict get $report checks] {append text "[dict get $check status] — [dict get $check name]: [dict get $check detail]\n"}
        return $text
    }
    proc write_text {text path} {set fp [open $path w]; try {fconfigure $fp -encoding utf-8 -translation lf; puts -nonewline $fp $text} finally {close $fp}}
    proc json_string {text} {
        set map [list \\ \\\\ \" \\\" \n \\n \r \\r \t \\t]
        for {set code 0} {$code < 32} {incr code} {
            if {$code ni {9 10 13}} {lappend map [format %c $code] [format {\u%04x} $code]}
        }
        return \"[string map $map $text]\"
    }
    proc report_json {} {
        variable report; variable build
        set environment {}; set checks {}; set final {}; set stages {}
        dict for {key value} [dict get $report environment] {lappend environment "[json_string $key]:[json_string $value]"}
        foreach item [dict get $report checks] {
            set encoded [format {{"name":%s,"status":%s,"detail":%s}} [json_string [dict get $item name]] [json_string [dict get $item status]] [json_string [dict get $item detail]]]
            lappend checks $encoded
            dict set final [dict get $item name] $encoded
        }
        dict for {name encoded} $final {lappend stages $encoded}
        return [format {{"schema":1,"build_id":%s,"status":%s,"qualification_scope":"local_reviewer_quick_check","environment":{%s},"stages":[%s],"checks":[%s]}} [json_string $build] [json_string [dict get $report status]] [join $environment ,] [join $stages ,] [join $checks ,]]
    }
    proc write_report {} {
        variable report_path
        if {$report_path eq ""} {return}
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write $report_path [list ::RMSXFlipbookTimeline::Reviewer::write_text [report_text]]
        ::RMSXFlipbookTimeline::OutputTxn::atomic_write "[file rootname $report_path].json" [list ::RMSXFlipbookTimeline::Reviewer::write_text [report_json]]
    }
    proc save_report {} {
        variable report
        if {$report eq {}} {return}
        set path [tk_getSaveFile -parent $::RMSXFlipbookTimeline::Dashboard::top -title "Save reviewer report" -initialfile rmsx-review-report.json -defaultextension .json -filetypes {{"JSON reports" {.json}} {"All files" {*}}}]
        if {$path ne ""} {
            ::RMSXFlipbookTimeline::OutputTxn::atomic_write $path [list ::RMSXFlipbookTimeline::Reviewer::write_text [report_json]]
            ::RMSXFlipbookTimeline::OutputTxn::atomic_write "[file rootname $path].txt" [list ::RMSXFlipbookTimeline::Reviewer::write_text [report_text]]
            ::RMSXFlipbookTimeline::Dashboard::set_status "Reviewer report saved: $path"
        }
    }
    proc quick_check {} {return [enqueue reviewer_check ::RMSXFlipbookTimeline::Reviewer::_quick_check]}
    proc centers {ids} {return [lmap id $ids {::RMSXFlipbookTimeline::Hotkeys::molecule_center $id}]}
    proc fixture_rows {spec} {
        set scene [::RMSXFlipbookTimeline::Scene::snapshot]
        set molid ""; set sel ""
        try {
            set molid [::RMSXFlipbookTimeline::ResidueIdentity::load_pdb [dict get $spec topology]]
            mol off $molid
            set selection {protein and name CA}
            if {[dict get $spec chain] eq "7"} {append selection { and segid "7"}}
            set sel [atomselect $molid $selection]
            return [lmap row [::RMSXFlipbookTimeline::ResidueIdentity::from_selection $sel] {::RMSXFlipbookTimeline::ResidueIdentity::portable $row}]
        } finally {
            if {$sel ne ""} {catch {$sel delete}}
            if {$molid ne ""} {catch {mol delete $molid}}
            ::RMSXFlipbookTimeline::Scene::restore_snapshot $scene
        }
    }
    proc check_dataset {dataset expected_rows columns} {
        ::RMSXFlipbookTimeline::Matrix::validate $dataset
        require {[dict get $dataset row_count] == $expected_rows && [dict get $dataset column_count] == $columns} "Fresh matrix shape does not match the fixture"
        set positive 0
        foreach column [dict get $dataset values] {
            foreach value $column {
                require {[string is double -strict $value] && $value >= 0 && $value < Inf} "Fresh RMSX matrix contains an invalid value"
                if {$value > 0} {incr positive}
            }
        }
        require {$positive > 0} "Fresh RMSX matrix has no molecular fluctuation"
        return "$expected_rows residues × $columns windows; finite nonnegative values"
    }
    proc background_error {message options} {
        variable background_errors
        lappend background_errors $message
        puts stderr "Reviewer background error: $message"
    }
    proc _quick_check {} {
        variable report; variable report_path
        # Clear the previous receipt before any output or capability check can
        # fail. A previous successful run must never stand in for this attempt.
        set report [dict create status RUNNING environment {} checks {}]
        set report_path ""
        try {
            return [_quick_check_body]
        } on error {message options} {
            set outcome [expr {[::RMSXFlipbookTimeline::Operation::cancelled $options] ? "CANCELLED" : "FAIL"}]
            dict set report status $outcome
            dict lappend report checks [dict create name execution status $outcome detail $message]
            if {[catch {write_report} write_error]} {
                dict lappend report checks [dict create name reporting status FAIL detail $write_error]
                append message "\nThe local report could not be saved: $write_error"
            }
            return -options $options $message
        }
    }
    proc _quick_check_body {} {
        variable workspace; variable build; variable example; variable report; variable report_path; variable background_errors
        set background_errors {}
        set dir [::RMSXFlipbookTimeline::Dashboard::unique_run_path [file join $workspace outputs] quick-check]
        file mkdir $dir
        set report_path [file join $dir report.txt]
        dict set report environment [preflight $workspace]
        write_report
        set old_scene [::RMSXFlipbookTimeline::Scene::snapshot]
        set old_state [::RMSXFlipbookTimeline::state_dict]
        set old_result [::RMSXFlipbookTimeline::Results::get]
        set before [molinfo list]
        set candidate {}; set errors {}; set outcome PASS
        set prior_bgerror [interp bgerror {}]
        interp bgerror {} ::RMSXFlipbookTimeline::Reviewer::background_error
        try {
            record preflight PASS "VMD/Tcl/Tk available; bundled inputs present; local output writable"
            set spec [example_spec $workspace $example]
            record calculation RUNNING "Fresh $example RMSX; three windows; no physical time assumed"
            set method [expr {$example eq "single" ? "::RMSXFlipbookTimeline::run_native_analysis" : "::RMSXFlipbookTimeline::run_native_all_chain_analysis"}]
            set args [list -num_slices 3 -start_frame 0 -end_frame [expr {$example eq "single" ? 26 : [dict get $spec last]}] -time_known 0 -mask_selection [dict get $spec mask] -verbose 0 -cleanup 1 -progress_callback ::RMSXFlipbookTimeline::Operation::checkpoint]
            if {$example eq "single"} {lappend args -chain 7}
            set analysis [$method [dict get $spec topology] [dict get $spec trajectory] [file join $dir fresh] {*}$args]
            set dataset [::RMSXFlipbookTimeline::TimelineIO::read_rmsx_folder [dict get $analysis output_dir]]
            set expected_rows [fixture_rows $spec]
            record calculation PASS [check_dataset $dataset [llength $expected_rows] 3]
            set expected_keys [lmap row $expected_rows {::RMSXFlipbookTimeline::ResidueIdentity::key $row}]
            set actual_keys [lmap row [dict get $dataset rows] {::RMSXFlipbookTimeline::ResidueIdentity::key $row}]
            require {[lsort $expected_keys] eq [lsort $actual_keys]} "Fresh matrix residue identities differ from the live representative atom selection"
            ::RMSXFlipbookTimeline::Operation::checkpoint [dict create stage loading message "Checking hidden structures and residue identity…"]
            set candidate [::RMSXFlipbookTimeline::Loader::prepare_folder [dict get $analysis output_dir]]
            set ids [dict get $candidate state molids]
            require {[llength $ids] == 3} "Quick Check did not load three candidate structures"
            set row [lindex [dict get $dataset rows] 0]
            foreach id $ids {
                set sel [atomselect $id [::RMSXFlipbookTimeline::ResidueIdentity::selection $row $id]]
                try {require {[$sel num] > 0 && [llength [lsort -unique [$sel get residue]]] == 1} "Residue identity did not resolve uniquely"} finally {$sel delete}
            }
            if {$example eq "multi"} {
                set masked {}
                foreach row [dict get $dataset rows] {if {[dict get $row masked]} {lappend masked [list [dict get $row chain] [dict get $row resid]]}}
                require {[lsort $masked] eq {{A 25} {A 26} {B 25} {B 26}}} "Multichain mask identities do not match residues 25:26 on both chains"
                foreach id $ids {
                    require {[molinfo $id get numreps] >= 3} "Masked candidate lacks transparency or marker representation"
                    foreach rep {1 2} {
                        set masked_sel [atomselect $id [lindex [molinfo $id get [list [list selection $rep]]] 0]]
                        try {
                            require {[lsort -unique [$masked_sel get {chain resid}]] eq {{A 25} {A 26} {B 25} {B 26}}} "Mask representation selects the wrong chain/residue identities"
                        } finally {$masked_sel delete}
                    }
                }
            }
            record identity PASS "Exact residue identity resolves on every candidate slice"
            set centers [centers $ids]
            ::RMSXFlipbookTimeline::state_replace [dict get $candidate state]
            set rotation [::RMSXFlipbookTimeline::Hotkeys::rotate_all y 5]
            require {[dict get $rotation rotated] == 3} "Not all candidate structures rotated"
            foreach a $centers b [centers $ids] {require {[veclength [vecsub $a $b]] < 0.001} "Rotation moved an individual protein center"}
            record rotation PASS "Rotation API preserves each center within 0.001 Å; mouse gestures require visual review"
            ::RMSXFlipbookTimeline::Operation::checkpoint [dict create stage writing message "Checking native PNG export…"]
            if {[lsearch -exact [::RMSXFlipbookTimeline::Render::render_methods] TachyonInternal] < 0} {
                set outcome PARTIAL
                record rendering UNAVAILABLE "TachyonInternal is absent; PNG export was not verified"
            } else {
                set options [dict create method TachyonInternal width 640 height auto background white shadows 0 ambient_occlusion 0 framing fit view_preset rmsx format png transparent_background 0 transparency_tolerance 2]
                set image [::RMSXFlipbookTimeline::OutputTxn::atomic_write [file join $dir molecular.png] [list ::RMSXFlipbookTimeline::Render::render_payload $options $ids]]
                require {[dict get $image pixel_bounds nonbackground_samples] > 20} "Rendered molecular image contains too few foreground pixels"
                set photo [image create photo -file [file join $dir molecular.png]]
                try {
                    require {[image width $photo] == [dict get $image width] && [image height $photo] == [dict get $image height]} "PNG decode dimensions differ"
                    set colors {}
                    for {set y 0} {$y < [image height $photo]} {incr y 5} {
                        for {set x 0} {$x < [image width $photo]} {incr x 5} {dict set colors [$photo get $x $y] 1}
                    }
                    require {[dict size $colors] > 8} "PNG has insufficient molecular color variation"
                } finally {image delete $photo}
                set figure [dict merge [dict get $candidate result] [dict create dataset $dataset molids $ids label {Reviewer fresh RMSX} display_settings [::RMSXFlipbookTimeline::display_record]]]
                set svg [file join $dir molecular.svg]
                ::RMSXFlipbookTimeline::OutputTxn::atomic_write $svg [list ::RMSXFlipbookTimeline::Render::figure_svg $image $figure [file join $dir molecular.png]]
                set fp [open $svg r]
                try {fconfigure $fp -encoding utf-8; set text [read $fp]} finally {close $fp}
                require {[string first {data:image/png;base64,} $text] >= 0 && [string first {frames 0–8} $text] >= 0} "SVG lacks embedded image or correct frame labels"
                record rendering PASS "Native PNG decoded with molecular color variation; fitted borders clear; SVG embeds PNG and frame labels"
                set thickness [::RMSXFlipbookTimeline::Render::verify_residue_thickness [lindex $ids 0] $dir ::RMSXFlipbookTimeline::Operation::checkpoint]
                record residue_thickness PASS "Native geometry changed at fixed camera/color: $thickness"
            }
        } on error {message options} {
            set outcome [expr {[::RMSXFlipbookTimeline::Operation::cancelled $options] ? "CANCELLED" : "FAIL"}]
            lappend errors $message
            dict lappend report checks [dict create name execution status $outcome detail $message]
        } finally {
            if {[catch {interp bgerror {} $prior_bgerror} message]} {lappend errors $message}
            if {[llength $background_errors]} {lappend errors "Background errors: [join $background_errors {; }]"}
            if {$candidate ne {} && [catch {::RMSXFlipbookTimeline::Loader::discard_candidate $candidate} message]} {lappend errors $message}
            if {[catch {::RMSXFlipbookTimeline::state_replace $old_state} message]} {lappend errors $message}
            if {[catch {::RMSXFlipbookTimeline::Scene::restore_snapshot $old_scene} message]} {lappend errors $message}
            if {[lsort -integer [molinfo list]] ne [lsort -integer $before]} {lappend errors "Molecule inventory changed after cleanup"}
            if {[::RMSXFlipbookTimeline::Results::get] ne $old_result} {lappend errors "The displayed result changed during Quick Check"}
            if {[llength $errors]} {
                if {$outcome ne "CANCELLED"} {set outcome FAIL}
                dict lappend report checks [dict create name cleanup status FAIL detail [join $errors {; }]]
            } else {dict lappend report checks [dict create name cleanup status PASS detail "Original molecules, current result and scene restored"]}
            dict set report status $outcome
        }
        if {$outcome eq "FAIL"} {error "Quick Check failed: [join $errors {; }]"}
        write_report
        ::RMSXFlipbookTimeline::Dashboard::set_status "Quick Check $outcome. Report: $report_path"
        if {$outcome eq "CANCELLED"} {return -code error -errorcode {RMSXFLIPBOOK CANCELLED} "Quick Check cancelled; report saved: $report_path"}
        return $report
    }
}

source -encoding utf-8 [file join [file dirname [info script]] windows_demo.tcl]
