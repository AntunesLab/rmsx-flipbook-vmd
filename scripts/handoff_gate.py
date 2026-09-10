#!/usr/bin/env python3
"""Require exact-build automated and human evidence before public handoff.

This validates submitted evidence; it does not invent observations or contact
testers. A missing machine, report, required check, or final receipt fails closed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

TARGETS = {
    "macos-arm64-2.0b1": "2.0b1",
    "macos-arm64-2.0.0a7-pre2": "2.0.0a7-pre2",
    "macos-intel-1.9.4a57": "1.9.4a57",
    "windows-x64-2.0.0a6": "2.0.0a6",
    "linux-x64-2.0.1a1": "2.0.1a1",
}
MANUAL_CHECKS = (
    "file_menu_open", "renamed_non_ascii_download", "offline_open",
    "single_and_multi_fresh_run", "comparison_and_residue_linking",
    "mouse_rotation_in_place", "resize_and_window_placement",
    "live_opengl_and_export", "cancel_close_reopen_remove",
    "unrelated_session_preserved", "unassisted_trial_under_two_minutes",
)
QUICK_STAGES = {"preflight", "calculation", "identity", "rotation", "rendering", "cleanup"}


def evaluate(evidence, artifact_sha256, build_id, revision, required_tests, base, optional_tests=()):
    failures = []
    def need(condition, message):
        if not condition:
            failures.append(message)
    need(evidence.get("schema") == 1, "Unsupported evidence schema")
    need(bool(re.fullmatch(r"[0-9a-f]{64}", build_id)), "Invalid build ID")
    need(bool(re.fullmatch(r"[0-9a-f]{40}", revision)), "Invalid source revision")
    for key in ("history_audit", "fixture_provenance_audit"):
        audit = evidence.get(key, {})
        need(audit.get("status") == "PASS" and audit.get("source_revision") == revision
             and bool(audit.get("reviewer")) and bool(audit.get("report")), f"{key}: final revision needs reviewed evidence")
        need(bool(audit.get("report")) and (base / audit.get("report", "")).is_file(), f"{key}: audit report missing")
    targets = evidence.get("targets", {})
    for target, version in TARGETS.items():
        item = targets.get(target, {})
        prefix = target + ": "
        need(item.get("status") == "PASS", prefix + "qualification pending or failed")
        for key, expected in (("artifact_sha256", artifact_sha256), ("build_id", build_id), ("source_revision", revision)):
            need(item.get(key) == expected, prefix + key + " does not identify this artifact")
        need(item.get("vmd_distribution") == version, prefix + "wrong or unrecorded VMD distribution")
        need(bool(item.get("reviewer")) and bool(item.get("os")) and bool(item.get("graphics")), prefix + "machine/reviewer details missing")
        for check in MANUAL_CHECKS:
            need(item.get("manual", {}).get(check) == "PASS", prefix + check + " has no passing observation")
        for kind in ("suite", "quick_check"):
            try:
                name = item[kind + "_report"]
                if not name:
                    raise ValueError("empty report path")
                report = json.loads((base / name).read_text(encoding="utf-8"))
            except (KeyError, OSError, ValueError) as exc:
                failures.append(prefix + kind + " report unavailable: " + str(exc))
                continue
            if kind == "suite":
                need(report.get("complete_local_release_profile") is True and report.get("profile") == "release", prefix + "full VMD suite was not run")
                source = report.get("source", {})
                need(source.get("revision") == revision and source.get("dirty") is False
                     and report.get("source_changed_during_run") is False, prefix + "suite did not test the clean final revision")
                results = report.get("results", [])
                ids = [r.get("id") for r in results]
                need(set(ids) == set(required_tests) and len(ids) == len(required_tests), prefix + "missing/duplicate suite receipts")
                need(bool(results) and all((r.get("status") == "PASS" or (r.get("id") in optional_tests and r.get("status") == "SKIP")) and str(r.get("receipt", "")).startswith("PASS\n") for r in results), prefix + "suite has failed, skipped required, or missing completion receipts")
            else:
                need(report.get("build_id") == build_id and report.get("status") == "PASS", prefix + "Quick Check did not pass this build")
                stages = report.get("stages", [])
                need({s.get("name") for s in stages} == QUICK_STAGES and len(stages) == len(QUICK_STAGES)
                     and all(s.get("status") == "PASS" for s in stages), prefix + "Quick Check contains missing or incomplete stages")
    return {"schema": 1, "release_qualified": not failures,
            "artifact_sha256": artifact_sha256, "build_id": build_id,
            "source_revision": revision, "failures": failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--source-revision", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    suite = json.loads((Path(__file__).parent / "suite.json").read_text(encoding="utf-8"))
    try:
        evidence = json.loads(args.evidence.read_text(encoding="utf-8"))
        digest = hashlib.sha256(args.artifact.read_bytes()).hexdigest()
        result = evaluate(evidence, digest, args.build_id, args.source_revision,
                          [t["id"] for t in suite["tests"]], args.evidence.resolve().parent,
                          [t["id"] for t in suite["tests"] if t.get("optional")])
    except (OSError, ValueError, TypeError) as exc:
        result = {"schema": 1, "release_qualified": False, "failures": [str(exc)]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: public handoff qualified" if result["release_qualified"] else "PENDING/FAIL: public handoff remains private; inspect " + str(args.output))
    return 0 if result["release_qualified"] else 1


if __name__ == "__main__":
    sys.exit(main())
