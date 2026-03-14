#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage:
  run_image_demo.sh [image_path] [model_path] [input_size] [conf] [display] [headless] [save_output] [log_file]

Default visual demo path:
  - model: generated 640x640 dynamic INT8
  - input size: 640
  - confidence: 0.25

Vendor 320x320 note:
  - visual runs auto-select the validated rt123 stack
  - low-latency benchmark runs can still force rt201 via BANANA_DEMO_RUNTIME_TAG=rt201

Environment overrides:
  BANANA_DEMO_RUNTIME_TAG=auto|rt123|rt201
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  IMAGE_PATH="${1:-${IMAGE_PATH:-$(banana_demo_resolve_default_image "${REPO_DIR}")}}"
  MODEL_PATH="${2:-${MODEL_PATH:-$(banana_demo_default_visual_model "${REPO_DIR}")}}"
  INPUT_SIZE="${3:-${INPUT_SIZE:-$(banana_demo_default_visual_input_size)}}"
  CONFIDENCE="${4:-${CONFIDENCE:-0.25}}"
  DISPLAY_FLAG="${5:-${DISPLAY_FLAG:-0}}"
  HEADLESS_FLAG="${6:-${HEADLESS_FLAG:-$((1-DISPLAY_FLAG))}}"
  SAVE_OUTPUT="${7:-${SAVE_OUTPUT:-${REPO_DIR}/outputs/image_${INPUT_SIZE}.jpg}}"
  LOG_FILE="${8:-${LOG_FILE:-${REPO_DIR}/logs/image_${INPUT_SIZE}.log}}"
  QUIET="${QUIET:-0}"
  RUNTIME_TAG="$(banana_demo_resolve_runtime_tag "${MODEL_PATH}" "visual")"
  APP_BIN="$(banana_demo_binary_path "${REPO_DIR}" "${RUNTIME_TAG}")"

  mkdir -p "$(dirname "${SAVE_OUTPUT}")" "$(dirname "${LOG_FILE}")"
  banana_demo_export_runtime_env "${REPO_DIR}" "${RUNTIME_TAG}"
  banana_demo_prepare_display_env "${DISPLAY_FLAG}"
  echo "runtime_tag=${RUNTIME_TAG}" >&2
  if banana_demo_is_vendor320_model "${MODEL_PATH}" && [[ "${RUNTIME_TAG}" == "rt201" ]] && [[ "${BANANA_DEMO_SUPPRESS_VENDOR320_WARN:-0}" != "1" ]]; then
    echo "WARN: vendor320 on rt201 remains perf-oriented; prefer the default visual auto-selection (rt123) unless you explicitly want the low-latency benchmark stack." >&2
  fi

  exec "${APP_BIN}" \
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
MODEL_PATH="${2:-$(banana_demo_default_visual_model "${BOARD_DIR}")}"
INPUT_SIZE="${3:-${INPUT_SIZE:-$(banana_demo_default_visual_input_size)}}"
CONFIDENCE="${4:-${CONFIDENCE:-0.25}}"
DISPLAY_FLAG="${DISPLAY_FLAG:-0}"
HEADLESS_FLAG="${HEADLESS_FLAG:-$((1-DISPLAY_FLAG))}"
SAVE_OUTPUT_REMOTE="${SAVE_OUTPUT_REMOTE:-${BOARD_DIR}/outputs/image_${INPUT_SIZE}.jpg}"
LOG_FILE_REMOTE="${LOG_FILE_REMOTE:-${BOARD_DIR}/logs/image_${INPUT_SIZE}.log}"

REMOTE_IMAGE_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${IMAGE_PATH}" inputs)"
REMOTE_MODEL_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${MODEL_PATH}" inputs)"

ssh "${TARGET}" "cd '${BOARD_DIR}' && \
  BANANA_DEMO_EXEC_MODE=board \
  QUIET=0 \
  BANANA_DEMO_RUNTIME_TAG='${BANANA_DEMO_RUNTIME_TAG:-auto}' \
  ./scripts/run_image_demo.sh \
    '${REMOTE_IMAGE_PATH}' \
    '${REMOTE_MODEL_PATH}' \
    '${INPUT_SIZE}' \
    '${CONFIDENCE}' \
    '${DISPLAY_FLAG}' \
    '${HEADLESS_FLAG}' \
    '${SAVE_OUTPUT_REMOTE}' \
    '${LOG_FILE_REMOTE}'"
