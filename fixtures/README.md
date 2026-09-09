# Curated test and demonstration fixtures

All data files are enumerated with origin and SHA-256 in `provenance.json`.
`run_tests.py` verifies checksums before every suite and copies data into each
test's private temporary directory. Tests must never write to this directory.

- `upstream/test_files`: small AntunesLab RMSX inputs and golden CSV/PDB outputs.
  The 1UBQ DCD is complete; the protease DCD is truncated to its first 27 frames.
- `upstream/rmsx_demo_outputs`: three nine-slice examples, including masking.
- `seed_outputs`: historical native VMD results needed for loading/display tests.
- `dna`: small VMD plugin fixture, with the UIUC notice included.

PNG plots, redundant trajectories, manifests containing machine paths and VMD
binaries are deliberately excluded. See the root THIRD_PARTY_NOTICES.md.
