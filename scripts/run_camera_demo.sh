#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  CAMERA_PATH="${1:-${CAMERA_PATH:-/dev/video0}}"
  MODEL_PATH="${2:-${MODEL_PATH:-${REPO_DIR}/models/vendor/yolo11/yolov11n_320x320.q.onnx}}"
  INPUT_SIZE="${3:-${INPUT_SIZE:-320}}"
  MAX_FRAMES="${4:-${MAX_FRAMES:-200}}"
  DISPLAY_FLAG="${DISPLAY_FLAG:-0}"
  CONFIDENCE="${CONFIDENCE:-0.05}"
  CAMERA_PIXFMT="${CAMERA_PIXFMT:-auto}"
  SAVE_OUTPUT="${SAVE_OUTPUT:-}"
  LOG_FILE="${LOG_FILE:-${REPO_DIR}/logs/camera_${INPUT_SIZE}.log}"
  QUIET="${QUIET:-0}"
  HEADLESS_FLAG="${HEADLESS_FLAG:-$((1-DISPLAY_FLAG))}"

  mkdir -p "${REPO_DIR}/logs" "${REPO_DIR}/outputs"
  banana_demo_export_runtime_env "${REPO_DIR}"
  banana_demo_prepare_display_env "${DISPLAY_FLAG}"

  cmd=(
    "${REPO_DIR}/bin/banana_yolo11_demo"
    --model "${MODEL_PATH}"
    --labels "${REPO_DIR}/assets/coco80.txt"
    --input-size "${INPUT_SIZE}"
    --source "camera:${CAMERA_PATH}"
    --provider spacemit
    --threads 4
    --pin cluster0
    --conf "${CONFIDENCE}"
    --camera-width 1280
    --camera-height 720
    --camera-fps 30
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

CAMERA_PATH="${1:-/dev/video0}"
MODEL_PATH="${2:-${BOARD_DIR}/models/vendor/yolo11/yolov11n_320x320.q.onnx}"
INPUT_SIZE="${3:-320}"
MAX_FRAMES="${4:-200}"
DISPLAY_FLAG="${DISPLAY_FLAG:-0}"
CONFIDENCE="${CONFIDENCE:-0.05}"
CAMERA_PIXFMT="${CAMERA_PIXFMT:-auto}"
SAVE_OUTPUT_REMOTE="${SAVE_OUTPUT_REMOTE:-}"
LOG_FILE_REMOTE="${LOG_FILE_REMOTE:-${BOARD_DIR}/logs/camera_${INPUT_SIZE}.log}"

remote_cmd="cd '${BOARD_DIR}' && BANANA_DEMO_EXEC_MODE=board QUIET=0 DISPLAY_FLAG='${DISPLAY_FLAG}' HEADLESS_FLAG='$((1-DISPLAY_FLAG))' CONFIDENCE='${CONFIDENCE}' CAMERA_PIXFMT='${CAMERA_PIXFMT}' LOG_FILE='${LOG_FILE_REMOTE}'"
if [[ -n "${SAVE_OUTPUT_REMOTE}" ]]; then
  remote_cmd="${remote_cmd} SAVE_OUTPUT='${SAVE_OUTPUT_REMOTE}'"
fi
remote_cmd="${remote_cmd} ./scripts/run_camera_demo.sh '${CAMERA_PATH}' '${MODEL_PATH}' '${INPUT_SIZE}' '${MAX_FRAMES}'"
ssh "${TARGET}" "${remote_cmd}"
