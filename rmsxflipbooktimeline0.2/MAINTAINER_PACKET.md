# RMSX/Flipbook Timeline 0.2 Maintainer Packet

## Release Intent

This package is a publication-oriented VMD Tcl plugin that combines the stable
RMSX/Flipbook workflow with a curated subset of Timeline-style matrix analysis.
It is designed to be installable as a normal community plugin first, while
leaving room for later discussion about replacing or modernizing the old VMD
Timeline plugin.

## VMD Plugin Compatibility Choices

- Plain Tcl package: `rmsxflipbooktimeline 0.2`.
- Package root exported through `env(RMSXFLIPBOOKTIMELINEDIR)`.
- Dashboard command: `rmsxflipbooktimeline`.
- Classic/legacy command: `rmsxflipbooktimeline_classic`.
- Suggested community menu path: `Plugins/Analysis/RMSX/Flipbook Timeline`.
- Possible Timeline replacement path: `Plugins/Analysis/Timeline`.

## Stable User-Facing Scope

The stable release surface is RMSX, Shift-Map, lDDT, masking, slice planning,
embedded/pop-out heatmaps, flipbook display, multi-chain output, image export,
Timeline matrices, supported live metrics, and TML import/export.

## Hidden Or Experimental Scope

Cross-correlation, raw coordinate metrics, arbitrary residue functions, test
metrics, mouse diagnostics, 3D viewer plot, repair utilities, manifest
inspection, and phi/psi region overlays are hidden from the normal workflow.

## External Review Items

These require machines or maintainer access outside this repository:

- Windows VMD smoke test.
- Linux VMD smoke test.
- Intel macOS VMD smoke test.
- Current non-beta VMD release smoke test.
- QwikMD developer review.
- VMD maintainer review.
- Final menu location decision.
- License/header expectations for official bundling.
