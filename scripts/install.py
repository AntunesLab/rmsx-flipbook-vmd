#!/usr/bin/env python3
"""Install/uninstall the user-owned VMD extension without changing VMD itself."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]
START = "# BEGIN RMSX-FLIPBOOK-TIMELINE MANAGED BLOCK"
END = "# END RMSX-FLIPBOOK-TIMELINE MANAGED BLOCK"
MARKER = ".rmsxflipbooktimeline-install.json"


def tcl_literal(value):
    return ('"' + str(value).replace("\\", "/").replace('"', '\\"').replace("$", "\\$").replace("[", "\\[") + '"').encode("ascii", "backslashreplace").decode("ascii")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def strip_block(text, separator_added=False):
    if START not in text and END not in text:
        return text
    if text.count(START) != 1 or text.count(END) != 1:
        raise ValueError("Ambiguous startup registration; refusing to modify it")
    before, rest = text.split(START, 1)
    _, after = rest.split(END, 1)
    if after.startswith("\n"):
        after = after[1:]
    if separator_added and before.endswith("\n"):
        before = before[:-1]
    return before + after


def verify_owned(prefix, receipt):
    version = receipt.get("version", "")
    if not re.fullmatch(r"\d+(?:\.\d+)+", version) or receipt.get("package") != f"tcl/rmsxflipbooktimeline{version}":
        raise ValueError("Invalid managed package identity")
    package = prefix / receipt["package"]
    if package.is_symlink():
        raise ValueError("Managed package was replaced with a symlink")
    if not package.resolve().is_relative_to(prefix.resolve()):
        raise ValueError("Invalid package path in installation receipt")
    expected = receipt["files"]
    if any(p.is_symlink() for p in package.rglob("*")):
        raise ValueError("Installed package contains a symlink; preserve it before uninstalling")
    actual = {str(p.relative_to(package)) for p in package.rglob("*") if p.is_file()}
    if actual != set(expected):
        raise ValueError("Installed package contains added/missing files; preserve them before uninstalling")
    for name, checksum in expected.items():
        if digest(package / name) != checksum:
            raise ValueError(f"Installed file was modified: {name}; preserve it before uninstalling")
    return package


def atomic_text(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".rmsx-write-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape", newline="") as handle:
            handle.write(text)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["install", "uninstall"])
    parser.add_argument("--prefix", type=Path, default=Path.home() / "vmd-plugins")
    parser.add_argument("--startup-file", type=Path,
                        default=Path.home() / ("vmd.rc" if os.name == "nt" else ".vmdrc"))
    args = parser.parse_args()
    prefix, startup = args.prefix.expanduser().resolve(), args.startup_file.expanduser().resolve()
    marker = prefix / MARKER
    previous = json.loads(marker.read_text(encoding="utf-8")) if marker.exists() else None
    if previous and Path(previous["startup"]) != startup:
        parser.error(f"Existing installation uses startup file {previous['startup']}")
    old_text = startup.read_bytes().decode("utf-8", errors="surrogateescape") if startup.exists() else ""
    text = strip_block(old_text, bool(previous and previous.get("separator_added")))
    old_package = verify_owned(prefix, previous) if previous else None
    if args.action == "uninstall":
        if not previous:
            parser.error("No managed RMSX installation at this prefix")
        atomic_text(startup, text)
        shutil.rmtree(old_package)
        marker.unlink()
        print(f"Removed managed extension from {prefix}; other startup content preserved")
        return
    source = next(p for p in ROOT.glob("rmsxflipbooktimeline*") if p.is_dir())
    version = (source / "VERSION").read_text(encoding="utf-8").strip()
    relative = f"tcl/rmsxflipbooktimeline{version}"
    target = prefix / relative
    if target.exists() and target != old_package:
        parser.error(f"Refusing to replace unmanaged directory: {target}")
    prefix.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=".rmsx-stage-", dir=prefix)) / source.name
    retained = staged.parent / "previous-package"
    old_marker = marker.read_text(encoding="utf-8") if marker.exists() else None
    startup_existed = startup.exists()
    published = False
    try:
        shutil.copytree(source, staged, ignore=shutil.ignore_patterns("tests", "__pycache__", ".DS_Store"))
        files = {str(p.relative_to(staged)): digest(p) for p in staged.rglob("*") if p.is_file()}
        target.parent.mkdir(parents=True, exist_ok=True)
        block = (f"{START}\n"
                 f"lappend auto_path {tcl_literal(prefix / 'tcl')}\n"
                 f"source -encoding utf-8 {tcl_literal(target / 'register.tcl')}\n{END}\n")
        if startup.exists() and old_text != text + block:
            backup = startup.with_name(startup.name + ".rmsx-backup")
            if not backup.exists():
                shutil.copy2(startup, backup)
        new_text = text + ("\n" if text and not text.endswith("\n") else "") + block
        receipt_text = json.dumps({"schema": 1, "version": version,
                    "separator_added": bool(text and not text.endswith("\n")),
                    "package": relative, "startup": str(startup), "files": files}, indent=2) + "\n"
        if old_package:
            os.replace(old_package, retained)
        try:
            os.replace(staged, target)
            published = True
            atomic_text(startup, new_text)
            atomic_text(marker, receipt_text)
        except Exception:
            # Retain the previous owned package until both registration writes
            # succeed. A failed upgrade must not discard the working install.
            if published and target.exists():
                shutil.rmtree(target)
            if retained.exists():
                os.replace(retained, old_package)
            if startup_existed:
                atomic_text(startup, old_text)
            elif startup.exists():
                startup.unlink()
            if old_marker is not None:
                atomic_text(marker, old_marker)
            elif marker.exists():
                marker.unlink()
            raise
        print(f"Installed RMSX/Flipbook Timeline {version} in {target}")
        print("Restart VMD; open Plugins/Extensions > Analysis > RMSX and Flipbook Timeline")
    finally:
        shutil.rmtree(staged.parent, ignore_errors=True)


if __name__ == "__main__":
    main()
