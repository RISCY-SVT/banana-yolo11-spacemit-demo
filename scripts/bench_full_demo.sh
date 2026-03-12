#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${BANANA_SSH_TARGET:-svt@banana}"
BOARD_DIR="${BOARD_DIR:-/home/svt/banana-yolo11-spacemit-demo}"
MODEL_PATH="${1:-${BOARD_DIR}/models/vendor/yolo11/yolov11n_320x320.q.onnx}"
INPUT_SIZE="${2:-320}"
IMAGE_PATH="${3:-/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg}"

source /data/build_scripts/01-env.sh
"${ROOT_DIR}/scripts/deploy_to_banana.sh"

ssh "${TARGET}" "\
  set -euo pipefail; \
  export LD_LIBRARY_PATH='${BOARD_DIR}/runtime/lib:/home/svt/opencv-install-k1x-gtk3/lib:\${LD_LIBRARY_PATH:-}'; \
  taskset -c 0,1,2,3 '${BOARD_DIR}/app/bin/banana_yolo11_demo' \
    --model '${MODEL_PATH}' \
    --labels '${BOARD_DIR}/assets/coco80.txt' \
    --input-size '${INPUT_SIZE}' \
    --source 'image:${IMAGE_PATH}' \
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
    --log-file '${BOARD_DIR}/logs/bench_full_${INPUT_SIZE}.log'"

