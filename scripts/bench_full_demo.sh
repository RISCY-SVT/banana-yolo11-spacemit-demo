#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage:
  bench_full_demo.sh [model_path] [input_size] [image_path]

Default benchmark path:
  - model: official vendor 320x320 INT8
  - input size: 320

Environment overrides:
  BANANA_DEMO_RUNTIME_TAG=auto|rt123|rt201
  - auto/visual uses rt123 for vendor320 correctness and rt201 otherwise
  BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=auto|0|1
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  MODEL_PATH="${1:-${MODEL_PATH:-$(banana_demo_default_benchmark_model "${REPO_DIR}")}}"
  INPUT_SIZE="${2:-${INPUT_SIZE:-320}}"
  IMAGE_PATH="${3:-${IMAGE_PATH:-$(banana_demo_resolve_default_image "${REPO_DIR}")}}"
  LOG_FILE="${LOG_FILE:-${REPO_DIR}/logs/bench_full_${INPUT_SIZE}.log}"
  RUNTIME_TAG="$(banana_demo_resolve_runtime_tag "${MODEL_PATH}" "visual")"
  APP_BIN="$(banana_demo_binary_path "${REPO_DIR}" "${RUNTIME_TAG}")"
  mkdir -p "${REPO_DIR}/logs"
  banana_demo_export_runtime_env "${REPO_DIR}" "${RUNTIME_TAG}"
  banana_demo_apply_vendor320_rt201_visual_fix "${MODEL_PATH}" "${RUNTIME_TAG}" "visual"
  banana_demo_unset_parallel_env
  echo "runtime_tag=${RUNTIME_TAG}"
  exec taskset -c 0,1,2,3 "${APP_BIN}" \
    --model "${MODEL_PATH}" \
    --labels "${REPO_DIR}/assets/coco80.txt" \
    --input-size "${INPUT_SIZE}" \
    --source "image:${IMAGE_PATH}" \
    --provider spacemit \
    --threads 4 \
    --pin cluster0 \
    --benchmark-only 1 \
    --benchmark-mode full \
    --warmup 10 \
    --runs 100 \
    --repeats 5 \
    --display 0 \
    --headless 1 \
    --quiet 1 \
    --log-file "${LOG_FILE}"
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
BOARD_DIR="$(banana_demo_host_board_dir)"
"${ROOT_DIR}/scripts/deploy_to_banana.sh"

MODEL_PATH="${1:-$(banana_demo_default_benchmark_model "${BOARD_DIR}")}"
INPUT_SIZE="${2:-320}"
IMAGE_PATH="${3:-/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg}"
REMOTE_IMAGE_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${IMAGE_PATH}" inputs)"
REMOTE_MODEL_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${MODEL_PATH}" inputs)"
ssh "${TARGET}" "cd '${BOARD_DIR}' && BANANA_DEMO_EXEC_MODE=board BANANA_DEMO_RUNTIME_TAG='${BANANA_DEMO_RUNTIME_TAG:-auto}' BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX='${BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX:-auto}' LOG_FILE='${BOARD_DIR}/logs/bench_full_${INPUT_SIZE}.log' ./scripts/bench_full_demo.sh '${REMOTE_MODEL_PATH}' '${INPUT_SIZE}' '${REMOTE_IMAGE_PATH}'"
