# Beta quick start

You need graphical **VMD with Tcl/Tk 8.6**. [Tested builds and limitations](SUPPORT.md).

## Open the example

The public one-file download is pending. With the supplied beta file:

1. Save **`TRY_RMSX_0.3.1.vmd`** anywhere on your computer.
2. In VMD, choose **File → Load Visualization State…**.
3. Select that file.

The dashboard and **nine precomputed structures** open automatically. No extraction, installation, terminal commands, or path editing. No network connection is needed after download.

**Windows:** click **Open fresh VMD** if prompted. This enables residue thickness in a separate session and keeps your original session open.

## Try three things

- **Run:** calculate a fresh result with the filled-in inputs.
- **Click a heatmap cell, then drag in the molecular window:** highlight a residue and rotate each protein in place.
- **Multi → Run:** try the two-chain example. **Single** returns to ubiquitin.

For an image, choose **Figure**, enter a filename, and click **Save**. For diagnostics, choose **Quick Check**, then **Save report…**; neither is required to try the example.

## Use your simulation

Choose your topology and trajectory in **Inputs**, then click **Run**. When opening the ordinary dashboard with exactly one supported simulation already loaded, empty inputs fill automatically. [Details](../rmsxflipbooktimeline0.3.1/USER_GUIDE.md#already-loaded-a-simulation-in-vmd).

## If something goes wrong

- **A different build is already loaded:** restart VMD, then open the beta file.
- **Want to keep the scene?** Close the panel. Reopen it from the Analysis extension menu.
- **Want to clear the result?** Click **Remove**.
- **Still stuck?** [Report the problem](https://github.com/AntunesLab/rmsx-flipbook-vmd/issues) with your VMD version and operating system.

[More controls](../rmsxflipbooktimeline0.3.1/USER_GUIDE.md) · [Example settings](HANDOFF.md#reviewer-route) · [Optional source installation](../rmsxflipbooktimeline0.3.1/INSTALL.md)
