# RMSX / Flipbook Timeline for VMD

Compare motion across time windows directly on molecular structures, alongside
linked residue heatmaps, RMSD/RMSF plots and figure export. This is a **0.3.1 developer-review build**, not an officially bundled VMD plugin. Publication remains gated on the final verification report.

## Try it in three steps

1. Download **`TRY_RMSX_0.3.1.vmd`** from the [review assets](https://github.com/AntunesLab/rmsx-flipbook-vmd/releases).
2. Open VMD and choose **File → Load Visualization State…**.
3. Select the downloaded file. The labeled **Precomputed preview** opens automatically.

The review assets also contain the captioned 30-second demonstration and platform-specific verification report. Until the qualification gate is complete, the repository remains private and no public download is available.

To calculate again, choose the ordinary **Run** button. **Multi** opens the
masked two-chain example. **Quick Check** performs a small fresh check;
**Save report…** saves diagnostics. The source ZIP and checksums are available
for code review and verification; they are not needed to open the demo.

On Windows, choose **Open fresh VMD** when the demo requests it. That button
opens a separate session with residue thickness enabled before VMD starts;
the original session stays open. Windows VMD may ignore thickness settings
changed after startup. Quick Check tests the rendered geometry as well as values.

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
