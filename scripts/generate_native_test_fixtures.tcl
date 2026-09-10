# Developer-only deterministic input generator; does not load RMSX or run analysis.
# Set RMSX_FIXTURE_OUTPUT to a NEW directory, then invoke VMD with
# -dispdev text -e scripts/generate_native_test_fixtures.tcl.
# Recipes below are preserved verbatim from the two smoke-test helpers at
# f0fff690163dc76179dda6e3a15795818d07eb59. The curated files let backend tests
# avoid exercising VMD's unrelated animate-dup/molecule-deletion behavior.
# Reproduce with a qualified VMD build (original generation: 2.0b1 ARM64).
# Maintainer note: Linux VMD 2.0.1a1 independently crashes on mol delete after
# animate dup even without this plugin, selections or a DCD writer. Normal
# plugin analysis does not use animate dup; runtime tests read curated inputs.
namespace eval ::RMSXFixtureGenerator {
    proc smoke_fail {message} { error $message }
proc write_dna_fixture_dcd {topology out_dcd {frames 10}} {
    mol new $topology type pdb waitfor all
    set molid [molinfo top get id]
    set all_sel [atomselect $molid "all"]
    set p_sel [atomselect $molid "nucleic and name P"]
    set backbone_sel [atomselect $molid "nucleic and backbone"]

    try {
        if {[$p_sel num] == 0} {
            smoke_fail "VMD did not recognize P atoms in the bundled DNA fixture"
        }
        if {[$backbone_sel num] == 0} {
            smoke_fail "VMD did not recognize nucleic backbone atoms in the bundled DNA fixture"
        }

        set base_coords [$all_sel get {x y z}]
        for {set frame 1} {$frame < $frames} {incr frame} {
            animate dup frame 0 $molid
        }

        for {set frame 0} {$frame < $frames} {incr frame} {
            $all_sel frame $frame
            set shifted {}
            set atom_index 0
            foreach xyz $base_coords {
                set phase [expr {double($frame) * 0.35 + double($atom_index) * 0.011}]
                set dx [expr {0.18 * sin($phase)}]
                set dy [expr {0.12 * cos($phase * 0.7)}]
                set dz [expr {0.08 * sin($phase * 1.3)}]
                lappend shifted [list \
                    [expr {[lindex $xyz 0] + $dx}] \
                    [expr {[lindex $xyz 1] + $dy}] \
                    [expr {[lindex $xyz 2] + $dz}]]
                incr atom_index
            }
            $all_sel set {x y z} $shifted
        }

        animate write dcd $out_dcd beg 0 end [expr {$frames - 1}] sel $all_sel waitfor all
    } finally {
        catch {$all_sel delete}
        catch {$p_sel delete}
        catch {$backbone_sel delete}
        catch {mol delete $molid}
    }

    if {![file exists $out_dcd]} {
        smoke_fail "Synthetic DNA DCD was not written: $out_dcd"
    }
}

proc duplicate_pdb_for_chains {in_path out_path} {
    set in [open $in_path r]
    set out [open $out_path w]
    set serial 1
    try {
        puts $out "REMARK synthetic two-chain 1UBQ fixture for RMSX Flipbook Timeline smoke testing"
        set atoms {}
        while {[gets $in line] >= 0} {
            if {[string match "ATOM*" $line] || [string match "HETATM*" $line]} {
                lappend atoms $line
            }
        }
        foreach chain {A B} {
            foreach line $atoms {
                set newline $line
                set newline [string replace $newline 6 10 [format "%5d" $serial]]
                set newline [string replace $newline 21 21 $chain]
                set padded [format "%-80s" $newline]
                set padded [string replace $padded 72 75 [format "%-4s" $chain]]
                puts $out $padded
                incr serial
            }
        }
        puts $out "END"
    } finally {
        catch {close $in}
        catch {close $out}
    }
}

proc write_two_chain_fixture {source_topology source_trajectory out_pdb out_dcd {frames 10}} {
    duplicate_pdb_for_chains $source_topology $out_pdb

    mol new $source_topology type pdb waitfor all
    set source [molinfo top get id]
    mol addfile $source_trajectory type dcd waitfor all molid $source

    mol new $out_pdb type pdb waitfor all
    set target [molinfo top get id]

    set src_sel [atomselect $source "all"]
    set a_sel [atomselect $target "segid A"]
    set b_sel [atomselect $target "segid B"]
    set all_sel [atomselect $target "all"]

    try {
        for {set frame 1} {$frame < $frames} {incr frame} {
            animate dup frame 0 $target
        }

        for {set frame 0} {$frame < $frames} {incr frame} {
            $src_sel frame [expr {$frame + 1}]
            $a_sel frame $frame
            $b_sel frame $frame
            set coords [$src_sel get {x y z}]
            $a_sel set {x y z} $coords

            set shifted {}
            foreach xyz $coords {
                lappend shifted [list [expr {[lindex $xyz 0] + 18.0}] [lindex $xyz 1] [lindex $xyz 2]]
            }
            $b_sel set {x y z} $shifted
        }

        animate write dcd $out_dcd beg 0 end [expr {$frames - 1}] sel $all_sel waitfor all
    } finally {
        catch {$src_sel delete}
        catch {$a_sel delete}
        catch {$b_sel delete}
        catch {$all_sel delete}
        catch {mol delete $source}
        catch {mol delete $target}
    }

    if {![file exists $out_dcd]} {
        smoke_fail "Synthetic two-chain DCD was not written: $out_dcd"
    }
}

