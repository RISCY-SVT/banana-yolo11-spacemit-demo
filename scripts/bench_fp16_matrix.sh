#!/usr/bin/env bash
## @file bench_fp16_matrix.sh
## @brief Run a reproducible YOLO11n FP16 benchmark matrix across staged runtimes.
## @details The helper treats FP16 coverage as a first-class repo workflow:
## it prepares verified FP16 models, deploys all requested runtime variants,
## runs `onnxruntime_perf_test`, app forward-only benchmarks, and full image
## pipeline checks, then stores raw logs plus TSV summaries for later reporting.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

## @brief Print CLI usage and the default benchmark policy.
usage() {
  cat <<'EOF'
Usage:
  bench_fp16_matrix.sh [out_dir] [image_path]

Matrix defaults:
  - runtimes: rt123,rt201,rt202b1
  - models: generated FP16 320 and 640
  - provider: spacemit
  - threads/pin: 4 / cluster0

Environment overrides:
  FP16_RUNTIME_TAGS=rt123,rt201,rt202b1,rt202
  FP16_MODEL_VARIANT=keep_io|full
  FP16_WARMUP=10
  FP16_RUNS=100
  FP16_REPEATS=5
  FP16_PERF_REPEATS=100
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

## @brief Return the repo-managed FP16 model path for one fixed input size.
## @param repo_root Repository root that owns the generated models.
## @param size Fixed square input size (`320` or `640`).
fp16_model_path() {
  local repo_root="$1"
  local size="$2"
  local variant="${FP16_MODEL_VARIANT:-keep_io}"
  case "${variant}" in
    keep_io)
      printf '%s\n' "${repo_root}/models/generated/fp16/yolov11n_${size}x${size}.fp16_iop32.onnx"
      ;;
    full)
      printf '%s\n' "${repo_root}/models/generated/fp16/yolov11n_${size}x${size}.fp16.onnx"
      ;;
    *)
      echo "ERROR: unsupported FP16_MODEL_VARIANT=${variant}; use keep_io|full" >&2
      return 2
      ;;
  esac
}

## @brief Extract the average latency from a perf_test log.
parse_perf_mean_ms() {
  local log_path="$1"
  python3 - "$log_path" <<'PY'
import re
import sys

text = open(sys.argv[1], "r", encoding="utf-8", errors="ignore").read()
matches = re.findall(r"Average inference time cost(?: total)?:\s*([0-9.]+)\s*ms", text)
print(matches[-1] if matches else "")
PY
}

## @brief Extract one key from the app RESULT line.
parse_result_field() {
  local log_path="$1"
  local key="$2"
  python3 - "$log_path" "$key" <<'PY'
import re
import sys

text = open(sys.argv[1], "r", encoding="utf-8", errors="ignore").read()
field = sys.argv[2]
if field in {"mean_ms", "std_ms", "fps"}:
    for line in text.splitlines():
        if line.startswith("RESULT "):
            match = re.search(rf"{re.escape(field)}=(\S+)", line)
            if match:
                print(match.group(1))
                break
    else:
        print("")
elif field in {"output0_sha256", "detections_sha256"}:
    for line in text.splitlines():
        if line.startswith("HASH "):
            match = re.search(rf"{re.escape(field)}=(\S+)", line)
            if match:
                print(match.group(1))
                break
    else:
        print("")
elif field in {"output_sha256", "detections_sha256_log"}:
    needle = "output_sha256" if field == "output_sha256" else "detections_sha256"
    for line in text.splitlines():
        if needle + "=" in line:
            match = re.search(rf"{re.escape(needle)}=(\S+)", line)
            if match:
                print(match.group(1))
                break
    else:
        print("")
else:
    print("")
PY
}

## @brief Extract one metric from the final image-mode INFO line.
parse_image_metric() {
  local log_path="$1"
  local key="$2"
  python3 - "$log_path" "$key" <<'PY'
import re
import sys

lines = open(sys.argv[1], "r", encoding="utf-8", errors="ignore").read().splitlines()
field = sys.argv[2]
for line in reversed(lines):
    if "objects=" not in line:
        continue
    match = re.search(rf"{re.escape(field)}=(\S+)", line)
    if match:
        print(match.group(1))
        break
else:
    print("")
PY
}

## @brief Convert a tab-separated summary file into a markdown table.
render_tsv_as_markdown() {
  local tsv_path="$1"
  local md_path="$2"
  python3 - "$tsv_path" "$md_path" <<'PY'
import csv
import sys

tsv_path, md_path = sys.argv[1:3]
with open(tsv_path, newline="", encoding="utf-8") as f:
    rows = list(csv.reader(f, delimiter="\t"))

with open(md_path, "w", encoding="utf-8") as f:
    if not rows:
        f.write("(no rows)\n")
        raise SystemExit(0)
    header = rows[0]
    f.write("| " + " | ".join(header) + " |\n")
    f.write("| " + " | ".join(["---"] * len(header)) + " |\n")
    for row in rows[1:]:
        f.write("| " + " | ".join(row) + " |\n")
PY
}

