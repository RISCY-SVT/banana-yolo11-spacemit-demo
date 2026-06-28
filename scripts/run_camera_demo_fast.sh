#!/usr/bin/env bash
## @file run_camera_demo_fast.sh
## @brief Run the explicit fast-live camera profile for the Banana demo.
## @details This wrapper keeps the default visual path unchanged while exposing
## a measured lower-latency live profile based on the trusted vendor320 visual
## stack (`rt123` + official vendor320 model + 320 letterbox inference).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

## @brief Print CLI usage and the fast-live trade-off summary.
usage() {
  cat <<'EOF'
Usage:
  run_camera_demo_fast.sh [camera_path_or_index] [model_path] [input_size] [max_frames]

Fast-live defaults:
  - profile: live-fast
  - model: official vendor320 INT8
  - runtime: rt123 visual path
  - input size: 320
  - camera request: 640x480 @ 60 FPS
  - camera pixfmt: auto (MJPG-preferred)
  - confidence: 0.25

This mode is intended for better perceived live responsiveness than the
default dynamic640 visual path. It is explicitly lower-resolution, but it keeps
the trusted vendor320 visual stack and does not silently switch to a raw perf
runtime.

Environment overrides:
  BANANA_DEMO_RUNTIME_TAG=auto|rt123|rt201|rt202b1|rt202
  BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=auto|0|1
  CAMERA_WIDTH / CAMERA_HEIGHT / CAMERA_FPS
  CAMERA_PIXFMT=auto|mjpg|yuyv
  DISPLAY_FLAG=auto|0|1
  HEADLESS_FLAG=auto|0|1
  SAVE_OUTPUT=<path>
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  CAMERA_PATH="${1:-${CAMERA_PATH:-auto}}"
  MODEL_PATH="${2:-${MODEL_PATH:-$(banana_demo_default_fast_live_model "${REPO_DIR}")}}"
  INPUT_SIZE="${3:-${INPUT_SIZE:-$(banana_demo_default_fast_live_input_size)}}"
  MAX_FRAMES="${4:-${MAX_FRAMES:-0}}"
else
  REPO_DIR="$(banana_demo_host_board_dir)"
  CAMERA_PATH="${1:-${CAMERA_PATH:-auto}}"
  MODEL_PATH="${2:-${MODEL_PATH:-$(banana_demo_default_fast_live_model "${REPO_DIR}")}}"
  INPUT_SIZE="${3:-${INPUT_SIZE:-$(banana_demo_default_fast_live_input_size)}}"
  MAX_FRAMES="${4:-${MAX_FRAMES:-200}}"
fi

export BANANA_DEMO_CAMERA_PROFILE="${BANANA_DEMO_CAMERA_PROFILE:-live-fast}"
export CAMERA_WIDTH="${CAMERA_WIDTH:-$(banana_demo_default_fast_live_camera_width)}"
export CAMERA_HEIGHT="${CAMERA_HEIGHT:-$(banana_demo_default_fast_live_camera_height)}"
export CAMERA_FPS="${CAMERA_FPS:-$(banana_demo_default_fast_live_camera_fps)}"
export CAMERA_PIXFMT="${CAMERA_PIXFMT:-auto}"
export CONFIDENCE="${CONFIDENCE:-0.25}"
export DISPLAY_FLAG="${DISPLAY_FLAG:-auto}"
export HEADLESS_FLAG="${HEADLESS_FLAG:-auto}"
export BANANA_DEMO_RUNTIME_TAG="${BANANA_DEMO_RUNTIME_TAG:-auto}"
export BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX="${BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX:-auto}"

if banana_demo_is_board_mode; then
  export LOG_FILE="${LOG_FILE:-${REPO_DIR}/logs/camera_fast_${INPUT_SIZE}.log}"
else
  export LOG_FILE_REMOTE="${LOG_FILE_REMOTE:-${REPO_DIR}/logs/camera_fast_${INPUT_SIZE}.log}"
fi

echo "camera_profile=${BANANA_DEMO_CAMERA_PROFILE}" >&2
echo "camera_profile_model=${MODEL_PATH}" >&2
echo "camera_profile_runtime_request=${BANANA_DEMO_RUNTIME_TAG}" >&2
echo "camera_profile_capture_request=${CAMERA_WIDTH}x${CAMERA_HEIGHT}@${CAMERA_FPS}" >&2

exec "${ROOT_DIR}/scripts/run_camera_demo.sh" "${CAMERA_PATH}" "${MODEL_PATH}" "${INPUT_SIZE}" "${MAX_FRAMES}"
