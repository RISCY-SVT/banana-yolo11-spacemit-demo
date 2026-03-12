#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Version: 0.2.0
# Date:    2025-12-09
# Author:  Sergey Tyurin
# License: MIT
###############################################################################

echo "[banana-setup] This script is intended to run on the Banana Pi as root (sudo)."

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[banana-setup] ERROR: This script must be run as root (use sudo)" >&2
  exit 1
fi

install_optional_pkg() {
  local pkg="$1"
  if apt-get install -y "$pkg"; then
    echo "[banana-setup] Installed optional package: ${pkg}"
  else
    echo "[banana-setup] WARNING: Failed to install optional package: ${pkg}, continuing" >&2
  fi
}

apt-get update
apt-get install -y \
  build-essential \
  cmake \
  git \
  curl \
  wget \
  python3 \
  python3-pip \
  libgtk-3-dev \
  libgl1-mesa-dev \
  libglib2.0-dev \
  libjpeg-dev \
  libpng-dev \
  libtiff-dev \
  libavcodec-dev \
  libavformat-dev \
  libswscale-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  libx11-dev \
  libxext-dev \
  libxrender-dev \
  libxrandr-dev \
  libxi-dev \
  libxinerama-dev \
  libxft-dev \
  libxcomposite-dev \
  libxcursor-dev \
  libxdamage-dev \
  libxau-dev \
  libxdmcp-dev \
  pkg-config \
  shared-mime-info

install_optional_pkg "python3-rosdep"

if ! command -v rosdep >/dev/null 2>&1; then
  echo "[banana-setup] rosdep not found after apt; attempting pip-based install (best-effort)"
  if command -v python3 >/dev/null 2>&1; then
    # PEP 668 compliant: allow pip to install into system environment if needed
    if python3 -m pip install -U rosdep --break-system-packages; then
      echo "[banana-setup] Installed rosdep via pip"
    else
      echo "[banana-setup] WARNING: Failed to install rosdep via pip; continuing without rosdep" >&2
    fi
  else
    echo "[banana-setup] WARNING: python3 not available; cannot install rosdep via pip" >&2
  fi
fi

if command -v rosdep >/dev/null 2>&1; then
  echo "[banana-setup] Initializing rosdep (idempotent)"
  rosdep init 2>/dev/null || true
  ROS_OS_OVERRIDE_VALUE="${ROS_OS_OVERRIDE:-ubuntu:noble}"
  echo "[banana-setup] Updating rosdep (ROS_OS_OVERRIDE=${ROS_OS_OVERRIDE_VALUE})"
  ROS_OS_OVERRIDE="${ROS_OS_OVERRIDE_VALUE}" rosdep update || true
else
  echo "[banana-setup] rosdep not available; skip initialization" >&2
fi

BANANA_DEV_USER="svt"
ROS2_HUMBLE_SRC_DIR="/home/${BANANA_DEV_USER}/ros2_humble_src"

mkdir -p "${ROS2_HUMBLE_SRC_DIR}"
chown -R "${BANANA_DEV_USER}:${BANANA_DEV_USER}" "${ROS2_HUMBLE_SRC_DIR}"

if [[ ! -f "${ROS2_HUMBLE_SRC_DIR}/README-ros2-humble.txt" ]]; then
  cat <<'EOF' > "${ROS2_HUMBLE_SRC_DIR}/README-ros2-humble.txt"
ROS 2 Humble workspace source tree for Banana Pi BPI-F3 (K1X).
This directory is prepared by build_scripts/03-banana-setup.sh.
EOF
  chown "${BANANA_DEV_USER}:${BANANA_DEV_USER}" "${ROS2_HUMBLE_SRC_DIR}/README-ros2-humble.txt"
fi

echo "[banana-setup] Package snapshot (gtk/gstreamer/x11)"
dpkg -l 'libgtk-3*' 'libgstreamer*' 'libx11*' | sed -n '1,40p'

echo "[banana-setup] Done. Ready for sysroot overlay extraction."
