#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Version: 0.2.0
# Date:    2025-12-01
# Author:  Sergey Tyurin
# License: MIT
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/01-env.sh"

TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT}"
OPENCV_SRC="${OPENCV_SRC}"
NCNN_SRC="${NCNN_SRC}"
K1_SYSROOT_OVERLAY="${K1_SYSROOT_OVERLAY}"
K1_SYSROOT_BASE="${K1_SYSROOT_BASE}"
OPENCV_INSTALL="${OPENCV_INSTALL}"
BANANA_HOST="${BANANA_HOST}"
BANANA_USER="${BANANA_USER}"

export PKG_CONFIG_SYSROOT_DIR="${K1_SYSROOT_OVERLAY}"
export PKG_CONFIG_LIBDIR="${K1_SYSROOT_OVERLAY}/usr/lib/pkgconfig:${K1_SYSROOT_OVERLAY}/usr/lib/riscv64-linux-gnu/pkgconfig:${K1_SYSROOT_OVERLAY}/usr/share/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_LIBDIR}"

COMMON_ARCH_FLAGS="${K1_ARCH_FLAGS}"

USE_SYNC=false
USE_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--sync-to-banana] [--test-on-banana] [-h|--help]

Builds OpenCV (RVV + GTK3) and NCNN examples for SpacemiT K1.
--sync-to-banana  Deploy OpenCV/NCNN to banana after build.
--test-on-banana  Deploy and run a quick GUI test on banana (implies --sync-to-banana).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync-to-banana) USE_SYNC=true; shift ;;
    --test-on-banana) USE_TEST=true; USE_SYNC=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

require_path() {
  local p="$1"
  if [[ ! -e "$p" ]]; then
    echo "Required path missing: $p" >&2
    exit 1
  fi
}

check_prereqs() {
  require_path "${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-gnu-gcc"
  require_path "${K1_SYSROOT_OVERLAY}"
  require_path "${OPENCV_SRC}"
  require_path "${NCNN_SRC}"
  require_path "${OPENCV_SRC}/platforms/linux/riscv64-gcc.toolchain.cmake"
}

build_opencv() {
  echo "==> Building OpenCV for K1X (RVV+GTK3)"
  local build_dir="${OPENCV_SRC}/build-k1x-gtk3"
  mkdir -p "${build_dir}"
  cmake -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="${OPENCV_SRC}/platforms/linux/riscv64-gcc.toolchain.cmake" \
    -DCMAKE_SYSROOT="${K1_SYSROOT_OVERLAY}" \
    -DCMAKE_FIND_ROOT_PATH="${K1_SYSROOT_OVERLAY};${K1_SYSROOT_BASE}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_INSTALL_PREFIX="${OPENCV_INSTALL}" \
    -DCMAKE_C_FLAGS="${COMMON_ARCH_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${COMMON_ARCH_FLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/lib" \
    -DWITH_GTK=ON \
    -DWITH_QT=OFF \
    -DWITH_OPENGL=ON \
    -DWITH_OPENCL=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_opencv_world=OFF \
    -DRISCV_RVV_SCALABLE=ON \
    -DENABLE_RVV=ON \
    -S "${OPENCV_SRC}" -B "${build_dir}"
  ninja -C "${build_dir}" -j"$(nproc)"
  ninja -C "${build_dir}" install
  echo "==> OpenCV installed to ${OPENCV_INSTALL}"
}

build_ncnn() {
  echo "==> Building NCNN (examples) for K1X"
  local build_dir="${NCNN_SRC}/build-riscv"
  mkdir -p "${build_dir}"
  cmake -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="${OPENCV_SRC}/platforms/linux/riscv64-gcc.toolchain.cmake" \
    -DCMAKE_SYSROOT="${K1_SYSROOT_OVERLAY}" \
    -DCMAKE_FIND_ROOT_PATH="${K1_SYSROOT_OVERLAY};${K1_SYSROOT_BASE};${OPENCV_INSTALL}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib/riscv64-linux-gnu -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_OVERLAY}/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/usr/lib -Wl,-rpath-link=${K1_SYSROOT_BASE}/lib" \
    -DCMAKE_C_FLAGS="${COMMON_ARCH_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${COMMON_ARCH_FLAGS}" \
    -DOpenCV_DIR="${OPENCV_INSTALL}/lib/cmake/opencv4" \
    -DNCNN_BUILD_EXAMPLES=ON \
    -DNCNN_XTHEADVECTOR=OFF \
    -DNCNN_OPENMP=ON \
    -DNCNN_RVV=ON \
    -DENABLE_RVV=ON \
    -S "${NCNN_SRC}" -B "${build_dir}"
  ninja -C "${build_dir}" -j"$(nproc)" examples/all
  echo "==> NCNN examples built in ${build_dir}/examples"
}

deploy_to_banana() {
  echo "==> Deploying to banana (${BANANA_USER}@${BANANA_HOST})"
  rsync -avz --delete "${OPENCV_INSTALL}/" "${BANANA_USER}@${BANANA_HOST}:/home/${BANANA_USER}/opencv-install-k1x-gtk3/"
  if [[ -x "${NCNN_SRC}/rsync_csi_to_bananaK1.sh" ]]; then
    (cd "${NCNN_SRC}" && ./rsync_csi_to_bananaK1.sh)
  else
    echo "Warning: rsync_csi_to_bananaK1.sh not found/executable; skipping NCNN sync." >&2
  fi
  if [[ -f "${K1_SYSROOT_BASE}/lib/libomp.so" ]]; then
    rsync -av "${K1_SYSROOT_BASE}/lib/libomp.so" "${BANANA_USER}@${BANANA_HOST}:/home/${BANANA_USER}/opencv-install-k1x-gtk3/lib/"
  else
    echo "Warning: libomp.so not found under ${K1_SYSROOT_BASE}/lib; OpenMP runtime not deployed." >&2
  fi
}

run_tests_on_banana() {
  echo "==> Running quick GUI test on banana"
  ssh "${BANANA_USER}@${BANANA_HOST}" bash -lc "'
    set -euo pipefail
    export LD_LIBRARY_PATH=/home/${BANANA_USER}/opencv-install-k1x-gtk3/lib:\${LD_LIBRARY_PATH:-}
    export DISPLAY=:0
    export XDG_RUNTIME_DIR=/run/user/1000
    export XAUTHORITY=\$(ls /run/user/1000/.mutter-Xwaylandauth.* 2>/dev/null | head -n1)
    export GDK_BACKEND=x11
    cd /home/${BANANA_USER}/ncnn/models
    if [[ ! -f ../build-riscv/examples/photo_2024-10-11_10-04-04.jpg ]]; then
      echo \"Image ../build-riscv/examples/photo_2024-10-11_10-04-04.jpg missing; skipping GUI test\" >&2
      exit 0
    fi
    timeout 8s ../build-riscv/examples/yolo11 ../build-riscv/examples/photo_2024-10-11_10-04-04.jpg || true
  '"
}

main() {
  check_prereqs
  build_opencv
  build_ncnn

  if $USE_SYNC; then
    deploy_to_banana
  fi
  if $USE_TEST; then
    run_tests_on_banana
  fi

  echo "==> Done"
  echo "OpenCV install: ${OPENCV_INSTALL}"
  echo "NCNN build dir: ${NCNN_SRC}/build-riscv"
  if $USE_SYNC; then echo "Synced to banana: ${BANANA_USER}@${BANANA_HOST}"; fi
  if $USE_TEST; then echo "GUI test attempted on banana"; fi
}

main "$@"
