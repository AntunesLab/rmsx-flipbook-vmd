# Verification and build identity

**14 September update:** [five native full suites passed 80/80 at a4c60d3](TEST_EVIDENCE.json). The published video is verified Mac media from 4e2bb57; later input autopopulation has focused Mac dashboard tests. Source is public for review; a final versioned one-file artifact remains separately qualified. Older evidence below retains its original revision scope.

**0.3.1 public-release status: PENDING.** This document describes the evidence
required for the new reviewer artifact. It does not transfer qualification from
an earlier commit or claim that a newly generated artifact has passed.

## Match the artifact to its source

The builder derives `TRY_RMSX_0.3.1.vmd` and the source ZIP from one captured
source snapshot. `BUILD_ID` identifies the sorted relative demo-payload paths
and bytes, excluding generated identity metadata to avoid a recursive hash.
`RELEASE_MANIFEST.json` records package version, source revision, dirty-review
status, BUILD_ID and individual file SHA-256 values. Each output artifact has
its own external SHA-256 checksum.

A matching BUILD_ID connects the reviewer payload to the companion source;
artifact hashes identify the delivered files. Neither is a digital signature
or proof that tests passed. Check the manifest, runtime report and qualification
receipts together. A different already-loaded source/build must be rejected;
start a fresh VMD session to try another build.

## Three kinds of evidence

| Evidence | What it establishes | What it does not establish |
|---|---|---|
| Precomputed preview | The bundled result loads and is inspectable | Fresh calculation, platform qualification or analysis runtime |
| Quick Check report | A bounded fresh example and the checks explicitly reported by that runtime | The complete scientific/failure suite, every GUI action, or another platform |
| Complete release profile plus manual review | Required automated calculations, failure, lifecycle, GUI and rendering tests for the recorded source/runtime, with manually observed interactions | An untested VMD build/platform or approval for VMD distribution |

The harness requires explicit completion receipts. Missing reports, exceptions,
timeouts, launch failures and skipped required capabilities fail the gate;
VMD’s shell exit code alone is insufficient. Retain per-case logs and source
hashes, and reject qualification if source files changed during a run.

Each completion receipt includes the interpreter's actual OS/kernel version,
machine, Tcl/Tk version, VMD version/architecture, and graphical or headless mode.
The runner records the launcher and VMD executable SHA-256 plus the startup
banner's build date. Quick Check records the same platform/display fields; GPU
driver details remain explicitly unknown unless observed separately. These
capability fields do not establish that the OpenGL window looked correct.

For an extracted source ZIP, the runner verifies every listed file checksum,
the generated BUILD_ID and the payload fingerprint before trusting its recorded
source revision. It rejects missing, modified, linked or unlisted source files
and never takes a revision from an unrelated enclosing Git repository. Generated
archive metadata is part of the verified inventory, not an uncommitted change.

## Required final gate

Use the repository handoff gate and qualification template to bind the artifact
hash and BUILD_ID to each full-suite summary, Quick Check report, and manual
File-menu launch/mouse/OpenGL review. The [template](qualification-template.json) names Apple Silicon 2.0b1 and
2.0.0a7-pre2, Intel macOS 1.9.4a57, Windows x64 2.0.0a6, and Linux x64 2.0.1a1.
Targets without an available licensed graphical runtime remain pending.
Long-term stable-VMD support is a separate policy decision for the maintainers.

Populate `vmd_executable_sha256` and `vmd_build_date` from the actual suite
receipts and confirm that they identify the intended VMD distribution. The
2.0.0a7-pre2 app reports runtime version `2.0.0a7`, so its binary hash/build date
are required along with the distribution label. The gate validates observed
OS, VMD architecture/version and graphical capabilities for each target; copying
one machine's reports into the other target entries cannot qualify them.

Qualification distinguishes production release from developer review. Production qualification requires the complete evidence set. The developer-review profile permits a documented usability-trial waiver; waived checks are never reported as passed, and technical checks remain required. See `scripts/handoff_gate.py --help` for profile options.

The maintainer fills a copy of the evidence template with actual observations,
then evaluates the final artifact, for example:

```sh
python3 scripts/handoff_gate.py --evidence review-evidence.json \
  --artifact TRY_RMSX_0.3.1.vmd --build-id BUILD_ID_FROM_MANIFEST \
  --source-revision FINAL_CLEAN_COMMIT --output handoff-result.json
```

The uppercase values are fields to copy from the generated manifest, not literal
IDs. The untouched pending template is expected to fail. The gate validates
recorded evidence; it does not perform or attest the manual observations itself.
