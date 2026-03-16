#!/usr/bin/env bash
## @file import_local_k1x_scripts.sh
## @brief Import canonical local K1X helper scripts into the repo reference tree.
## @details The imported copies document the exact external workflow the repo
## expects, without making the repo depend on mutable host-side paths at run time.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="/data/build_scripts"
DEST_DIR="${ROOT_DIR}/scripts/reference/build_scripts"

mkdir -p "${DEST_DIR}"

for file in 01-env.sh 03-banana-setup.sh 04-overlay-update.sh 05-build-opencv-ncnn.sh board_info.sh cluster_topology.sh; do
  if [[ -f "${SRC_DIR}/${file}" ]]; then
    cp -f "${SRC_DIR}/${file}" "${DEST_DIR}/${file}"
  fi
done

echo "Imported local K1X helper scripts into ${DEST_DIR}"
