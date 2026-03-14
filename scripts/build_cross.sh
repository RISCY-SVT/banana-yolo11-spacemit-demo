#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source /data/build_scripts/01-env.sh
"${ROOT_DIR}/scripts/ensure_opencv.sh"
"${ROOT_DIR}/scripts/fetch_vendor_runtime.sh"

if [[ ! -f /data/opencv/install-k1x-gtk3/lib/cmake/opencv4/OpenCVConfig.cmake ]]; then
  echo "Missing /data/opencv/install-k1x-gtk3. Build OpenCV first or run prepare scripts." >&2
  exit 1
fi

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
  case "${runtime_tag}" in
    rt201)
      build_variant "rt201" "${ROOT_DIR}/third_party/vendor/spacemit-ort.riscv64.2.0.1"
      ;;
    rt123)
      build_variant "rt123" "${ROOT_DIR}/third_party/vendor/spacemit-ort.riscv64.1.2.3"
      ;;
    *)
      echo "Unknown runtime tag in BANANA_DEMO_BUILD_VARIANTS: ${runtime_tag}" >&2
      exit 2
      ;;
  esac
done
