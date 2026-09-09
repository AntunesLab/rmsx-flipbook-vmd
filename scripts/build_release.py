#!/usr/bin/env python3
"""Build a reproducible source/plugin archive without VMD binaries or local outputs."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import zipfile
from check_release import main as check_release
from run_tests import ROOT, PACKAGE
from release_inventory import release_paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--allow-dirty", action="store_true", help="Build a clearly marked local review snapshot")
    args = parser.parse_args()
    check_release()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
    if dirty and not args.allow_dirty:
        parser.error("Commit the release contents first, or use --allow-dirty for a local review snapshot")
    version = (PACKAGE / "VERSION").read_text().strip()
    paths = release_paths()
    contents = {str(p.relative_to(ROOT)).replace("\\", "/"): p.read_bytes() for p in paths}
    manifest = {"schema": 1, "package": "rmsxflipbooktimeline", "version": version,
                "source_revision": revision, "dirty_review_snapshot": dirty,
                "distribution_status": "private_review_build", "release_qualified": False,
                "files": {n: hashlib.sha256(data).hexdigest() for n, data in sorted(contents.items())}}
    contents["RELEASE_MANIFEST.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    args.output.mkdir(parents=True, exist_ok=True)
    target = args.output / f"rmsx-flipbook-vmd-{version}-review.zip"
    if target.exists():
        parser.error(f"Archive exists; choose a new output directory: {target}")
    prefix = f"rmsx-flipbook-vmd-{version}/"
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(contents.items()):
            info = zipfile.ZipInfo(prefix + name, date_time=(2026, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100755 if name.endswith(".sh") else 0o100644) << 16
            archive.writestr(info, data)
    checksum = hashlib.sha256(target.read_bytes()).hexdigest()
    target.with_suffix(".zip.sha256").write_text(f"{checksum}  {target.name}\n")
    print(target)
    print(f"SHA256 {checksum}")


if __name__ == "__main__":
    main()
