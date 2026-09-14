# Source and fixture provenance

This document records fixture origins, license notices, and the scope of source screening. Platform test results are documented in [Verification](VERIFICATION.md).

## Fixture provenance

All **132/132** current fixture SHA-256 values match the retained files. The original
114 fixtures remain unchanged; 15 reproducible reviewer-preview files and three
synthetic backend inputs were added separately. The additive
origin/license metadata in [fixtures/provenance.json](../fixtures/provenance.json)
now records the following evidence:

| Group | Evidence |
|---|---|
| 48 unchanged AntunesLab RMSX fixtures | Byte-identical to committed source paths at `dbd394198a6eeba257339fd630a4038eba424afe` |
| One shortened protease DCD | All 790 atoms in all 27 retained frames are bitwise equal after decoding to source frames 0–26; maximum coordinate difference 0 Å; original has 5001 frames |
| 64 native baseline outputs | Byte-identical to their first tracked fixture import at `750b551c320a138a94b4d6b3f7565303a3333229`; original generator-run metadata was not retained |
| One DNA fixture | Byte-identical to `vmdlite1.1/sandboxMolecules/bdna.pdb` in the retained VMD 2.0b1 ARM64 distribution |
| 15 new 0.3.1 protease-preview files | Fresh VMD generation from the bundled 27-frame input: nine three-frame windows, all recognized protein chains, mask `resid 25:26`; nine PDBs and six CSVs |
| Three synthetic backend inputs | Exact historical helper recipes from `f0fff690`; two ten-frame DCDs and one two-chain topology, with deterministic DCD comments and all coordinates unchanged |

The upstream commit was verified against the
[AntunesLab source repository](https://github.com/AntunesLab/rmsx/commit/dbd394198a6eeba257339fd630a4038eba424afe).
Its committed [MIT license](https://github.com/AntunesLab/rmsx/blob/dbd394198a6eeba257339fd630a4038eba424afe/LICENSE)
is byte-identical to the retained upstream notice, SHA-256
`36761829c077c240e0f98b497422fcec02ed699e040b231f49659d4f6de4c60e`.
The shortened DCD was read for comparison with MDAnalysis 2.7.0; its documented
transformation is frame truncation, not an invented physical-time assignment.
The DNA fixture retains its University of Illinois Open Source License notice.
The synthetic DNA trajectory retains that same notice; the two-chain ubiquitin
inputs retain MIT provenance. Their generator is an original MIT contribution.
Two independent Mac VMD 2.0b1 generations produced identical hashes after
normalizing only DCD title comments. Decoded coordinates matched both original
recipes exactly (maximum difference 0 Å), and both smoke tests retained every
analysis assertion. Fixture validation is separate from platform qualification.

The 64 baseline artifacts are regression references, not fresh 0.3.1 analysis
results. Their original execution environments cannot be reconstructed from the
retained metadata alone. The primary reviewer’s fresh checks use explicit input
fixtures and the current package, so they do not depend on attributing a new
calculation to those historical outputs.

The 0.3.1 reviewer uses `seed_outputs/reviewer-protease-9/combined` for Multi.
The older multichain baseline was not a nine-window result from the bundled
27-frame trajectory and must not be relabeled as one. Its original files remain
unchanged for regression tests. The new preview was freshly calculated in VMD
2.0b1/Tcl 8.6.16 with input hashes and generator-method hashes recorded in the
manifest. The `reviewer_preview_frames` VMD check passed all 18 single/multichain
PDB-to-input-frame mappings; this is focused fixture evidence, not a full release
qualification.

An independent decoded-coordinate check also matched the new Multi snapshots
to source frames 0, 3, …, 24 within 0.00001 Å, and found exactly four masked rows:
A25, A26, B25 and B26. The VMD `protein` selection recognizes 196 CA rows here;
the two terminal PHE99 residues lack an O atom and are not recognized as protein
by this runtime. The preview records this selection rather than silently claiming
all 198 raw CA atoms were analyzed. See [fixture notes](../fixtures/README.md)
for the reproduction command.

## Notices and code provenance

Original contributions retain MIT licensing. Upstream RMSX and the VMD DNA
fixture retain their applicable notices; see
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). VMD executables and libraries
are excluded. The extension acknowledges Timeline, RMSD toolkit and QwikMD
reference material. The earlier limited verbatim-code comparison is useful
screening, but does not establish authorship of every adaptation. Maintainer
acceptance of attribution and license handling remains part of upstream review.


## Source screening

Reachable repository history and current files were screened before public source publication on 14 September 2026 for recognizable credentials, private keys, personal paths, and private-network addresses. No credential candidates were found by that pattern scan. Pattern scanning cannot establish the absence of unknown-format or encoded secrets; unreachable objects and server-side caches were outside its scope.

`python3 scripts/check_release.py` verifies fixture hashes and the explicit package inventory. VMD executables are not distributed with this project.
