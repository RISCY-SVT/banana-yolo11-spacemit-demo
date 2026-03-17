#!/usr/bin/env bash
## @file build_cross.sh
## @brief Cross-build the demo for all validated runtime variants.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source /data/build_scripts/01-env.sh
source "${ROOT_DIR}/scripts/common.sh"
"${ROOT_DIR}/scripts/ensure_opencv.sh"
"${ROOT_DIR}/scripts/fetch_vendor_runtime.sh"

if [[ ! -f /data/opencv/install-k1x-gtk3/lib/cmake/opencv4/OpenCVConfig.cmake ]]; then
  echo "Missing /data/opencv/install-k1x-gtk3. Build OpenCV first or run prepare scripts." >&2
  exit 1
fi

## @brief Configure, build, and install one runtime-specific binary variant.
build_variant() {
  local runtime_tag="$1"
  local runtime_root="$2"
  local build_dir="${ROOT_DIR}/build/k1x-release-${runtime_tag}"
  local install_dir="${ROOT_DIR}/install/k1x-release-${runtime_tag}"

  cmake -S "${ROOT_DIR}" -B "${build_dir}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="${ROOT_DIR}/cmake/toolchains/k1x-spacemit-cross.cmake" \
    -DCMAKE_INSTALL_PREFIX="${install_dir}" \
    -DVENDOR_SPACEMIT_ORT_ROOT="${runtime_root}" \
    -DBANANA_DEMO_RUNTIME_SUBDIR="${runtime_tag}/lib" \
    -DOpenCV_DIR="/data/opencv/install-k1x-gtk3/lib/cmake/opencv4"

  cmake --build "${build_dir}" -j"$(nproc)"
  cmake --install "${build_dir}"
  file "${install_dir}/bin/banana_yolo11_demo"
}

VARIANTS="${BANANA_DEMO_BUILD_VARIANTS:-rt201,rt123}"
IFS=',' read -r -a BUILD_VARIANTS <<<"${VARIANTS}"
for runtime_tag in "${BUILD_VARIANTS[@]}"; do
  build_variant "${runtime_tag}" "$(banana_demo_runtime_vendor_root "${ROOT_DIR}" "${runtime_tag}")"
done
