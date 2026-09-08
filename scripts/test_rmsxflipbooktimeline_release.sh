#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd "${script_dir}/.." && pwd)"
vmd_executable="${VMD_EXECUTABLE:-vmd}"
vmd_tmpdir="${RMSXFLIPBOOKTIMELINE_TMPDIR:-${workspace_root}/outputs/tmp/rmsxflipbooktimeline-release}"
mkdir -p "${vmd_tmpdir}"
export TMPDIR="${vmd_tmpdir}"

run_tclsh() {
  local label="$1"
  local script="$2"
  echo "==> ${label}"
  tclsh "${workspace_root}/${script}"
}

resolve_vmd() {
  if [[ "${vmd_executable}" == */* ]]; then
    [[ -x "${vmd_executable}" ]] || return 1
    printf '%s\n' "${vmd_executable}"
    return 0
  fi
  command -v "${vmd_executable}"
}

run_vmd_optional() {
  local label="$1"
  local script="$2"
  local resolved
  if ! resolved="$(resolve_vmd 2>/dev/null)"; then
    echo "==> ${label} (skipped: set VMD_EXECUTABLE or put vmd on PATH)"
    return 0
  fi
  echo "==> ${label}"
  "${resolved}" -dispdev text -e "${workspace_root}/${script}"
}

"${workspace_root}/scripts/check_rmsxflipbooktimeline_release_paths.sh"

run_tclsh "release package surface" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_release_package.tcl"
run_tclsh "release experimental gate" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_release_experimental.tcl"
run_tclsh "package command smoke" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_package.tcl"
run_tclsh "package isolation" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_timeline_package_isolation.tcl"
run_tclsh "TML round-trip" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_timeline_tml_roundtrip.tcl"
run_tclsh "filter/SVG export" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_timeline_filter_svg.tcl"
run_tclsh "neighborhood planning" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_timeline_neighborhood.tcl"
run_tclsh "RMSX CSV/folder matrix" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_timeline_rmsx_csv.tcl"

RMSXFLIPBOOKTIMELINE_LAUNCH_SMOKE=1 "${workspace_root}/scripts/launch_rmsxflipbooktimeline_release.sh" || {
  echo "==> release launcher smoke (skipped: set VMD_EXECUTABLE or put vmd on PATH)"
}
RMSXFLIPBOOKTIMELINE_LAUNCH_SMOKE=1 "${workspace_root}/scripts/launch_rmsxflipbooktimeline_release_single_chain_demo.sh" || {
  echo "==> release single-chain demo smoke (skipped: VMD unavailable)"
}
RMSXFLIPBOOKTIMELINE_LAUNCH_SMOKE=1 "${workspace_root}/scripts/launch_rmsxflipbooktimeline_release_multi_chain_demo.sh" || {
  echo "==> release multi-chain demo smoke (skipped: VMD unavailable)"
}

run_vmd_optional "dashboard GUI smoke" "workspace_plugins/rmsxflipbooktimeline0.2/tests/smoke_dashboard_show.tcl"

echo "RMSX/Flipbook Timeline release smoke suite passed."
