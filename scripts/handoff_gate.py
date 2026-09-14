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
QUICK_STAGES = {"preflight", "calculation", "identity", "rotation", "rendering", "residue_thickness", "cleanup"}
# Distribution names and interpreter-reported versions are different for pre2.
# Its exact binary hash/build date must also be supplied and match suite receipts.
RUNTIMES = {
    "macos-arm64-2.0b1": ("darwin", "MACOSXARM64", "2.0b1", {"aqua", "x11"}),
    "macos-arm64-2.0.0a7-pre2": ("darwin", "MACOSXARM64", "2.0.0a7", {"aqua", "x11"}),
    "macos-intel-1.9.4a57": ("darwin", "MACOSXX86_64", "1.9.4a57", {"aqua", "x11"}),
    "windows-x64-2.0.0a6": ("windowsnt", "WIN64", "2.0.0a6", {"win32"}),
    "linux-x64-2.0.1a1": ("linux", "LINUXAMD64", "2.0.1a1", {"x11"}),
}
# The official Windows a6 installer reports a6 through vmdinfo, but its startup
# banner says a7. Preserve both observations; exact binary/date checks still apply.
STARTUP_VERSIONS = {"windows-x64-2.0.0a6": {"2.0.0a6", "2.0.0a7"}}


def digest(value):
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{64}", value))


def environment_failures(environment, target, capability):
    """Validate observed interpreter data, never the target's claimed label."""
    if not isinstance(environment, dict):
        return ["runtime environment is missing"]
    expected_os, expected_arch, expected_vmd, windowing = RUNTIMES[target]
    errors = []
    actual_os = str(environment.get("os", "")).lower().replace(" ", "")
    if actual_os != expected_os:
        errors.append("observed OS does not match target")
    for key in ("os_version", "machine", "executable"):
        if environment.get(key) in (None, "", "unknown", "unavailable"):
            errors.append("observed " + key + " is missing")
    if not str(environment.get("tcl", "")).startswith("8.6."):
        errors.append("observed Tcl is not 8.6")
    if capability != "tcl":
        if environment.get("vmd") != expected_vmd or environment.get("vmd_arch") != expected_arch:
            errors.append("observed VMD version/architecture does not match target")
    if capability in {"gui", "render", "quick_check"}:
        if (environment.get("graphics_mode") != "gui"
                or not str(environment.get("tk", "")).startswith("8.6.")
                or environment.get("windowing") not in windowing):
            errors.append("graphical Tcl/Tk environment was not observed")
        for key in ("display_width", "display_height"):
            try:
                positive = int(environment.get(key, 0)) > 0
            except (TypeError, ValueError):
                positive = False
            if not positive:
                errors.append("observed " + key + " is missing")
    elif environment.get("graphics_mode") != "headless":
        errors.append("headless test environment is not explicit")
    return errors


