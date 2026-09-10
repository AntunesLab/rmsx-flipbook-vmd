# Curated test and demonstration fixtures

All data files are enumerated with origin and SHA-256 in `provenance.json`.
`run_tests.py` verifies checksums before every suite and copies data into each
test's private temporary directory. Tests must never write to this directory.

- `upstream/test_files`: small AntunesLab RMSX inputs and golden CSV/PDB outputs.
  The 1UBQ DCD is complete; the protease DCD is truncated to its first 27 frames.
- `upstream/rmsx_demo_outputs`: three nine-slice examples, including masking.
- `seed_outputs`: 64 historical native VMD results needed for loading/display
  tests, plus the separately generated 15-file `reviewer-protease-9` preview.
- `dna`: small VMD plugin fixture, with the UIUC notice included.

PNG plots, redundant trajectories, manifests containing machine paths and VMD
binaries are deliberately excluded. See the root THIRD_PARTY_NOTICES.md.

The 49 upstream-derived files are pinned to AntunesLab/rmsx revision
`dbd394198a6eeba257339fd630a4038eba424afe` in the manifest. Forty-eight match
committed source bytes; the shortened protease DCD retains frames 0–26 and all
790 atoms exactly after decoding. Baseline outputs record their first tracked
import separately from their unavailable original generator-run metadata.
License/source fields are additive; all 114 original fixtures and their checksums
remain unchanged. The 15 new reviewer files bring the manifest total to 129. See [the publication audit](../docs/PUBLICATION_AUDIT.md).

## Reproduce the 0.3.1 protease reviewer preview

`seed_outputs/reviewer-protease-9/combined` contains nine PDB snapshots and six
CSV files generated from the exact bundled short protease trajectory. It is the
Multi preview used by the reviewer launcher; the historical multichain seed
was generated with different windows and is retained only as a regression input.

In a graphical VMD session with this package loaded, set `fixture_root` to this
fixture directory and `output` to a new result directory, then run:

```tcl
set topology [file join $fixture_root upstream test_files protease_backbone.pdb]
set trajectory [file join $fixture_root upstream test_files short_protease_backbone.dcd]
::RMSXFlipbookTimeline::run_native_all_chain_analysis $topology $trajectory $output \
    -num_slices 9 -start_frame 0 -end_frame 26 -time_known 0 \
    -mask_selection {resid 25:26} -verbose 0 -cleanup 1
```

This selects nine three-frame windows and masks A25, A26, B25 and B26. The
runtime’s `protein` selection recognizes 196 CA rows. The raw structure has
198 CA atoms, but terminal PHE99 in each chain lacks an O atom and is excluded
by VMD’s protein recognition. Keep this distinction when reproducing results.
Input hashes, relevant generator source hashes and method settings are recorded
in `provenance.json`. The focused VMD `reviewer_preview_frames` test validates
all nine snapshot frame mappings for each reviewer example. Full platform
qualification is recorded separately.
