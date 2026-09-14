# Maintenance and VMD integration

The maintained artifact is a Tcl/Tk extension. The one-file reviewer launcher
embeds generated copies of that source; edits belong in the package and builder,
not in the generated `.vmd`. VMD itself and its existing Timeline plugin are
separate dependencies. No VMD fork is needed for the proposed extension entry.

## Ownership boundaries

Paths below are relative to `rmsxflipbooktimeline0.3.1/`.

| Responsibility | Source boundary | Review focus |
|---|---|---|
| Scientific calculations | `core/native_analysis.tcl`, `core/timeline_analysis.tcl` | Established formulas, representative atoms, alignment/reference assumptions and parity fixtures |
| Data identity and interchange | `core/residue_identity.tcl`, `core/matrix.tcl`, `core/timeline_io.tcl`, `core/collections.tcl` | Unique residue/frame mapping, masks, immutable datasets and backward-compatible formats |
| Result and resource lifetime | `core/session.tcl`, `core/effects.tcl`, `core/loader.tcl` | Generation guards, staged activation, cancellation and preserving later user changes |
| Files and provenance | `core/output_txn.tcl`, `core/manifest.tcl` | Owned output transactions, recovery and atomic export |
| Shared heatmap behavior | `visualization/navigation.tcl`, `visualization/heatmap_tools.tcl`, `visualization/threshold_controls.tcl` | Model/canvas transforms, event/pin/replay cleanup and selection consistency |
| Plot presentation | `visualization/plot_window.tcl`, `visualization/timeline_plot.tcl`, `gui/dashboard_window.tcl` | Readable layout; reuse shared exploration rather than duplicate it |
| Molecular view and export | `visualization/style.tcl`, `visualization/mouse_rotate.tcl`, `visualization/render.tcl` | Stable centers, supported VMD APIs, graphics capability and scene restoration |
| Packaging and qualification | repository `scripts/` and `.github/workflows/` | One source snapshot, explicit inventory, receipt validation and platform gates |

A primary lab maintainer, backup maintainer and VMD integration reviewer must
be named before public support is promised. The repository is institutional;
that does not by itself establish staffing or a response-time commitment.

## Change contract

- Keep public launch callbacks and documented analysis APIs compatible. Add
  optional arguments rather than silently changing established metric formulas.
- Use canonical residue identity. Labels, chain-or-segment guesses and row
  positions are not substitutes for a unique scientific mapping.
- Bind UI actions to the current result generation. A stale canvas must not
  select newly loaded molecules or change another result’s export target.
- Use `Navigation::to_model`/`to_canvas` and `choose` for heatmap input/overlays.
  Keep threshold and collection data immutable. Persistence counts passing
  columns, not consecutive dwell or physical time.
- Track representations by stable names and resolve indices at cleanup time.
  Register timers and input hooks; cancellation and cleanup must preserve
  independently changed VMD state.
- Add focused failure tests and register every smoke test in the suite manifest.
  Update documentation, fixture provenance and the explicit release inventory.

Run the focused tests first, then the full required profile after integration.
An old green receipt is not evidence for changed bytes. See
[verification](VERIFICATION.md) and the package’s
[developer notes](../rmsxflipbooktimeline0.3.1/DEVELOPER_NOTES.md).

## Run checks and build a review packet

Run these commands from the repository root. Replace the runtime placeholders
with your installed Tcl 8.6 and licensed VMD executable paths. Use the local
Python 3 command (`python3`, or `python` where configured). Choose new output
directories for each run so earlier evidence and artifacts remain intact.

```sh
python3 scripts/check_release.py
python3 scripts/run_tests.py --profile tcl --tclsh /path/to/tclsh8.6
python3 scripts/run_tests.py --profile release --tclsh /path/to/tclsh8.6 \
    --vmd /path/to/vmd --artifacts ../rmsx-release-check
python3 scripts/build_release.py --output ../rmsx-review-artifacts
```

`TCLSH` and `VMD_EXECUTABLE` can provide the same defaults; explicit flags take
precedence. Do not substitute Tcl 8.5 or assume Tcl 9 qualification. The release
profile needs a usable graphical VMD session and real rendering capability.
Commit the reviewed source before building a qualifying packet; `--allow-dirty`
is for disposable review snapshots and cannot establish final qualification.

For an additional check of VMD’s visualization-state playback route:

```sh
python3 scripts/demo_vmd_play_test.py --vmd /path/to/vmd \
    --output ../rmsx-play-check
```

That targeted transport check complements the full suite and manual File-menu
trial; it does not replace either. Retain the generated receipts and use the
handoff gate described in [VERIFICATION.md](VERIFICATION.md).

## Upstream integration proposal

The current proposal is an entry in the existing **Analysis** extension category,
with `rmsxflipbooktimeline` as the launch callback. After the package is placed
on VMD’s package search path, the conventional registration is:

```tcl
package require -exact rmsxflipbooktimeline 0.3.1
vmd_install_extension rmsxflipbooktimeline rmsxflipbooktimeline \
    "Analysis/RMSX and Flipbook Timeline"
```

For a separately installed package, use its idempotent `register.tcl` rather
than repeatedly running that snippet. It selects the intended package and
rejects a different already-loaded build. The exact registration location and
bootstrap API must be approved for the target VMD source revision; the snippet
is an integration proposal, not a claim that VMD has accepted or bundled it.
Keep VMD’s existing Timeline registration untouched.

Before writing an upstream patch, agree on the VMD/plugin-tree revision, target
versions, package placement, menu conventions, acceptable mouse/redraw hooks,
license handling and who owns updates. Produce the small packaging/registration
patch against that exact revision. A patch against an unspecified source tree
cannot be called ready to merge.

## Release and handover

Integrate reviewed changes into the release branch. Use
the exact source revision recorded in the matching build manifest, rather than
assuming that a branch name identifies the delivered build. Freeze a clean commit, generate
both artifacts together, retain their hashes and full test receipts, and pass
all targets in the handoff gate. Publish versioned release assets only after the audit and qualification pass.

Have a second developer follow only these documents to launch the artifact,
run Quick Check and the full test harness, diagnose a small failing case, make a
change, and rebuild matching artifacts. Record obstacles and update the guide.
This handover exercise, named maintainers and reproducible checks are stronger
maintenance evidence than a promise that the code will be easy to maintain.
