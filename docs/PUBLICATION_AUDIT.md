# Publication audit

## Public source publication — 14 September 2026

The owner explicitly requested public source visibility with the finished video and an HD Tachyon figure. Source publication is separate from a qualified versioned release; no final one-file release is asserted here.

A fresh bounded scan of all fetched reachable refs and current files covered 63 commits, 282 trees, and 686 blobs before the publication-documentation commit. It found no matches for the credential, private-key, token, credential-URL, personal-path, or private-network patterns used in the retained audit script. The new media are app-only footage and generated molecular figures, inspected separately; committee paperwork and email drafts are excluded. The fixture checksums and explicit package inventory pass. Self-hosted VMD CI remains manually dispatched.

The scan does not prove absence of unknown-format or encoded secrets. Scope excludes unreachable objects and GitHub-internal caches. The earlier provenance and notice review below remains applicable; no fixture bytes or licensing terms were changed for publication. Final-artifact qualification remains separate.

## Historical audit

The following records the earlier 10 September source/provenance review.

## History and secret scan

Audit date: 2026-09-10. Audited starting commit:
`4027f9a0ab26b50a66e533c164e8e9da7aaa11f4`.

The scan covered all locally reachable refs, commits and blobs: 7 refs,
13 commits, 100 trees and 429 unique blobs, approximately 18.3 MB including
commit metadata. All 3 remote branch tips were already represented in that
history. There were no local or remote tags. Current tracked working files
were also scanned. No repository history was rewritten and nothing was published.

The custom byte/text scan checked private-key headers, GitHub/provider token
formats, AWS access identifiers, credential-bearing URLs, credential-like
assignments, personal absolute paths and private-network addresses. It inspected
binary blobs as well as text and commit metadata without recording matched
credential values. No credential/private-key/token candidates were found in
this maintained repository’s scanned history or tracked files.

Three historical blob matches were local-path strings inside forbidden-path
scanner expressions in `scripts/check_release.py` and the historical
`scripts/check_rmsxflipbooktimeline_release_paths.sh`. They were detection rules,
not runtime dependencies, user datasets or credentials. The current rule has
been generalized. These historical scanner literals do not require a history
rewrite to establish runtime portability.

This was a custom pattern scan; dedicated secret scanners were unavailable.
It cannot prove that arbitrary encoded or unknown-format secrets do not exist.
Unreachable Git objects, server-side pull-request/cache objects, unrelated local
checkouts and untracked personal workspaces are outside the maintained-repository
history scope. An auxiliary legacy checkout had a credential-bearing remote
configuration; it was reported privately for credential rotation and config
cleanup, and is not part of the release inventory or this repository’s history.
Do not copy that configuration or diagnostic secret values into review packets.

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
analysis assertion. The private `qa/native-fixtures-verification.json` receipt
records this fixture evidence separately from platform qualification. Earlier
final-artifact audits of the 129-file fixture set remain accurate for those
earlier artifact hashes.

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
qualification. The retained private receipt is
`one-file-reviewer/qa/preview-frames-vmd/result.txt` in the review archive.

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

## Final publication checklist

- Re-run the history/current-source scan at the final clean integrated commit;
  confirm every current remote branch/tag is covered and inspect new changes.
- Verify both generated artifacts against their manifests and hashes; inspect
  decoded one-file contents, source inventory, notices and fixture checksums.
- Keep auxiliary credentials, VMD distributions, recordings and personal output
  directories outside the package. Sanitize reports before external sharing.
- Attach a reviewed final-revision history/provenance report to the qualification
  template and pass every required build target with matching artifact identity.
- Integrate the agreed private branch chain and confirm that the final source
  revision/PR matches the artifact manifest. Confirm maintainer roles.
- Only after those gates pass, carry out the separately authorized public
  visibility/release action. This audit document performs no publication.
