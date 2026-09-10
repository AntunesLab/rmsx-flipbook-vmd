#!/usr/bin/env python3
"""Build a reproducible source/plugin archive without VMD binaries or local outputs."""
from pathlib import Path
import argparse
import hashlib
import io
import json
import subprocess
import sys
import zipfile
from check_release import main as check_release
from run_tests import ROOT, PACKAGE
from release_inventory import release_paths
from build_demo import generate, select_payload, write_immutable, checksum_bytes


def release_artifacts(snapshot, package_name, version, revision, dirty):
    """Produce every handoff artifact from the same immutable source snapshot."""
    demo = generate(select_payload(snapshot, package_name), package_name, version,
                    template=snapshot["scripts/reviewer_bootstrap.tcl.in"].decode("utf-8"),
                    revision=revision, dirty=dirty)
    contents = dict(snapshot)
    contents[f"{package_name}/BUILD_ID"] = demo.files[f"{package_name}/BUILD_ID"]
    contents["REVIEW_BUILD.json"] = demo.files["REVIEW_BUILD.json"]
    manifest = {"schema": 2, "package": "rmsxflipbooktimeline", "version": version,
                "source_revision": revision, "dirty_review_snapshot": dirty,
                "distribution_status": "private_review_build", "release_qualified": False,
                "build_id": demo.build_id,
                "demo_payload_files": sorted(demo.source_files),
                "files": {n: hashlib.sha256(data).hexdigest() for n, data in sorted(contents.items())}}
    contents["RELEASE_MANIFEST.json"] = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    prefix = f"rmsx-flipbook-vmd-{version}/"
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(contents.items()):
            info = zipfile.ZipInfo(prefix + name, date_time=(2026, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100755 if name.endswith(".sh") else 0o100644) << 16
            archive.writestr(info, data)
    artifacts = {f"rmsx-flipbook-vmd-{version}-review.zip": buffer.getvalue(),
                 f"TRY_RMSX_{version}.vmd": demo.data}
    for name, data in list(artifacts.items()):
        artifacts[name + ".sha256"] = checksum_bytes(Path(name), data)
    return artifacts, manifest


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--allow-dirty", action="store_true", help="Build a clearly marked local review snapshot")
    args = parser.parse_args()
    check_release()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
    if dirty and not args.allow_dirty:
        parser.error("Commit the release contents first, or use --allow-dirty for a local review snapshot")
    paths = release_paths()
    snapshot = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in paths}
    version = snapshot[f"{PACKAGE.name}/VERSION"].decode("utf-8").strip()
    artifacts, manifest = release_artifacts(snapshot, PACKAGE.name, version, revision, dirty)
    after = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in release_paths()}
    if after != snapshot:
        parser.error("Release source changed while building; no artifacts were published")
    for name, data in artifacts.items():
        target = args.output / name
        if target.exists() and target.read_bytes() != data:
            parser.error(f"Different artifact already exists; choose a new output directory: {target}")
    for name, data in artifacts.items():
        target = args.output / name
        write_immutable(target, data)
        print(target)
    print(f"Build ID: {manifest['build_id']}")


if __name__ == "__main__":
    main()
