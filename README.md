# RMSX / Flipbook Timeline for VMD

A native Tcl/Tk extension linking residue-by-time motion maps to molecular
structures in VMD. This private review repository contains the active 0.3
source. The historical 0.2 baseline is retained in Git history; there is one
active package tree.

Normal analysis and viewing require VMD with Tcl/Tk 8.6. They do not require
Python, R, a web browser, or changes to VMD source. Python 3.9+ is used only by
installation, launch convenience, testing and packaging tools.

- [Install and register in VMD](rmsxflipbooktimeline0.3/INSTALL.md)
- [User guide](rmsxflipbooktimeline0.3/USER_GUIDE.md)
- [Scientific methods and formats](docs/METHODS.md)
- [Supported and pending environments](docs/SUPPORT.md)
- [Developer and test workflow](rmsxflipbooktimeline0.3/DEVELOPER_NOTES.md)
- [Meeting walkthrough and acceptance](docs/MEETING.md)
- [Changelog](CHANGELOG.md) · [License](LICENSE) · [Provenance](THIRD_PARTY_NOTICES.md)

From the VMD Tk console:

```tcl
lappend auto_path "/path/to/rmsx-flipbook-vmd"
package require -exact rmsxflipbooktimeline 0.3
rmsxflipbooktimeline
```

For a disposable preconfigured demonstration:

```sh
python3 scripts/launch.py --vmd /path/to/vmd --demo single
python3 scripts/launch.py --vmd /path/to/vmd --demo multi
```

These launchers copy demo data into a new temporary directory before use.
The repository fixtures remain unchanged. Standard VMD menu installation is
available with `python3 scripts/install.py install`.

A release claim requires the complete graphical release profile to pass on
each environment claimed as supported. A green Tcl-only CI check establishes
portable data/API tests; it does not certify VMD graphics or platform support.
