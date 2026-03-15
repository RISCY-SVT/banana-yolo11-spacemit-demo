#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage:
  run_camera_demo.sh [camera_path_or_index] [model_path] [input_size] [max_frames]

Examples:
  ./scripts/run_camera_demo.sh
  ./scripts/run_camera_demo.sh auto
  ./scripts/run_camera_demo.sh /dev/video20
  ./scripts/run_camera_demo.sh 20

Default visual demo path:
  - model: generated 640x640 dynamic INT8
  - input size: 640
  - confidence: 0.25
  - board-local display: auto
  - board-local max_frames: 0 (run until q/ESC or Ctrl-C)
  - host-wrapper display: 0
  - host-wrapper max_frames: 200

Vendor 320x320 note:
  - visual runs auto-select the validated rt123 stack
  - if you explicitly force rt201 in visual mode, the script auto-enables the validated public workaround
  - low-latency benchmarking can still force raw rt201 behavior via BANANA_DEMO_RUNTIME_TAG=rt201 and BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=0

Environment overrides:
  BANANA_DEMO_RUNTIME_TAG=auto|rt123|rt201
  BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=auto|0|1
  CAMERA_PIXFMT=auto|mjpg|yuyv
  CAMERA_WIDTH / CAMERA_HEIGHT / CAMERA_FPS
  DISPLAY_FLAG=auto|0|1
  HEADLESS_FLAG=auto|0|1
  SAVE_OUTPUT=<path>   # opt-in recording
  CONFIDENCE=<float>
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  CAMERA_PATH="${1:-${CAMERA_PATH:-auto}}"
  MODEL_PATH="${2:-${MODEL_PATH:-$(banana_demo_default_visual_model "${REPO_DIR}")}}"
  INPUT_SIZE="${3:-${INPUT_SIZE:-$(banana_demo_default_visual_input_size)}}"
  MAX_FRAMES="${4:-${MAX_FRAMES:-0}}"
  DISPLAY_REQUEST="${DISPLAY_FLAG:-auto}"
  HEADLESS_REQUEST="${HEADLESS_FLAG:-auto}"
  CONFIDENCE="${CONFIDENCE:-0.25}"
  CAMERA_WIDTH="${CAMERA_WIDTH:-1280}"
  CAMERA_HEIGHT="${CAMERA_HEIGHT:-720}"
  CAMERA_FPS="${CAMERA_FPS:-30}"
  SAVE_OUTPUT="${SAVE_OUTPUT:-}"
  LOG_FILE="${LOG_FILE:-${REPO_DIR}/logs/camera_${INPUT_SIZE}.log}"
  QUIET="${QUIET:-0}"
  RUNTIME_TAG="$(banana_demo_resolve_runtime_tag "${MODEL_PATH}" "visual")"
  APP_BIN="$(banana_demo_binary_path "${REPO_DIR}" "${RUNTIME_TAG}")"
  DISPLAY_REASON=""
  HEADLESS_REASON=""
  IFS=$'\t' read -r DISPLAY_FLAG DISPLAY_REASON < <(banana_demo_resolve_display_flag "${DISPLAY_REQUEST}")
  IFS=$'\t' read -r HEADLESS_FLAG HEADLESS_REASON < <(banana_demo_resolve_headless_flag "${HEADLESS_REQUEST}" "${DISPLAY_FLAG}")

  if [[ -z "${CAMERA_PATH}" || "${CAMERA_PATH}" == "auto" ]]; then
    CAMERA_PATH="$(banana_demo_default_camera_path || true)"
  fi
  if [[ -z "${CAMERA_PATH}" ]]; then
    echo "ERROR: no usable camera node found" >&2
    exit 2
  fi

  CAMERA_REALPATH="$(banana_demo_resolve_camera_path "${CAMERA_PATH}")"
  CAMERA_PIXFMT="${CAMERA_PIXFMT:-$(banana_demo_choose_camera_pixfmt "${CAMERA_REALPATH}" "${CAMERA_WIDTH}" "${CAMERA_HEIGHT}")}"

  mkdir -p "${REPO_DIR}/logs" "${REPO_DIR}/outputs"
  banana_demo_export_runtime_env "${REPO_DIR}" "${RUNTIME_TAG}"
  banana_demo_apply_vendor320_rt201_visual_fix "${MODEL_PATH}" "${RUNTIME_TAG}" "visual"
  banana_demo_prepare_display_env "${DISPLAY_FLAG}"
  if banana_demo_is_vendor320_model "${MODEL_PATH}" && [[ "${RUNTIME_TAG}" == "rt201" ]] && [[ "${BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX_APPLIED:-0}" != "1" ]] && [[ "${BANANA_DEMO_SUPPRESS_VENDOR320_WARN:-0}" != "1" ]]; then
    echo "WARN: vendor320 on rt201 is using the raw perf-oriented path; set BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=1 or prefer the default rt123 visual path." >&2
  fi
  if [[ "${DISPLAY_FLAG}" == "1" && "${DISPLAY_REASON}" == "gui-socket" ]]; then
    echo "INFO: board-local auto display enabled from GUI socket detection; attempting live window output." >&2
  elif [[ "${DISPLAY_FLAG}" == "0" ]]; then
    echo "INFO: GUI backend/session not detected (reason=${DISPLAY_REASON}); switching to headless mode with periodic progress logs." >&2
  fi
  echo "runtime_tag=${RUNTIME_TAG}" >&2
  echo "display_request=${DISPLAY_REQUEST}" >&2
  echo "display_resolved=${DISPLAY_FLAG}" >&2
  echo "display_reason=${DISPLAY_REASON}" >&2
  echo "headless_request=${HEADLESS_REQUEST}" >&2
  echo "headless_resolved=${HEADLESS_FLAG}" >&2
  echo "headless_reason=${HEADLESS_REASON}" >&2
  echo "max_frames=${MAX_FRAMES}" >&2
  echo "vendor320_rt201_visual_fix_applied=${BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX_APPLIED:-0}" >&2
  if banana_demo_is_vendor320_model "${MODEL_PATH}"; then
    echo "vendor320_model_sha256=$(banana_demo_vendor320_model_hash "${MODEL_PATH}" 2>/dev/null || echo unknown)" >&2
  fi
  if [[ "${BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX_APPLIED:-0}" == "1" ]]; then
    echo "SPACEMIT_EP_DISABLE_FLOAT16_EPILOGUE=${SPACEMIT_EP_DISABLE_FLOAT16_EPILOGUE:-}" >&2
    echo "SPACEMIT_EP_DISABLE_OP_NAME_FILTER=${SPACEMIT_EP_DISABLE_OP_NAME_FILTER:-}" >&2
  fi
  echo "camera_selected=${CAMERA_PATH}" >&2
  echo "camera_resolved=${CAMERA_REALPATH}" >&2
  echo "camera_pixfmt_selected=${CAMERA_PIXFMT}" >&2

  cmd=(
    "${APP_BIN}"
    --model "${MODEL_PATH}"
    --labels "${REPO_DIR}/assets/coco80.txt"
    --input-size "${INPUT_SIZE}"
    --source "camera:${CAMERA_PATH}"
    --provider spacemit
    --threads 4
    --pin cluster0
    --conf "${CONFIDENCE}"
    --camera-width "${CAMERA_WIDTH}"
    --camera-height "${CAMERA_HEIGHT}"
    --camera-fps "${CAMERA_FPS}"
    --camera-pixfmt "${CAMERA_PIXFMT}"
    --display "${DISPLAY_FLAG}"
    --headless "${HEADLESS_FLAG}"
    --log-file "${LOG_FILE}"
    --quiet "${QUIET}"
    --max-frames "${MAX_FRAMES}"
  )
  if [[ -n "${SAVE_OUTPUT}" ]]; then
    cmd+=(--save-output "${SAVE_OUTPUT}")
  fi
  exec "${cmd[@]}"
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
BOARD_DIR="$(banana_demo_host_board_dir)"
"${ROOT_DIR}/scripts/deploy_to_banana.sh"

