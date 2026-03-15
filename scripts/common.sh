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

banana_demo_default_visual_model() {
  local repo_root="$1"
  printf '%s\n' "${repo_root}/models/generated/xquant_640/yolov11n_640x640.dynamic_int8.onnx"
}

banana_demo_default_visual_input_size() {
  printf '640\n'
}

banana_demo_default_benchmark_model() {
  local repo_root="$1"
  printf '%s\n' "${repo_root}/models/vendor/yolo11/yolov11n_320x320.q.onnx"
}

banana_demo_is_vendor320_model() {
  local model_path="${1:-}"
  [[ "$(basename "${model_path}")" == "yolov11n_320x320.q.onnx" ]]
}

banana_demo_runtime_dir() {
  local repo_root="$1"
  local runtime_tag="$2"
  printf '%s\n' "${repo_root}/runtime/${runtime_tag}"
}

banana_demo_binary_path() {
  local repo_root="$1"
  local runtime_tag="$2"
  local candidate="${repo_root}/bin/banana_yolo11_demo_${runtime_tag}"
  if [[ -x "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  printf '%s\n' "${repo_root}/bin/banana_yolo11_demo"
}

banana_demo_perf_test_path() {
  local repo_root="$1"
  local runtime_tag="$2"
  printf '%s\n' "${repo_root}/runtime/${runtime_tag}/bin/onnxruntime_perf_test"
}

banana_demo_runtime_tag_from_override() {
  local override="${BANANA_DEMO_RUNTIME_TAG:-auto}"
  case "${override}" in
    auto|"")
      return 1
      ;;
    rt123|1.2.3)
      printf 'rt123\n'
      return 0
      ;;
    rt201|2.0.1)
      printf 'rt201\n'
      return 0
      ;;
    *)
      echo "ERROR: unsupported BANANA_DEMO_RUNTIME_TAG=${override}; use auto|rt123|rt201" >&2
      return 2
      ;;
  esac
}

banana_demo_resolve_runtime_tag() {
  local model_path="$1"
  local runtime_profile="${2:-visual}"
  local override
  if override="$(banana_demo_runtime_tag_from_override)"; then
    printf '%s\n' "${override}"
    return 0
  fi

  if [[ "${runtime_profile}" == "perf" ]]; then
    printf 'rt201\n'
    return 0
  fi

  if banana_demo_is_vendor320_model "${model_path}"; then
    printf 'rt123\n'
    return 0
  fi

  printf 'rt201\n'
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
  local runtime_tag="$2"
  local libs
  libs="$(banana_demo_join_colon_paths "$(banana_demo_runtime_dir "${repo_root}" "${runtime_tag}")/lib" "${repo_root}/opencv/lib")"
  if [[ -n "${libs}" ]]; then
    export LD_LIBRARY_PATH="${libs}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi
}

banana_demo_apply_vendor320_rt201_visual_fix() {
  local model_path="$1"
  local runtime_tag="$2"
  local runtime_profile="${3:-visual}"
  local mode="${BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX:-auto}"
  export BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX_APPLIED=0

  banana_demo_is_vendor320_model "${model_path}" || return 0
  [[ "${runtime_tag}" == "rt201" ]] || return 0

  case "${mode}" in
    0|off|false|disable|disabled)
      return 0
      ;;
    auto)
      [[ "${runtime_profile}" == "visual" ]] || return 0
      ;;
    1|on|true|enable|enabled)
      ;;
    *)
      echo "ERROR: unsupported BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=${mode}; use auto|0|1" >&2
      return 2
      ;;
  esac

  export SPACEMIT_EP_DISABLE_FLOAT16_EPILOGUE=1
  export SPACEMIT_EP_DISABLE_OP_NAME_FILTER="/model.23/Slice;/model.23/Slice_1;/model.23/Add_1;/model.23/Add_2;/model.23/Sub;/model.23/Sub_1"
  export BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX_APPLIED=1
  echo "INFO: enabling vendor320 rt201 visual workaround (disable float16 epilogue; keep /model.23 tail Slice/Add/Sub ops on CPU)." >&2
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

