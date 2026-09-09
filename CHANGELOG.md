# Changelog

## 0.3 — review build

- Enable per-protein rotation after every successful dashboard result activation, including direct preview loading and saved-display retry. Verify fixed centers after loading, spacing, Reset View, reopen, and retry.

- Align input and slice controls, combine source choice with Inputs, and group analysis and view buttons independently. Reduce panel borders, hide idle progress and unavailable Retry View, and preserve the compact header and linked plots.

- Replace the verbose header with a single dataset/metric/count line. Move reproducibility metadata into collapsible Result Details, separate diagnostics into Log, and add Copy Details and atomic Save Log actions.

- Restore linked comparison plots: click RMSD to choose a slice and RMSF to choose a residue, with cross-plot selection markers, values in Å, and per-canvas/result guards. Move the comparison toggle above the embedded heatmap and align RMSF samples to heatmap cell centers.
- Restore per-protein rotation when VMD reopens a closed dashboard; each
  protein turns about its own center while the flipbook row stays in place.
- One version authority (`rmsxflipbooktimeline0.3/VERSION`) and active package.
- Compact native dashboard with persistent result context, readable metric
  labels, progress/cancel, expandable diagnostics and clearer destructive actions.
- Managed output transactions, result provenance and full residue identity;
  staged loading, VMD state restoration and export capability checks.
- Portable user installation/menu registration and isolated example launchers.
- Explicit test receipts, complete suite manifest, disposable per-test inputs
  and outputs, real GUI/render test categories and fixture checksums.
- Cross-platform Tcl CI plus manually dispatched licensed VMD runner workflow.
- MIT licensing, upstream notices, support/method documentation and deterministic
  source archives with checksums. Platform certification remains evidence-based.

## 0.2 — imported baseline

The research prototype combined native RMSX/Shift-Map/lDDT calculations with
Timeline matrices, linked structure navigation, TML import/export and rendering.
The unmodified baseline is preserved in repository history.
