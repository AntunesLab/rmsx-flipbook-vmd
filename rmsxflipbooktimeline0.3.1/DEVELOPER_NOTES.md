# Developer workflow

VERSION is authoritative. Keep the package directory, package index and archive
name consistent with it. Public commands remain `rmsxflipbooktimeline`,
`rmsxflipbooktimeline_dashboard`, `rmsxflipbooktimeline_classic`,
`rmsxflipbooktimeline_about` and `rmsxflipbooktimeline_citation`.

## Checks

```sh
python3 scripts/check_release.py
python3 scripts/tooling_tests.py
python3 scripts/run_tests.py --profile tcl
python3 scripts/run_tests.py --profile vmd --vmd /path/to/vmd
python3 scripts/run_tests.py --profile release --vmd /path/to/vmd
```

The profile names describe capability coverage: `tcl` uses Tcl8.6 without VMD;
`vmd` adds backend VMD tests; `gui` additionally runs windowed Tk tests;
`release` includes actual molecular rendering. `--only id1,id2` is useful for
iteration, but is not a complete release run. `--list` shows test classification.

Every `smoke_*.tcl` must appear in scripts/suite.json. New safety regressions
belong in that manifest with the correct capability. Experimental cases must
explicitly request the feature flag. Only the MDFF experimental test may be
skipped because its optional dependency is unavailable. Required GUI tests do
not run under text mode and missing displays are failures.

The runner copies checksum-verified fixtures into a unique temporary directory
for every case. Tests use RMSX_TEST_REPO, RMSX_TEST_PACKAGE, RMSX_TEST_WORKDIR and
TMPDIR, never development-machine paths. They emit an explicit PASS/FAIL receipt
through test_harness.tcl; a zero VMD process status is insufficient. Results and
logs are retained in the printed directory, with summary.json for automation.

## Data and lifecycle contracts

Use canonical residue identity and validated matrix/provenance helpers. Route
native output through staging/commit ownership checks; never glob-delete an
arbitrary user-selected directory. Load replacements transactionally. Keep
plugin-created molecules, callbacks, bindings, color/material/display changes
and temporary files in the session/effect ownership registry. Respect VMD
state changed independently by the user while a plugin window is open.

Operation/result state drives current-result UI and exports. A failed or
canceled operation does not publish a replacement result. Treat analysis,
loading and rendering as distinct outcomes, and expose full diagnostics.

## Heatmap exploration and collections

`Navigation` owns each canvas's model-coordinate cell records and zoom transform.
Use `to_canvas`/`to_model` for overlays and input coordinates; selection callbacks
receive model records. Route picking and count-bar selection through `choose`.
The `HeatmapTools` selection/geometry hooks refresh related controls. Its
`allowed` guard requires the displayed result generation and an idle operation;
replay, pin representations and timers must be released on replacement or close.
Replay distinguishes verified live-frame intervals from saved `slice_molid`
windows, whose original trajectory frames are unavailable.

`ThresholdControls::attach parent canvas dataset` returns a frame for the host
to place. `update_dataset` resets the previous filter and pending callback;
`detach` cancels timers and removes its overlays. `set_range canvas min max` and
`set_options canvas dict` debounce computation. Options include `categories`,
`min_frames`, `first_column`, `last_column` and `enabled`; `min_frames` counts
passing **columns**, not consecutive frames or physical dwell. Bounds are
inclusive, with masks and missing/nonfinite values excluded. `analyze` and
`selected_rows` are pure helpers; `refresh` follows geometry changes and
`sync_selection` updates current-column counts. The dataset remains immutable.

`Collections::load directory ?molid? ?plot-options...?` loads and activates a
saved TML collection; `Collections::select index ?plot-options...?` switches by
zero-based index. Omitting `molid` leaves imported data unbound. Explicit binding
resolves canonical residue identities and discards serialized molecule IDs and
atom indices, and validates frame bounds and nonempty free selections before
activation. Selection mapping requires verified common source information,
a unique residue match in both directions and a compatible frame/window;
unknown or conflicting sources clear the selection. Labels and row positions
are not identity. Keep live rows on `ResidueIdentity` schema 2, deriving occurrence
ordinals from the complete molecule before applying a residue selection.
Retain one row per representative atom, including alternate-location atoms,
to preserve the established row/value ordering.

The threshold smoke has portable pure-data/timer assertions and a separate
real-Tk branch when run by the GUI harness. A portable pass does not exercise
its widgets or pointer/zoom behavior. Use the registered zoom, exploration,
collection and live-identity regressions for changes to these contracts.

## CI and packaging

.github/workflows/tcl.yml runs portable Tcl/tooling checks on Linux, macOS and
Windows. It does not install or redistribute VMD. The manual vmd.yml workflow
requires a licensed self-hosted VMD runner with a usable display. Record actual
receipts before marking a platform supported; a workflow file is not evidence
that the platform passed.

`python3 scripts/build_release.py` creates a deterministic ZIP from explicit
source/package/docs/scripts/fixture inputs, with RELEASE_MANIFEST.json and an
external SHA-256 file. It requires a clean source revision. `--allow-dirty`
produces a clearly named local review snapshot and records that condition.
The archive excludes VMD binaries, historical source forks and local outputs.

## Archive and qualification gates

`scripts/release_files.txt` is the explicit reviewed file allowlist. Add each new
deliverable deliberately; `check_release.py` rejects files missing from it, stale
entries, traversal and symlinks. The builder reads only that allowlist and adds
a checksummed `RELEASE_MANIFEST.json`. It always creates a `-review.zip` archive.

Suite receipts include a hash of the exact source bytes, Git revision/dirty
state, architecture and runtime versions. A source change during a run fails
qualification. A complete local release profile does not certify other
platforms; see `docs/SUPPORT.md` for the still-required external runs.