## @brief Run the board-local matrix and materialize raw logs plus TSV tables.
run_board_matrix() {
  local repo_dir="$1"
  local out_dir="$2"
  local image_path="$3"
  local runtimes_csv="${FP16_RUNTIME_TAGS:-rt123,rt201,rt202b1}"
  local warmup="${FP16_WARMUP:-10}"
  local runs="${FP16_RUNS:-100}"
  local repeats="${FP16_REPEATS:-5}"
  local perf_repeats="${FP16_PERF_REPEATS:-100}"
  local labels_path="${repo_dir}/assets/coco80.txt"

  mkdir -p \
    "${out_dir}/perf_test" \
    "${out_dir}/app_forward" \
    "${out_dir}/app_full" \
    "${out_dir}/outputs" \
    "${out_dir}/tables"

  local perf_tsv="${out_dir}/tables/perf_test_matrix.tsv"
  local forward_tsv="${out_dir}/tables/app_forward_matrix.tsv"
  local full_tsv="${out_dir}/tables/app_full_matrix.tsv"
  printf 'runtime\tmodel\tvariant\tinput_size\tstatus\tmean_ms\tfps\tlog\n' > "${perf_tsv}"
  printf 'runtime\tmodel\tvariant\tinput_size\tstatus\tmean_ms\tstd_ms\tfps\toutput_sha256\tdetections_sha256\tlog\n' > "${forward_tsv}"
  printf 'runtime\tmodel\tvariant\tinput_size\tstatus\tobjects\tpreprocess_ms\tinference_ms\tpostprocess_ms\ttotal_ms\tfps\toutput_sha256\tdetections_sha256\tlog\timage\n' > "${full_tsv}"

  IFS=',' read -r -a runtimes <<<"${runtimes_csv}"
  local size runtime_tag model_path perf_log forward_log full_log output_image dump_bin
  local variant="${FP16_MODEL_VARIANT:-keep_io}"
  for size in 320 640; do
    model_path="$(fp16_model_path "${repo_dir}" "${size}")"
    [[ -f "${model_path}" ]] || {
      echo "ERROR: missing FP16 model ${model_path}. Run ./scripts/fetch_or_build_fp16_models.sh first." >&2
      return 2
    }
    for runtime_tag in "${runtimes[@]}"; do
      banana_demo_export_runtime_env "${repo_dir}" "${runtime_tag}"
      banana_demo_unset_parallel_env

      perf_log="${out_dir}/perf_test/${runtime_tag}_${size}.log"
      if taskset -c 0,1,2,3 "$(banana_demo_perf_test_path "${repo_dir}" "${runtime_tag}")" \
          -m times -e spacemit -x 4 -y 1 -r "${perf_repeats}" -I "${model_path}" \
          > "${perf_log}" 2>&1; then
        local perf_mean perf_fps
        perf_mean="$(parse_perf_mean_ms "${perf_log}")"
        perf_fps="$(python3 - "${perf_mean}" <<'PY'
import sys
value = float(sys.argv[1]) if sys.argv[1] else 0.0
print(f"{1000.0 / value:.6f}" if value > 0 else "")
PY
)"
        printf '%s\tfp16-%s\t%s\t%s\tok\t%s\t%s\t%s\n' "${runtime_tag}" "${size}" "${variant}" "${size}" "${perf_mean}" "${perf_fps}" "${perf_log}" >> "${perf_tsv}"
      else
        printf '%s\tfp16-%s\t%s\t%s\tfail\t\t\t%s\n' "${runtime_tag}" "${size}" "${variant}" "${size}" "${perf_log}" >> "${perf_tsv}"
      fi

      forward_log="${out_dir}/app_forward/${runtime_tag}_${size}.log"
      if taskset -c 0,1,2,3 "$(banana_demo_binary_path "${repo_dir}" "${runtime_tag}")" \
          --model "${model_path}" \
          --labels "${labels_path}" \
          --input-size "${size}" \
          --source "image:${image_path}" \
          --provider spacemit \
          --threads 4 \
          --pin cluster0 \
          --benchmark-only 1 \
          --benchmark-mode forward \
          --warmup "${warmup}" \
          --runs "${runs}" \
          --repeats "${repeats}" \
          --display 0 \
          --headless 1 \
          --quiet 1 \
          --dump-hash 1 \
          > "${forward_log}" 2>&1; then
        printf '%s\tfp16-%s\t%s\t%s\tok\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "${runtime_tag}" "${size}" "${variant}" "${size}" \
          "$(parse_result_field "${forward_log}" mean_ms)" \
          "$(parse_result_field "${forward_log}" std_ms)" \
          "$(parse_result_field "${forward_log}" fps)" \
          "$(parse_result_field "${forward_log}" output0_sha256)" \
          "$(parse_result_field "${forward_log}" detections_sha256)" \
          "${forward_log}" \
          >> "${forward_tsv}"
      else
        printf '%s\tfp16-%s\t%s\t%s\tfail\t\t\t\t\t\t%s\n' "${runtime_tag}" "${size}" "${variant}" "${size}" "${forward_log}" >> "${forward_tsv}"
      fi

      full_log="${out_dir}/app_full/${runtime_tag}_${size}.log"
      output_image="${out_dir}/outputs/${runtime_tag}_${size}.jpg"
      dump_bin="${out_dir}/outputs/${runtime_tag}_${size}.bin"
      if taskset -c 0,1,2,3 "$(banana_demo_binary_path "${repo_dir}" "${runtime_tag}")" \
          --model "${model_path}" \
          --labels "${labels_path}" \
          --input-size "${size}" \
          --source "image:${image_path}" \
          --provider spacemit \
          --threads 4 \
          --pin cluster0 \
          --conf 0.25 \
          --display 0 \
          --headless 1 \
          --save-output "${output_image}" \
          --dump-hash 1 \
          --dump-out "${dump_bin}" \
          --quiet 0 \
          > "${full_log}" 2>&1; then
        printf '%s\tfp16-%s\t%s\t%s\tok\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "${runtime_tag}" "${size}" "${variant}" "${size}" \
          "$(parse_image_metric "${full_log}" objects)" \
          "$(parse_image_metric "${full_log}" preprocess_ms)" \
          "$(parse_image_metric "${full_log}" inference_ms)" \
          "$(parse_image_metric "${full_log}" postprocess_ms)" \
          "$(parse_image_metric "${full_log}" total_ms)" \
          "$(parse_image_metric "${full_log}" fps)" \
          "$(parse_result_field "${full_log}" output_sha256)" \
          "$(parse_result_field "${full_log}" detections_sha256_log)" \
          "${full_log}" \
          "${output_image}" \
          >> "${full_tsv}"
      else
        printf '%s\tfp16-%s\t%s\t%s\tfail\t\t\t\t\t\t\t\t\t%s\t%s\n' "${runtime_tag}" "${size}" "${variant}" "${size}" "${full_log}" "${output_image}" >> "${full_tsv}"
      fi
    done
  done

  render_tsv_as_markdown "${perf_tsv}" "${out_dir}/tables/perf_test_matrix.md"
  render_tsv_as_markdown "${forward_tsv}" "${out_dir}/tables/app_forward_matrix.md"
  render_tsv_as_markdown "${full_tsv}" "${out_dir}/tables/app_full_matrix.md"
}

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  OUT_DIR="${1:-${OUT_DIR:-${REPO_DIR}/logs/fp16_matrix_$(date +%Y-%m-%d_%H-%M-%S)}}"
  IMAGE_PATH="${2:-${IMAGE_PATH:-$(banana_demo_resolve_default_image "${REPO_DIR}")}}"
  run_board_matrix "${REPO_DIR}" "${OUT_DIR}" "${IMAGE_PATH}"
  exit 0
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
BOARD_DIR="$(banana_demo_host_board_dir)"
LOCAL_OUT_DIR="${1:-${OUT_DIR:-${ROOT_DIR}/logs/fp16_matrix_$(date +%Y-%m-%d_%H-%M-%S)}}"
IMAGE_PATH="${2:-${IMAGE_PATH:-$(find /data -name 'photo_2024-10-11_10-04-04.jpg' 2>/dev/null | head -n 1)}}"
REMOTE_OUT_DIR="${BOARD_DIR}/logs/$(basename "${LOCAL_OUT_DIR}")"

