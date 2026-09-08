#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd "${script_dir}/.." && pwd)"
vmd_executable="${VMD_EXECUTABLE:-vmd}"
export RMSXFLIPBOOKTIMELINE_WORKSPACE_ROOT="${workspace_root}"
vmd_tmpdir="${RMSXFLIPBOOKTIMELINE_TMPDIR:-${workspace_root}/outputs/tmp/rmsxflipbooktimeline}"
mkdir -p "${vmd_tmpdir}"
export TMPDIR="${vmd_tmpdir}"
dispdev="${RMSXFLIPBOOKTIMELINE_DISPDEV:-win}"

if [[ -n "${RMSXFLIPBOOKTIMELINE_LAUNCH_SMOKE:-}" ]]; then
  dispdev="${RMSXFLIPBOOKTIMELINE_DISPDEV:-text}"
fi

if [[ "${vmd_executable}" == */* ]]; then
  if [[ ! -x "${vmd_executable}" ]]; then
    echo "VMD executable not found or not executable: ${vmd_executable}" >&2
    echo "Set VMD_EXECUTABLE to your VMD executable path." >&2
    exit 1
  fi
else
  resolved_vmd="$(command -v "${vmd_executable}" || true)"
  if [[ -z "${resolved_vmd}" ]]; then
    echo "VMD executable '${vmd_executable}' was not found on PATH." >&2
    echo "Set VMD_EXECUTABLE to your VMD executable path." >&2
    exit 1
  fi
  vmd_executable="${resolved_vmd}"
fi

if [[ "$#" -gt 0 ]]; then
  exec "${vmd_executable}" -dispdev "${dispdev}" -e "${workspace_root}/scripts/launch_rmsxflipbooktimeline_release.tcl" -args "$@"
fi

exec "${vmd_executable}" -dispdev "${dispdev}" -e "${workspace_root}/scripts/launch_rmsxflipbooktimeline_release.tcl"
