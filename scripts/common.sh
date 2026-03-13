#!/usr/bin/env bash

banana_demo_repo_root() {
  local source_path="${BASH_SOURCE[0]}"
  while [ -L "${source_path}" ]; do
    source_path="$(readlink "${source_path}")"
  done
  local script_dir
  script_dir="$(cd "$(dirname "${source_path}")" && pwd)"
  cd "${script_dir}/.." && pwd
}

banana_demo_is_board_mode() {
  if [[ "${BANANA_DEMO_EXEC_MODE:-}" == "board" ]]; then
    return 0
  fi
  [[ "$(uname -m)" == "riscv64" ]]
}

banana_demo_board_root() {
  if [[ -n "${BOARD_DIR:-}" ]]; then
    printf '%s\n' "${BOARD_DIR}"
    return 0
  fi
  banana_demo_repo_root
}

banana_demo_host_target() {
  printf '%s\n' "${BANANA_SSH_TARGET:-svt@banana}"
}

banana_demo_host_board_dir() {
  printf '%s\n' "${BOARD_DIR:-/home/svt/banana-yolo11-spacemit-demo}"
}

banana_demo_join_colon_paths() {
  local out=""
  local item
  for item in "$@"; do
    [[ -n "${item}" ]] || continue
    [[ -d "${item}" ]] || continue
    if [[ -n "${out}" ]]; then
      out="${out}:${item}"
    else
      out="${item}"
    fi
  done
  printf '%s\n' "${out}"
}

banana_demo_export_runtime_env() {
  local repo_root="$1"
  local libs
  libs="$(banana_demo_join_colon_paths "${repo_root}/runtime/lib" "${repo_root}/opencv/lib")"
  if [[ -n "${libs}" ]]; then
    export LD_LIBRARY_PATH="${libs}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi
}

banana_demo_prepare_display_env() {
  local display_flag="${1:-0}"
  [[ "${display_flag}" == "1" ]] || return 0
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [[ -z "${WAYLAND_DISPLAY:-}" && -S "${XDG_RUNTIME_DIR}/wayland-0" ]]; then
    export WAYLAND_DISPLAY="wayland-0"
  fi
  export DISPLAY="${DISPLAY:-:0}"
  if [[ -z "${XAUTHORITY:-}" ]]; then
    local auth
    for auth in "${XDG_RUNTIME_DIR}"/.mutter-Xwaylandauth.*; do
      [[ -f "${auth}" ]] || continue
      export XAUTHORITY="${auth}"
      break
    done
  fi
}

banana_demo_unset_parallel_env() {
  unset OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES OMP_SCHEDULE OMP_MAX_ACTIVE_LEVELS OMP_NESTED OMP_STACKSIZE OMP_CANCELLATION OMP_DISPLAY_ENV
  unset GOMP_CPU_AFFINITY GOMP_STACKSIZE GOMP_SPINCOUNT
}

banana_demo_resolve_default_image() {
  local repo_root="$1"
  local candidates=(
    "${IMAGE_PATH:-}"
    "${BANANA_DEMO_IMAGE:-}"
    "${repo_root}/inputs/photo_2024-10-11_10-04-04.jpg"
    "/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg"
    "${HOME}/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -n "${candidate}" ]] || continue
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

banana_demo_stage_remote_file() {
  local target="$1"
  local board_dir="$2"
  local local_path="$3"
  local remote_subdir="$4"
  if [[ -f "${local_path}" ]]; then
    ssh "${target}" "mkdir -p '${board_dir}/${remote_subdir}'"
    rsync -av "${local_path}" "${target}:${board_dir}/${remote_subdir}/"
    printf '%s/%s/%s\n' "${board_dir}" "${remote_subdir}" "$(basename "${local_path}")"
    return 0
  fi
  printf '%s\n' "${local_path}"
}
