# RMSX/Flipbook Timeline 0.2 Installation

`rmsxflipbooktimeline 0.2` is a VMD Tcl plugin. It can be loaded from any Tcl
`auto_path` directory, or installed into a VMD-style plugin tree.

## Quick Load From This Repository

From the VMD Tk console:

```tcl
lappend auto_path "/path/to/workspace_plugins"
package require rmsxflipbooktimeline 0.2
rmsxflipbooktimeline
```

`rmsxflipbooktimeline` opens the release dashboard. The legacy/classic controls
remain available for advanced use:

```tcl
rmsxflipbooktimeline_classic
```

## User Plugin Path

VMD appends `tcl` below each `VMDPLUGINPATH` entry, so the package directory
should live one level below that `tcl` directory:

```sh
mkdir -p "$HOME/vmd-plugins/tcl"
cp -R rmsxflipbooktimeline0.2 "$HOME/vmd-plugins/tcl/"
export VMDPLUGINPATH="$HOME/vmd-plugins"
```

Then start VMD and run:

```tcl
package require rmsxflipbooktimeline 0.2
rmsxflipbooktimeline
```

## Bundled VMD-Style Layout

For a VMD distribution or site-wide install, place the directory here:

```text
plugins/noarch/tcl/rmsxflipbooktimeline0.2/
```

VMD will add `plugins/noarch/tcl` to `auto_path` during startup.

## Menu Registration Snippets

Community plugin menu location:

```tcl
vmd_install_default_extension rmsxflipbooktimeline rmsxflipbooktimeline \
    "Plugins/Analysis/RMSX/Flipbook Timeline"
```

Possible Timeline replacement location for maintainer discussion:

```tcl
vmd_install_default_extension rmsxflipbooktimeline rmsxflipbooktimeline \
    "Plugins/Analysis/Timeline"
```

The first option is safer for community release because it does not replace the
existing Timeline menu item.

## Shell Launch

The repository launcher is platform-neutral if `VMD_EXECUTABLE` points to VMD:

```sh
VMD_EXECUTABLE=/path/to/vmd scripts/launch_rmsxflipbooktimeline_release.sh
```

If `VMD_EXECUTABLE` is not set, the script uses `vmd` from `PATH`.

## Experimental Tools

Prototype tools are hidden by default. To expose them for development:

```sh
RMSXFLIPBOOKTIMELINE_EXPERIMENTAL=1 \
VMD_EXECUTABLE=/path/to/vmd \
scripts/launch_rmsxflipbooktimeline_release.sh
```

or set `RMSXFLIPBOOKTIMELINE_EXPERIMENTAL=1` before `package require`.
