# Third-party notices and provenance

Original RMSX/Flipbook VMD extension contributions are MIT licensed, copyright
2024–2026 Finn2400. See LICENSE. Scientific citation is separate from licensing.

## AntunesLab RMSX

The upstream project is https://github.com/AntunesLab/rmsx, copyright 2024
Finn2400, MIT licensed. The curated numerical/structure fixtures under
`fixtures/upstream` come from that project's test and demo files. Its complete
notice is retained in `fixtures/upstream/LICENSE`. Native VMD baseline fixtures
in `fixtures/seed_outputs` were generated in the RMSX/Flipbook 0.2 workspace.
They are retained as regression data, not current analysis results.

`fixtures/provenance.json` records the source and SHA-256 of each data file.
The protease trajectory contains only its first 27 original frames; it was
rewritten with MDAnalysis 2.7.0 with coordinates unchanged. The complete 1UBQ
trajectory is retained because the numerical reference covers frames 0–314.

## VMD plugin reference material

VMD Timeline 2.3 (copyright 2008 The Board of Trustees of the University of
Illinois), bundled RMSD toolkit `rmsx2.3`, and QwikMD informed API, file-format
and UI design. The project began as a separate extension, not an edit to VMD.
No VMD executable or shared library is distributed here.

The small `fixtures/dna/bdna.pdb` fixture comes from the VMD plugin
`vmdlite1.1/sandboxMolecules`. Its UIUC Open Source License is retained in
`fixtures/dna/LICENSE`. VMD plugins are generally covered by that license
except where a file is specifically marked otherwise:
https://www.ks.uiuc.edu/Research/vmd/plugins/pluginlicense.html

This release preserves acknowledgement of the VMD plugin authors. A review of
verbatim code sequences found no six-significant-line matches with bundled
Timeline/RMSD toolkit source; that limited check does not prove independent
provenance of every adaptation. Maintainers should review any additional
contributed/ported code and retain the applicable source notices.

VMD itself is separately obtained and licensed by each user. The main VMD
program's license is distinct from the plugin library license:
https://www.ks.uiuc.edu/Research/vmd/current/LICENSE.html

## Publication citation

Beruldsen F., de Freitas M. V., Antunes D. A. High resolution mapping of protein
motions in time and space with RMSX and Flipbook. Scientific Reports (2026).
https://doi.org/10.1038/s41598-026-39869-7

When publishing figures generated through VMD, also cite Humphrey W., Dalke A.,
Schulten K. VMD: Visual Molecular Dynamics. Journal of Molecular Graphics 14
(1996), 33–38. Naming upstream projects does not imply their endorsement.
