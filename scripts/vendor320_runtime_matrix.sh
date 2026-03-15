#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage:
  vendor320_runtime_matrix.sh [image_path] [output_dir]

Purpose:
  Run a compact vendor320 visual/runtime matrix and save annotated outputs plus a CSV/Markdown summary.

Board-local default matrix:
  - rt123 visual reference
  - rt201 raw
  - rt201 fixed
  - rt202b1 raw (if staged locally)
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

run_board_matrix() {
  local repo_dir="$1"
  local image_path="$2"
  local out_dir="$3"
  local model_path="${MODEL_PATH:-$(banana_demo_default_benchmark_model "${repo_dir}")}"
  local matrix_csv="${out_dir}/runtime_matrix.csv"
  local matrix_md="${out_dir}/runtime_matrix.md"

  mkdir -p "${out_dir}"
  echo "runtime,fix_mode,applied,objects,total_ms,inference_ms,image,log" > "${matrix_csv}"

  local runtimes=("rt123:auto" "rt201:0" "rt201:1")
  if [[ -d "${repo_dir}/runtime/rt202b1" ]]; then
    runtimes+=("rt202b1:0")
  fi

  local entry runtime_tag fix_mode name image_out log_out objects total_ms inference_ms applied summary_source
  for entry in "${runtimes[@]}"; do
    runtime_tag="${entry%%:*}"
    fix_mode="${entry##*:}"
    name="${runtime_tag}"
    [[ "${fix_mode}" == "1" ]] && name="${name}_fixed"
    [[ "${fix_mode}" == "0" && "${runtime_tag}" == "rt201" ]] && name="${name}_raw"
    image_out="${out_dir}/${name}.jpg"
    log_out="${out_dir}/${name}.log"
    (
      cd "${repo_dir}"
      BANANA_DEMO_RUNTIME_TAG="${runtime_tag}" \
      BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX="${fix_mode}" \
      QUIET=0 \
      ./scripts/run_image_demo.sh "${image_path}" "${model_path}" 320 0.25 0 auto "${image_out}" "${log_out}"
    ) > "${log_out}.stdout" 2>&1 || true

    summary_source="${log_out}"
    if ! grep -q 'INFO objects=' "${summary_source}" 2>/dev/null; then
      summary_source="${log_out}.stdout"
    fi
    applied="$(grep -E '^vendor320_rt201_visual_fix_applied=' "${log_out}.stdout" | tail -n1 | cut -d= -f2- || true)"
    objects="$(grep -E 'INFO objects=' "${summary_source}" | tail -n1 | sed -E 's/.*objects=([0-9]+).*/\1/' || true)"
    total_ms="$(grep -E 'INFO objects=' "${summary_source}" | tail -n1 | sed -E 's/.*total_ms=([0-9.]+).*/\1/' || true)"
    inference_ms="$(grep -E 'INFO objects=' "${summary_source}" | tail -n1 | sed -E 's/.*inference_ms=([0-9.]+).*/\1/' || true)"
    echo "${runtime_tag},${fix_mode},${applied:-0},${objects:-},${total_ms:-},${inference_ms:-},${image_out},${log_out}" >> "${matrix_csv}"
  done

  {
    echo "| runtime | fix_mode | applied | objects | total_ms | inference_ms | image | log |"
    echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
    tail -n +2 "${matrix_csv}" | while IFS=, read -r runtime fix applied objects total_ms inference_ms image log_path; do
      echo "| ${runtime} | ${fix} | ${applied} | ${objects} | ${total_ms} | ${inference_ms} | ${image} | ${log_path} |"
    done
  } > "${matrix_md}"

  echo "saved ${matrix_csv}"
  echo "saved ${matrix_md}"
}

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  IMAGE_PATH="${1:-${IMAGE_PATH:-${REPO_DIR}/inputs/photo_2024-10-11_10-04-04.jpg}}"
  if [[ ! -f "${IMAGE_PATH}" ]]; then
    IMAGE_PATH="$(banana_demo_resolve_default_image "${REPO_DIR}")"
  fi
  OUT_DIR="${2:-${OUT_DIR:-${REPO_DIR}/outputs/vendor320_runtime_matrix_$(date +%Y%m%d_%H%M%S)}}"
  run_board_matrix "${REPO_DIR}" "${IMAGE_PATH}" "${OUT_DIR}"
  exit 0
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
BOARD_DIR="$(banana_demo_host_board_dir)"
"${ROOT_DIR}/scripts/deploy_to_banana.sh"

IMAGE_PATH="${1:-/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg}"
OUT_DIR="${2:-${BOARD_DIR}/outputs/vendor320_runtime_matrix_$(date +%Y%m%d_%H%M%S)}"
REMOTE_IMAGE_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${IMAGE_PATH}" inputs)"
ssh "${TARGET}" "cd '${BOARD_DIR}' && BANANA_DEMO_EXEC_MODE=board ./scripts/vendor320_runtime_matrix.sh '${REMOTE_IMAGE_PATH}' '${OUT_DIR}'"
