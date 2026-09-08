#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd "${script_dir}/.." && pwd)"

export VMD_EXECUTABLE="${VMD_EXECUTABLE:-${workspace_root}/downloads/vmd/current/macos/VMD2b1.app/Contents/MacOS/startup.command}"

output_folder="${RMSXFLIPBOOKTIMELINE_DEMO_OUTPUT_FOLDER:-${RMSXFLIPBOOK_DEMO_OUTPUT_FOLDER:-${workspace_root}/outputs/native-rmsx-1ubq-9/chain_7_rmsx}}"
topology="${RMSXFLIPBOOKTIMELINE_DEMO_TOPOLOGY:-${RMSXFLIPBOOK_DEMO_TOPOLOGY:-${workspace_root}/downloads/rmsx/AntunesLab-rmsx/test_files/1UBQ.pdb}}"
trajectory="${RMSXFLIPBOOKTIMELINE_DEMO_TRAJECTORY:-${RMSXFLIPBOOK_DEMO_TRAJECTORY:-${workspace_root}/downloads/rmsx/AntunesLab-rmsx/test_files/mon_sys.dcd}}"
native_output="${RMSXFLIPBOOKTIMELINE_DEMO_NATIVE_OUTPUT:-${RMSXFLIPBOOK_DEMO_NATIVE_OUTPUT:-${workspace_root}/outputs/native-rmsx-1ubq-9}}"
chain="${RMSXFLIPBOOKTIMELINE_DEMO_CHAIN:-${RMSXFLIPBOOK_DEMO_CHAIN:-7}}"
slices="${RMSXFLIPBOOKTIMELINE_DEMO_SLICES:-${RMSXFLIPBOOK_DEMO_SLICES:-9}}"
start_frame="${RMSXFLIPBOOKTIMELINE_DEMO_START_FRAME:-${RMSXFLIPBOOK_DEMO_START_FRAME:-0}}"
end_frame="${RMSXFLIPBOOKTIMELINE_DEMO_END_FRAME:-${RMSXFLIPBOOK_DEMO_END_FRAME:--1}}"
time_step="${RMSXFLIPBOOKTIMELINE_DEMO_TIME_STEP:-${RMSXFLIPBOOK_DEMO_TIME_STEP:-0.04888821}}"
metric="${RMSXFLIPBOOKTIMELINE_DEMO_METRIC:-${RMSXFLIPBOOK_DEMO_METRIC:-RMSX}}"
analysis_type="${RMSXFLIPBOOKTIMELINE_DEMO_ANALYSIS_TYPE:-${RMSXFLIPBOOK_DEMO_ANALYSIS_TYPE:-protein}}"
mask_selection="${RMSXFLIPBOOKTIMELINE_DEMO_MASK_SELECTION:-${RMSXFLIPBOOK_DEMO_MASK_SELECTION:-}}"
slice_size="${RMSXFLIPBOOKTIMELINE_DEMO_SLICE_SIZE:-${RMSXFLIPBOOK_DEMO_SLICE_SIZE:-}}"
total_time_ns="${RMSXFLIPBOOKTIMELINE_DEMO_TOTAL_TIME_NS:-${RMSXFLIPBOOK_DEMO_TOTAL_TIME_NS:-auto}}"

exec "${script_dir}/launch_rmsxflipbooktimeline_release.sh" \
  "${output_folder}" \
  "${topology}" \
  "${trajectory}" \
  "${native_output}" \
  "${chain}" \
  "${slices}" \
  "${start_frame}" \
  "${end_frame}" \
  "${time_step}" \
  "${metric}" \
  "${analysis_type}" \
  "${mask_selection}" \
  "${slice_size}" \
  "${total_time_ns}"
