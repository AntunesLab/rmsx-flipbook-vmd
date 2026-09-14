# Contributor overview

RMSX / Flipbook is a Tcl/Tk extension for residue-level analysis, linked heatmaps, and side-by-side molecular views.

- [Installation](INSTALL.md): package loading and optional menu registration.
- [User guide](USER_GUIDE.md): analysis, interaction, and export.
- [Developer notes](DEVELOPER_NOTES.md): package structure and interfaces.
- [Maintainer guide](../docs/MAINTAINING.md): module ownership, tests, packaging, and proposed VMD integration.
- [Runtime support](../docs/SUPPORT.md): tested builds and qualification limits.
- [Methods](../docs/METHODS.md): scientific conventions.

The launch callback is `rmsxflipbooktimeline`. Runtime use requires VMD with Tcl/Tk 8.6; VMD itself is not included. Official bundling requires agreement with VMD maintainers on the target source revision, packaging, supported runtimes, and maintenance ownership.
