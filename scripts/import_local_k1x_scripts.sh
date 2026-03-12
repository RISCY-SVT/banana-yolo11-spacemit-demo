#!/usr/bin/env bash
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

