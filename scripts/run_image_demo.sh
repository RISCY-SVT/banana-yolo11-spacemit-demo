#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${BANANA_SSH_TARGET:-svt@banana}"
BOARD_DIR="${BOARD_DIR:-/home/svt/banana-yolo11-spacemit-demo}"
IMAGE_PATH="${1:-/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg}"
MODEL_PATH="${2:-${BOARD_DIR}/models/vendor/yolo11/yolov11n_320x320.q.onnx}"
INPUT_SIZE="${3:-320}"
CONFIDENCE="${4:-${CONFIDENCE:-0.01}}"
DISPLAY_FLAG="${DISPLAY_FLAG:-0}"
HEADLESS_FLAG="${HEADLESS_FLAG:-$((1-DISPLAY_FLAG))}"

source /data/build_scripts/01-env.sh
"${ROOT_DIR}/scripts/deploy_to_banana.sh"

ssh "${TARGET}" "\
  set -euo pipefail; \
  export LD_LIBRARY_PATH='${BOARD_DIR}/runtime/lib:/home/svt/opencv-install-k1x-gtk3/lib:\${LD_LIBRARY_PATH:-}'; \
  if [[ '${DISPLAY_FLAG}' == '1' ]]; then \
    export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; \
    if [[ -S \"\$XDG_RUNTIME_DIR/wayland-0\" ]]; then export WAYLAND_DISPLAY='wayland-0'; fi; \
    export DISPLAY=':0'; \
    for auth in /run/user/\$(id -u)/.mutter-Xwaylandauth.*; do \
      [[ -f \"\$auth\" ]] || continue; \
      export XAUTHORITY=\"\$auth\"; \
      break; \
    done; \
  fi; \
  '${BOARD_DIR}/app/bin/banana_yolo11_demo' \
    --model '${MODEL_PATH}' \
    --labels '${BOARD_DIR}/assets/coco80.txt' \
    --input-size '${INPUT_SIZE}' \
    --source 'image:${IMAGE_PATH}' \
    --provider spacemit \
    --threads 4 \
    --pin cluster0 \
    --conf '${CONFIDENCE}' \
    --display '${DISPLAY_FLAG}' \
    --headless '${HEADLESS_FLAG}' \
    --save-output '${BOARD_DIR}/outputs/image_${INPUT_SIZE}.jpg' \
    --log-file '${BOARD_DIR}/logs/image_${INPUT_SIZE}.log' \
    --quiet 0"
