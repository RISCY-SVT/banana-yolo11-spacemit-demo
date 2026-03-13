#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/k1x-release"
INSTALL_DIR="${ROOT_DIR}/install/k1x-release"

source /data/build_scripts/01-env.sh
"${ROOT_DIR}/scripts/ensure_opencv.sh"
"${ROOT_DIR}/scripts/fetch_vendor_runtime.sh"

if [[ ! -f /data/opencv/install-k1x-gtk3/lib/cmake/opencv4/OpenCVConfig.cmake ]]; then
  echo "Missing /data/opencv/install-k1x-gtk3. Build OpenCV first or run prepare scripts." >&2
  exit 1
fi

cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="${ROOT_DIR}/cmake/toolchains/k1x-spacemit-cross.cmake" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DVENDOR_SPACEMIT_ORT_ROOT="${ROOT_DIR}/third_party/vendor/spacemit-ort.riscv64.2.0.1" \
  -DOpenCV_DIR="/data/opencv/install-k1x-gtk3/lib/cmake/opencv4"

cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}"
file "${INSTALL_DIR}/bin/banana_yolo11_demo"
