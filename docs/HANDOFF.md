# Private reviewer handoff — 0.3.1

**Status: private review; public distribution pending.** Share the generated
review packet directly with the agreed reviewer. Use the exact source revision
recorded in its build manifest; do not substitute a branch checkout, an earlier
archive, or a launcher from another packet.

## Reviewer route

1. Save the maintainer-provided `TRY_RMSX_0.3.1.vmd` file.
2. Open a graphical VMD session.
3. Choose **File → Load Visualization State…** and select
   **`TRY_RMSX_0.3.1.vmd`**. The **Precomputed preview** opens automatically.

Use the ordinary **Run** button when you want to calculate a new result.
**Quick Check** runs a bounded fresh check; **Save report…** saves diagnostics.


The launcher provides **Single**, **Multi**, **Quick Check**, and
**Save report…**. Single uses ubiquitin with nine 35-frame windows over frames
0–314. Multi uses both protease chains with nine three-frame windows over
frames 0–26 and mask `resid 25:26`. Physical time remains unspecified.

The Multi precomputed preview was freshly generated from these same 27 input
frames for the 0.3.1 review build. Earlier multichain seed results are retained
for regression tests and are not relabeled as this example.


Run uses the ordinary dashboard analysis path and the current settings.
Quick Check uses a bounded three-slice calculation for the selected example,
checks the candidate result, and retains the displayed result. It writes human
`report.txt` and machine `report.json` receipts beneath the reviewer workspace’s
`outputs/quick-check-<timestamp>/` directory. Save report uses VMD’s native file
chooser and saves the JSON report with a text companion.
The workspace and report paths are shown locally; inspect them before sharing
if they include private dataset names or local account paths.

## A five-minute walkthrough

- Rotate in VMD’s molecular window; each protein should turn about its own center.
- Click a heatmap cell, then the RMSD/RMSF comparison plots.
- Shift-drag an event; pin its rows across the structures and play the selected
  windows. Live Timeline datasets with verified frame mappings can replay frames.
- Open Tools for independent row/time zoom, Every residue and threshold counts.
- Switch to Multi; confirm both chains and the visible residue mask.
- Run and save the Quick Check report. Export a figure if rendering is
  available, then resize the viewer and confirm that it repaints.

A current-launcher screenshot and recording belong in the final packet only
after capture from that exact build. The scientific figures in QUICK_START
are explicitly labeled as earlier 0.3 examples; they do not qualify this launcher.

## Copy-ready invitation — not sent

> I’d like your feedback on a private RMSX/Flipbook extension for VMD. It adds
> simultaneous structural views of trajectory windows, linked quantitative plots,
> and figure export while preserving the existing Timeline workflow. To try the
> attached build, open VMD’s File → Load Visualization State and choose
> TRY_RMSX_0.3.1.vmd. The first view is a labeled precomputed example; Run
> performs a calculation. Please try Quick Check and send its report with your
> VMD version and operating system. We would especially value your advice on
> supported integration hooks, packaging, maintenance, and the path to inclusion.

For the developer invitation, link the review prerelease and short video instead of attaching archives. Keep the committee form in a separate email to Rafael. No invitation is sent by the build or test tools.

## Feedback to retain

Independent first-time trials are waived by the user for this developer review; no external tester is required. The [reviewer sheet](FIRST_TRY.md) remains optional feedback guidance. This waiver does not count as a pass or waive any technical check.

Record the launcher SHA-256, BUILD_ID, VMD/Tcl/Tk versions, OS and architecture,
Quick Check report, and the smallest steps that reproduce a problem. Include
whether the File-menu launch, real mouse rotation, OpenGL redraw and export were
actually inspected. “Quick Check passed” alone is not a full platform claim.

## Developer-review gate

Run `scripts/handoff_gate.py --profile developer-review --waiver qualification-waiver.json` with the ordinary evidence, artifact, build ID, revision and output arguments. The waiver must explicitly name only `unassisted_trial_under_two_minutes`, all five targets, developer-review scope, user authorization, and `WAIVED_BY_USER` with `passed: false` and `other_checks_waived: false`. Each corresponding evidence row must also say `WAIVED_BY_USER`; missing rows fail. Keep the authorization in the private qualification packet rather than the distributed source.

`developer_review_ready` may pass with this waiver; `release_qualified` remains false. The default `release` profile rejects waivers. All native, Quick Check, manual technical, and exact-build audit requirements remain enforced.
