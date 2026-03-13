#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  IMAGE_PATH="${1:-${IMAGE_PATH:-$(banana_demo_resolve_default_image "${REPO_DIR}")}}"
  MODEL_PATH="${2:-${MODEL_PATH:-${REPO_DIR}/models/vendor/yolo11/yolov11n_320x320.q.onnx}}"
  INPUT_SIZE="${3:-${INPUT_SIZE:-320}}"
  CONFIDENCE="${4:-${CONFIDENCE:-0.05}}"
  DISPLAY_FLAG="${5:-${DISPLAY_FLAG:-0}}"
  HEADLESS_FLAG="${6:-${HEADLESS_FLAG:-$((1-DISPLAY_FLAG))}}"
  SAVE_OUTPUT="${7:-${SAVE_OUTPUT:-${REPO_DIR}/outputs/image_${INPUT_SIZE}.jpg}}"
  LOG_FILE="${8:-${LOG_FILE:-${REPO_DIR}/logs/image_${INPUT_SIZE}.log}}"
  QUIET="${QUIET:-0}"

  mkdir -p "$(dirname "${SAVE_OUTPUT}")" "$(dirname "${LOG_FILE}")"
  banana_demo_export_runtime_env "${REPO_DIR}"
  banana_demo_prepare_display_env "${DISPLAY_FLAG}"

  exec "${REPO_DIR}/bin/banana_yolo11_demo" \
    --model "${MODEL_PATH}" \
    --labels "${REPO_DIR}/assets/coco80.txt" \
    --input-size "${INPUT_SIZE}" \
    --source "image:${IMAGE_PATH}" \
    --provider spacemit \
    --threads 4 \
    --pin cluster0 \
    --conf "${CONFIDENCE}" \
    --display "${DISPLAY_FLAG}" \
    --headless "${HEADLESS_FLAG}" \
    --save-output "${SAVE_OUTPUT}" \
    --log-file "${LOG_FILE}" \
    --quiet "${QUIET}"
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
BOARD_DIR="$(banana_demo_host_board_dir)"
"${ROOT_DIR}/scripts/deploy_to_banana.sh"

IMAGE_PATH="${1:-/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg}"
MODEL_PATH="${2:-${BOARD_DIR}/models/vendor/yolo11/yolov11n_320x320.q.onnx}"
INPUT_SIZE="${3:-320}"
CONFIDENCE="${4:-${CONFIDENCE:-0.05}}"
DISPLAY_FLAG="${DISPLAY_FLAG:-0}"
HEADLESS_FLAG="${HEADLESS_FLAG:-$((1-DISPLAY_FLAG))}"
SAVE_OUTPUT_REMOTE="${SAVE_OUTPUT_REMOTE:-${BOARD_DIR}/outputs/image_${INPUT_SIZE}.jpg}"
LOG_FILE_REMOTE="${LOG_FILE_REMOTE:-${BOARD_DIR}/logs/image_${INPUT_SIZE}.log}"

REMOTE_IMAGE_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${IMAGE_PATH}" inputs)"

ssh "${TARGET}" "cd '${BOARD_DIR}' && \
  BANANA_DEMO_EXEC_MODE=board \
  QUIET=0 \
  ./scripts/run_image_demo.sh \
    '${REMOTE_IMAGE_PATH}' \
    '${MODEL_PATH}' \
    '${INPUT_SIZE}' \
    '${CONFIDENCE}' \
    '${DISPLAY_FLAG}' \
    '${HEADLESS_FLAG}' \
    '${SAVE_OUTPUT_REMOTE}' \
    '${LOG_FILE_REMOTE}'"
