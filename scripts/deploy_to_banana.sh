#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${BANANA_SSH_TARGET:-svt@banana}"
BOARD_DIR="${BOARD_DIR:-/home/svt/banana-yolo11-spacemit-demo}"

source /data/build_scripts/01-env.sh

"${ROOT_DIR}/scripts/build_cross.sh"
"${ROOT_DIR}/scripts/fetch_models.sh"

ssh "${TARGET}" "mkdir -p '${BOARD_DIR}'"
rsync -av "${ROOT_DIR}/install/k1x-release/" "${TARGET}:${BOARD_DIR}/app/"
rsync -av "${ROOT_DIR}/third_party/vendor/spacemit-ort.riscv64.2.0.1/" "${TARGET}:${BOARD_DIR}/runtime/"
rsync -av "${ROOT_DIR}/models/" "${TARGET}:${BOARD_DIR}/models/"
rsync -av "${ROOT_DIR}/assets/" "${TARGET}:${BOARD_DIR}/assets/"

if ! ssh "${TARGET}" "test -f /home/svt/opencv-install-k1x-gtk3/lib/libopencv_core.so"; then
  rsync -av /data/opencv/install-k1x-gtk3/ "${TARGET}:/home/svt/opencv-install-k1x-gtk3/"
fi

ssh "${TARGET}" "mkdir -p '${BOARD_DIR}/outputs' '${BOARD_DIR}/logs'"
echo "Deployed to ${TARGET}:${BOARD_DIR}"