CAMERA_PATH="${1:-auto}"
MODEL_PATH="${2:-$(banana_demo_default_visual_model "${BOARD_DIR}")}"
INPUT_SIZE="${3:-${INPUT_SIZE:-$(banana_demo_default_visual_input_size)}}"
MAX_FRAMES="${4:-${MAX_FRAMES:-200}}"
DISPLAY_FLAG="${DISPLAY_FLAG:-0}"
HEADLESS_FLAG="${HEADLESS_FLAG:-auto}"
CONFIDENCE="${CONFIDENCE:-0.25}"
SAVE_OUTPUT_REMOTE="${SAVE_OUTPUT_REMOTE:-}"
LOG_FILE_REMOTE="${LOG_FILE_REMOTE:-${BOARD_DIR}/logs/camera_${INPUT_SIZE}.log}"
CAMERA_WIDTH="${CAMERA_WIDTH:-1280}"
CAMERA_HEIGHT="${CAMERA_HEIGHT:-720}"
CAMERA_FPS="${CAMERA_FPS:-30}"
CAMERA_PIXFMT="${CAMERA_PIXFMT:-}"
REMOTE_MODEL_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${MODEL_PATH}" inputs)"

remote_cmd="cd '${BOARD_DIR}' && BANANA_DEMO_EXEC_MODE=board QUIET=0 DISPLAY_FLAG='${DISPLAY_FLAG}' HEADLESS_FLAG='${HEADLESS_FLAG}' CONFIDENCE='${CONFIDENCE}' LOG_FILE='${LOG_FILE_REMOTE}' BANANA_DEMO_RUNTIME_TAG='${BANANA_DEMO_RUNTIME_TAG:-auto}' BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX='${BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX:-auto}'"
remote_cmd="${remote_cmd} CAMERA_WIDTH='${CAMERA_WIDTH}' CAMERA_HEIGHT='${CAMERA_HEIGHT}' CAMERA_FPS='${CAMERA_FPS}'"
if [[ -n "${CAMERA_PIXFMT}" ]]; then
  remote_cmd="${remote_cmd} CAMERA_PIXFMT='${CAMERA_PIXFMT}'"
fi
if [[ -n "${SAVE_OUTPUT_REMOTE}" ]]; then
  remote_cmd="${remote_cmd} SAVE_OUTPUT='${SAVE_OUTPUT_REMOTE}'"
fi
remote_cmd="${remote_cmd} ./scripts/run_camera_demo.sh '${CAMERA_PATH}' '${REMOTE_MODEL_PATH}' '${INPUT_SIZE}' '${MAX_FRAMES}'"
ssh "${TARGET}" "${remote_cmd}"
