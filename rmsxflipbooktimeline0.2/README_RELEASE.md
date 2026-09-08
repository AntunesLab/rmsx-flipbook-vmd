# RMSX/Flipbook Timeline 0.2 Release Notes

This package is the publication-oriented release fork of `rmsxflipbooktimeline`.
It is separate from `rmsxflipbooktimeline0.1`, which remains available for the
prototype/development workflow.

Release-facing documents:

- `INSTALL.md`: VMD install and menu registration notes.
- `USER_GUIDE.md`: stable RMSX/Flipbook and Interactive Timeline workflows.
- `DEVELOPER_NOTES.md`: package surface, cleanup policy, and release checks.
- `MAINTAINER_PACKET.md`: summary for VMD/QwikMD maintainer review.
- `CITATION.cff`: machine-readable citation metadata.

## Load In VMD

From the VMD Tk console:

```tcl
lappend auto_path "/path/to/workspace_plugins"
package require rmsxflipbooktimeline 0.2
rmsxflipbooktimeline
```

`rmsxflipbooktimeline` opens the dashboard UI. The dense legacy control surface
is still available:

```tcl
rmsxflipbooktimeline_classic
```

When both 0.1 and 0.2 are installed in the same `auto_path`, Tcl will normally
choose the newest compatible version. To intentionally load the old 0.1 package,
use:

```tcl
package require -exact rmsxflipbooktimeline 0.1
```

For shell launches, prefer:

```sh
VMD_EXECUTABLE=/path/to/vmd scripts/launch_rmsxflipbooktimeline_release.sh
```

The release launcher does not assume a macOS VMD bundle. If `VMD_EXECUTABLE` is
not set, it uses `vmd` from `PATH`.

For VMD-style plugin installs, place the package under:

```text
plugins/noarch/tcl/rmsxflipbooktimeline0.2/
```

or place it under a user plugin path such as:

```text
$HOME/vmd-plugins/tcl/rmsxflipbooktimeline0.2/
```

and set `VMDPLUGINPATH=$HOME/vmd-plugins`.

## Stable UI Surface

The first tab is the supported RMSX/Flipbook workflow:

- RMSX, Shift-Map, and lDDT analysis
- single-chain and multi-chain output
- masking with masked values excluded from the display scaling range
- slice planning and total-time estimation
- embedded and pop-out heatmap views
- flipbook display, spacing, reset, clear, and image export

The second tab is the supported Interactive Timeline workflow:

- displacement, displacement velocity, RMSD, RMSF, SASA
- secondary structure, phi, psi, delta phi/psi
- native contacts, H-bonds, salt bridges, inter-selection contacts
- TML import/export and collection loading
- matrix cell selection linked to frame navigation and flipbook neighborhoods

## Experimental Feature Gate

The release UI hides prototype/compatibility tools by default, including raw
coordinate/user-field metrics, cross-correlation, arbitrary Tcl residue
functions, Timeline test metrics, the VMD RMSD tool shim, the 3D viewer plot, and
the phi/psi region overlay.

To expose these tools for development:

```sh
RMSXFLIPBOOKTIMELINE_EXPERIMENTAL=1 VMD_EXECUTABLE=/path/to/vmd scripts/launch_rmsxflipbooktimeline_release.sh
```

or set the environment variable before `package require rmsxflipbooktimeline 0.2`.

## Cleanup Policy

Release 0.2 adds a central side-effect cleanup registry. Clear, Reset, and window
close paths use it to clean temporary plot windows, Timeline neighborhoods,
overlays, and mouse hooks. Loaded RMSX flipbook molecules are deleted by Clear
and Reset, but not by simply closing the dashboard window.

## Release Checks

Run the release gate:

```sh
scripts/test_rmsxflipbooktimeline_release.sh
```

The headless checks always run. VMD GUI checks run only when `VMD_EXECUTABLE` is
set or `vmd` is available on `PATH`.

The path checker rejects local development assumptions such as user-specific
home paths, workspace-local VMD bundle paths, and beta-app bundle names in the
0.2 release surface.
