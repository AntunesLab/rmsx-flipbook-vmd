#!/usr/bin/env python3
"""Exercise installation ownership and the result gate independently of VMD."""
import argparse
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


if __name__ == "__main__":
    unittest.main()
