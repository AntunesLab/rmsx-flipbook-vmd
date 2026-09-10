# Verification and build identity

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

## Historical evidence retained privately

- Commit `4027f9a0ab26b50a66e533c164e8e9da7aaa11f4` (0.3) has a complete local
  release-profile receipt on macOS ARM64. Source SHA-256:
  `77c96f39d3dc84a85368bc0a36321546ca9c3b4dc949f2f984458e50ca12e75e`.
  Retained receipt: `timeline-parity/qualified-4027f9a/summary.json` in the
  private qualification archive. It explicitly sets `release_qualified: false`.
- Earlier commit `2f425e76d98283886ebeddce51de29520ee4e1c3` has local Apple
  Silicon release evidence and additional ARM/Linux backend receipts in the
  dated 0.3 meeting archive. Those receipts describe that older source only.

These establish a regression baseline. The 0.3.1 launcher, package rename and
packaging changes need their own matching final receipts. Historical artifacts
are retained privately and are not promised as public downloads.

## Required final gate

Use the repository handoff gate and qualification template to bind the artifact
hash and BUILD_ID to each full-suite summary, Quick Check report, and manual
File-menu launch/mouse/OpenGL review. The [template](qualification-template.json) names Apple Silicon 2.0b1 and
2.0.0a7-pre2, Intel macOS 1.9.4a57, Windows x64 2.0.0a6, and Linux x64 2.0.1a1.
Targets without an available licensed graphical runtime remain pending.
Long-term stable-VMD support is a separate policy decision for the maintainers.

Retain an independent reviewer trial using only the delivered packet and its
instructions. Add the final walkthrough/recording only after inspecting the
actual encoded media and matching its build to the packet. Complete the
[publication audit](PUBLICATION_AUDIT.md), integrate the agreed branch, and
review the final archive inventory before any public release action.

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
