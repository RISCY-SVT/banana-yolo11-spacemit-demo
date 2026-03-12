#!/usr/bin/env bash
set -euo pipefail

TARGET="${BANANA_SSH_TARGET:-svt@banana}"
CAMERA_PATH="${1:-/dev/video0}"
source /data/build_scripts/01-env.sh

ssh "${TARGET}" "\
  set -euo pipefail; \
  command -v v4l2-ctl >/dev/null; \
  echo '== devices =='; \
  v4l2-ctl --list-devices; \
  echo '== formats ${CAMERA_PATH} =='; \
  v4l2-ctl -d '${CAMERA_PATH}' --list-formats-ext"

