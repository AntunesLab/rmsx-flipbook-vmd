package require Tcl 8.6
set package_dir [file dirname [file dirname [info script]]]
source -encoding utf-8 [file join $package_dir rmsxflipbooktimeline.tcl]
source -encoding utf-8 [file join $package_dir gui dashboard_window.tcl]
proc expect {expression message} { if {![uplevel 1 [list expr $expression]]} { error $message } }
set original [file join [pwd] result-original]
set other [file join [pwd] next-input]
file mkdir $original $other
set dataset [dict create title "Committed" values {{1.0 2.0}}]
set saved [::RMSXFlipbookTimeline::Results::publish [dict create kind matrix label Committed folder $original dataset $dataset view_options {scale_mode fit}]]
set ::RMSXFlipbookTimeline::Dashboard::folder $other
set ::RMSXFlipbookTimeline::Dashboard::native_output $other
set ::RMSXFlipbookTimeline::Dashboard::timeline_scale_mode every_residue
expect {[::RMSXFlipbookTimeline::Dashboard::current_native_folder] eq [file normalize $original]} "Editable folder redirected active result"
rename ::RMSXFlipbookTimeline::TimelinePlot::write_svg ::RMSXFlipbookTimeline::TimelinePlot::real_write_svg
proc ::RMSXFlipbookTimeline::TimelinePlot::write_svg {dataset filename args} { set ::captured_export [list $dataset $args]; return $filename }
rename ::RMSXFlipbookTimeline::Dashboard::choose_save_file ::RMSXFlipbookTimeline::Dashboard::real_choose_save_file
proc ::RMSXFlipbookTimeline::Dashboard::choose_save_file {kind} { return [file join [pwd] result.svg] }
::RMSXFlipbookTimeline::Dashboard::export_current svg
expect {[lindex $::captured_export 0] eq $dataset} "Export used an uncommitted matrix"
expect {[lindex $::captured_export 1] eq {scale_mode fit}} "Export used next-run form options"
proc fail_run {} { error "deliberate failure" }
expect {[catch {::RMSXFlipbookTimeline::Dashboard::perform_operation test fail_run}]} "Failed operation did not propagate"
expect {[::RMSXFlipbookTimeline::Results::get] eq $saved} "Failed operation replaced the current result"
expect {![::RMSXFlipbookTimeline::Operation::running]} "Failed operation remained busy"
set unique [::RMSXFlipbookTimeline::Dashboard::unique_run_path $other RMSX]
file mkdir $unique
set next [::RMSXFlipbookTimeline::Dashboard::unique_run_path $other RMSX]
expect {$next ne $unique && [file dirname $next] eq [file normalize $other]} "Repeated run reused a previous output path"
expect {[lsearch -exact [::RMSXFlipbookTimeline::Dashboard::native_metric_values] 1-lDDT] >= 0} "1-lDDT display label missing"
puts "RMSX Flipbook Timeline current result smoke passed"
