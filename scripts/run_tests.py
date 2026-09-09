#!/usr/bin/env python3
"""Run explicit Tcl/VMD suites with isolated fixtures and result receipts.

The plugin itself does not require Python. This standard-library tool is for
developers, packaging and CI; VMD's process status alone is not a test result.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import vmd_process

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = next(p for p in ROOT.glob("rmsxflipbooktimeline*") if p.is_dir())
MANIFEST = ROOT / "scripts/suite.json"


def check_manifest(entries):
    scripts = {p.name for p in (PACKAGE / "tests").glob("smoke_*.tcl")}
    listed = {e["script"] for e in entries}
    missing, stale = scripts - listed, listed - scripts
    if missing or stale:
        raise ValueError(f"Suite coverage mismatch; unlisted={sorted(missing)}, missing files={sorted(stale)}")
    if len({e["id"] for e in entries}) != len(entries):
        raise ValueError("Duplicate suite test IDs")


def verify_fixtures():
    manifest = json.loads((ROOT / "fixtures/provenance.json").read_text(encoding="utf-8"))
    for entry in manifest["files"]:
        path = ROOT / "fixtures" / entry["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"Fixture checksum mismatch: {entry['file']}")


def source_provenance():
    """Bind receipts to exact source bytes, including an uncommitted review build."""
    digest = hashlib.sha256()
    roots = [PACKAGE, ROOT / "scripts", ROOT / "docs", ROOT / ".github"]
    paths = [p for base in roots for p in base.rglob("*") if p.is_file()]
    paths += [p for p in ROOT.iterdir() if p.is_file()]
    paths += [ROOT / "fixtures/provenance.json"]
    for path in sorted(paths):
        if "__pycache__" in path.parts or path.name == ".DS_Store" or path.suffix == ".pyc":
            continue
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    def git(*arguments):
        result = subprocess.run(["git", "-C", str(ROOT), *arguments], capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else None
    try:
        revision, state = git("rev-parse", "HEAD"), git("status", "--porcelain")
    except OSError:
        revision, state = None, None
    return {"revision": revision, "dirty": bool(state) if state is not None else None,
            "sha256": digest.hexdigest()}


def run_one(entry, args, artifact_root):
    work = artifact_root / entry["id"]
    work.mkdir()
    shutil.copytree(ROOT / "fixtures", work / "fixtures")
    (work / "outputs").mkdir()
    for name in entry.get("seed_outputs", []):
        shutil.copytree(ROOT / "fixtures/seed_outputs" / name, work / "outputs" / name)
    (work / "tmp").mkdir()
    status_path = work / "result.txt"
    env = os.environ.copy()
    # Do not inherit a developer's feature gate or Tk behavior into stable tests.
    env.pop("RMSXFLIPBOOKTIMELINE_EXPERIMENTAL", None)
    env.update({
        "RMSX_TEST_REPO": str(ROOT), "RMSX_TEST_PACKAGE": str(PACKAGE),
        "RMSX_TEST_WORKDIR": str(work), "RMSX_TEST_RESULT": str(status_path),
        "RMSX_TEST_SCRIPT": str(PACKAGE / "tests" / entry["script"]),
        "RMSX_TEST_GUI": "1" if entry["capability"] in {"gui", "render"} else "0",
        "RMSX_TEST_ASYNC": "1" if entry.get("async") else "0",
        "RMSX_TEST_ARGS": "\n".join(str(work / p) for p in entry.get("args", [])),
        "RMSXFLIPBOOKTIMELINE_DNA_FIXTURE": str(work / "fixtures/dna/bdna.pdb"),
        "TMPDIR": str(work / "tmp"), "TEMP": str(work / "tmp"), "TMP": str(work / "tmp"),
    })
    if entry.get("experimental"):
        env["RMSXFLIPBOOKTIMELINE_EXPERIMENTAL"] = "1"
    if entry["capability"] == "tcl":
        command = [args.tclsh, str(ROOT / "scripts/test_harness.tcl")]
    else:
        command = [args.vmd, "-dispdev", "win" if env["RMSX_TEST_GUI"] == "1" else "text",
                   "-e", str(ROOT / "scripts/test_harness.tcl")]
    began = time.monotonic()
    status, reason, code = "FAIL", "No explicit PASS receipt", None
    try:
        if entry["capability"] == "tcl":
            result = subprocess.run(command, cwd=work, env=env, stdout=subprocess.PIPE,
                                    stdin=subprocess.DEVNULL, stderr=subprocess.STDOUT,
                                    text=True, encoding="utf-8", errors="replace", timeout=args.timeout)
        else:
            result = vmd_process.run(command, cwd=work, env=env, timeout=args.timeout)
        output, code = result.stdout, result.returncode
        receipt = status_path.read_text(encoding="utf-8") if status_path.exists() else ""
        if receipt.startswith("PASS\n") and code == 0:
            status, reason = "PASS", "Assertions completed"
        elif receipt:
            reason = receipt.strip()
        if re.search(r"smoke (?:failed|skipped)|^FAIL |^SKIP ", output, re.I | re.M):
            status, reason = "FAIL", "Test reported a failure or unavailable required capability; inspect log"
        if (entry.get("optional") and code == 0 and receipt.startswith("PASS\n")
                and "skipped" in output.lower() and "failed" not in output.lower()):
            status, reason = "SKIP", "Optional experimental capability unavailable; inspect log"
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        reason = f"Timed out after {args.timeout}s"
    except OSError as exc:
        output, reason = str(exc), f"Cannot launch required runtime: {exc}"
    (work / "test.log").write_text(output, encoding="utf-8")
    return {"id": entry["id"], "status": status, "reason": reason,
            "seconds": round(time.monotonic() - began, 3), "exit_code": code,
            "capability": entry["capability"], "script": entry["script"],
            "receipt": status_path.read_text(encoding="utf-8") if status_path.exists() else None,
            "log": str(work / "test.log")}


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=["tcl", "vmd", "gui", "release"], default="tcl")
    parser.add_argument("--vmd", default=os.environ.get("VMD_EXECUTABLE", "vmd"))
    parser.add_argument("--tclsh", default=os.environ.get("TCLSH", shutil.which("tclsh8.6") or "tclsh"))
    parser.add_argument("--only", help="Comma-separated test IDs; capability requirements still apply")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--artifacts", type=Path, help="New directory; defaults to a unique OS temp directory")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["tests"]
    try:
        check_manifest(entries)
        verify_fixtures()
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    allowed = {"tcl": {"tcl"}, "vmd": {"tcl", "vmd"},
               "gui": {"tcl", "vmd", "gui"}, "release": {"tcl", "vmd", "gui", "render"}}[args.profile]
    selected = [e for e in entries if e["capability"] in allowed]
    if args.only:
        wanted = set(args.only.split(","))
        selected = [e for e in selected if e["id"] in wanted]
        if wanted != {e["id"] for e in selected}:
            parser.error("Requested tests missing or require a broader --profile")
    if args.list:
        for e in selected:
            print(f"{e['id']:44s} {e['capability']:7s} {'experimental' if e.get('experimental') else 'stable'}")
        return 0
    if args.artifacts:
        artifact_root = args.artifacts.resolve()
        artifact_root.mkdir(parents=True, exist_ok=False)
    else:
        artifact_root = Path(tempfile.mkdtemp(prefix="rmsx-tests-"))
    before_source = source_provenance()
    results = []
    print(f"Profile: {args.profile}; {len(selected)} tests; artifacts: {artifact_root}", flush=True)
    for entry in selected:
        result = run_one(entry, args, artifact_root)
        results.append(result)
        print(f"{result['status']:4s} {entry['id']} ({result['seconds']}s)", flush=True)
        if result["status"] != "PASS":
            print(f"     {result['reason']} - {result['log']}", flush=True)
    after_source = source_provenance()
    source_changed = before_source["sha256"] != after_source["sha256"]
    summary = {"schema": 2, "profile": args.profile,
               "source": before_source, "source_changed_during_run": source_changed,
               "platform": platform.platform(), "architecture": platform.machine(),
               "version": (PACKAGE / "VERSION").read_text(encoding="utf-8").strip(),
               "complete_local_release_profile": args.profile == "release" and not args.only,
               "qualification_scope": "local_runtime_only",
               "release_qualified": False,
               "required_platforms_pending": ["Intel macOS", "Linux graphical VMD",
                                               "Windows VMD", "maintainer-approved stable VMD"],
               "results": results}
    (artifact_root / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    counts = {s: sum(r["status"] == s for r in results) for s in ["PASS", "FAIL", "SKIP"]}
    print(f"{counts}; report: {artifact_root / 'summary.json'}")
    if source_changed:
        print("FAIL source changed during this run; rerun qualification against a stable revision")
    return 1 if counts["FAIL"] or source_changed else 0


if __name__ == "__main__":
    sys.exit(main())
