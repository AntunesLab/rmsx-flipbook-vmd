#!/usr/bin/env python3
"""Time VMD's actual play parser on a large synthetic reviewer payload.

This is a parser/extractor regression, not a graphical or scientific qualification.
It requires the caller's licensed VMD executable; it never downloads VMD.
"""
from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path
import random
import shutil
import tempfile
import time
import zlib

import build_demo
from demo_tooling_tests import PACKAGE, VERSION, test_package
from run_tests import native_crash_diagnostic
import vmd_process


def tcl_path(path):
    encoded = base64.b64encode(str(path).encode("utf-8")).decode("ascii")
    return f"[encoding convertfrom utf-8 [binary decode base64 {encoded}]]"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vmd", required=True)
    parser.add_argument("--output", type=Path, help="New directory for the test artifact and evidence")
    parser.add_argument("--timeout", type=float, default=30)
    args = parser.parse_args()
    if args.timeout <= 2:
        parser.error("Timeout must exceed two seconds")
    if args.output:
        directory = args.output.resolve()
        directory.mkdir(parents=True, exist_ok=False)
    else:
        directory = Path(tempfile.mkdtemp(prefix="rmsx-real-vmd-play-"))
    downloads = directory / "renamed π review directory"
    downloads.mkdir()
    unrelated = directory / "unrelated cwd"
    unrelated.mkdir()
    raw = random.Random(0x524D5358).randbytes(6 * 1024 * 1024)
    payload = test_package()
    payload["data/parser-regression.bin"] = raw
    demo = build_demo.generate(payload, PACKAGE, VERSION)
    artifact = downloads / "renamed demonstration.vmd"
    artifact.write_bytes(demo.data)
    receipt = directory / "receipt.txt"
    driver = directory / "driver.tcl"
    driver.write_text(f"""# Runs through VMD's actual queued play command.
set ::rmsx_play_started [clock milliseconds]
set ::rmsx_play_receipt {tcl_path(receipt)}
proc ::rmsx_play_finish {{status message}} {{
    set channel [open $::rmsx_play_receipt w]
    fconfigure $channel -encoding utf-8 -translation lf
    puts $channel "status=$status"
    puts $channel "message=$message"
    puts $channel "milliseconds=[expr {{[clock milliseconds]-$::rmsx_play_started}}]"
    puts $channel "vmd=[vmdinfo version]"
    puts $channel "tcl=[info patchlevel]"
    if {{[info exists ::RMSXReviewBootstrap::last_workspace]}} {{puts $channel "workspace=$::RMSXReviewBootstrap::last_workspace"}}
    close $channel
    puts "RMSX_REAL_PLAY_$status $message"
    after 1 quit
}}
proc ::rmsx_play_poll {{}} {{
    if {{[info exists ::RMSXFlipbookTimeline::Reviewer::launches] && $::RMSXFlipbookTimeline::Reviewer::launches == 1}} {{
        if {{[catch {{
            if {{[::RMSXFlipbookTimeline::build_id] ne "{demo.build_id}"}} {{error "build identity mismatch"}}
            set channel [open [file join $::RMSXReviewBootstrap::last_workspace data parser-regression.bin] r]
            fconfigure $channel -translation binary -encoding binary
            set bytes [read $channel]
            close $channel
            if {{[string length $bytes] != {len(raw)} || [zlib crc32 $bytes] != {zlib.crc32(raw)}}} {{error "extracted bytes mismatch"}}
        }} message]}} {{::rmsx_play_finish FAIL $message}} else {{::rmsx_play_finish PASS "native play and extraction completed"}}
        return
    }}
    if {{[info exists ::RMSXReviewBootstrap::last_error] && $::RMSXReviewBootstrap::last_error ne ""}} {{
        ::rmsx_play_finish FAIL $::RMSXReviewBootstrap::last_error
        return
    }}
    if {{[clock milliseconds]-$::rmsx_play_started > {int((args.timeout-1)*1000)}}} {{
        ::rmsx_play_finish FAIL "native play exceeded its time limit"
        return
    }}
    after 25 ::rmsx_play_poll
}}
after 25 ::rmsx_play_poll
play {tcl_path(artifact)}
""", encoding="utf-8")
    began = time.monotonic()
    result = None
    failure = None
    try:
        result = vmd_process.run([args.vmd, "-dispdev", "text", "-e", str(driver)],
                                 cwd=unrelated, timeout=args.timeout)
        (directory / "vmd.log").write_text(result.stdout, encoding="utf-8")
        crash = native_crash_diagnostic(result.stdout)
        if crash:
            failure = "Native runtime crash: " + crash
    except Exception as error:
        failure = str(error)
        output = getattr(error, "output", "") or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        (directory / "vmd.log").write_text(output + "\n" + failure, encoding="utf-8")
    evidence = dict(line.split("=", 1) for line in receipt.read_text(encoding="utf-8").splitlines() if "=" in line) if receipt.exists() else {}
    passed = (failure is None and result is not None and result.returncode == 0 and evidence.get("status") == "PASS"
              and float(evidence.get("milliseconds", "inf")) < args.timeout * 1000)
    summary = {"schema": 1, "status": "PASS" if passed else "FAIL", "scope": "native VMD play parser and synthetic extraction only",
               "artifact_bytes": len(demo.data), "payload_decoded_bytes": sum(map(len, demo.files.values())),
               "build_id": demo.build_id, "timeout_seconds": args.timeout,
               "wall_seconds": round(time.monotonic()-began, 3), "receipt": evidence, "failure": failure}
    # Only this synthetic run's exact marked workspace is eligible for cleanup.
    if evidence.get("workspace"):
        workspace = Path(evidence["workspace"])
        marker = workspace / ".rmsx_review_owner"
        expected = f"owner rmsxflipbooktimeline build_id {demo.build_id} token {workspace.name.removesuffix('.workspace')}\n"
        if marker.is_file() and not workspace.is_symlink() and marker.read_text() == expected:
            shutil.rmtree(workspace)
    (directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    print(directory / "summary.json")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
