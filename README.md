# RMSX / Flipbook Timeline for VMD

Compare motion across time windows directly on molecular structures, alongside
linked residue heatmaps, RMSD/RMSF plots and figure export. This is a **private
0.3.1 review build**, not a public release or an officially bundled VMD plugin.

## Try it in three steps

1. Save the maintainer-provided **`TRY_RMSX_0.3.1.vmd`** file.
2. Open a graphical VMD session.
3. Choose **File → Load Visualization State…** and select
   **`TRY_RMSX_0.3.1.vmd`**. The labeled **Precomputed preview** opens automatically.

To calculate again, choose the ordinary **Run** button. **Multi** opens the
masked two-chain example. **Quick Check** performs a small fresh check;
**Save report…** saves diagnostics. The source ZIP and checksums are available
for code review and verification; they are not needed to open the demo.

VMD must already be installed. This route needs no Python, terminal commands,
permanent installation, or VMD source changes. The single-file reviewer launcher
is generated from the same reviewed source snapshot as the companion source ZIP;
it is not maintained as a separate plugin fork. A precomputed preview is clearly
labeled and is not evidence of a successful calculation on the reviewer’s machine.

The build opens through VMD’s existing **Analysis** extension category when
registered. It leaves VMD’s own Timeline entry intact. The outer menu name can
be **Extensions** or **Plugins**, depending on the VMD build.

## Review and support

- [First session and examples](docs/QUICK_START.md)
- [Private handoff and feedback](docs/HANDOFF.md)
- [Verification and exact build identity](docs/VERIFICATION.md)
- [Supported and pending environments](docs/SUPPORT.md)
- [Maintenance and upstream integration](docs/MAINTAINING.md)
- [Publication audit](docs/PUBLICATION_AUDIT.md)
- [Scientific methods](docs/METHODS.md) · [User guide](rmsxflipbooktimeline0.3.1/USER_GUIDE.md)
- [Optional installation](rmsxflipbooktimeline0.3.1/INSTALL.md)
- [Changelog](CHANGELOG.md) · [License](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)

Normal analysis, viewing and reviewer launch require VMD with Tcl/Tk 8.6.
Python 3.9+ is used by optional developer installation, CI and packaging tools.
The maintained source is `rmsxflipbooktimeline0.3.1/`; older versions remain in
Git history. Use the archive manifest and `BUILD_ID` to identify the exact bytes.

Public distribution remains **PENDING** until the publication audit and all
required VMD qualification targets pass for the final artifact. Portable Tcl CI
and a local Quick Check are useful evidence, but neither qualifies VMD graphics
on an untested platform. No public download is being offered by this document.
