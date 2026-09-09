# Maintainer meeting walkthrough

Aim for a short demonstration of one coherent workflow, followed by the
implementation and scientific questions that require maintainer input. Use a
single source revision and a known VMD build; retain the validation receipt.

## Before the meeting

- Complete the required release profile on the demonstration Mac, after the
  final code changes. Review every result; a Tcl-only run is insufficient.
- Test a clean user installation and open the plugin through VMD's menu.
- Prepare the single-chain and multichain disposable demos, a PNG/SVG figure,
  and a saved screenshot as a fallback if the live display environment changes.
- Keep experiment-only controls off. Place VMD's molecular window and the
  compact dashboard side by side at normal display scaling.
- Verify the normal 600px minimum dashboard width without clipped controls,
  readable labels, keyboard focus, resizing and scroll access on every tab.

## Suggested demonstration (about ten minutes)

1. Open the plugin from the VMD menu. Identify the source and active-result
   header; show that repeated opening reuses the existing window.
2. Load the precomputed 1UBQ example, inspect the legend/units and select a
   heatmap cell. Show linked residue/time structure context and keyboard access.
3. Run a small new RMSX calculation into its own result directory. Point out
   slice planning, progress and the distinction between a completed result and
   an image export. Demonstrate a canceled operation retaining the prior result.
4. Switch to the protease example. Show both chains and the distinct treatment of masked/clipped
   values; keep the scientific story focused on the difference between chains.
5. Open Interactive Timeline on a compatible live molecule, inspect one stable
   metric and link a selected matrix cell to its frame/neighborhood.
6. Export the active result with metric, unit, scale, mask legend and provenance.
   Change an uncommitted form field and show it does not redirect that export.
7. Close/remove the plugin's temporary view and verify the original VMD scene
   remains usable. Show expanded diagnostics for one harmless invalid input.

## Review material

Bring README/INSTALL, USER_GUIDE, METHODS, SUPPORT, CHANGELOG, third-party notices,
the complete test receipt, and the versioned archive/checksum. The source uses
one active package; baseline0.2 is in Git history. Explain the separation between
analysis, result state, matrix interchange, output transactions and VMD effects.

## Questions for the VMD maintainer

- Is the community extension menu/callback and package layout appropriate for
  the VMD builds they support? What is the preferred bundling path?
- Which VMD/Tcl/Tk versions and platforms must qualify before public support?
- Which mouse/display/material restoration conventions should plugins follow
  when users modify global VMD state while a plugin window is open?
- Are the current residue-identity and TML interoperability choices suitable?
- Which scientific comparisons or upstream lDDT convention notes need more
  evidence, and what contribution/license notices are expected for bundling?

## Review-ready acceptance

The demonstrated source revision must install cleanly; preserve user files and
scene state on failure/cancel/close; show readable, unclipped native controls;
export exactly the active result; pass required numerical/GUI/render tests;
and ship clear methods, provenance and honest platform status. External
platform certification and official bundling approval remain explicit follow-up
items until evidence or maintainer decisions are available.
