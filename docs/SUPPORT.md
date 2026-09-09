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

## Qualification matrix

| Environment | Available environment | Qualification status |
|---|---|---|
| Apple Silicon, VMD2.0b1 | Primary local runtime | Current review target; retain complete release receipt for the final source revision |
| Apple Silicon, VMD2.0.0a7 | Additional installed local app | Compatibility checks pending unless a corresponding receipt is attached |
| Apple Silicon, VMD1.9.4a57 | Additional installed local app | Compatibility checks pending unless a corresponding receipt is attached |
| Linux, Carya VMD1.9.4a57 | Historical accepted CPU runtime profile | Plugin qualification pending; that build lacks TachyonInternal and has a working POV-Ray path |
| Linux VMD2.x graphical | A binary archive is retained outside this repository | Running/display environment not established here |
| Intel macOS | No established graphical runner | Pending external access |
| Windows VMD | No established graphical runner | Pending external access |
| Stable non-beta VMD | Target build to be agreed with maintainer | Pending build access and qualification |

A passing portable Tcl job on Windows/Linux/macOS qualifies data/API tests in
that Tcl runtime only. It does not certify the corresponding VMD graphics,
mouse, renderer, loader or lifecycle behavior. Keep actual test receipts,
source revision, VMD architecture and Tcl/Tk versions with every support claim.

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
The only optional test skip is experimental MDFF when its capability is absent.
Required stable calculations, GUI and rendering must all pass in release mode.

A complete `--profile release` run is a gate for that local runtime only. Its
summary records `complete_local_release_profile`, the exact source checksum,
revision, architecture and per-test runtime versions. It never sets global
`release_qualified` true: Intel macOS, graphical Linux, Windows, and the agreed
stable VMD build still need corresponding evidence. Changing source files while
a suite runs invalidates that qualification even when every case passes.
The archive remains named `0.3-review` whether its source is committed or dirty.

## Diagnostics

Retain `summary.json`, per-case `result.txt` and `test.log`. The test harness
catches top-level Tcl and asynchronous Tk errors and writes explicit results.
Missing receipt, timeout, nonzero launch failure, required capability skip or
reported assertion failure fails the gate even if VMD returns shell status0.
Fixtures are copied per case, so retained diagnostics do not modify source data.
On POSIX, the runner gives VMD a real pseudo-terminal on all three console
streams and drains it into the case log. This avoids early EOF and display-loop
stalls observed with redirected console streams. Timeout terminates the entire
test process group. Windows console behavior remains subject to its pending
real VMD qualification; the portable Tcl job does not exercise that path.
