#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage:
  detect_camera_formats.sh [camera_path_or_index]

If no camera is provided, the script auto-selects the first stable USB capture node.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

CAMERA_PATH="${1:-auto}"

if banana_demo_is_board_mode; then
  command -v v4l2-ctl >/dev/null
  if [[ -z "${CAMERA_PATH}" || "${CAMERA_PATH}" == "auto" ]]; then
    CAMERA_PATH="$(banana_demo_default_camera_path || true)"
  fi
  if [[ -z "${CAMERA_PATH}" ]]; then
    echo "ERROR: no usable camera node found" >&2
    exit 2
  fi
  CAMERA_REALPATH="$(banana_demo_resolve_camera_path "${CAMERA_PATH}")"
  echo "== selected camera =="
  echo "requested=${CAMERA_PATH}"
  echo "resolved=${CAMERA_REALPATH}"
  echo "== devices =="
  v4l2-ctl --list-devices
  echo "== formats ${CAMERA_REALPATH} =="
  exec v4l2-ctl -d "${CAMERA_REALPATH}" --list-formats-ext
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
ssh "${TARGET}" "cd '$(banana_demo_host_board_dir)' && BANANA_DEMO_EXEC_MODE=board ./scripts/detect_camera_formats.sh '${CAMERA_PATH}'"
