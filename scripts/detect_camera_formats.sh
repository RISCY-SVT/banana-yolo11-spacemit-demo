#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"
CAMERA_PATH="${1:-/dev/video0}"

if banana_demo_is_board_mode; then
  command -v v4l2-ctl >/dev/null
  echo "== devices =="
  v4l2-ctl --list-devices
  echo "== formats ${CAMERA_PATH} =="
  exec v4l2-ctl -d "${CAMERA_PATH}" --list-formats-ext
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
ssh "${TARGET}" "cd '$(banana_demo_host_board_dir)' && BANANA_DEMO_EXEC_MODE=board ./scripts/detect_camera_formats.sh '${CAMERA_PATH}'"
