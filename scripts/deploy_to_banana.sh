#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${BANANA_SSH_TARGET:-svt@banana}"
BOARD_DIR="${BOARD_DIR:-/home/svt/banana-yolo11-spacemit-demo}"

source /data/build_scripts/01-env.sh

"${ROOT_DIR}/scripts/build_cross.sh"
"${ROOT_DIR}/scripts/fetch_models.sh"

ssh "${TARGET}" "mkdir -p '${BOARD_DIR}' '${BOARD_DIR}/bin' '${BOARD_DIR}/runtime' '${BOARD_DIR}/scripts' '${BOARD_DIR}/assets' '${BOARD_DIR}/logs' '${BOARD_DIR}/outputs' '${BOARD_DIR}/inputs'"
rsync -av "${ROOT_DIR}/install/k1x-release/bin/banana_yolo11_demo" "${TARGET}:${BOARD_DIR}/bin/"
rsync -av "${ROOT_DIR}/third_party/vendor/spacemit-ort.riscv64.2.0.1/" "${TARGET}:${BOARD_DIR}/runtime/"
rsync -av "${ROOT_DIR}/models/" "${TARGET}:${BOARD_DIR}/models/"
rsync -av "${ROOT_DIR}/assets/" "${TARGET}:${BOARD_DIR}/assets/"
rsync -av "${ROOT_DIR}/scripts/" "${TARGET}:${BOARD_DIR}/scripts/"
rsync -av "${ROOT_DIR}/docs/" "${TARGET}:${BOARD_DIR}/docs/"
rsync -av "${ROOT_DIR}/third_party_manifest/" "${TARGET}:${BOARD_DIR}/third_party_manifest/"
rsync -av "${ROOT_DIR}/README.md" "${TARGET}:${BOARD_DIR}/"

ssh "${TARGET}" "mkdir -p '${BOARD_DIR}/opencv'"
rsync -av /data/opencv/install-k1x-gtk3/lib/ "${TARGET}:${BOARD_DIR}/opencv/lib/"
echo "Deployed to ${TARGET}:${BOARD_DIR}"
