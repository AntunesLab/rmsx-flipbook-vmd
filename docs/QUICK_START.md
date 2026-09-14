# Beta quick start

You need graphical **VMD with Tcl/Tk 8.6**. See [tested builds and limitations](SUPPORT.md).

## 1. Open the example

The public one-file download is pending. With the supplied beta file:

1. Save **`TRY_RMSX_0.3.1.vmd`** anywhere on your computer.
2. In VMD, choose **File → Load Visualization State…**.
3. Select that file.

The dashboard and **nine precomputed ubiquitin structures** open automatically. Each structure represents one trajectory window. The heatmap shows residue values across those windows.

No extraction, plugin installation, terminal commands, or path editing is needed. The file needs no network connection after download.

**Windows:** click **Open fresh VMD** if prompted. This enables residue thickness in a separate session and keeps your original session open.

## 2. Run an analysis

Click **Run**. The topology, trajectory, group, frame range, and nine slices are already filled in. Wait for completion; the new result replaces the preview. Each calculation saves to a new output folder, shown in **Details…**.

The first example uses frames **0–314**, divided into nine **35-frame** windows. RMSX color and thickness show residue fluctuations within each window; read the legend for the actual scale in Å. **Stop** requests cancellation after the current VMD operation returns.

## 3. Explore the result

- **Click a heatmap cell** to highlight its residue in the corresponding structure. Selection retains the metric color.
- **Drag in VMD’s molecular window** to rotate each protein around its own center while keeping the nine-window arrangement.
- Use **Compare: RMSD / RMSF** above the heatmap to inspect the linked comparison plots. Clicking a plot selects a window or residue.
- For keyboard selection, focus the heatmap with **Tab**, move with the **arrow keys**, and press **Enter**. **Escape** clears highlighting.

## 4. Try two chains or another metric

Click **Multi** to load the protease preview, then **Run** to calculate it. This example uses both chains and nine three-frame windows over frames **0–26**. Residues **25–26** are masked and appear transparent. Click residues from each chain to explore their values separately. **Single** returns to ubiquitin.

To try **Shift-Map**, change the metric and click **Run**. It shows displacement from the first selected frame, rather than fluctuations within each window. See [example settings](HANDOFF.md#example-settings) and [methods](METHODS.md).

## 5. Save an image

Choose **Figure**, enter an **`.svg`** filename, and click **Save**. The figure embeds the molecular image with editable labels and a legend. Use **3D Image** for a clean PNG or **Matrix** for numerical data. Rendering depends on your VMD build; unavailable options are disabled.

![Example Tachyon figure with nine protease windows](media/protease-tachyon-hd.png)

This illustration uses an unmasked protease result. [Full image and rendering settings](media/README.md).

## Use your simulation

Choose your topology and trajectory in **Inputs**, select the chain and frame range, set the slices, and click **Run**. When opening the ordinary dashboard with exactly one supported simulation already loaded, empty inputs fill automatically. [Autopopulation details](../rmsxflipbooktimeline0.3.1/USER_GUIDE.md#already-loaded-a-simulation-in-vmd).

## Finish or get help

Close the panel to keep the scene; reopen it from VMD’s **Analysis** extension menu. Click **Remove** to clear the plugin result. If another build is already loaded, restart VMD before opening this beta.

For a problem, run **Quick Check → Save report…** and [open an issue](https://github.com/AntunesLab/rmsx-flipbook-vmd/issues) with your VMD version, operating system, and steps to reproduce it. Review local paths before sharing reports.

[All controls](../rmsxflipbooktimeline0.3.1/USER_GUIDE.md) · [Optional source installation](../rmsxflipbooktimeline0.3.1/INSTALL.md)
