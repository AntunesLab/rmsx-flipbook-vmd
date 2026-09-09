# User guide

RMSX / Flipbook Timeline links a residue-by-time matrix to structures displayed
in VMD. RMSX/Flipbook analyzes files; Interactive Timeline analyzes a selected
live molecule or imported matrix. The persistent result area identifies which
result is currently shown and exported.

## First analysis

1. Open the plugin through the VMD Plugins/Extensions menu or run
   `rmsxflipbooktimeline` in its Tk console.
2. Choose a topology and trajectory. Use the matching atom order and a format
   supported by the VMD build. Select the intended molecule/chain and atoms.
3. Choose RMSX, Shift-Map or **1-lDDT**. These metrics have different meanings
   and units; see the result legend and method notes.
4. Choose the frame range and either slice count or frames per slice. Confirm
   the preview and physical time units before calculating. RMSX needs at least
   two frames in each slice.
5. Choose a parent location for the new result. The dashboard uses a new result
   directory, rather than silently replacing files already in that location.
6. Run. Progress and cancellation describe the current operation. A failed or
   canceled run must not replace the current successful result. Expand the
   diagnostic panel for a full error message.
7. Click a heatmap cell or use keyboard navigation to inspect the corresponding
   residue/time. VMD provides the structural context. Use the pop-out heatmap
   when more space is helpful.

## Viewing existing results

Choose an existing RMSX result folder and load it. Loading data does not imply
permission to rewrite its source files. Save exported data or images to an
explicit output location. The active-result header remains the authority for
what the export controls will use; selecting a different result updates it.

Old two-column residue identity tables can be imported when unambiguous. New
results retain segment, chain, residue number, insertion code and residue
ordinal so repeated numbering is distinguishable. Ambiguous legacy mappings
must produce a diagnostic rather than attach values to the wrong atoms.

## Metrics and masking

RMSX reports residue fluctuation within each time slice. Shift-Map reports
motion relative to a reference; 1-lDDT is a dimensionless local-distance-change
score, with zero meaning preserved local distances. It is deliberately labeled
as the complement of lDDT, not as confidence in a predicted structure.

A mask excludes selected residues from the display scaling range and marks
those cells separately. A missing value is not a measured zero. Keep the
legend, units, scaling range and mask meaning with any exported figure.

## Interactive Timeline

Select a live molecule from VMD, choose a metric and define its selection,
frame range and any reference parameters. Supported metrics include RMSD,
RMSF, displacement, step displacement, SASA, secondary structure, phi/psi and
angle changes, native contacts, hydrogen bonds, salt bridges and contacts
between selections. Their options appear in context. Secondary structure uses
categorical colors; angle aggregation uses circular rather than arithmetic
statistics where appropriate.

Click a matrix cell to select its residue/frame. A live molecule can jump to
that frame and display a neighborhood of structures. Imported matrices without
a matching live molecule can still be inspected/exported, but cannot provide
verified atom/frame navigation until a compatible source is associated.

TML and RMSX CSV/folders can be imported. TML data remains separate from VMD's
existing Timeline namespace. Do not use arbitrary Tcl residue functions with
untrusted input; those functions are experimental and hidden by default.

## Export and cleanup

Use Export for the **current result**. Include the metric, units, color scale,
frame/slice range and source identity. Matrix SVG remains resolution-independent;
PNG requires the supported image path, and molecular rendering depends on the
renderers available in the current VMD build. Unsupported choices should be
disabled or explain their missing capability.

A successful calculation and a successful rendered figure are separate events.
If figure generation fails, the result remains available and diagnostics explain
which export failed. Keep the generated provenance alongside publication data.

“Remove loaded flipbook” removes plugin-owned loaded structures; it does not
mean deleting trajectory files. Closing the dashboard releases temporary hooks,
overlays and views and restores tracked VMD state. Use VMD's own molecule list
to manage structures that were loaded independently of this plugin.

## Example walkthrough

The source archive includes single-chain 1UBQ and multichain protease examples.
`python3 scripts/launch.py --vmd /path/to/vmd --demo single` or `--demo multi`
creates a disposable example directory. Start by loading the existing result,
inspect a cell and a structure, then make a small new calculation and export.
The protease demo trajectory is a short 27-frame excerpt, not production data.

## Reporting a problem

Include the package VERSION, VMD version/architecture, Tcl/Tk versions, metric,
selection, relevant input format and expanded diagnostic text. Keep private
trajectories out of public reports. A small reproducible fixture is preferable.
See the source archive's docs/SUPPORT.md and docs/METHODS.md for the current
support matrix and scientific conventions.
