#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Version: 0.2.0
# Date:    2025-12-09
# Author:  Sergey Tyurin
# License: MIT
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/01-env.sh"

BANANA_HOST="${BANANA_HOST:-banana}"
BANANA_USER="${BANANA_USER:-svt}"
BANANA_SNAPSHOT="${BANANA_SNAPSHOT:-/data/banana-rootfs-snapshot}"
K1_SYSROOT_OVERLAY="${K1_SYSROOT_OVERLAY:-/data/sysroots/k1x-gtk3-overlay}"
ROS2_ROSDEP_PKG_LIST_DEFAULT="/data/ros2/banana-rosdep-humble-packages.txt"
ROS2_ROSDEP_PKG_LIST="${ROS2_ROSDEP_PKG_LIST:-${ROS2_ROSDEP_PKG_LIST_DEFAULT}}"

MODULES=(
  gtk+-3.0
  gdk-3.0
  pangocairo
  pangoft2
  cairo
  gdk-pixbuf-2.0
  glib-2.0
  gobject-2.0
  gstreamer-1.0
  gstreamer-video-1.0
  gstreamer-base-1.0
  gstreamer-app-1.0
  gstreamer-riff-1.0
  gstreamer-pbutils-1.0
  gstreamer-rtsp-1.0
  x11
  xext
  xrender
  xrandr
  xfixes
  xi
  xinerama
  xft
  xcomposite
  xcursor
  xdamage
)

EXCLUDE_PATTERNS=(
  --exclude='vlc/**'
  --exclude='perl*/**'
  --exclude='python*/**'
)
if [[ "${OVERLAY_INCLUDE_QT:-0}" -ne 1 ]]; then
  EXCLUDE_PATTERNS+=(--exclude='qt5/**' --exclude='qt6/**')
fi

ALLOWED_LIB_NAMES=(
  atk-1.0
  atspi
  blkid
  bsd
  bz2
  cairo
  cairo-gobject
  cap
  crypt
  datrie
  fribidi
  graphite2
  dbus-1
  deflate
  dw
  elf
  epoxy
  expat
  ffi
  fontconfig
  freetype
  gcrypt
  brotlidec
  brotlicommon
  brotlienc
  gdk-3
  gtk-3
  gdk_pixbuf-2.0
  gio-2.0
  glib-2.0
  gmodule-2.0
  gobject-2.0
  gpg-error
  gstreamer-1.0
  gstreamer-app-1.0
  gstreamer-audio-1.0
  gstreamer-base-1.0
  gstallocators-1.0
  gstaudio-1.0
  gstreamer-pbutils-1.0
  gstreamer-riff-1.0
  gstreamer-rtp-1.0
  gstreamer-rtsp-1.0
  gstreamer-sdp-1.0
  gstreamer-tag-1.0
  gstreamer-video-1.0
  gstapp-1.0
  gstbase-1.0
  gstaudio-1.0
  gstcheck-1.0
  gstcontroller-1.0
  gstelements-1.0
  gstfft-1.0
  gstpbutils-1.0
  gstriff-1.0
  gstrtp-1.0
  gstrtsp-1.0
  gstsdp-1.0
  gsttag-1.0
  gstvideo-1.0
  gthread-2.0
  harfbuzz
  jpeg
  lerc
  lz4
  lzma
  md
  mount
  openjp2
  orc-0.4
  pango-1.0
  pangocairo-1.0
  pangoft2-1.0
  pcre2-8
  thai
  pixman-1
  png16
  pulse
  pulse-mainloop-glib
  pulse-simple
  selinux
  sepol
  systemd
  tiff
  uuid
  webp
  webpdecoder
  webpdemux
  webpmux
  wayland-client
  wayland-cursor
  wayland-egl
  x11
  X11
  xau
  Xau
  xcb
  xcb-render
  xcb-shm
  xcb-xkb
  xcomposite
  Xcomposite
  xcursor
  Xcursor
  xdamage
  Xdamage
  xdmcp
  Xdmcp
  xext
  Xext
  xfixes
  Xfixes
  xft
  Xft
  xi
  Xi
  xinerama
  Xinerama
  xkbcommon
  xkbcommon-x11
  xrandr
  Xrandr
  xrender
  Xrender
  Xtst
  z
  zstd
  unwind
  atk-bridge-2.0
)

