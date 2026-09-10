"""Negative qualification gates must remain failures, regardless of labels."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import handoff_gate as gate


def complete_evidence(root):
    (root / "audit.md").write_text("Synthetic test audit\n")
    evidence = {"schema": 1, "targets": {}}
    for target, distribution in gate.TARGETS.items():
        os_name, arch, version, windowing = gate.RUNTIMES[target]
        environment = {"os": os_name, "os_version": "verified-kernel-version", "machine": "actual-cpu",
                       "executable": "/test/vmd", "tcl": "8.6.16", "tk": "8.6.16", "vmd": version,
                       "vmd_arch": arch, "graphics_mode": "gui", "windowing": sorted(windowing)[0],
                       "display_width": "800", "display_height": "600", "graphics_driver": "unknown"}
        suite = {"profile": "release", "complete_local_release_profile": True,
                 "source": {"revision": "a" * 40, "dirty": False}, "source_changed_during_run": False,
                 "launcher": {"sha256": "d" * 64},
                 "results": [{"id": "required", "capability": "render", "status": "PASS", "receipt": "PASS\n",
                              "environment": environment, "executable": {"sha256": "e" * 64},
                              "startup": {"vmd": version, "vmd_arch": arch, "build_date": "verified-build-date"}}]}
        quick = {"build_id": "b" * 64, "status": "PASS", "environment": environment,
                 "stages": [{"name": name, "status": "PASS"} for name in gate.QUICK_STAGES]}
        (root / (target + "-suite.json")).write_text(json.dumps(suite))
        (root / (target + "-quick.json")).write_text(json.dumps(quick))
        evidence["targets"][target] = {"status": "PASS", "artifact_sha256": "c" * 64, "build_id": "b" * 64,
            "source_revision": "a" * 40, "reviewer": "test", "os": "test", "graphics": "test",
            "vmd_distribution": distribution, "vmd_executable_sha256": "e" * 64, "vmd_build_date": "verified-build-date",
            "manual": {name: "PASS" for name in gate.MANUAL_CHECKS},
            "suite_report": target + "-suite.json", "quick_check_report": target + "-quick.json"}
    for name in ("history_audit", "fixture_provenance_audit"):
        evidence[name] = {"status": "PASS", "source_revision": "a" * 40, "reviewer": "test", "report": "audit.md"}
    return evidence


class HandoffGateTests(unittest.TestCase):
    def qualifies(self, evidence, root):
        return gate.evaluate(evidence, "c" * 64, "b" * 64, "a" * 40, ["required"], root,
                             test_capabilities={"required": "render"})["release_qualified"]

    def test_complete_evidence_and_missing_or_stale_receipts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); evidence = complete_evidence(root)
            self.assertTrue(self.qualifies(evidence, root))
            first = next(iter(gate.TARGETS))
            for field, value in (("status", "PENDING"), ("artifact_sha256", "old"), ("manual", {}),
                                 ("suite_report", "missing.json"), ("vmd_executable_sha256", "f" * 64),
                                 ("vmd_build_date", "wrong-build-date")):
                bad = copy.deepcopy(evidence); bad["targets"][first][field] = value
                self.assertFalse(self.qualifies(bad, root), field)
            bad = copy.deepcopy(evidence); del bad["targets"][first]
            self.assertFalse(self.qualifies(bad, root))
            path = root / evidence["targets"][first]["suite_report"]
            original = json.loads(path.read_text())
            for change in ({"results": []}, {"profile": "tcl"}, {"source_changed_during_run": True},
                           {"source": {"revision": "a" * 40, "dirty": False, "kind": "release_manifest", "build_id": "f" * 64}},
                           {"results": [{"id": "required", "status": "PASS", "receipt": ""}]}):
                path.write_text(json.dumps(dict(original, **change)))
                self.assertFalse(self.qualifies(evidence, root), change)

    def test_one_runtime_report_cannot_qualify_other_platforms_or_vmd_builds(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); evidence = complete_evidence(root)
            source = next(iter(evidence["targets"].values()))
            for field in ("suite_report", "quick_check_report"):
                bad = copy.deepcopy(evidence)
                for target in bad["targets"].values():
                    target[field] = source[field]
                self.assertFalse(self.qualifies(bad, root), field)

    def test_missing_mismatched_and_headless_runtime_evidence_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); evidence = complete_evidence(root)
            target = next(iter(evidence["targets"]))
            for report_field in ("suite_report", "quick_check_report"):
                path = root / evidence["targets"][target][report_field]
                original = json.loads(path.read_text())
                for key, value in (("os", "Linux"), ("os_version", ""), ("vmd_arch", "MACOSXX86_64"),
                                   ("vmd", "1.9.4a57"), ("graphics_mode", "headless"), ("tk", "unavailable"),
                                   ("display_width", "unavailable"), ("tcl", "8.5.9")):
                    changed = copy.deepcopy(original)
                    row = changed["results"][0] if report_field == "suite_report" else changed
                    row["environment"][key] = value
                    path.write_text(json.dumps(changed))
                    self.assertFalse(self.qualifies(evidence, root), (report_field, key))
                path.write_text(json.dumps(original))

    def test_capability_cannot_be_relabeled_to_bypass_graphical_checks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); evidence = complete_evidence(root)
            path = root / next(iter(evidence["targets"].values()))["suite_report"]
            suite = json.loads(path.read_text())
            suite["results"][0]["capability"] = "tcl"
            suite["results"][0]["environment"]["graphics_mode"] = "headless"
            path.write_text(json.dumps(suite))
            self.assertFalse(self.qualifies(evidence, root))


if __name__ == "__main__":
    unittest.main()
