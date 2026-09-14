# RMSX / Flipbook Timeline 0.3.1 beta

The active native VMD Tcl package is `rmsxflipbooktimeline 0.3.1`. VERSION in this
directory is the authoritative version. There is one active source tree.

Read INSTALL.md, USER_GUIDE.md, DEVELOPER_NOTES.md and MAINTAINER_PACKET.md.
License and third-party notices ship in this directory. Scientific citation is
in CITATION.cff and available through `rmsxflipbooktimeline_citation`.

`rmsxflipbooktimeline` opens the compact dashboard;
`rmsxflipbooktimeline_classic` preserves the legacy control surface.
Experimental tools remain hidden unless explicitly enabled before package load.

The source release includes curated fixtures, complete test classification,
installation and archive tools, and platform evidence guidance. Release checks
must use `python3 scripts/run_tests.py --profile release --vmd /path/to/vmd`.
Missing required GUI/render capabilities fail that profile. Experimental MDFF
is reported separately when unavailable. Tcl-only tests are not graphical
validation. Review build status does not imply VMD maintainer endorsement.
