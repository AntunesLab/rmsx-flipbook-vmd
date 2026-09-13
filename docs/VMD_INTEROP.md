# VMD interoperability observations

These observations were reproduced with macOS ARM64 VMD 2.0b1 (February 18, 2026). They are implementation observations, not assumptions about every VMD build. The linked identity smoke test provides a reproducible fixture with blank and literal `X` chains, insertion codes, multiple segments, and repeated residue numbers.

## Blank chain IDs when reading PDB

The stock PDB reader substitutes `X` for a blank chain field. Adjacent blank and literal `X` residues with the same residue number and segment can consequently share one VMD `residue` index. Changing their chain strings after loading cannot repair that internal merge.

For a PDB containing a blank chain in column 22, inspect the result with:

```tcl
set molid [mol new input.pdb type pdb waitfor all]
set atoms [atomselect $molid all]
puts [$atoms get {chain segid resid insertion residue}]
$atoms delete
mol delete $molid
```

`ResidueIdentity::load_pdb` temporarily encodes blank chains with an unused one-character chain code before calling VMD. After parsing, it checks atom count, atom order, atom names, residue names, residue numbers, insertion codes, and a one-to-one mapping of source residue groups to VMD residue indices. It then restores the original chain and segment values. It does not change coordinates. Temporary input is removed in `finally`; failed loads remove their new molecule. The molecule name and plugin provenance retain the original source name/path. VMD's internal filename history can still show the temporary reader path.

## Blank chain IDs when writing PDB

Setting a VMD chain to an empty string can cause its PDB writer to emit a NUL byte in column 22. A subsequent stock PDB read can truncate those atom records, losing coordinates, residue fields and B-factors. Assigning a space through the chain setter also produced this behavior in the tested build.

```tcl
set atoms [atomselect $molid all]
$atoms set chain [lrepeat [$atoms num] ""]
$atoms writepdb raw-output.pdb
set input [open raw-output.pdb rb]
puts "NUL offset: [string first \u0000 [read $input]]"
close $input
$atoms delete
```

`ResidueIdentity::write_pdb` publishes atomically. It replaces only a NUL in the PDB chain field with the required ASCII space and rejects NUL bytes elsewhere. Native slice exports, B-factor repairs and neighborhood snapshots use this writer. The golden round-trip test checks that the file has no NUL bytes, preserves every full residue identity and leaves coordinates unchanged.

## Insertion codes and ambiguous identities

In this build, `atomselect set insertion` reports that the field is not modifiable. The plugin validates insertion codes against the original PDB rather than trying to overwrite them. Residue identities include chain, segment, residue number, insertion code and an occurrence ordinal. If a PDB or legacy table cannot identify one residue unambiguously, the plugin reports the mismatch instead of assigning values to a same-number fallback.

Run the relevant tests through the repository harness:

```sh
python3 scripts/run_tests.py --profile vmd \
  --only linked_residue_identity,native_analysis,native_transaction_lifecycle \
  --vmd /absolute/path/to/vmd
```

## Physical time provenance

The native Tcl API and graphical input both default to unknown physical time. An explicitly supplied `-rmsd_time_step` establishes known time unless `-time_known 0` was also supplied; that explicit unknown flag wins. Unknown time produces frame-indexed RMSD sidecars (`Frame,RMSD`), retains slice labels for the matrix, and records `time_unit unknown` and an empty physical time step in method metadata. Known-time sidecars keep their existing `Frame,Time,RMSD` schema and picosecond time values. Combining sidecars rejects a mixture of these schemas. RMSX-style filenames use a frame count when time is unknown and no manual duration was supplied. Callers migrating numerical baselines that previously accepted the historical step must now specify it explicitly.

## Console streams during graphical redraw

On the tested macOS VMD2.0b1 build, stdin EOF can begin shutdown while a scripted
scene is still loading. A render may then contain only the VMD logo. Keeping
stdin open while redirecting stdout can instead block the console during a
display update. A pseudo-terminal on stdin, stdout and stderr produces the
expected molecular render; the test runner drains its master into the log.
`vmd_process.py` implements that POSIX console contract and kills the entire
test process group on timeout. Windowed tests require a real display/OpenGL
context. A text-only run cannot establish renderer availability.

Production scene changes use redraw-only `display update` where appropriate.
`display update ui` may reenter script/event processing during a scene operation;
a plugin must not infer completed loading from that reentry. Render assertions
check a valid image and actual molecular scene, followed by visual inspection
for the meeting example.

## User key descriptions and shutdown

An isolated VMD2.0b1 process, without this plugin loaded, exited normally after
adding a user key with the key and command arguments. Supplying the optional
description argument reproduced a malloc/free abort during VMD shutdown,
with both empty and nonempty descriptions. The plugin supplies the key and command, and overrides only existing bindings whose command can be read and whose
description is empty. It skips absent bindings when no reliable deletion API
is available. Cleanup restores a binding only while the plugin still owns its
current value. Dashboard keyboard navigation is independent of these optional
VMD-wide bindings.

## Representation availability

The installed ARM VMD1.9.4a57 build does not support `NewTube`; the tested
VMD2.0.0a7 and VMD2.0b1 builds do. An unsupported `mol modstyle` request can print
an error without producing a Tcl exception and leave an old `Lines`
representation active. The extension chooses `NewCartoon` with unit aspect ratio for the older build,
because legacy `Tube` does not modulate thickness from the residue user field.
Native Intel 1.9.4a57 rendering verifies that `NewCartoon` responds to those values. It
filters the displayed choices and checks the representation actually applied.
An explicitly unsupported request is an error rather than a successful-looking
style change. These observations do not establish support on untested builds.
