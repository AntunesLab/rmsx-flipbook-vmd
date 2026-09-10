"""Negative qualification gates must remain failures, regardless of process status."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import handoff_gate as gate


class HandoffGateTests(unittest.TestCase):
    def test_complete_evidence_and_missing_or_stale_receipts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            suite = {"profile": "release", "complete_local_release_profile": True,
                     "source": {"revision": "a" * 40, "dirty": False}, "source_changed_during_run": False,
                     "results": [{"id": "required", "status": "PASS", "receipt": "PASS\n"}]}
            quick = {"build_id": "b" * 64, "status": "PASS", "stages": [{"name": name, "status": "PASS"} for name in gate.QUICK_STAGES]}
            (root / "suite.json").write_text(json.dumps(suite))
            (root / "quick.json").write_text(json.dumps(quick))
            (root / "audit.md").write_text("Synthetic test audit\n")
            item = {"status": "PASS", "artifact_sha256": "c" * 64, "build_id": "b" * 64,
                    "source_revision": "a" * 40, "reviewer": "test", "os": "test", "graphics": "test",
                    "manual": {name: "PASS" for name in gate.MANUAL_CHECKS},
                    "suite_report": "suite.json", "quick_check_report": "quick.json"}
            evidence = {"schema": 1, "targets": {key: dict(copy.deepcopy(item), vmd_distribution=value) for key, value in gate.TARGETS.items()}}
            for name in ("history_audit", "fixture_provenance_audit"):
                evidence[name] = {"status": "PASS", "source_revision": "a" * 40, "reviewer": "test", "report": "audit.md"}
            def qualifies(data):
                return gate.evaluate(data, "c" * 64, "b" * 64, "a" * 40, ["required"], root)["release_qualified"]
            self.assertTrue(qualifies(evidence))
            first = next(iter(gate.TARGETS))
            for field, value in (("status", "PENDING"), ("artifact_sha256", "old"), ("manual", {}), ("suite_report", "missing.json")):
                bad = copy.deepcopy(evidence)
                bad["targets"][first][field] = value
                self.assertFalse(qualifies(bad), field)
            bad = copy.deepcopy(evidence)
            del bad["targets"][first]
            self.assertFalse(qualifies(bad))
            for change in ({"results": []}, {"profile": "tcl"}, {"source_changed_during_run": True},
                           {"results": [{"id": "required", "status": "PASS", "receipt": ""}]}):
                (root / "suite.json").write_text(json.dumps(dict(suite, **change)))
                self.assertFalse(qualifies(evidence), change)


if __name__ == "__main__":
    unittest.main()
