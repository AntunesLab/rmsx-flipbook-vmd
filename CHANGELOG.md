# Changelog

## 0.3.1 — beta

- Autopopulate empty dashboard inputs from one loaded VMD simulation, including
  chain choices and an explicit Timeline molecule ID. Preserve existing input
  choices and refuse ambiguous or concatenated trajectory sources. RMSX retains
  its original file-based calculation behavior.

- Fix explicit `-method Tachyon` PNG/SVG exports to use VMD's bundled
  executable at the requested resolution without resizing the OpenGL window.
  Preserve camera, visibility, and display settings on success and failure.
  Forward Figure's renderer and lighting options instead of ignoring them.
- Suspend Cocoa drawing while programmatic native resizing settles, restoring
  the previous update state on success or failure. Prevent the dashboard's
  auto-fit timer from changing the view midway through a resize. Add live
  OpenGL framebuffer checks alongside the independent Tachyon export tests.
- Report measured export dimensions when Retina rounds an odd pixel size;
  use those dimensions for fitting and annotations.
- Wait for stable native display dimensions on Cocoa as well as X11 before
  rendering; reject stale-size images rather than comparing incompatible
  thickness proofs. Avoid reapplying unchanged render modes, which can hang
  the Linux VMD text display during scene restoration.

- Skip ray-traced lighting in temporary silhouette-fit proofs, while retaining
  the requested shadows and ambient occlusion in final exported images.
- Restore residue-dependent thickness on VMD 1.9.4 using NewCartoon instead
  of the non-modulating legacy Tube fallback. Use representation-appropriate
  8/12/32 mesh quality presets; keep NewTube and its presets on VMD 2.x.
- Remove oversized Aqua notebook content insets within the plugin and lay out
  Advanced utilities in two columns so they fit the 600-pixel minimum width.

- Center SVG slice and frame labels on the projected molecular positions in
  the rendered image, including its framing margins. Preserve uneven spacing
  and stagger crowded annotations without shifting their horizontal anchors.

- Preserve existing molecular camera matrices when temporary analysis inputs
  are loaded. Frame counting hides its input molecule and restores the prior
  top molecule, avoiding oversized previous results during setup.

- Keep coordinate rotations rigid during sustained mouse dragging and spinning.
  Remove numerical scale/shear from VMD view matrices before transforming
  display-axis rotations; verify molecular size and residue distances over
  20,000 native rotation commands at an oblique viewing angle.

- Keep residue selection within the displayed metric palette instead of adding
  red spheres. Enlarge the selected unmasked residue using its existing color
  scale; masked residues remain transparent. Test both chains in nine-slice views.

- Wait for X11 window resizing before rendering or restoring the display, and
  settle initial window dimensions before principal-axis fitting. This prevents
  stale export dimensions and a second fit on the first refresh. Resize waits
  are bounded and report failure if the requested dimensions cannot be reached.

- Show masked regions with transparency alone by default, without the yellow
  sphere overlay. The explicit marker API option remains available. Reviewer
  Quick Check validates the transparent material and exact mask identities
  without requiring the removed marker overlay.

- Orient new results and Reset View with each slice's longest principal axis
  vertical and its secondary axis horizontal. Keep multichain assemblies intact,
  tighten row spacing and refit after resize without changing source coordinates
  or metric calculations.
- Add an explicit Windows reviewer button to open a separate VMD session with
  native residue-thickness modulation configured before startup. Preserve the
  original session. Verify actual low/high thickness geometry in Quick Check
  and a required render test rather than inferring it from Tcl settings.

- Use platform-native temporary files for view fitting and comparison structures.
  Stage Windows native PDB writes through a short temporary path before Tcl
  copies them into the output transaction, avoiding VMD's native path-length
  limit without changing the working directory.
- Finish loading cross-correlation volumes before analysis, using the explicit
  target molecule. Use a deterministic Tcl-written density fixture to avoid
  an independently reproduced Windows VMD `mdff sim` output-handle leak.
- Record the official Windows a6 installer's inconsistent a7 startup banner
  while still requiring its a6 runtime identity, architecture and binary hash.
- Add a generated single-file reviewer route through VMD’s File → Load
  Visualization State menu, with labeled precomputed single/multichain previews,
  fresh calculation and a bounded Quick Check/report workflow.
- Bind the reviewer launcher and companion source archive to a shared BUILD_ID
  and file checksums; keep generated artifacts separate from maintained source.
- Add developer documentation, maintenance ownership, provenance audit and
  artifact-specific qualification guidance. Public distribution remains pending.
- Preserve the Tcl/Tk extension and existing Analysis-menu category; retain
  public launch callbacks and VMD’s own Timeline entry.
- Fit wide nine-slice exports using the final image aspect ratio, including
  spacing after in-place rotation; refine very small proof images once.
- Place figure slice names and frame/time annotations on separate editable
  lines so long nine-slice labels remain readable.
- Use reproducible, curated synthetic trajectories for native regression tests,
  avoiding a confirmed VMD 2.0.1a1 frame-duplication crash in fixture generation.
  Reject native crash diagnostics even when a launcher returns zero after a
  test has written its completion receipt.

## 0.3 — review build

- Restore shared heatmap exploration: Shift-drag events, Ctrl+Shift row addition,
  persistent row pins, and playback of verified live frames or loaded native
  snapshot windows, with owned representation/timer cleanup.
- Add independent row/time zoom, rectangle zoom and an every-residue view, with
  linked picking and overlays following the canvas transform.
- Add live inclusive threshold bounds, categorical toggles, clickable per-column
  counts and minimum-passing-column highlights. Exclude masked, missing and
  nonfinite values; persistence counts columns rather than consecutive dwell.
- Add saved TML collection switching with unique residue/frame selection mapping;
  unify live residue rows with canonical identity, preserving literal chains,
  insertion codes and full-molecule occurrence ordinals.

- Recover stale/black OpenGL views with a debounced resize/expose refresh and a 750 ms visible-result redraw pulse. Invalidate the scene by reapplying an unchanged owned viewing matrix; retain positions and orientation, pause during analysis/export, and cancel timers on close.

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