    proc normalize_dcd_comments {path} {
        # VMD writes a date and nonzero padding into the 80-byte title strings.
        # Replace only those comments; record sizes and all coordinates stay intact.
        set fp [open $path r+]
        fconfigure $fp -translation binary -encoding binary
        try {
            set marker [read $fp 4]
            binary scan $marker i first_size
            set format ii
            if {$first_size != 84} {
                binary scan $marker I first_size
                set format II
            }
            if {$first_size != 84} { error "Unexpected DCD header record size" }
            seek $fp [expr {$first_size + 8}] start
            binary scan [read $fp 8] $format title_size title_count
            if {$title_count != 2 || $title_size != 164} {
                error "Unexpected DCD title record layout"
            }
            foreach comment {
                {Created by DCD plugin; RMSX deterministic fixture}
                {Recipe: native smoke helpers f0fff690; coordinate bytes unchanged}
            } {
                puts -nonewline $fp [format "%-80s" $comment]
            }
        } finally {
            close $fp
        }
    }

    proc run {repo output} {
        if {[file exists $output]} { error "Fixture generation requires a new output directory" }
        file mkdir $output
        set fixtures [file join $repo fixtures]
        set dna [file join $fixtures dna bdna.pdb]
        set single_pdb [file join $fixtures upstream test_files 1UBQ.pdb]
        set single_dcd [file join $fixtures upstream test_files mon_sys.dcd]
        foreach input [list $dna $single_pdb $single_dcd] {
            if {![file isfile $input]} { error "Required fixture input is missing: $input" }
        }
        write_dna_fixture_dcd $dna [file join $output bdna_synthetic.dcd] 10
        write_two_chain_fixture $single_pdb $single_dcd \
            [file join $output two_chain_1ubq.pdb] [file join $output two_chain_1ubq.dcd] 10
        foreach name {bdna_synthetic.dcd two_chain_1ubq.dcd} {
            normalize_dcd_comments [file join $output $name]
        }
        set files {bdna_synthetic.dcd two_chain_1ubq.pdb two_chain_1ubq.dcd}
        foreach name $files {
            if {![file isfile [file join $output $name]] || [file size [file join $output $name]] == 0} {
                error "Generated fixture is missing or empty: $name"
            }
        }
        set receipt [dict create complete 1 status PASS recipe_revision \
            f0fff690163dc76179dda6e3a15795818d07eb59 vmd_version [vmdinfo version] \
            vmd_arch [vmdinfo arch] tcl_version [info patchlevel] frames 10 files $files]
        set fp [open [file join $output COMPLETED.tcldict] {WRONLY CREAT EXCL}]
        try { puts $fp $receipt } finally { close $fp }
        puts "RMSX_NATIVE_FIXTURES_COMPLETE $receipt"
    }
}
if {[catch {
    if {![info exists ::env(RMSX_FIXTURE_OUTPUT)] || $::env(RMSX_FIXTURE_OUTPUT) eq ""} {
        error "Set RMSX_FIXTURE_OUTPUT to a new output directory"
    }
    set repo [file dirname [file dirname [file normalize [info script]]]]
    ::RMSXFixtureGenerator::run $repo [file normalize $::env(RMSX_FIXTURE_OUTPUT)]
} message options]} {
    puts stderr "RMSX_NATIVE_FIXTURES_FAILED $message\n[dict get $options -errorinfo]"
    exit 1
}
quit
