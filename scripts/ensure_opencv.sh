#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -m)" == "riscv64" ]]; then
  if pkg-config --exists opencv4; then
    echo "Board OpenCV OK: $(pkg-config --modversion opencv4)"
    exit 0
  fi
  if [[ -d "${ROOT_DIR}/opencv/lib" ]]; then
    echo "Board-local OpenCV runtime OK: ${ROOT_DIR}/opencv/lib"
    exit 0
  fi
  echo "Missing OpenCV on board. Install libopencv-dev or deploy ${ROOT_DIR}/opencv/lib." >&2
  exit 1
fi

source /data/build_scripts/01-env.sh

OPENCV_ROOT="/data/opencv/install-k1x-gtk3"
OPENCV_CONFIG="${OPENCV_ROOT}/lib/cmake/opencv4/OpenCVConfig.cmake"

if [[ -f "${OPENCV_CONFIG}" ]]; then
  echo "Host OpenCV OK: ${OPENCV_ROOT}"
  exit 0
fi

cat >&2 <<EOF
Missing host OpenCV cross install at:
  ${OPENCV_CONFIG}

Recommended fix:
  ./scripts/import_local_k1x_scripts.sh
  source ./scripts/reference/build_scripts/01-env.sh
  ./scripts/reference/build_scripts/05-build-opencv-ncnn.sh
EOF
exit 1
