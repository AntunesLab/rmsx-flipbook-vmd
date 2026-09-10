"""Validate the reviewed, explicit archive allowlist against deliverable files."""
from pathlib import PurePosixPath
from run_tests import ROOT, PACKAGE

LIST = ROOT / "scripts/release_files.txt"
ROOT_FILES = {"README.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "CHANGELOG.md", ".gitignore", ".gitattributes"}


def expected_inventory():
    paths = {ROOT / name for name in ROOT_FILES}
    for directory in [PACKAGE, ROOT / "scripts", ROOT / "docs", ROOT / "fixtures", ROOT / ".github"]:
        paths.update(p for p in directory.rglob("*") if p.is_file()
                     and "__pycache__" not in p.parts and p.name != ".DS_Store" and p.suffix != ".pyc")
    return {p.relative_to(ROOT).as_posix() for p in paths}


def release_paths():
    names = [line.strip() for line in LIST.read_text(encoding="utf-8").splitlines()
             if line.strip() and not line.lstrip().startswith("#")]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate file in release_files.txt")
    for name in names:
        relative = PurePosixPath(name)
        if relative.is_absolute() or ".." in relative.parts or "\\" in name:
            raise ValueError(f"Unsafe release path: {name}")
        path = ROOT / name
        if not path.is_file() or path.is_symlink() or any(p.is_symlink() for p in path.parents if p != ROOT.parent):
            raise ValueError(f"Missing file or symlink in release allowlist: {name}")
    expected = expected_inventory()
    missing, extra = expected - set(names), set(names) - expected
    if missing or extra:
        raise ValueError(f"Release allowlist needs review; unlisted={sorted(missing)}, unexpected={sorted(extra)}")
    return [ROOT / name for name in names]
