#!/usr/bin/env bash
## @file bench_forward_only.sh
## @brief Run forward-only benchmark checks for the current runtime/model path.
## @details This helper keeps vendor `perf_test` and app-side forward-only
## numbers close together so benchmark regressions stay easy to spot.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

## @brief Print CLI usage and the default forward-only benchmark policy.
usage() {
  cat <<'EOF'
Usage:
  bench_forward_only.sh [model_path] [input_size] [image_path]

Default benchmark path:
  - model: official vendor 320x320 INT8
  - input size: 320

Environment overrides:
  BANANA_DEMO_RUNTIME_TAG=auto|rt123|rt201|rt202b1|rt202
  - auto/perf defaults to rt201 for vendor320 low-latency benchmarking
  BENCH_PERF_REPEATS=<n>  # default: 1000
  BENCH_WARMUP=<n>        # default: 10
  BENCH_RUNS=<n>          # default: 100
  BENCH_REPEATS=<n>       # default: 5
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
  LOG_FILE="${LOG_FILE:-${REPO_DIR}/logs/bench_forward_${INPUT_SIZE}.log}"
  BENCH_PERF_REPEATS="${BENCH_PERF_REPEATS:-1000}"
  BENCH_WARMUP="${BENCH_WARMUP:-10}"
  BENCH_RUNS="${BENCH_RUNS:-100}"
  BENCH_REPEATS="${BENCH_REPEATS:-5}"
  RUNTIME_TAG="$(banana_demo_resolve_runtime_tag "${MODEL_PATH}" "perf")"
  PERF_TEST_BIN="$(banana_demo_perf_test_path "${REPO_DIR}" "${RUNTIME_TAG}")"
  APP_BIN="$(banana_demo_binary_path "${REPO_DIR}" "${RUNTIME_TAG}")"
  mkdir -p "${REPO_DIR}/logs"
  banana_demo_export_runtime_env "${REPO_DIR}" "${RUNTIME_TAG}"
  banana_demo_unset_parallel_env
  echo "runtime_tag=${RUNTIME_TAG}"
  echo "bench_perf_repeats=${BENCH_PERF_REPEATS}"
  echo "bench_warmup=${BENCH_WARMUP}"
  echo "bench_runs=${BENCH_RUNS}"
  echo "bench_repeats=${BENCH_REPEATS}"
  echo "== perf_test =="
  taskset -c 0,1,2,3 "${PERF_TEST_BIN}" -m times -e spacemit -x 4 -y 1 -r "${BENCH_PERF_REPEATS}" -I "${MODEL_PATH}"
  echo "== app =="
  exec taskset -c 0,1,2,3 "${APP_BIN}" \
    --model "${MODEL_PATH}" \
    --labels "${REPO_DIR}/assets/coco80.txt" \
    --input-size "${INPUT_SIZE}" \
    --source "image:${IMAGE_PATH}" \
    --provider spacemit \
    --threads 4 \
    --pin cluster0 \
    --benchmark-only 1 \
    --benchmark-mode forward \
    --warmup "${BENCH_WARMUP}" \
    --runs "${BENCH_RUNS}" \
    --repeats "${BENCH_REPEATS}" \
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
ssh "${TARGET}" "cd '${BOARD_DIR}' && BANANA_DEMO_EXEC_MODE=board BANANA_DEMO_RUNTIME_TAG='${BANANA_DEMO_RUNTIME_TAG:-auto}' BENCH_PERF_REPEATS='${BENCH_PERF_REPEATS:-1000}' BENCH_WARMUP='${BENCH_WARMUP:-10}' BENCH_RUNS='${BENCH_RUNS:-100}' BENCH_REPEATS='${BENCH_REPEATS:-5}' LOG_FILE='${BOARD_DIR}/logs/bench_forward_${INPUT_SIZE}.log' ./scripts/bench_forward_only.sh '${REMOTE_MODEL_PATH}' '${INPUT_SIZE}' '${REMOTE_IMAGE_PATH}'"
