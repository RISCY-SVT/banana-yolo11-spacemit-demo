set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

if(NOT DEFINED ENV{TOOLCHAIN_ROOT})
    message(FATAL_ERROR "TOOLCHAIN_ROOT is not set. Source /data/build_scripts/01-env.sh first.")
endif()

set(TOOLCHAIN_ROOT "$ENV{TOOLCHAIN_ROOT}")
set(K1_SYSROOT_BASE "$ENV{K1_SYSROOT_BASE}")
set(K1_SYSROOT_OVERLAY "$ENV{K1_SYSROOT_OVERLAY}")
set(K1_ARCH_FLAGS "$ENV{K1_ARCH_FLAGS}")

set(CMAKE_C_COMPILER "${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-gnu-gcc")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-gnu-g++")
set(CMAKE_AR "${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-gnu-ar")
set(CMAKE_RANLIB "${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-gnu-ranlib")
set(CMAKE_STRIP "${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-gnu-strip")
set(CMAKE_OBJDUMP "${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-gnu-objdump")

set(CMAKE_SYSROOT "${K1_SYSROOT_BASE}")
set(CMAKE_C_FLAGS_INIT "${K1_ARCH_FLAGS} --sysroot=${K1_SYSROOT_BASE}")
set(CMAKE_CXX_FLAGS_INIT "${K1_ARCH_FLAGS} --sysroot=${K1_SYSROOT_BASE}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "--sysroot=${K1_SYSROOT_BASE}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "--sysroot=${K1_SYSROOT_BASE}")

set(CMAKE_FIND_ROOT_PATH
    "${K1_SYSROOT_BASE}"
    "${K1_SYSROOT_OVERLAY}"
    "/data/opencv/install-k1x-gtk3"
)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(ENV{PKG_CONFIG_SYSROOT_DIR} "${K1_SYSROOT_OVERLAY}")
set(ENV{PKG_CONFIG_LIBDIR} "${K1_SYSROOT_OVERLAY}/usr/lib/riscv64-linux-gnu/pkgconfig:${K1_SYSROOT_OVERLAY}/lib/riscv64-linux-gnu/pkgconfig")
set(ENV{PKG_CONFIG_PATH} "/data/opencv/install-k1x-gtk3/lib/pkgconfig:$ENV{PKG_CONFIG_LIBDIR}")

set(CMAKE_INSTALL_RPATH "$ORIGIN/../runtime/lib;$ORIGIN/../lib")
set(CMAKE_BUILD_WITH_INSTALL_RPATH OFF)
