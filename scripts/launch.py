#!/usr/bin/env python3
"""Launch the package with a discovered VMD executable and isolated demo data."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import vmd_process

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vmd", default=os.environ.get("VMD_EXECUTABLE", "vmd"))
    parser.add_argument("--demo", choices=["single", "multi"])
    parser.add_argument("--check", action="store_true", help="Validate executable/package without launching VMD")
    args = parser.parse_args()
    executable = shutil.which(args.vmd)
    if not executable:
        parser.error("VMD executable unavailable; set VMD_EXECUTABLE or --vmd")
    package = next(p for p in ROOT.glob("rmsxflipbooktimeline*") if p.is_dir())
    if args.check:
        print(f"VMD: {executable}; package: {package}")
        return
    env = os.environ.copy()
    env["RMSX_LAUNCH_REPO"] = str(ROOT)
    env["RMSX_LAUNCH_PACKAGE"] = str(package)
    env["RMSX_LAUNCH_DEMO"] = args.demo or ""
    if args.demo:
        work = Path(tempfile.mkdtemp(prefix="rmsx-demo-"))
        shutil.copytree(ROOT / "fixtures", work / "fixtures")
        env["RMSX_LAUNCH_WORK"] = str(work)
        print(f"Demo working directory: {work}", flush=True)
    command = [executable, "-dispdev", "win", "-e",
               str(ROOT / "scripts/launch_rmsxflipbooktimeline_release.tcl")]
    if sys.stdin.isatty():
        return subprocess.call(command, env=env)
    return vmd_process.run(command, env=env, stream=True).returncode



if __name__ == "__main__":
    raise SystemExit(main())