FP16_IO_MODE=all "${ROOT_DIR}/scripts/fetch_or_build_fp16_models.sh"
BANANA_DEMO_BUILD_VARIANTS="${FP16_RUNTIME_TAGS:-rt123,rt201,rt202b1}" \
BANANA_DEMO_DEPLOY_VARIANTS="${FP16_RUNTIME_TAGS:-rt123,rt201,rt202b1}" \
  "${ROOT_DIR}/scripts/deploy_to_banana.sh"

REMOTE_IMAGE_PATH="$(banana_demo_stage_remote_file "${TARGET}" "${BOARD_DIR}" "${IMAGE_PATH}" inputs)"
ssh "${TARGET}" "cd '${BOARD_DIR}' && BANANA_DEMO_EXEC_MODE=board FP16_RUNTIME_TAGS='${FP16_RUNTIME_TAGS:-rt123,rt201,rt202b1}' FP16_MODEL_VARIANT='${FP16_MODEL_VARIANT:-keep_io}' FP16_WARMUP='${FP16_WARMUP:-10}' FP16_RUNS='${FP16_RUNS:-100}' FP16_REPEATS='${FP16_REPEATS:-5}' FP16_PERF_REPEATS='${FP16_PERF_REPEATS:-100}' ./scripts/bench_fp16_matrix.sh '${REMOTE_OUT_DIR}' '${REMOTE_IMAGE_PATH}'"
mkdir -p "${LOCAL_OUT_DIR}"
rsync -av "${TARGET}:${REMOTE_OUT_DIR}/" "${LOCAL_OUT_DIR}/"
echo "FP16 matrix copied to ${LOCAL_OUT_DIR}"
