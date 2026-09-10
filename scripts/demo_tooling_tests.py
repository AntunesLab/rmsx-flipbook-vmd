#!/usr/bin/env python3
"""Check generated extraction, build identity, byte fidelity and private artifacts."""
from __future__ import annotations

import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
import zipfile
import zlib

import build_demo
import build_release

PACKAGE = "rmsxflipbooktimeline0.3.1"
VERSION = "0.3.1"
HARNESS = Path(__file__).with_name("reviewer_bootstrap_tests.tcl")


def test_package():
    main = r'''
namespace eval ::RMSXFlipbookTimeline {
    variable basedir [file dirname [info script]]
    proc package_root {} {variable basedir; return $basedir}
    proc build_id {} {
        set channel [open [file join [package_root] BUILD_ID] r]
        try {return [string trim [read $channel]]} finally {close $channel}
    }
}
proc rmsxflipbooktimeline {} {return .review}
package provide rmsxflipbooktimeline 0.3.1
'''
    reviewer = r'''
namespace eval ::RMSXFlipbookTimeline::Reviewer {
    variable workspace ""
    variable launches 0
    variable reopens 0
    proc launch {path build} {variable workspace; variable launches; set workspace $path; incr launches; return .review}
    proc reopen {build} {variable reopens; incr reopens; return .review}
}
'''
    index = 'package ifneeded rmsxflipbooktimeline 0.3.1 [list source -encoding utf-8 [file join $dir rmsxflipbooktimeline.tcl]]\n'
    return {f"{PACKAGE}/VERSION": b"0.3.1\n", f"{PACKAGE}/pkgIndex.tcl": index.encode(),
            f"{PACKAGE}/rmsxflipbooktimeline.tcl": main.encode(),
            f"{PACKAGE}/gui/reviewer.tcl": reviewer.encode(),
            "data/binary π sample.bin": bytes(range(256)) * 513,
            "data/empty.txt": b"", "data/unicode.txt": "π Å β\r\n[not Tcl] $not_code\n".encode()}


class BootstrapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tclsh = os.environ.get("TCLSH") or shutil.which("tclsh8.6") or shutil.which("tclsh")
        if not cls.tclsh:
            raise RuntimeError("Tcl 8.6 is required for bootstrap tooling tests")
        probe = subprocess.run([cls.tclsh], input='puts [info patchlevel]\n', text=True, capture_output=True, check=True)
        if not probe.stdout.strip().startswith("8.6."):
            raise RuntimeError(f"Select Tcl 8.6 with TCLSH, got {probe.stdout.strip()!r}")

    def run_scenario(self, scenario, build, other=None):
        with tempfile.TemporaryDirectory(prefix="rmsx-bootstrap-test-") as tmp:
            directory = Path(tmp) / "space π directory"
            directory.mkdir()
            path = directory / "renamed review.vmd"
            path.write_bytes(build.data if hasattr(build, "data") else build)
            # Tcl and Python can select different ANSI/UTF-8 defaults on
            # Windows. Keep the diagnostic path transport explicitly UTF-8;
            # the tested artifact and workspace still contain real Unicode.
            driver = directory / "utf8-bootstrap-harness.tcl"
            driver.write_text("fconfigure stdout -encoding utf-8 -translation lf\n"
                              "fconfigure stderr -encoding utf-8 -translation lf\n"
                              + HARNESS.read_text(encoding="utf-8"), encoding="utf-8")
            command = [self.tclsh, str(driver), scenario, str(path)]
            if other is not None:
                second = directory / "another.vmd"
                second.write_bytes(other.data)
                command.append(str(second))
            temporary = directory / "temporary"
            temporary.mkdir()
            env = {**os.environ, "TMPDIR": str(temporary), "TMP": str(temporary), "TEMP": str(temporary)}
            result = subprocess.run(command, cwd=temporary, env=env, text=True,
                                    encoding="utf-8", capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("BOOTSTRAP_TEST_PASS", result.stdout)
            match = re.search(r"^WORKSPACE=(.+)$", result.stdout, re.M)
            extracted = {}
            if match:
                workspace = Path(match.group(1))
                self.assertTrue(workspace.is_dir(), f"Missing workspace {workspace!s}; Tcl receipt: {result.stdout!r}")
                self.assertTrue((workspace / ".rmsx_review_owner").is_file())
                extracted = {p.relative_to(workspace).as_posix(): p.read_bytes()
                             for p in workspace.rglob("*") if p.is_file() and p.name != ".rmsx_review_owner"}
                # The harness reports only the newly created, marked fixture workspace.
                shutil.rmtree(workspace)
            if scenario in {"fail", "unknown", "stickyfail", "incomplete"}:
                self.assertEqual(list(temporary.iterdir()), [], result.stdout + result.stderr)
            return result.stdout, extracted

    def test_binary_utf8_and_multichunk_extraction_from_play_style_evaluation(self):
        build = build_demo.generate(test_package(), PACKAGE, VERSION)
        _, actual = self.run_scenario("extract", build)
        self.assertEqual(actual, build.files)

    def test_same_build_reopens_and_different_or_unknown_build_is_rejected(self):
        payload = test_package()
        build = build_demo.generate(payload, PACKAGE, VERSION)
        self.run_scenario("repeat", build)
        payload["data/unicode.txt"] += b"changed"
        other = build_demo.generate(payload, PACKAGE, VERSION)
        self.assertNotEqual(build.build_id, other.build_id)
        self.run_scenario("different", build, other)
        self.run_scenario("unknown", build)

    def test_corruption_cleans_partial_extraction_before_package_load(self):
        build = build_demo.generate(test_package(), PACKAGE, VERSION)
        # Change one valid base64 character in the first compressed block. The
        # unchanged compressed checksum must reject it before any package loads.
        text = build.data.decode()
        start = text.index("::RMSXReviewBootstrap::stage begin {schema")
        suffix = text[start:]
        match = re.search(r"\{\d+ \d+ \d+ \d+ \{([A-Za-z0-9+/])", suffix)
        self.assertIsNotNone(match)
        position = start + match.start(1)
        changed = "A" if text[position] != "A" else "B"
        output, _ = self.run_scenario("fail", (text[:position] + changed + text[position+1:]).encode())
        self.assertIn("checksum mismatch", output)
        self.run_scenario("stickyfail", (text[:position] + changed + text[position+1:]).encode())

    def test_payload_commands_are_bounded_and_missing_or_reordered_chunks_cannot_activate(self):
        build = build_demo.generate(test_package(), PACKAGE, VERSION)
        lines = build.data.decode().splitlines()
        payload = [line for line in lines if line.startswith("::RMSXReviewBootstrap::stage")]
        self.assertTrue(payload[0].startswith("::RMSXReviewBootstrap::stage begin "))
        self.assertEqual(payload[-1], "::RMSXReviewBootstrap::stage commit")
        self.assertLess(max(map(len, payload)), 12500)
        chunk_index = next(i for i, line in enumerate(lines) if line.startswith("::RMSXReviewBootstrap::stage chunk "))
        missing = lines[:chunk_index] + lines[chunk_index+1:]
        self.run_scenario("stickyfail", ("\n".join(missing) + "\n").encode())
        duplicate = lines[:chunk_index] + [lines[chunk_index]] + lines[chunk_index:]
        self.run_scenario("stickyfail", ("\n".join(duplicate) + "\n").encode())
        extra_error = lines[:chunk_index] + ["::RMSXReviewBootstrap::stage chunk bad extra"] + lines[chunk_index:]
        self.run_scenario("stickyfail", ("\n".join(extra_error) + "\n").encode())
        self.run_scenario("incomplete", build.data.replace(b"::RMSXReviewBootstrap::stage commit\n", b""))

    def test_tcl_85_rejects_cleanly_before_using_86_commands(self):
        tcl85 = os.environ.get("TCLSH85") or shutil.which("tclsh8.5")
        if not tcl85:
            self.skipTest("Optional Tcl 8.5 rejection check requires TCLSH85 or tclsh8.5")
        with tempfile.TemporaryDirectory(prefix="rmsx-tcl85-") as tmp:
            artifact = Path(tmp) / "review.vmd"
            artifact.write_bytes(build_demo.generate(test_package(), PACKAGE, VERSION).data)
            script = 'set caught [catch {source {' + str(artifact) + '}} message]\n'
            script += 'if {!$caught || [string first "requires VMD with Tcl/Tk 8.6" $message] < 0} {puts stderr $message; exit 1}\n'
            script += 'if {[package provide rmsxflipbooktimeline] ne "" || $::RMSXReviewBootstrap::last_workspace ne ""} {exit 1}\nputs TCL85_REJECT_PASS\n'
            result = subprocess.run([tcl85], input=script, text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("TCL85_REJECT_PASS", result.stdout)

    def test_unsafe_paths_duplicate_paths_and_bounded_expansion(self):
        payload = test_package()
        for name in ("../escape", "/absolute", "a/../escape", "C:/escape", "a\\escape", "CON", "a/./b"):
            with self.assertRaises(ValueError):
                build_demo.generate({**payload, name: b"no"}, PACKAGE, VERSION)
        with self.assertRaisesRegex(ValueError, "duplicate"):
            build_demo.generate({**payload, "data/UNICODE.txt": b"collision"}, PACKAGE, VERSION)
        build = build_demo.generate(payload, PACKAGE, VERSION)
        text = build.data.decode()
        safe = base64.b64encode(b"data/empty.txt").decode()
        unsafe = base64.b64encode(b"../escaped.txt").decode()
        self.run_scenario("fail", text.replace(safe, unsafe, 1).encode())
        # A stream that expands beyond its declared size must fail the bounded
        # get even with correct compressed checksum and metadata length fields.
        packed = zlib.compress(b"x" * 1000000, 9)
        encoded = base64.b64encode(packed).decode()
        pattern = r"\{(\d+) (\d+) (\d+) (\d+) \{[A-Za-z0-9+/=]+\}\}"
        start = text.index("::RMSXReviewBootstrap::stage begin {schema")
        match = re.search(pattern, text[start:])
        old = match.group(0)
        replacement = f"{{{match.group(1)} {match.group(2)} {len(packed)} {zlib.crc32(packed)} {{\n{encoded}\n}}}}"
        self.run_scenario("fail", (text[:start] + text[start:].replace(old, replacement, 1)).encode())

    def test_package_failure_restores_interpreter_and_removes_owned_files(self):
        payload = test_package()
        payload[f"{PACKAGE}/rmsxflipbooktimeline.tcl"] += b'error "injected load failure"\n'
        output, _ = self.run_scenario("fail", build_demo.generate(payload, PACKAGE, VERSION))
        self.assertIn("injected load failure", output)

    def test_ui_failure_retains_runtime_and_cannot_use_rollback_cleanup(self):
        payload = test_package()
        payload[f"{PACKAGE}/gui/reviewer.tcl"] += b'proc ::RMSXFlipbookTimeline::Reviewer::launch {path build} {error "injected UI failure"}\n'
        self.run_scenario("runtimefail", build_demo.generate(payload, PACKAGE, VERSION))


class BuildTests(unittest.TestCase):
    def snapshot(self):
        source = test_package()
        source["scripts/reviewer_bootstrap.tcl.in"] = build_demo.TEMPLATE.read_bytes()
        for name in build_demo.DEMO_FILES:
            source[name] = b"fixture\n"
        for prefix in build_demo.DEMO_PREFIXES:
            source[prefix + "example.pdb"] = b"fixture\n"
        source[f"{PACKAGE}/tests/excluded.tcl"] = b"test only"
        source["unrelated.txt"] = b"not a demo dependency"
        return source

    def test_source_zip_and_one_file_payload_share_exact_bytes_and_identity(self):
        snapshot = self.snapshot()
        artifacts, manifest = build_release.release_artifacts(snapshot, PACKAGE, VERSION, "revision", True)
        again, _ = build_release.release_artifacts(snapshot, PACKAGE, VERSION, "revision", True)
        self.assertEqual(artifacts, again)
        self.assertFalse(manifest["release_qualified"])
        self.assertEqual(manifest["distribution_status"], "private_review_build")
        self.assertNotIn("unrelated.txt", manifest["demo_payload_files"])
        self.assertNotIn(f"{PACKAGE}/tests/excluded.tcl", manifest["demo_payload_files"])
        zipped = artifacts[f"rmsx-flipbook-vmd-{VERSION}-review.zip"]
        with zipfile.ZipFile(io.BytesIO(zipped)) as archive:
            prefix = f"rmsx-flipbook-vmd-{VERSION}/"
            self.assertEqual(archive.read(prefix + PACKAGE + "/BUILD_ID").decode().strip(), manifest["build_id"])
            for name in manifest["demo_payload_files"]:
                self.assertEqual(archive.read(prefix + name), snapshot[name])
            self.assertEqual(json.loads(archive.read(prefix + "RELEASE_MANIFEST.json")), manifest)
        for name, data in artifacts.items():
            if not name.endswith(".sha256"):
                self.assertEqual(artifacts[name + ".sha256"].split()[0].decode(), hashlib.sha256(data).hexdigest())

    def test_immutable_output_is_idempotent_and_rejects_replacement(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "artifact.vmd"
            build_demo.write_immutable(path, b"same")
            build_demo.write_immutable(path, b"same")
            with self.assertRaises(ValueError):
                build_demo.write_immutable(path, b"different")
            self.assertEqual(path.read_bytes(), b"same")


if __name__ == "__main__":
    unittest.main()
