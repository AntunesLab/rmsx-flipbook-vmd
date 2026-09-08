################################################################################
# RMSX Flipbook Timeline multi-model PDB export smoke test
################################################################################

proc smoke_fail {message} {
    puts "RMSX Flipbook Timeline multi-model export smoke failed: $message"
    exit 1
}

proc count_lines_matching {filename pattern} {
    set count 0
    set fp [open $filename r]
    try {
        while {[gets $fp line] >= 0} {
            if {[string match $pattern $line]} {
                incr count
            }
        }
    } finally {
        catch {close $fp}
    }
    return $count
}

proc first_atom_bfactor {filename} {
    set fp [open $filename r]
    try {
        while {[gets $fp line] >= 0} {
            if {[string match "ATOM*" $line] || [string match "HETATM*" $line]} {
                return [string trim [string range $line 60 65]]
            }
        }
    } finally {
        catch {close $fp}
    }
    return ""
}

set script_name [info script]
if {$script_name ne "" && [file exists $script_name]} {
    set script_path [file normalize $script_name]
    set test_dir [file dirname $script_path]
    set plugin_dir [file dirname $test_dir]
    set plugin_parent [file dirname $plugin_dir]
    set workspace_root [file dirname $plugin_parent]
} else {
    set workspace_root [pwd]
    set plugin_parent [file normalize [file join $workspace_root workspace_plugins]]
}

lappend auto_path $plugin_parent

if {[catch {package require rmsxflipbooktimeline 0.2} err]} {
    smoke_fail "package require failed: $err"
}

set folder [file join $workspace_root outputs native-rmsx-1ubq-9 chain_7_rmsx]
if {![file isdirectory $folder]} {
    smoke_fail "Expected 9-slice native smoke folder is missing: $folder"
}

set out_path [file join $workspace_root outputs native-rmsx-1ubq-9 chain_7_rmsx rmsx_flipbook_multimodel_smoke.pdb]
if {[file exists $out_path]} {
    file delete $out_path
}

if {[catch {
    ::RMSXFlipbookTimeline::write_multimodel_pdb \
        $folder \
        -output_name $out_path \
        -overwrite 0
} result]} {
    smoke_fail "write_multimodel_pdb failed: $result"
}

if {[dict get $result models] != 9 || [dict get $result files] != 9} {
    smoke_fail "Expected 9 exported models, got $result"
}
if {![file exists $out_path]} {
    smoke_fail "Expected exported PDB is missing: $out_path"
}

set model_count [count_lines_matching $out_path "MODEL*"]
set endmdl_count [count_lines_matching $out_path "ENDMDL*"]
set atom_count [count_lines_matching $out_path "ATOM*"]
if {$model_count != 9 || $endmdl_count != 9} {
    smoke_fail "Expected 9 MODEL/ENDMDL records, got MODEL=$model_count ENDMDL=$endmdl_count"
}
if {$atom_count != [dict get $result atoms]} {
    smoke_fail "Reported atom count [dict get $result atoms] does not match exported ATOM count $atom_count"
}
if {$atom_count != 2745} {
    smoke_fail "Expected 2745 exported atoms for 9 1UBQ slices, got $atom_count"
}

set source_b [first_atom_bfactor [file join $folder slice_1_first_frame.pdb]]
set export_b [first_atom_bfactor $out_path]
if {$source_b eq "" || $source_b ne $export_b} {
    smoke_fail "First exported B-factor '$export_b' did not match source '$source_b'"
}

if {[catch {
    mol new $out_path type pdb waitfor all
    set exported_molid [molinfo top get id]
} load_error]} {
    smoke_fail "VMD could not load exported multi-model PDB: $load_error"
}
set exported_frames [molinfo $exported_molid get numframes]
set exported_atoms [molinfo $exported_molid get numatoms]
if {$exported_frames != 9} {
    smoke_fail "Expected exported PDB to load as 9 VMD frames, got $exported_frames"
}
if {$exported_atoms != 305} {
    smoke_fail "Expected exported PDB to load with 305 atoms per frame, got $exported_atoms"
}
catch {mol delete $exported_molid}

if {![catch {
    ::RMSXFlipbookTimeline::write_multimodel_pdb \
        $folder \
        -output_name $out_path \
        -overwrite 0
} duplicate_result]} {
    smoke_fail "Expected overwrite=0 duplicate export to fail"
}

puts "RMSX Flipbook Timeline multi-model export smoke passed"
quit
