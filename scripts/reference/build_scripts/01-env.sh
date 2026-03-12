#!/usr/bin/env bash
set -uo pipefail

###############################################################################
# Version: 0.2.0
# Date:    2025-12-08
# Author:  Sergey Tyurin
# License: MIT
###############################################################################

# Shared environment for K1X cross-build
export TOOLCHAIN_ROOT="/data/SpacemiT/spacemit-toolchain-linux-glibc-x86_64-v1.1.2"
# Expect tarball at /data/SpacemiT/spacemit-toolchain-linux-glibc-x86_64-v1.1.2.tar.xz
# from https://archive.spacemit.com/toolchain/
export TOOLCHAIN_TARBALL="${TOOLCHAIN_ROOT}.tar.xz"

export OPENCV_SRC="/data/opencv"
export NCNN_SRC="/data/ncnn"
export OPENCV_REPO="https://github.com/opencv/opencv.git"
export OPENCV_BRANCH="4.x"
export NCNN_REPO="https://github.com/Tencent/ncnn.git"
export NCNN_BRANCH="master"

export K1_SYSROOT_BASE="${TOOLCHAIN_ROOT}/sysroot"
export K1_SYSROOT_OVERLAY="/data/sysroots/k1x-gtk3-overlay"
export BANANA_SNAPSHOT="/data/banana-rootfs-snapshot"

export BANANA_HOST="${BANANA_HOST:-banana}"
export BANANA_USER="${BANANA_USER:-svt}"
# Allow override from the environment while keeping a stable default.
export BANANA_SSH_TARGET="${BANANA_SSH_TARGET:-${BANANA_USER}@${BANANA_HOST}}"

export OPENCV_INSTALL="${OPENCV_SRC}/install-k1x-gtk3"

# Common arch flags for K1X (RVV + Zfh)
export K1_ARCH_FLAGS="-march=rv64gcv_zvfh -mabi=lp64d"

# ROS 2 Humble cross-build workspace (paths only; creation handled elsewhere)
export ROS2_HUMBLE_WS="/data/ros2/humble"
export ROS2_HUMBLE_SRC="${ROS2_HUMBLE_WS}/src"
export ROS2_HUMBLE_BUILD="${ROS2_HUMBLE_WS}/build-riscv"
export ROS2_HUMBLE_INSTALL="${ROS2_HUMBLE_WS}/install-riscv"
export ROS2_HUMBLE_LOG="${ROS2_HUMBLE_WS}/log-riscv"
export ROS2_HUMBLE_TOOLCHAIN="${ROS2_HUMBLE_WS}/toolchain/k1x-riscv64-ros2.cmake"

# Toolchain on PATH
export PATH="${TOOLCHAIN_ROOT}/bin:${PATH}"

echo "[env] TOOLCHAIN_ROOT=${TOOLCHAIN_ROOT}"
echo "[env] ARCH_FLAGS=${K1_ARCH_FLAGS}"
echo "[env] OPENCV_SRC=${OPENCV_SRC}"
echo "[env] NCNN_SRC=${NCNN_SRC}"
echo "[env] K1_SYSROOT_OVERLAY=${K1_SYSROOT_OVERLAY}"
echo "[env] ROS2_HUMBLE_WS=${ROS2_HUMBLE_WS}"