echo "[overlay] Generating minimal sysroot overlay from ${BANANA_USER}@${BANANA_HOST}"
echo "[overlay] Refreshing snapshot directory at ${BANANA_SNAPSHOT}"
mkdir -p "${BANANA_SNAPSHOT}"
find "${BANANA_SNAPSHOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
mkdir -p "${BANANA_SNAPSHOT}/pkgconfig-info"

MODULE_LIST="${MODULES[*]}"
CFLAGS_LIBS_FILE="${BANANA_SNAPSHOT}/pkgconfig-info/gtk_gst_x11.txt"
STATIC_LIBS_FILE="${BANANA_SNAPSHOT}/pkgconfig-info/gtk_gst_x11_static.txt"
PC_PATH_FILE="${BANANA_SNAPSHOT}/pkgconfig-info/pkgconfig_path.txt"

echo "[overlay] Capturing pkg-config flags for modules: ${MODULE_LIST}"
ssh "${BANANA_USER}@${BANANA_HOST}" "pkg-config --cflags --libs ${MODULE_LIST}" > "${CFLAGS_LIBS_FILE}"
echo "[overlay] Capturing pkg-config static libs for dependency closure"
ssh "${BANANA_USER}@${BANANA_HOST}" "pkg-config --static --libs ${MODULE_LIST}" > "${STATIC_LIBS_FILE}"

echo "[overlay] Capturing pkg-config search path"
ssh "${BANANA_USER}@${BANANA_HOST}" "pkg-config --variable pc_path pkg-config" > "${PC_PATH_FILE}"

declare -a RAW_HEADER_DIRS=()
declare -a RAW_LIB_DIRS=()
declare -a RAW_LIB_NAMES=()
while IFS= read -r token; do
  case "${token}" in
    -I*) RAW_HEADER_DIRS+=("${token#-I}") ;;
    -L*) RAW_LIB_DIRS+=("${token#-L}") ;;
    -l*) RAW_LIB_NAMES+=("${token#-l}") ;;
  esac
done < <(cat "${CFLAGS_LIBS_FILE}" "${STATIC_LIBS_FILE}" | tr ' ' '\n')
# Manually seed a few dependency libs that may not show up in non-static pkg-config outputs.
RAW_LIB_NAMES+=(bsd cap gcrypt gpg-error lz4 dw elf md)

declare -a PC_DIRS=()
if [[ -s "${PC_PATH_FILE}" ]]; then
  while IFS=: read -ra pcs; do
    for dir in "${pcs[@]}"; do
      [[ -n "${dir}" ]] && PC_DIRS+=("${dir}")
    done
  done < "${PC_PATH_FILE}"
fi

dedup_array() {
  local -n input=$1
  local -n output=$2
  declare -A seen=()
  output=()
  for item in "${input[@]}"; do
    [[ -z "${item}" ]] && continue
    if [[ -z "${seen[$item]+x}" ]]; then
      output+=("${item}")
      seen[$item]=1
    fi
  done
}

