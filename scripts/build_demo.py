#!/usr/bin/env python3
"""Generate a VMD-native reviewer file from canonical, allowlisted source bytes.

The recipient needs only VMD with Tcl/Tk 8.6. Python is a release-author tool.
Generated payloads are never committed or maintained as a second implementation.
"""
from __future__ import annotations

import argparse
import base64
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import zlib

from run_tests import ROOT, PACKAGE
from release_inventory import release_paths

TEMPLATE = ROOT / "scripts/reviewer_bootstrap.tcl.in"
CHUNK_SIZE = 8192
MAX_FILE_SIZE = 16 * 1024 * 1024
MAX_TOTAL_SIZE = 96 * 1024 * 1024
# These prefixes are deliberate release inputs, not a recursive repository scan.
DEMO_PREFIXES = (
    "fixtures/seed_outputs/native-rmsx-1ubq-9/",
    "fixtures/seed_outputs/reviewer-protease-9/",
)
DEMO_FILES = (
    "fixtures/upstream/test_files/1UBQ.pdb",
    "fixtures/upstream/test_files/mon_sys.dcd",
    "fixtures/upstream/test_files/protease_backbone.pdb",
    "fixtures/upstream/test_files/short_protease_backbone.dcd",
    "fixtures/upstream/LICENSE",
    "fixtures/provenance.json",
    "fixtures/README.md",
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "scripts/reviewer_start.tcl",
)


@dataclass(frozen=True)
class DemoBuild:
    data: bytes
    build_id: str
    files: dict[str, bytes]
    source_files: dict[str, bytes]
    metadata: dict


def safe_path(name: str) -> None:
    path = PurePosixPath(name)
    if (not name or len(name) > 1024 or len(name.encode("utf-8")) > 1536
            or path.is_absolute() or "\\" in name or ":" in name
            or any(ord(c) < 32 or ord(c) == 127 for c in name)
            or any(p in {"", ".", ".."} or p.rstrip(" .") != p for p in name.split("/"))):
        raise ValueError(f"Unsafe demo payload path: {name!r}")
    if any(re.match(r"^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$", p, re.I) for p in name.split("/")):
        raise ValueError(f"Nonportable demo payload path: {name!r}")


def select_payload(snapshot: dict[str, bytes], package_name: str) -> dict[str, bytes]:
    """Select from the already-validated release snapshot, never read extra files."""
    selected = {}
    for name, data in snapshot.items():
        parts = PurePosixPath(name).parts
        package_file = name.startswith(package_name + "/") and "tests" not in parts
        if package_file or name in DEMO_FILES or name.startswith(DEMO_PREFIXES):
            if name != f"{package_name}/BUILD_ID":
                safe_path(name)
                selected[name] = data
    required = list(DEMO_FILES) + [f"{package_name}/{name}" for name in
        ("VERSION", "pkgIndex.tcl", "rmsxflipbooktimeline.tcl", "gui/reviewer.tcl")]
    missing = [name for name in required if name not in selected]
    missing += [prefix for prefix in DEMO_PREFIXES if not any(p.startswith(prefix) for p in selected)]
    if missing:
        raise ValueError(f"Reviewer payload is missing reviewed inputs: {missing}")
    return dict(sorted(selected.items()))


def fingerprint(files: dict[str, bytes]) -> str:
    digest = hashlib.sha256(b"RMSX reviewer payload source v1\0")
    for name, data in sorted(files.items()):
        encoded = name.encode("utf-8")
        digest.update(str(len(encoded)).encode("ascii") + b":" + encoded)
        digest.update(str(len(data)).encode("ascii") + b":" + data)
    return digest.hexdigest()


def encode_records(files: dict[str, bytes]) -> str:
    if not 1 <= len(files) <= 512 or sum(map(len, files.values())) > MAX_TOTAL_SIZE:
        raise ValueError("Reviewer payload exceeds the bootstrap file/size limits")
    folded = set()
    records = []
    for name, data in sorted(files.items()):
        safe_path(name)
        if name.lower() in folded:
            raise ValueError(f"Case-insensitive duplicate payload path: {name}")
        folded.add(name.lower())
        if len(data) > MAX_FILE_SIZE:
            raise ValueError(f"Reviewer payload file too large: {name}")
        path = base64.b64encode(name.encode("utf-8")).decode("ascii")
        records.append(f"::RMSXReviewBootstrap::stage file {{{path} {len(data)} {zlib.crc32(data)}}}")
        for offset in range(0, len(data), CHUNK_SIZE):
            raw = data[offset:offset + CHUNK_SIZE]
            packed = zlib.compress(raw, 9)
            encoded = base64.b64encode(packed).decode("ascii")
            records.append(f"::RMSXReviewBootstrap::stage chunk {{{len(raw)} {zlib.crc32(raw)} {len(packed)} {zlib.crc32(packed)} {{{encoded}}}}}")
    return "\n".join(records)


