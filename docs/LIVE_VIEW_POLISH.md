# Live-view polish candidate

The interactive scene now prefers GLSL when VMD advertises it and requests antialiasing. Both settings use scene leases: Close retains the scene, Remove restores earlier settings only if the user has not subsequently changed them. Unsupported display capabilities are tolerated. Palette switching does not alter material or opacity; the existing AOChalky representation remains unchanged.

GLSL and antialiasing improve interactive shading and edge smoothness. They do not reproduce Tachyon ambient occlusion. Adding a molecular surface would obscure the residue-thickness signal and is not a default in this candidate. VMD references: https://www.ks.uiuc.edu/Research/vmd/current/ug/node126.html and https://www.ks.uiuc.edu/Research/vmd/minitutorials/tachyonao/ .

Slice numbers use a plugin-scoped font at approximately 90% of TkDefaultFont's size, respecting positive point and negative pixel sizes. The bar height follows font metrics and leaves clearance from its borders, including after font scaling.

Local verification on 2026-09-13: 27 Tcl tests and 2 native VMD 2.0b1 dashboard/lifecycle tests passed. Actual dashboard glyph bounds and screenshots were inspected. Live Viridis/Turbo/BWR switches preserved material, opacity, representation and display settings. These edits are on codex/live-view-polish after frozen build 8eb0e31; other platform qualification is pending. No frozen download was replaced. Evidence: recordings/rmsx-review-8eb0e31-4k/qa under the development workspace.
