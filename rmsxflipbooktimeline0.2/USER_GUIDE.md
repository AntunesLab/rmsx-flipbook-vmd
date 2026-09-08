# RMSX/Flipbook Timeline 0.2 User Guide

## Main Workflow

The release dashboard is organized around the intended analysis order:

1. Load topology and trajectory files, or load an existing RMSX output folder.
2. Choose a metric.
3. Set the chain, frame range, masking, and slice settings.
4. Run the analysis.
5. Inspect the embedded heatmap and flipbook structures.
6. Export images or data.

## RMSX/Flipbook Tab

This is the stable release workflow. It supports:

- RMSX, Shift-Map, and lDDT.
- Single-chain and multi-chain analyses.
- Masking for flexible/disordered regions, with masked residues excluded from
  display scaling.
- Slice count or frames-per-slice planning.
- Total simulation time estimation and manual total-time override.
- Embedded heatmap, pop-out heatmap, flipbook display, reset, clear, spacing,
  and image export.
- Palette selection for heatmaps and VMD User-field coloring.

## Interactive Timeline Tab

This tab brings Timeline-style matrix analysis into the Flipbook workflow. The
stable metrics are:

- displacement and displacement velocity
- RMSD and RMSF
- SASA
- secondary structure
- phi, psi, delta phi, and delta psi
- native contacts
- H-bonds, salt bridges, and inter-selection contacts

Clicking a matrix cell selects the residue/frame, jumps the trajectory when a
live molecule is available, and can create a small matrix-colored flipbook
neighborhood around the selected frame.

## Data Import And Export

Timeline data can be loaded from live VMD molecules, RMSX CSV/folder output, TML
files, or TML collections. Supported exports include filtered data, TML, SVG,
PNG, and VMD-rendered flipbook images.

## Stable Versus Experimental

The normal release UI hides prototype tools that are not ready for routine
community use. These include MDFF cross-correlation, raw coordinate/user-field
metrics, arbitrary residue functions, test/demo metrics, the 3D viewer plot, and
the phi/psi region overlay. They can be enabled for development with
`RMSXFLIPBOOKTIMELINE_EXPERIMENTAL=1`.

## Citation

Please cite RMSX/Flipbook when using this plugin:

Beruldsen, F., de Freitas, M.V. & Antunes, D.A. High resolution mapping of
protein motions in time and space with RMSX and Flipbook. Scientific Reports
(2026). https://doi.org/10.1038/s41598-026-39869-7
