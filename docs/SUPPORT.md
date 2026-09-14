# Runtime support and qualification

## Requirements

The backend is a Tcl8.6 VMD package. The dashboard additionally needs Tk8.6 and
a graphical VMD session. There is no Python/R dependency for ordinary native
analysis or viewing. Optional installation/CI/archive tooling uses Python3.9+.
Tcl9 is not currently declared supported; select Tcl8.6 explicitly for tests.
VMD trajectory readers, secondary-structure support and renderers depend on the
installed VMD build. Unavailable features must report their actual capability.

PNG/SVG matrix export and VMD molecular-scene rendering are different paths.
A working Tk PNG exporter does not establish that a scene renderer produces a
meaningful molecular image. The release profile exercises real scene rendering.

## Qualification matrix for the final 0.3.1 artifact

The [qualification template](qualification-template.json) names five build
checks across four platform families. Every row is **PENDING for 0.3.1** until
its final artifact has complete matching receipts; an installed application or
an older successful test run is not a pass for this artifact.

| Gate target | VMD distribution tested | Retained full-suite evidence |
|---|---|---|
| `macos-arm64-2.0b1` | Apple Silicon 2.0b1 | 80/80 passed at `a4c60d3` |
| `macos-arm64-2.0.0a7-pre2` | Apple Silicon 2.0.0a7-pre2 | 80/80 passed at `a4c60d3` |
| `macos-intel-1.9.4a57` | Intel macOS 1.9.4a57 | 80/80 passed at `a4c60d3` |
| `windows-x64-2.0.0a6` | Windows x64 2.0.0a6 | 80/80 passed at `a4c60d3` |
| `linux-x64-2.0.1a1` | Linux x64 2.0.1a1 | 80/80 passed at `a4c60d3` |

[Sanitized receipt summary](TEST_EVIDENCE.json). Later export and input-autopopulation changes have focused regression checks; these historical full-suite results are not relabeled as full qualification of those later revisions. The finished Mac video uses `4e2bb57`; input autopopulation was added in `4eb669d`.

A portable Tcl job on Windows/Linux/macOS qualifies data/API tests in that Tcl
runtime only. It does not certify VMD graphics, mouse behavior, loading, rendering
or lifecycle. Keep the exact source hash, artifact hash, BUILD_ID, VMD/Tcl/Tk
versions, OS, architecture and graphics configuration with every support claim.
See [verification](VERIFICATION.md) for the retained historical receipts and
[VMD interoperability](VMD_INTEROP.md) for observed platform-specific behavior.

## CI activation

The portable workflow can run on GitHub-hosted machines. Linux installs Tcl8.6;
macOS uses the Homebrew `tcl-tk@8` formula; Windows uses the MSYS2 MinGW Tcl8.6
package. Those runtimes are not bundled into the extension.

The VMD workflow is manually dispatched to a trusted self-hosted runner labeled
`vmd-macos-arm64`, `vmd-macos-intel`, `vmd-linux` or `vmd-windows`. The runner
administrator provides a licensed VMD executable through `VMD_EXECUTABLE`, a
Tcl8.6 runtime and a usable display (including platform-specific headless display
configuration if required). The workflow does not download or redistribute VMD.
Do not run untrusted pull-request code automatically on personal VMD machines.

Pending runners remain pending; no placeholder workflow is counted as a pass.
The handoff gate checks the actual required suite inventory. Missing required
calculations, GUI, rendering or completion receipts are failures; follow the
current gate’s explicit policy for any experimental capability.

A complete `--profile release` run is a gate for that local runtime only. Its
summary records `complete_local_release_profile`, the exact source checksum,
revision, architecture and per-test runtime versions. It never sets global
`release_qualified` true: the other build targets still need corresponding evidence. Changing source files while
a suite runs invalidates that qualification even when every case passes.
Generated artifacts remain unqualified until their required qualification checks pass. A dirty snapshot cannot qualify as the clean final source.

## Diagnostics

Retain `summary.json`, per-case `result.txt` and `test.log`. The test harness
catches top-level Tcl and asynchronous Tk errors and writes explicit results.
Missing receipt, timeout, nonzero launch failure, required capability skip or
reported assertion failure fails the gate even if VMD returns shell status0.
Fixtures are copied per case, so retained diagnostics do not modify source data.
On POSIX, the runner gives VMD a real pseudo-terminal on all three console
streams and drains it into the case log. This avoids early EOF and display-loop
stalls observed with redirected console streams. Timeout terminates the entire
test process group. Windows console behavior was exercised by the recorded
`afa2c22` VMD release profile; final downloadable-artifact qualification remains
pending. The portable Tcl job does not exercise that VMD path.
