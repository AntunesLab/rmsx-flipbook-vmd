#!/usr/bin/env python3
"""Exercise installation ownership and the result gate independently of VMD."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import shutil
import unittest
from unittest.mock import patch
import install
import demo_vmd_play_test
import run_tests
import vmd_process


class InstallerTests(unittest.TestCase):
    def run_installer(self, home, action, success=True):
        result = subprocess.run([sys.executable, str(install.ROOT / "scripts/install.py"), action,
                                 "--prefix", str(home / "plugin path"),
                                 "--startup-file", str(home / "vmd.rc")],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.assertEqual(result.returncode == 0, success, result.stdout)

    def test_round_trip_and_duplicate_install_preserve_user_startup(self):
        for original in [b"set user_setting 17\r\n", b"set user_setting 17", b"# legacy comment: \xe9\r\nset user_setting 17\r\n"]:
            with tempfile.TemporaryDirectory(prefix="rmsx-install-test-") as tmp:
                home = Path(tmp)
                (home / "vmd.rc").write_bytes(original)
                self.run_installer(home, "install")
                self.run_installer(home, "install")
                self.assertEqual((home / "vmd.rc").read_bytes().count(install.START.encode()), 1)
                tclsh = os.environ.get("TCLSH", shutil.which("tclsh8.6") or "tclsh")
                script = home / "check_install.tcl"
                script.write_text('set calls 0\nproc vmd_install_extension {args} {incr ::calls}\n' +
                                  'source ' + install.tcl_literal(home / "vmd.rc") + '\n' +
                                  'source ' + install.tcl_literal(home / "vmd.rc") + '\n' +
                                  'if {$calls != 1} {error "Duplicate registration"}\n' +
                                  'if {[package provide rmsxflipbooktimeline] ne "' +
                                  (run_tests.PACKAGE / "VERSION").read_text(encoding="utf-8").strip() +
                                  '"} {error "Wrong installed version"}\n')
                result = subprocess.run([tclsh, str(script)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.run_installer(home, "uninstall")
                self.assertEqual((home / "vmd.rc").read_bytes(), original)

    def test_unmanaged_and_modified_files_are_preserved(self):
        with tempfile.TemporaryDirectory(prefix="rmsx-install-test-") as tmp:
            home = Path(tmp)
            version = (run_tests.PACKAGE / "VERSION").read_text(encoding="utf-8").strip()
            target = home / "plugin path/tcl" / f"rmsxflipbooktimeline{version}"
            target.mkdir(parents=True)
            keep = target / "private-notes.txt"
            keep.write_text("keep this")
            self.run_installer(home, "install", success=False)
            self.assertEqual(keep.read_text(encoding="utf-8"), "keep this")
            keep.unlink()
            target.rmdir()
            self.run_installer(home, "install")
            installed = target / "VERSION"
            installed.write_text("user modification")
            self.run_installer(home, "uninstall", success=False)
            self.assertEqual(installed.read_text(encoding="utf-8"), "user modification")

    def test_failed_upgrade_restores_owned_package_startup_and_receipt(self):
        with tempfile.TemporaryDirectory(prefix="rmsx-install-rollback-") as tmp:
            home = Path(tmp)
            self.run_installer(home, "install")
            prefix, startup = home / "plugin path", home / "vmd.rc"
            marker = prefix / install.MARKER
            original_startup, original_receipt = startup.read_bytes(), marker.read_bytes()
            target = install.verify_owned(prefix, json.loads(original_receipt))
            before = {p.relative_to(target).as_posix(): p.read_bytes()
                      for p in target.rglob("*") if p.is_file()}
            actual_write = install.atomic_text
            failed = False
            def fail_once(path, text):
                nonlocal failed
                if path.resolve() == marker.resolve() and not failed:
                    failed = True
                    raise OSError("Injected receipt write failure")
                return actual_write(path, text)
            arguments = ["install.py", "install", "--prefix", str(prefix), "--startup-file", str(startup)]
            with patch.object(sys, "argv", arguments), patch.object(install, "atomic_text", fail_once):
                with self.assertRaisesRegex(OSError, "Injected"):
                    install.main()
            self.assertEqual(startup.read_bytes(), original_startup)
            self.assertEqual(marker.read_bytes(), original_receipt)
            self.assertEqual(before, {p.relative_to(target).as_posix(): p.read_bytes()
                                     for p in target.rglob("*") if p.is_file()})


class ConsoleTests(unittest.TestCase):
    @unittest.skipUnless(os.name == "posix", "POSIX pseudo-terminal contract")
    def test_all_vmd_console_streams_are_terminals_and_timeout_is_failure(self):
        result = vmd_process.run([sys.executable, "-c",
                    "import os; print('TTY', [os.isatty(i) for i in range(3)], flush=True)"], timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertIn("TTY [True, True, True]", result.stdout)
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            vmd_process.run([sys.executable, "-c",
                    "import time; print('STARTED', flush=True); time.sleep(10)"], timeout=0.25)
        self.assertIn("STARTED", caught.exception.output)


class ResultGateTests(unittest.TestCase):
    def test_native_play_crash_after_pass_receipt_cannot_pass(self):
        for diagnostic, expected in (("Segmentation fault (core dumped)", 1),
                                     ("Expected error: Segmentation fault (core dumped)", 0)):
            with self.subTest(diagnostic=diagnostic), tempfile.TemporaryDirectory(prefix="rmsx-play-gate-") as tmp:
                output = Path(tmp) / "play"
                def fake_run(command, **kwargs):
                    (output / "receipt.txt").write_text(
                        "status=PASS\nmessage=Completed π\nmilliseconds=1\n", encoding="utf-8")
                    return argparse.Namespace(stdout=diagnostic + "\n", returncode=0)
                arguments = ["demo_vmd_play_test.py", "--vmd", "unused", "--output", str(output)]
                with patch.object(sys, "argv", arguments), \
                     patch.object(demo_vmd_play_test.vmd_process, "run", fake_run), patch("builtins.print"):
                    self.assertEqual(demo_vmd_play_test.main(), expected)
                summary = json.loads((output / "summary.json").read_text(encoding="utf-8"))
                self.assertEqual(summary["status"], "FAIL" if expected else "PASS")
                self.assertEqual(summary["receipt"]["message"], "Completed π")
                if expected:
                    self.assertIn("Native runtime crash:", summary["failure"])
                else:
                    self.assertIsNone(summary["failure"])

    def test_native_crash_overrides_zero_exit_pass_receipt_and_optional_skip(self):
        reports = ("Segmentation fault (core dumped)", "Segmentation fault: 11",
                   "Bus error: 10", "Abort trap: 6", "Aborted (core dumped)",
                   '/tmp/vmd: line 520: 1234 Segmentation fault (core dumped) "$binary" "$@"')
        for report in reports:
            for optional in (False, True):
                with self.subTest(report=report, optional=optional), tempfile.TemporaryDirectory(prefix="rmsx-crash-gate-") as tmp:
                    def fake_run(command, **kwargs):
                        result_path = Path(kwargs["env"]["RMSX_TEST_RESULT"])
                        result_path.write_text("PASS\n")
                        Path(str(result_path) + ".environment.json").write_text(json.dumps({
                            "schema": 1, "status": "PASS", "environment": {"os": "Linux", "executable": sys.executable}}))
                        return argparse.Namespace(stdout=("optional capability skipped\n" if optional else "") + report + "\n", returncode=0)
                    args = argparse.Namespace(tclsh="unused", vmd="unused", timeout=1)
                    entry = {"id": "native_crash", "script": "not-run.tcl", "capability": "vmd", "optional": optional}
                    with patch.object(run_tests.vmd_process, "run", fake_run):
                        result = run_tests.run_one(entry, args, Path(tmp))
                    self.assertEqual(result["status"], "FAIL")
                    self.assertIn("Native runtime crash:", result["reason"])

    def test_native_crash_mentions_in_paths_and_error_assertions_are_not_reports(self):
        for message in ("Expected error: Segmentation fault (core dumped)",
                        "Expected error: line 42: Segmentation fault (core dumped)",
                        "EXPECTED_ERROR=Bus error: 10", "Assertion checks 'Abort trap: 6'",
                        "Opening /tmp/Segmentation fault (core dumped)/input.pdb",
                        "Segmentation fault handler assertion passed", "Analysis Aborted by user"):
            self.assertIsNone(run_tests.native_crash_diagnostic(message), message)

    def test_pass_requires_a_matching_environment_receipt(self):
        for include_environment in (False, True):
            with tempfile.TemporaryDirectory(prefix="rmsx-environment-test-") as tmp:
                def fake_run(command, **kwargs):
                    result_path = Path(kwargs["env"]["RMSX_TEST_RESULT"])
                    result_path.write_text("PASS\n")
                    if include_environment:
                        Path(str(result_path) + ".environment.json").write_text(json.dumps({
                            "schema": 1, "status": "PASS", "environment": {
                                "os": "Windows NT", "executable": sys.executable,
                                "path_sample": "C:\\review π\\sample"}}), encoding="utf-8")
                    return argparse.Namespace(stdout="VMD for WIN64, version 2.0.0a6 (test build date)\n", returncode=0)
                args = argparse.Namespace(tclsh="unused", vmd="unused", timeout=1)
                entry = {"id": "environment", "script": "not-run.tcl", "capability": "tcl"}
                with patch.object(run_tests.subprocess, "run", fake_run):
                    result = run_tests.run_one(entry, args, Path(tmp))
                self.assertEqual(result["status"], "PASS" if include_environment else "FAIL")
                if include_environment:
                    self.assertEqual(result["environment"]["path_sample"], "C:\\review π\\sample")
                    self.assertEqual(result["startup"]["vmd_arch"], "WIN64")
                    self.assertEqual(result["executable"]["sha256"], hashlib.sha256(Path(sys.executable).read_bytes()).hexdigest())

    def test_zero_process_status_does_not_override_failed_or_missing_receipt(self):
        for receipt in [None, "FAIL\ndetail assertion failed\n"]:
            with tempfile.TemporaryDirectory(prefix="rmsx-gate-test-") as tmp:
                def fake_run(command, **kwargs):
                    if receipt:
                        Path(kwargs["env"]["RMSX_TEST_RESULT"]).write_text(receipt)
                    return argparse.Namespace(stdout="VMD exited normally\n", returncode=0)
                args = argparse.Namespace(tclsh="unused", vmd="unused", timeout=1)
                entry = {"id": "injected_failure", "script": "not-run.tcl", "capability": "tcl"}
                with patch.object(run_tests.subprocess, "run", fake_run):
                    result = run_tests.run_one(entry, args, Path(tmp))
                self.assertEqual(result["status"], "FAIL")

    def test_required_skip_is_failure(self):
        with tempfile.TemporaryDirectory(prefix="rmsx-gate-test-") as tmp:
            def fake_run(command, **kwargs):
                Path(kwargs["env"]["RMSX_TEST_RESULT"]).write_text("PASS\n")
                return argparse.Namespace(stdout="dashboard smoke skipped: Tk unavailable\n", returncode=0)
            args = argparse.Namespace(tclsh="unused", vmd="unused", timeout=1)
            entry = {"id": "injected_skip", "script": "not-run.tcl", "capability": "gui"}
            with patch.object(run_tests.vmd_process, "run", fake_run):
                result = run_tests.run_one(entry, args, Path(tmp))
            self.assertEqual(result["status"], "FAIL")


class SourceArchiveTests(unittest.TestCase):
    def make_archive(self, root):
        package = "rmsxflipbooktimeline0.3.1"
        files = {package + "/VERSION": b"0.3.1\n", package + "/core/example.tcl": b"set example 1\n"}
        payload = sorted(files)
        fingerprint = hashlib.sha256(b"RMSX reviewer payload source v1\0")
        for name in payload:
            encoded, data = name.encode(), files[name]
            fingerprint.update(str(len(encoded)).encode() + b":" + encoded)
            fingerprint.update(str(len(data)).encode() + b":" + data)
        build_id = fingerprint.hexdigest()
        files[package + "/BUILD_ID"] = (build_id + "\n").encode()
        files["REVIEW_BUILD.json"] = b"{}\n"
        for name, content in files.items():
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(content)
        manifest = {"schema": 2, "package": "rmsxflipbooktimeline", "version": "0.3.1",
                    "source_revision": "a" * 40, "dirty_review_snapshot": False, "build_id": build_id,
                    "demo_payload_files": payload,
                    "files": {name: hashlib.sha256(content).hexdigest() for name, content in files.items()}}
        (root / "RELEASE_MANIFEST.json").write_text(json.dumps(manifest))
        return package, manifest

    def test_clean_archive_preserves_identity_without_trusting_parent_git(self):
        with tempfile.TemporaryDirectory(prefix="rmsx-archive-test-") as tmp:
            root = Path(tmp) / "archive"; root.mkdir()
            package, manifest = self.make_archive(root)
            result = run_tests.archive_provenance(root, package)
            self.assertEqual(result["revision"], manifest["source_revision"])
            self.assertFalse(result["dirty"])
            self.assertEqual(result["build_id"], manifest["build_id"])
            with patch.object(run_tests, "ROOT", root), patch.object(run_tests, "PACKAGE", root / package), \
                 patch.object(run_tests.subprocess, "run", return_value=argparse.Namespace(stdout=tmp, returncode=0)):
                observed = run_tests.source_provenance()
            self.assertEqual(observed, result)

    def test_modified_missing_unlisted_and_traversing_archive_files_are_rejected(self):
        for failure in ("modified", "missing", "unlisted", "traversal", "wrong_build_id"):
            with tempfile.TemporaryDirectory(prefix="rmsx-archive-negative-") as tmp:
                root = Path(tmp); package, manifest = self.make_archive(root)
                path = root / package / "core/example.tcl"
                if failure == "modified": path.write_text("modified")
                elif failure == "missing": path.unlink()
                elif failure == "unlisted": (path.parent / "extra.tcl").write_text("extra")
                elif failure == "traversal": manifest["files"]["../outside"] = "b" * 64
                else:
                    changed = ("c" * 64 + "\n").encode()
                    (root / package / "BUILD_ID").write_bytes(changed)
                    manifest["files"][package + "/BUILD_ID"] = hashlib.sha256(changed).hexdigest()
                (root / "RELEASE_MANIFEST.json").write_text(json.dumps(manifest))
                with self.assertRaises(ValueError, msg=failure):
                    run_tests.archive_provenance(root, package)


if __name__ == "__main__":
    unittest.main()