banana_demo_parse_video_index() {
  local candidate="${1:-}"
  if [[ "${candidate}" =~ ^/dev/video([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

banana_demo_resolve_camera_path() {
  local candidate="${1:-}"
  if [[ -z "${candidate}" || "${candidate}" == "auto" ]]; then
    return 1
  fi

  if [[ "${candidate}" =~ ^[0-9]+$ ]]; then
    printf '/dev/video%s\n' "${candidate}"
    return 0
  fi

  if [[ -e "${candidate}" ]]; then
    readlink -f "${candidate}"
    return 0
  fi

  printf '%s\n' "${candidate}"
}

banana_demo_default_camera_path() {
  local candidate

  for candidate in /dev/v4l/by-id/*video-index0; do
    [[ -e "${candidate}" ]] || continue
    printf '%s\n' "${candidate}"
    return 0
  done

  for candidate in /dev/v4l/by-path/*video-index0; do
    [[ -e "${candidate}" ]] || continue
    printf '%s\n' "${candidate}"
    return 0
  done

  if command -v v4l2-ctl >/dev/null 2>&1; then
    local chosen
    chosen="$(
      v4l2-ctl --list-devices 2>/dev/null | awk '
        /^[^ \t].*:$/ {header=$0; next}
        /^[ \t]+\/dev\/video[0-9]+$/ {
          node=$1
          if (header ~ /(usb|USB)/ && chosen == "") {
            chosen=node
          }
        }
        END {
          if (chosen != "")
            print chosen
        }'
    )"
    if [[ -n "${chosen}" ]]; then
      printf '%s\n' "${chosen}"
      return 0
    fi
  fi

  for candidate in /dev/video*; do
    [[ -e "${candidate}" ]] || continue
    printf '%s\n' "${candidate}"
    return 0
  done

  return 1
}

banana_demo_choose_camera_pixfmt() {
  local camera_path="${1:-}"
  local camera_width="${2:-1280}"
  local camera_height="${3:-720}"

  if ! command -v v4l2-ctl >/dev/null 2>&1; then
    printf 'auto\n'
    return 0
  fi

  local resolved
  resolved="$(banana_demo_resolve_camera_path "${camera_path}")" || {
    printf 'auto\n'
    return 0
  }

  local formats
  formats="$(v4l2-ctl -d "${resolved}" --list-formats-ext 2>/dev/null || true)"
  [[ -n "${formats}" ]] || {
    printf 'auto\n'
    return 0
  }

  local exact_size="${camera_width}x${camera_height}"
  if printf '%s\n' "${formats}" | awk -v fmt="MJPG" -v size="${exact_size}" '
      $0 ~ "\\047" fmt "\\047" {in_fmt=1; next}
      /^[ \t]*\\[[0-9]+\\]:/ {in_fmt=0}
      in_fmt && index($0, "Size: Discrete " size) {found=1}
      END {exit(found ? 0 : 1)}'; then
    printf 'mjpg\n'
    return 0
  fi
  if printf '%s\n' "${formats}" | awk -v fmt="YUYV" -v size="${exact_size}" '
      $0 ~ "\\047" fmt "\\047" {in_fmt=1; next}
      /^[ \t]*\\[[0-9]+\\]:/ {in_fmt=0}
      in_fmt && index($0, "Size: Discrete " size) {found=1}
      END {exit(found ? 0 : 1)}'; then
    printf 'yuyv\n'
    return 0
  fi
  if printf '%s\n' "${formats}" | grep -q "'MJPG'"; then
    printf 'mjpg\n'
    return 0
  fi
  if printf '%s\n' "${formats}" | grep -q "'YUYV'"; then
    printf 'yuyv\n'
    return 0
  fi
  printf 'auto\n'
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
