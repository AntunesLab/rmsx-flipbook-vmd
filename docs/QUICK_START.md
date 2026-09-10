# A first RMSX/Flipbook session — 0.3.1

This is the private reviewer route. Obtain the generated packet from the
maintainer; a public download is not yet available.

1. Save the maintainer-provided `TRY_RMSX_0.3.1.vmd` file.
2. Open a graphical VMD session.
3. Choose **File → Load Visualization State…** and select
   **`TRY_RMSX_0.3.1.vmd`**. The **Precomputed preview** opens automatically.

Use the ordinary **Run** button when you want to calculate a new result.
**Quick Check** runs a bounded fresh check; **Save report…** saves diagnostics.


A fresh launch opens the nine-window Single preview after the dashboard paints.
Reopening the same build reuses it. Another already-loaded build requires a
fresh VMD session. No Python or permanent installation is needed for this route.

## Two reproducible examples

| Reviewer button | Inputs and selection | Frames and windows | Mask |
|---|---|---|---|
| Single | `1UBQ.pdb` + `mon_sys.dcd`; group `7` | 0–314; nine 35-frame windows | None |
| Multi | `protease_backbone.pdb` + `short_protease_backbone.dcd`; all chains | 0–26; nine three-frame windows | `resid 25:26` |

Leave physical time unspecified; these examples use frame/window labels.

The Multi precomputed preview was freshly generated from these same 27 input
frames for the 0.3.1 review build. Earlier multichain seed results are retained
for regression tests and are not relabeled as this example.

Run uses the normal pipeline and publishes into a unique output folder.
A displayed precomputed preview establishes loading, not calculation success.
Quick Check uses a separate bounded three-slice sample for the chosen example.
The bundled inputs remain unchanged. These compact examples demonstrate the
workflow; they do not establish equilibrium sampling.

The header describes the current result. Editing setup fields prepares another
calculation without changing that result’s export target. Stop requests
cancellation after the current VMD calculation returns.

## Earlier scientific export examples

The following three-window figures were generated with the earlier 0.3 native
export path. They illustrate output appearance and scientific labels; they are
not screenshots or qualification evidence for the 0.3.1 reviewer launcher.

![Earlier three-window ubiquitin export with its actual RMSX scale](figures/ubiquitin.png)

[Editable ubiquitin SVG](figures/ubiquitin.svg).

![Earlier three-window masked two-chain protease export](figures/protease.png)

[Editable protease SVG](figures/protease.svg). The legend reports the applied
range in ångströms. Masked residues retain their distinct treatment.

## Select, export and clean up

1. Focus a heatmap with Tab. Use arrows, Home/End or Ctrl+Home/End to navigate;
   Enter activates the cell and Escape clears highlighting. Mouse selection
   uses the same structure-linking action.
2. Use **3D Image**, **Figure**, or **Matrix** for the current result. Default
   3D framing fits the owned structures with a small margin while keeping their
   orientation. Current view and the RMSX preset are explicit alternatives.
3. Close the panel to keep the displayed scene. Reopen it through the existing Analysis extension entry.
   Use **Remove** to delete the plugin's result resources and restore settings
   still equal to the plugin's last applied values.
4. If calculation is saved but display activation fails, retain the output
   folder and use the saved-result retry action. The previous result stays active.

To regenerate both native analyses and 2400-pixel PNG/SVG exports, set
`RMSX_EXAMPLE_REPO` to the checkout and `RMSX_EXAMPLE_OUTPUT` to a new output
directory, then launch **windowed VMD** with
`-e scripts/make_meeting_examples.tcl`. An explicit `COMPLETED.tcldict` receipt
marks successful completion. The generation script never overwrites an existing
result. The [meeting walkthrough](MEETING.md) and [methods](METHODS.md) explain
the review sequence and scientific conventions.

### Linked comparison plots

Keep **Compare: RMSD / RMSF** enabled above the heatmap. RMSD shows displacement over frames; click its curve area to choose a slice while retaining the selected residue. RMSF shows residue fluctuations over the analyzed trajectory; click its curve area to choose a residue while retaining the selected slice. Hover shows the value in Å. Heatmap selection adds red guides to both comparison plots. Each chain retains its own RMSF mapping. RMSD linking uses the current result’s actual frame ranges; folders without that metadata remain hover-only for RMSD.

### Result details and diagnostics

The one-line header identifies the displayed dataset, metric, and slice/frame count. **Details…** expands Result Details for the frame ranges, chain/group, selection, input/output paths, and method. **Copy Details** copies that metadata. **Log…** opens diagnostics; **Save Log…** saves the current result details and diagnostic history together. **Hide** collapses the panel. Opening either panel does not change the current result or the bottom status message.

The main tab groups source choice and file paths under **Inputs**. The first action row runs analysis or opens/exports the result; the second keeps **Spacing − / +**, **Reset View**, and **Remove…** together. **Retry view** appears only when a saved calculation needs display recovery, and the progress bar appears during an operation.

Per-protein rotation is enabled when a dashboard result finishes loading, including preview and Retry View paths. Use normal rotation dragging in VMD’s molecular window: each protein turns around its own center while the slice arrangement stays fixed.

The dashboard automatically repaints the molecular viewer after resize/expose and result loading, with a lightweight 750 ms refresh while a result is visible. The refresh marks the scene for repaint without shifting or rotating it. It pauses during analysis and export, stops when the panel closes, and resumes when reopened.

## Explore an event

Shift-drag across rows and columns to select an event. Ctrl+Shift adds rows.
Pin rows highlights the same selections across loaded structures; Unpin rows
removes those pins. Play windows steps through saved native snapshots; Play
event uses a verified live trajectory mapping when available. Stop ends replay
and restores frames that have not been independently changed. Escape clears
the exploration selection.

Tools provides separate time/row zoom, Fit all, Every residue, and threshold
controls. Right-drag zooms a rectangle. Threshold bounds are inclusive; masked,
missing and nonfinite values are excluded. Minimum passing columns describes
persistence across the selected columns, not consecutive dwell or physical time.
Saved TML collections provide dataset switching with selection retained only
when source, residue identity and frame/window mappings resolve uniquely.