def evaluate(evidence, artifact_sha256, build_id, revision, required_tests, base, optional_tests=(), test_capabilities=None, *, profile="release", waiver=None):
    failures = []
    def need(condition, message):
        if not condition:
            failures.append(message)
    need(evidence.get("schema") == 1, "Unsupported evidence schema")
    need(bool(re.fullmatch(r"[0-9a-f]{64}", build_id)), "Invalid build ID")
    need(bool(re.fullmatch(r"[0-9a-f]{40}", revision)), "Invalid source revision")
    need(profile in {"release", "developer-review"}, "Unknown qualification profile")
    waived = []
    waiver_valid = False
    if waiver is not None:
        waiver_valid = (profile == "developer-review" and isinstance(waiver, dict)
            and waiver.get("scope") == "developer review"
            and waiver.get("check") == "unassisted_trial_under_two_minutes"
            and waiver.get("status") == "WAIVED_BY_USER"
            and waiver.get("passed") is False and waiver.get("other_checks_waived") is False
            and isinstance(waiver.get("authorization"), str) and bool(waiver["authorization"].strip())
            and isinstance(waiver.get("date"), str) and bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}", waiver["date"]))
            and isinstance(waiver.get("targets"), list)
            and all(isinstance(t, str) for t in waiver["targets"])
            and len(waiver["targets"]) == len(TARGETS) and set(waiver["targets"]) == set(TARGETS))
        need(waiver_valid, "Invalid waiver or waiver requested outside developer-review profile")
    capabilities = test_capabilities or {name: "vmd" for name in required_tests}
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
        need(digest(item.get("vmd_executable_sha256")), prefix + "exact VMD executable hash missing")
        need(bool(item.get("vmd_build_date")), prefix + "VMD startup build date missing")
        need(bool(item.get("reviewer")) and bool(item.get("os")) and bool(item.get("graphics")), prefix + "machine/reviewer details missing")
        for check in MANUAL_CHECKS:
            status = item.get("manual", {}).get(check)
            if waiver_valid and check == "unassisted_trial_under_two_minutes" and status == "WAIVED_BY_USER":
                waived.append({"target": target, "check": check, "status": status})
            else:
                need(status == "PASS", prefix + check + " has no passing observation")
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
                if source.get("kind") == "release_manifest":
                    need(source.get("build_id") == build_id, prefix + "source archive belongs to a different reviewer payload")
                results = report.get("results", [])
                ids = [r.get("id") for r in results]
                need(set(ids) == set(required_tests) and len(ids) == len(required_tests), prefix + "missing/duplicate suite receipts")
                need(bool(results) and all((r.get("status") == "PASS" or (r.get("id") in optional_tests and r.get("status") == "SKIP")) and str(r.get("receipt", "")).startswith("PASS\n") for r in results), prefix + "suite has failed, skipped required, or missing completion receipts")
                need(digest(report.get("launcher", {}).get("sha256")), prefix + "suite launcher hash missing")
                for result in results:
                    name = result.get("id")
                    capability = capabilities.get(name)
                    need(capability in {"tcl", "vmd", "gui", "render"} and result.get("capability") == capability,
                         prefix + str(name) + ": capability does not match the test manifest")
                    for error in environment_failures(result.get("environment"), target, capability):
                        failures.append(prefix + str(name) + ": " + error)
                    if capability != "tcl":
                        startup = result.get("startup", {})
                        need(digest(result.get("executable", {}).get("sha256"))
                             and result["executable"]["sha256"] == item.get("vmd_executable_sha256"),
                             prefix + str(name) + ": runtime binary does not match the reviewed distribution")
                        need(startup.get("vmd") in STARTUP_VERSIONS.get(target, {RUNTIMES[target][2]})
                             and startup.get("vmd_arch") == RUNTIMES[target][1]
                             and startup.get("build_date") == item.get("vmd_build_date"),
                             prefix + str(name) + ": VMD startup identity does not match the target")
            else:
                need(report.get("build_id") == build_id and report.get("status") == "PASS", prefix + "Quick Check did not pass this build")
                stages = report.get("stages", [])
                need({s.get("name") for s in stages} == QUICK_STAGES and len(stages) == len(QUICK_STAGES)
                     and all(s.get("status") == "PASS" for s in stages), prefix + "Quick Check contains missing or incomplete stages")
                for error in environment_failures(report.get("environment"), target, "quick_check"):
                    failures.append(prefix + "Quick Check: " + error)
    return {"schema": 1, "profile": profile, "qualified": not failures,
            "release_qualified": not failures and not waived,
            "developer_review_ready": profile == "developer-review" and not failures,
            "waived_checks": waived,
            "artifact_sha256": artifact_sha256, "build_id": build_id,
            "source_revision": revision, "failures": failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("release", "developer-review"), default="release")
    parser.add_argument("--waiver", type=Path, help="Explicit user waiver; developer-review only")
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
                          [t["id"] for t in suite["tests"] if t.get("optional")],
                          {t["id"]: t["capability"] for t in suite["tests"]}, profile=args.profile,
                          waiver=json.loads(args.waiver.read_text(encoding="utf-8")) if args.waiver else None)
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
        result = {"schema": 1, "release_qualified": False, "failures": [str(exc)]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: " + args.profile + " handoff qualified" if result.get("qualified", False) else "PENDING/FAIL: public handoff remains private; inspect " + str(args.output))
    return 0 if result.get("qualified", False) else 1


if __name__ == "__main__":
    sys.exit(main())
