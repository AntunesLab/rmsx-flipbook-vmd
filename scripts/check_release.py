#!/usr/bin/env python3
"""Check portable paths, package/version metadata and complete test coverage."""
from pathlib import Path
import json
import re
from run_tests import ROOT, PACKAGE, check_manifest, verify_fixtures
from release_inventory import release_paths


def main():
    version = (PACKAGE / "VERSION").read_text(encoding="utf-8").strip()
    if PACKAGE.name != "rmsxflipbooktimeline" + version:
        raise SystemExit("Package directory and VERSION disagree")
    check_manifest(json.loads((ROOT / "scripts/suite.json").read_text(encoding="utf-8"))["tests"])
    verify_fixtures()
    release_paths()
    forbidden = re.compile(r"/Users/finn|downloads/vmd/current|VMD2b1\.app|rmsxflipbooktimeline0\.[12]")
    failures = []
    for directory in [PACKAGE, ROOT / "scripts"]:
        for path in directory.rglob("*"):
            if path.suffix not in {".tcl", ".sh", ".py"} or path.name == "check_release.py":
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if forbidden.search(line):
                    failures.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
    required = ["LICENSE", "THIRD_PARTY_NOTICES.md", "README.md", "CHANGELOG.md", "docs/SUPPORT.md"]
    failures.extend(f"Missing {name}" for name in required if not (ROOT / name).is_file())
    if failures:
        raise SystemExit("Release check failed:\n" + "\n".join(failures))
    print(f"Release paths, VERSION {version}, fixtures and suite coverage passed")


if __name__ == "__main__":
    main()
