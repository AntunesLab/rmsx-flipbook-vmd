# Scientific conventions and data formats

This document describes the native VMD implementation. It does not redefine
the published method or claim that every upstream implementation choice is
identical. Keep metric settings and provenance with exported numerical data.

## Native metric definitions

| Display name | Calculation | Unit / reference |
|---|---|---|
| RMSX | VMD `measure rmsfperresidue` within each selected time window | Å; fluctuations within that slice |
| Shift-Map | Euclidean displacement of a residue representative atom from its position in the first selected frame; sample at each slice's first frame | Å; first selected frame |
| 1-lDDT | One minus the average fraction of preserved local reference distances across thresholds | Dimensionless, nominal range 0–1 |

RMSX does **not** multiply RMSD and RMSF. Native RMSX and Shift-Map do not
implicitly fit the trajectory; whole-system translation/rotation can affect
coordinate-based quantities. Prepare/fix alignment deliberately when required
by the scientific question. The native RMSD sidecar does perform fitting;
that sidecar's definition must not be mistaken for the RMSX window definition.

For 1-lDDT the default reference neighborhood uses representative-atom
reference distances strictly below 15 Å. Default distance-difference thresholds
are 0.5, 1.0, 2.0 and 4.0 Å, with strict `<` comparisons. Protein representatives
are CA; nucleic-acid representatives are P. The reference is the first selected
frame. This is a representative-atom local instability score, not predicted
structure confidence and not an all-heavy-atom lDDT implementation.

The `-empty_neighbor_instability` convention defaults to 0.0 when a
representative has no reference neighbors. Zero in that situation means the
configured empty-neighborhood value, not independent evidence of stability.
Record this option; exclude or flag such rows when that distinction matters.
Upstream methods may differ in representative selection or missing-value
handling. Numerical parity tests therefore cover the actual native conventions
instead of asserting unrestricted equivalence to every external lDDT tool.

## Frames, time and windows

Frame indices are zero based. Native frame-offset handling accounts for a
coordinate frame loaded with topology before adding trajectory frames. Start,
end and stride refer to the requested trajectory range as documented by the
native API. A slice comprises selected frames; RMSX requires at least two frames
per slice. First-frame structure samples are not time averages of coordinates.

The dashboard provides slice count or frames-per-slice input and a preview.
Physical time labels require a verified timestep or total-time override. A
trajectory's frame spacing must not be confused with the integrator timestep.
If physical timing is unknown, retain frame/slice indices rather than inventing
nanoseconds. The short protease demonstration is 27 frames from upstream data.

## Masking and missing data

Masks are stored separately from values. Masked residues do not determine the
visible scaling range and receive a distinct visual treatment. Some legacy
RMSX export conventions clip masked values to the unmasked range; those numbers
remain masked and must not be treated as independent measured values. Missing
matrix values likewise are not zeros. Include the mask legend and scale in
figures. Log-transformed output needs a stated transformation and units.

## Residue identity

New native residue tables begin with:

```text
ResidueID,ChainID,SegID,InsertionCode,ResidueOrdinal,...metric columns...
```

Mask tables use the same identity fields followed by `Masked`; RMSF sidecars
use them followed by `RMSF`. Preserve all identity fields. Chain, segment,
insertion code and residue ordinal are distinct; chain `X` or a blank chain
must not silently become a segment name. The stored ordinal is a zero-based occurrence count for otherwise identical
chain/segment/residue/insertion tuples in source atom order. It distinguishes
repeated identifiers. Live selections additionally retain VMD's internal residue
index and source-molecule association for exact picking.

Legacy `ResidueID,ChainID` inputs remain readable where the mapping is unique.
Ambiguous inputs require an error or explicit compatible association, not a
best guess. Numerical regression readers project current columns by header
onto historical golden tables (including the old effective-chain convention)
solely for value comparisons. Dedicated identity tests validate the complete
new schema, insertion codes and ambiguous mappings.

## Timeline metrics and interchange

Timeline matrices carry row/column metadata, metric/units, masks, categories
and source provenance. Displacement is relative to a reference; step
displacement is change between selected frames, not a physical velocity unless
a physical time interval has been applied. RMSD requires a stated fitting
selection/reference; RMSF depends on its temporal window. SASA depends on the
probe radius and selected atoms. Contacts, salt bridges and hydrogen bonds
must retain selection/distance/angle criteria. Phi/psi are angular quantities;
circular aggregation avoids wrapping artifacts near ±180°. Secondary structure
is categorical and uses a category legend rather than a continuous numerical
scale.

TML exports preserve extended metadata while retaining the legacy text matrix
interchange. Imported provenance and parsed file headers should both survive a
round trip. Import is data parsing; metadata must not be executed as Tcl.

Output ownership metadata (`.rmsx_output_manifest.tcldict`, schema2) identifies
complete files eligible for transactional replacement. It is distinct from the
saved viewing manifest (`rmsx_flipbook_timeline_manifest.tcldict`, schema2),
which records source/view/provenance. Content checks protect against accidental
replacement of changed results; they are not a cryptographic trust boundary.

## Regression evidence

The 1UBQ native RMSX test compares every corresponding value against the
upstream reference (absolute tolerance 1e-5). RMSD/RMSF sidecar checks use 1e-4.
Shift-Map and 1-lDDT tests independently calculate representative examples and
check range/reference behavior. Multichain, masks, file types, DNA, insertion
identity, output transactions and cancellation have separate tests.

These small fixtures establish correctness on specific cases. Large-trajectory
performance, unusual chemistries and every platform/build require additional
validation; neither a rendered image nor a successful package load substitutes
for scientific numerical checks.

Published method: https://doi.org/10.1038/s41598-026-39869-7
VMD measurement API: https://www.ks.uiuc.edu/Research/vmd/current/ug/node138.html
