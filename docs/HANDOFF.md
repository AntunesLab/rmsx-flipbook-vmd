# Bundled examples

Start with the [quick start](QUICK_START.md). **Single** and **Multi** open precomputed nine-slice previews and fill the inputs for a fresh calculation. Click **Run** to calculate with those settings.

## Example settings

| Button | System | Frames | Windows | Selection and mask |
|---|---|---|---|---|
| Single | Ubiquitin (`1UBQ.pdb`, `mon_sys.dcd`) | 0–314 | Nine × 35 frames | Group 7; no mask |
| Multi | Protease (`protease_backbone.pdb`, `short_protease_backbone.dcd`) | 0–26 | Nine × 3 frames | All chains; mask `resid 25:26` |

Both examples use frame labels, not physical time. The ubiquitin trajectory has 316 frames; the example uses the first 315 to form nine equal windows. Frame 315 is excluded. The initial topology coordinate frame is not included in these trajectory indices.

The multichain mask keeps residues 25–26 in both chains transparent and excludes their values from the analysis. The [video](media/README.md) instead shows an unmasked multichain result.

## Compare metrics

**RMSX** measures residue fluctuations within each window. To compare with **Shift-Map**, keep the same inputs and slices, select Shift-Map, and click **Run**. Shift-Map measures displacement relative to the first selected frame. These metrics have different interpretations; use each result’s legend. See [methods](METHODS.md).

## Diagnostics

**Quick Check** runs a bounded three-slice calculation, checks loading and rendering, and retains the displayed result. **Save report…** saves a JSON report and a text companion. Reports include local paths; inspect them before posting an issue.

Quick Check describes the checks performed in that VMD session. It is not a complete platform certification. See [verification](VERIFICATION.md).