sync_rosdep_packages() {
  echo "[overlay][ros2] Checking rosdep package list at ${ROS2_ROSDEP_PKG_LIST}"
  if [[ ! -s "${ROS2_ROSDEP_PKG_LIST}" ]]; then
    echo "[overlay][ros2] No rosdep package list found; skipping ROS 2 additions"
    return
  fi

  local pkg_list_file="${ROS2_ROSDEP_PKG_LIST}"

  while IFS= read -r pkg; do
    pkg="${pkg%%#*}"
    pkg="$(echo "${pkg}" | xargs || true)"
    [[ -z "${pkg}" ]] && continue

    echo "[overlay][ros2] Processing package ${pkg}"
    local pkg_list_output
    pkg_list_output=$(ssh -n "${BANANA_USER}@${BANANA_HOST}" "dpkg -L \"${pkg}\"" 2>/dev/null || true)
    if [[ -z "${pkg_list_output}" ]]; then
      echo "[overlay][ros2] WARNING: No files returned for package ${pkg} (missing on Banana?)" >&2
      continue
    fi
    local -a pkg_files=()
    mapfile -t pkg_files <<< "${pkg_list_output}"

    declare -a pkg_dirs=()
    for path in "${pkg_files[@]}"; do
      [[ -z "${path}" ]] && continue
      case "${path}" in
        /usr/include/*)
          pkg_dirs+=("$(dirname "${path}")")
          ;;
        /usr/lib/*|/lib/*)
          case "${path}" in
            *.so*|*.a|*/pkgconfig/*.pc|*Config.cmake|*ConfigVersion.cmake|*ConfigExtras.cmake|*ConfigExtrasMkspecDir.cmake|*Macros.cmake|*config.cmake|*config-version.cmake|*Targets*.cmake|*targets*.cmake|*Find*.cmake|*ModuleLocation.cmake|*/qt5/bin/*)
              pkg_dirs+=("$(dirname "${path}")")
              ;;
          esac
          ;;
        /usr/bin/*)
          case "${path}" in
            /usr/bin/riscv64-linux-gnu-qmake|/usr/bin/qmake|/usr/bin/qtchooser)
              pkg_dirs+=("$(dirname "${path}")")
              ;;
          esac
          ;;
        */pkgconfig/*.pc|*Config.cmake|*ConfigVersion.cmake|*config.cmake|*config-version.cmake|*Targets*.cmake|*targets*.cmake|*Find*.cmake)
          pkg_dirs+=("$(dirname "${path}")")
          ;;
      esac
    done

    declare -a UNIQUE_PKG_DIRS=()
    dedup_array pkg_dirs UNIQUE_PKG_DIRS
    if ((${#UNIQUE_PKG_DIRS[@]} == 0)); then
      echo "[overlay][ros2] No eligible directories for ${pkg}; skipping"
      continue
    fi

    for dir in "${UNIQUE_PKG_DIRS[@]}"; do
      echo "[overlay][ros2] Syncing assets from ${dir} for package ${pkg}"
      if ! ssh -n "${BANANA_USER}@${BANANA_HOST}" "test -d \"${dir}\""; then
        echo "[overlay][ros2] WARN: Missing dir ${dir} on Banana for ${pkg}"
        continue
      fi
      mkdir -p "${BANANA_SNAPSHOT}${dir}"
      local filters=(--include='*/')
      if [[ "${dir}" == /usr/include/* ]]; then
        # Eigen and other header-only libs use extensionless headers (e.g., Eigen/Eigen).
        filters+=(--include='*')
      elif [[ "${dir}" == /usr/lib/qt5/bin ]]; then
        # Qt tools (moc/rcc/uic/qmake) live under /usr/lib/qt5/bin and are referenced by Qt5 CMake configs.
        filters+=(--include='*')
      else
        filters+=(--include='*.h' --include='*.hpp' --include='*.ipp')
        filters+=(--include='*.so*' --include='*.a' --include='qmake' --include='riscv64-linux-gnu-qmake' --include='qtchooser')
        filters+=(--include='*.pc' --include='*Config.cmake' --include='*ConfigVersion.cmake' --include='*ConfigExtras.cmake' --include='*ConfigExtrasMkspecDir.cmake' --include='*Macros.cmake' --include='*config.cmake' --include='*config-version.cmake' --include='*Targets*.cmake' --include='*targets*.cmake' --include='*Find*.cmake' --include='*ModuleLocation.cmake')
      fi
      filters+=("--exclude=*")
      rsync -avz \
        "${filters[@]}" \
        "${BANANA_USER}@${BANANA_HOST}:${dir}/" \
        "${BANANA_SNAPSHOT}${dir}/"
    done
  done < "${pkg_list_file}"
}

declare -a HEADER_DIRS=()
declare -a LIB_DIRS=()
declare -a LIB_DIRS_WITH_PC=()
declare -a LIB_NAMES=()
dedup_array RAW_HEADER_DIRS HEADER_DIRS
LIB_DIRS_WITH_PC=("${RAW_LIB_DIRS[@]}" "${PC_DIRS[@]}")
# Always include common multiarch lib roots in case pkg-config omits -L for defaults.
LIB_DIRS_WITH_PC+=("/usr/lib/riscv64-linux-gnu" "/lib/riscv64-linux-gnu")
dedup_array LIB_DIRS_WITH_PC LIB_DIRS
dedup_array RAW_LIB_NAMES LIB_NAMES
# Restrict to allowlist to avoid copying unrelated libs from short names like -lm.
if ((${#ALLOWED_LIB_NAMES[@]} > 0)); then
  declare -A allowed_map=()
  for name in "${ALLOWED_LIB_NAMES[@]}"; do allowed_map["$name"]=1; done
  filtered=()
  for name in "${LIB_NAMES[@]}"; do
    [[ -n "${allowed_map[$name]+x}" ]] && filtered+=("$name")
  done
  LIB_NAMES=("${filtered[@]}" "${ALLOWED_LIB_NAMES[@]}")
  declare -a DEDUPED_LIB_NAMES=()
  dedup_array LIB_NAMES DEDUPED_LIB_NAMES
  LIB_NAMES=("${DEDUPED_LIB_NAMES[@]}")
fi
if ((${#LIB_NAMES[@]} == 0)); then
  LIB_NAMES+=(gstreamer-1.0 gtk-3 gobject-2.0 glib-2.0 x11)
fi

echo "[overlay] Header directories:"
printf '  %s\n' "${HEADER_DIRS[@]}"
echo "[overlay] Library/pkgconfig directories:"
printf '  %s\n' "${LIB_DIRS[@]}"

rsync_headers() {
  local inc_dir="$1"
  echo "[overlay] Syncing headers from ${inc_dir}"
  if [[ "${inc_dir}" == "/usr/include/riscv64-linux-gnu" ]]; then
    echo "[overlay] Skip glibc multiarch include dir (${inc_dir}) to avoid clashing with toolchain sysroot; creating placeholder dir"
    mkdir -p "${BANANA_SNAPSHOT}${inc_dir}"
    return
  fi
  if ! ssh "${BANANA_USER}@${BANANA_HOST}" "test -d \"${inc_dir}\""; then
    echo "[overlay] WARN: Skip missing include dir ${inc_dir}"
    return
  fi
  mkdir -p "${BANANA_SNAPSHOT}${inc_dir}"
  rsync -avz \
    --include='*/' \
    --include='*.h' --include='*.hpp' \
    --exclude='*' \
    "${BANANA_USER}@${BANANA_HOST}:${inc_dir}/" \
    "${BANANA_SNAPSHOT}${inc_dir}/"
}

rsync_libs() {
  local lib_dir="$1"
  echo "[overlay] Syncing libs/pkgconfig from ${lib_dir}"
  if ! ssh "${BANANA_USER}@${BANANA_HOST}" "test -d \"${lib_dir}\""; then
    echo "[overlay] WARN: Skip missing lib dir ${lib_dir}"
    return
  fi
  local filters=("${EXCLUDE_PATTERNS[@]}" --include='*/' --include='*.pc')
  for name in "${LIB_NAMES[@]}"; do
    filters+=("--include=lib${name}.so*" "--include=lib${name}*.so*" "--include=lib${name}*.a")
  done
  filters+=("${EXCLUDE_PATTERNS[@]}")
  filters+=("--exclude=*")
  mkdir -p "${BANANA_SNAPSHOT}${lib_dir}"
  rsync -avz \
    "${filters[@]}" \
    "${BANANA_USER}@${BANANA_HOST}:${lib_dir}/" \
    "${BANANA_SNAPSHOT}${lib_dir}/"
}

for inc_dir in "${HEADER_DIRS[@]}"; do
  rsync_headers "${inc_dir}"
done

for lib_dir in "${LIB_DIRS[@]}"; do
  rsync_libs "${lib_dir}"
done

echo "[overlay] Optional ROS 2 ROSDEP package overlay from ${ROS2_ROSDEP_PKG_LIST}"
sync_rosdep_packages

echo "[overlay] Mirroring snapshot into overlay at ${K1_SYSROOT_OVERLAY}"
mkdir -p "${K1_SYSROOT_OVERLAY}"
rsync -a --delete "${BANANA_SNAPSHOT}/" "${K1_SYSROOT_OVERLAY}/"

echo "[overlay] Overlay size:"
du -sh "${K1_SYSROOT_OVERLAY}"
echo "[overlay] Sample files:"
set +o pipefail
find "${K1_SYSROOT_OVERLAY}" -maxdepth 4 -type f | head
set -o pipefail

echo "[overlay] Done."
