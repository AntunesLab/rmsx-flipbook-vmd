# First-time reviewer check

Use a graphical VMD with Tcl/Tk 8.6 already installed. Please try these steps
without assistance; report where you get stuck instead of editing file paths.
The maintainer supplies the candidate file and its matching checksum.

1. Start timing when you choose **File → Load Visualization State** in VMD.
2. Select **TRY_RMSX_0.3.1.vmd**. Stop timing when the dashboard and nine
   molecular structures are visible. Record the elapsed time.
3. On Windows, follow **Open fresh VMD** if prompted. This enables native
   residue thickness in a separate VMD session and preserves your original one.
   Include this step in the timing.
4. Click **Run** and wait for completion. Were you able to calculate without
   changing paths? Click a heatmap cell and rotate the structures.
5. Choose **Multi**, then **Run**. Confirm nine structures, both chains and
   transparent masked regions. Open a comparison plot.
6. Run **Quick Check**, then **Save report…**. Note any confusing label,
   missing control, blank viewer, unexpected window placement or error.

Return the saved report with the following short answers. Inspect the report
before sharing because it may contain local account or dataset paths.

- VMD distribution, operating system and computer architecture:
- Time to the initial visualization (including any fresh-session step):
- Both calculations completed without path editing: yes / no
- Heatmap selection, rotation and comparison plot worked: yes / no
- Assistance received, if any:
- Confusing step or error (exact wording if possible):

The independent trial passes only when an actual first-time tester reaches the
initial visualization within two minutes and completes a fresh calculation
without developer assistance or path editing. An automated run or a maintainer
following these instructions cannot substitute for that observation.
