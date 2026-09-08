# RMSX/Flipbook Timeline 0.2 Developer Notes

## Package Surface

The package name is `rmsxflipbooktimeline` and the release version is `0.2`.
The package index sets `env(RMSXFLIPBOOKTIMELINEDIR)` to the package directory,
then sources `rmsxflipbooktimeline.tcl`.

Public launch commands:

- `rmsxflipbooktimeline`
- `rmsxflipbooktimeline_dashboard`
- `rmsxflipbooktimeline_classic`
- `rmsxflipbooktimeline_about`
- `rmsxflipbooktimeline_citation`

Most scripted functionality lives under `::RMSXFlipbookTimeline::*`.

## Feature Gates

Release builds hide experimental modules unless
`RMSXFLIPBOOKTIMELINE_EXPERIMENTAL=1` is set before package load. Gated tools
include the 3D viewer plot and phi/psi region overlay modules. Dashboard metric
metadata also hides experimental metrics by default.

## Side Effects And Cleanup

VMD plugins can leave state behind through molecules, reps, traces, temp files,
mouse hooks, and window callbacks. Release cleanup should go through
`::RMSXFlipbookTimeline::cleanup_side_effects`, which delegates to the central
effects registry. Clear and Reset may delete loaded flipbook molecules; closing
the dashboard should clean temporary side effects but leave loaded RMSX output
alone.

Do not reintroduce automatic display resize or refresh loops for centering.
Display centering should remain conservative and manually verifiable.

## Release Checks

Run:

```sh
scripts/test_rmsxflipbooktimeline_release.sh
```

The release path check rejects local user paths, local beta VMD bundle paths,
and other Mac-first assumptions on the release surface.

## Manual Validation Matrix

Before a tagged release, manually test:

- single-chain 1UBQ RMSX
- multi-chain RMSX
- masked RMSX with visible heatmap masking and scaling exclusion
- Shift-Map and lDDT
- Timeline displacement
- Timeline secondary structure
- Timeline selection to flipbook neighborhood
- embedded and pop-out heatmap resize
- image export
- Clear, Reset, and close-window cleanup
