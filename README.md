# RMSX / Flipbook for VMD

See residue-level changes across trajectory windows at once, directly on molecular structures, with linked heatmaps, RMSD/RMSF comparison plots, and figure export.

[![Watch the 30-second VMD demonstration](docs/media/demo-thumbnail.png)](https://github.com/AntunesLab/rmsx-flipbook-vmd/raw/refs/heads/main/docs/media/demo-30s-1440p.mp4)

**[Watch or download the 30-second demo — 1440p MP4](https://github.com/AntunesLab/rmsx-flipbook-vmd/raw/refs/heads/main/docs/media/demo-30s-1440p.mp4)**

## High-resolution Tachyon figure

![Nine protease trajectory windows rendered with Tachyon, with frame labels and a Viridis RMSX legend](docs/media/protease-tachyon-hd.png)

[Open the full-resolution figure (2560 pixels wide)](docs/media/protease-tachyon-hd.png). Nine unmasked protease windows, three frames each, colored by RMSX in Å. Rendered in VMD on Mac with Tachyon. [Media settings and provenance](docs/media/README.md).

## Try the plugin

This is public **0.3.1 developer-review source**, not an officially bundled VMD plugin. VMD with Tcl/Tk 8.6 must already be installed.

For the source checkout, follow the [quick start](docs/QUICK_START.md) or [installation instructions](rmsxflipbooktimeline0.3.1/INSTALL.md).

The one-file trial is being prepared for a versioned review release. Its workflow is:

1. Download **TRY_RMSX_0.3.1.vmd** from that release once available.
2. In VMD, choose **File → Load Visualization State…**.
3. Select the download to open the labeled precomputed nine-slice example.

The one-file download is **not published yet**. The video demonstrates that workflow using the recorded review build. The launcher needs no extraction, terminal commands, Python, or permanent installation. **Run** calculates a fresh result; **Multi** offers the two-chain example; **Quick Check** saves local diagnostics. On Windows, follow the **Open fresh VMD** prompt to enable residue thickness in a separate session.

Already have one simulation loaded? The current source can autopopulate empty input fields from its topology and trajectory files. See the [user guide](rmsxflipbooktimeline0.3.1/USER_GUIDE.md#already-loaded-a-simulation-in-vmd) for scope and frame-selection details.

The package uses VMD's existing **Analysis** extension category; the outer menu name may be **Extensions** or **Plugins**, depending on the VMD build.

## Review and support

- [First session and examples](docs/QUICK_START.md)
- [Developer handoff and feedback](docs/HANDOFF.md)
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

Source visibility is separate from release qualification. The [verification report](docs/VERIFICATION.md) and [support table](docs/SUPPORT.md) describe evidence boundaries; repository visibility does not certify untested runtimes or a final downloadable artifact.
