# Installation

The package requires VMD with Tcl 8.6; the dashboard requires Tk 8.6. VMD is
obtained separately. Python 3.9+ is needed only for the optional installer and
other development tools, not to use the plugin.

## User installation

From this repository or the unpacked source release:

```sh
python3 scripts/install.py install
```

This copies the package to `$HOME/vmd-plugins/tcl/rmsxflipbooktimeline0.3` and
adds one marked startup block to `.vmdrc` (`vmd.rc` on Windows). An existing
startup file receives a backup the first time it is changed. The installer
preserves other startup content and refuses to replace an unowned package.
Restart VMD and open **Plugins/Extensions → Analysis → RMSX and Flipbook Timeline**.
The exact top-level menu wording depends on the VMD version.

To choose a different user location or startup file:

```sh
python3 scripts/install.py install --prefix /path/to/vmd-plugins --startup-file /path/to/.vmdrc
```

To uninstall, use the same locations:

```sh
python3 scripts/install.py uninstall
```

Uninstall removes only receipt-verified package files and the marked startup
block. If installed files have been edited or extra files added, it refuses to
delete them. Preserve those changes before removing the installation.

## Manual installation (no Python)

Place this directory beneath a Tcl package path, for example:
`plugins/noarch/tcl/rmsxflipbooktimeline0.3/`, or
`$HOME/vmd-plugins/tcl/rmsxflipbooktimeline0.3/`.

VMD also supports `VMDPLUGINPATH=$HOME/vmd-plugins`; it appends `tcl` beneath
that location. In a VMD Tk console, a direct load is sufficient:

```tcl
lappend auto_path "/path/to/package-parent"
package require -exact rmsxflipbooktimeline 0.3
rmsxflipbooktimeline
```

For persistent menu registration, source this package's `register.tcl` from
your VMD startup file with `source -encoding utf-8`, after adding its parent to
`auto_path`. The helper uses:

```tcl
vmd_install_extension rmsxflipbooktimeline rmsxflipbooktimeline \
    "Analysis/RMSX and Flipbook Timeline"
```

Official bundling is a separate maintainer decision. A VMD maintainer can use
`vmd_install_default_extension` with the same callback/menu label. Neither
installation route replaces VMD's existing Timeline plugin.

## Launch and troubleshooting

`python3 scripts/launch.py --vmd /path/to/vmd` launches a fresh graphical VMD
instance. `VMD_EXECUTABLE` may supply the executable instead. The release shell
launchers are convenience wrappers around the same tool; Windows users can
invoke the Python script directly.

A missing Tk display is a GUI dependency failure; text-mode VMD remains useful
for supported backend calculations. A Tcl 9-only system shell is not the
Tcl 8.6 test target: use `--tclsh /path/to/tclsh8.6` for development checks.

Experimental tools require `RMSXFLIPBOOKTIMELINE_EXPERIMENTAL=1` before loading
the package. Leave that unset for the reviewed stable workflow.
