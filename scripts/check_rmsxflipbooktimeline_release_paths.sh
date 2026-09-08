#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd "${script_dir}/.." && pwd)"
plugin_dir="${workspace_root}/workspace_plugins/rmsxflipbooktimeline0.2"

if [[ ! -d "${plugin_dir}" ]]; then
  echo "Release plugin directory not found: ${plugin_dir}" >&2
  exit 1
fi

targets=(
  "${plugin_dir}/pkgIndex.tcl"
  "${plugin_dir}/README_RELEASE.md"
  "${plugin_dir}/INSTALL.md"
  "${plugin_dir}/USER_GUIDE.md"
  "${plugin_dir}/DEVELOPER_NOTES.md"
  "${plugin_dir}/MAINTAINER_PACKET.md"
  "${plugin_dir}/CITATION.cff"
  "${plugin_dir}/rmsxflipbooktimeline.tcl"
  "${plugin_dir}/core"
  "${plugin_dir}/gui"
  "${plugin_dir}/visualization"
  "${plugin_dir}/tests"
  "${workspace_root}/scripts/launch_rmsxflipbooktimeline_release.tcl"
  "${workspace_root}/scripts/launch_rmsxflipbooktimeline_release.sh"
)

if rg -n "/Users/finn|downloads/vmd/current/macos|VMD2b1\\.app" "${targets[@]}"; then
  echo "Release path check failed: remove local/macOS-specific paths from the release surface." >&2
  exit 1
fi

echo "RMSX/Flipbook Timeline release path check passed."