def generate(payload: dict[str, bytes], package_name: str, version: str,
             *, template: str | None = None, revision: str | None = None,
             dirty: bool = False) -> DemoBuild:
    """Pure generation, also used for a small synthetic extraction test package."""
    if not re.fullmatch(r"rmsxflipbooktimeline\d+\.\d+(?:\.\d+)?", package_name):
        raise ValueError("Invalid package directory")
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", version):
        raise ValueError("Invalid version")
    if package_name != "rmsxflipbooktimeline" + version:
        raise ValueError("Package directory does not match VERSION")
    sources = dict(payload)
    sources.pop(f"{package_name}/BUILD_ID", None)
    build_id = fingerprint(sources)
    files = dict(sources)
    files[f"{package_name}/BUILD_ID"] = (build_id + "\n").encode("ascii")
    evidence = {"schema": 1, "package": "rmsxflipbooktimeline", "version": version,
                "build_id": build_id, "source_revision": revision,
                "dirty_review_snapshot": dirty, "distribution_status": "private_review_build",
                "release_qualified": False,
                "files": {name: hashlib.sha256(data).hexdigest() for name, data in sorted(sources.items())}}
    files["REVIEW_BUILD.json"] = (json.dumps(evidence, indent=2, sort_keys=True) + "\n").encode("utf-8")
    metadata = {"schema": 1, "build_id": build_id, "version": version, "package_dir": package_name,
                "file_count": len(files), "total_bytes": sum(map(len, files.values()))}
    metadata_tcl = " ".join(f"{key} {value}" for key, value in metadata.items())
    if template is None:
        template = TEMPLATE.read_text(encoding="utf-8")
    if template.count("@METADATA@") != 1 or template.count("@PAYLOAD@") != 1:
        raise ValueError("Bootstrap template must contain one metadata and one payload marker")
    text = template.replace("@METADATA@", metadata_tcl).replace("@PAYLOAD@", encode_records(files))
    header = (f"# TRY_RMSX_{version}.vmd — private, unqualified reviewer build\n"
              f"# Payload source SHA-256: {build_id}\n"
              "# In VMD: File > Load Visualization State; select this file.\n"
              "# This self-contained Tcl script extracts owned temporary files and opens an example.\n")
    return DemoBuild((header + text).encode("utf-8"), build_id, files, sources, metadata)


def write_immutable(path: Path, data: bytes) -> None:
    """Repeating an identical build is harmless; a conflicting file is preserved."""
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError(f"Different artifact already exists; choose another output directory: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(data)


def checksum_bytes(path: Path, data: bytes) -> bytes:
    return f"{hashlib.sha256(data).hexdigest()}  {path.name}\n".encode("ascii")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--allow-dirty", action="store_true")
    args = parser.parse_args()
    from check_release import main as check_release
    check_release()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
    if dirty and not args.allow_dirty:
        parser.error("Commit the release contents first, or use --allow-dirty for a review snapshot")
    snapshot = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in release_paths()}
    version = snapshot[f"{PACKAGE.name}/VERSION"].decode("utf-8").strip()
    demo = generate(select_payload(snapshot, PACKAGE.name), PACKAGE.name, version,
                    template=snapshot["scripts/reviewer_bootstrap.tcl.in"].decode("utf-8"),
                    revision=revision, dirty=dirty)
    after = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in release_paths()}
    if after != snapshot:
        parser.error("Release source changed while building; no artifacts were published")
    target = args.output / f"TRY_RMSX_{version}.vmd"
    write_immutable(target, demo.data)
    write_immutable(target.with_suffix(".vmd.sha256"), checksum_bytes(target, demo.data))
    print(target)
    print(f"Build ID: {demo.build_id}")


if __name__ == "__main__":
    main()
