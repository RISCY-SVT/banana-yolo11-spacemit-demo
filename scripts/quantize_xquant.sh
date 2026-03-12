#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIZE="${1:-640}"
MODEL_PATH="${2:-${ROOT_DIR}/models/generated/yolo11n.onnx}"
OUTPUT_PREFIX="${3:-yolov11n_${SIZE}x${SIZE}.q}"
CALIB_COUNT="${CALIB_COUNT:-10}"
DATASET_DIR="${DATASET_DIR:-/data/datasets/coco_calib2K/images}"
WORK_DIR="${ROOT_DIR}/models/generated/xquant_${SIZE}"
CALIB_LIST="${WORK_DIR}/calib_list.txt"
CONFIG_TEMPLATE="${ROOT_DIR}/configs/xquant/yolov11_${SIZE}.json.in"
CONFIG_PATH="${WORK_DIR}/xquant_config.json"
VENV_DIR="${ROOT_DIR}/.venv/xquant"
XQUANT_MODE="${XQUANT_MODE:-static}"

resolve_python() {
  if [[ -n "${XQUANT_PYTHON:-}" ]]; then
    echo "${XQUANT_PYTHON}"
    return 0
  fi
  if [[ -x /data/ort-spacemit-track/quant/venv/bin/python3 ]]; then
    echo /data/ort-spacemit-track/quant/venv/bin/python3
    return 0
  fi
  echo "${VENV_DIR}/bin/python3"
}

prepare_python() {
  local py="$1"
  if [[ -x "${py}" ]]; then
    "${py}" -m xquant --help >/dev/null 2>&1 && return 0
  fi

  python3 -m venv "${VENV_DIR}"
  source "${VENV_DIR}/bin/activate"
  python3 -m pip install --upgrade pip
  python3 -m pip install --index-url https://git.spacemit.com/api/v4/projects/33/packages/pypi/simple "xquant==2.0.4"
  python3 -m pip install "onnx>=1.16,<1.19"
}

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "Model not found: ${MODEL_PATH}" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}"
python3 - <<PY
from pathlib import Path

dataset_dir = Path("${DATASET_DIR}")
images = sorted(str(p) for p in dataset_dir.iterdir() if p.is_file())
selected = images[: int("${CALIB_COUNT}")]
if not selected:
    raise SystemExit("No calibration images found in ${DATASET_DIR}")
Path("${CALIB_LIST}").write_text("\n".join(selected) + "\n", encoding="utf-8")
PY
test -s "${CALIB_LIST}"

PYTHON_BIN="$(resolve_python)"
prepare_python "${PYTHON_BIN}"
PYTHON_BIN="$(resolve_python)"

echo "Using XQUANT_MODE=${XQUANT_MODE}"
echo "Using XQUANT_PYTHON=${PYTHON_BIN}"

if [[ ! -f "${CONFIG_TEMPLATE}" ]]; then
  echo "Missing config template: ${CONFIG_TEMPLATE}" >&2
  exit 1
fi

if [[ "${XQUANT_MODE}" == "static" ]]; then
  sed \
    -e "s#@ONNX_MODEL@#${MODEL_PATH}#g" \
    -e "s#@WORKING_DIR@#${WORK_DIR}#g" \
    -e "s#@OUTPUT_PREFIX@#${OUTPUT_PREFIX}#g" \
    -e "s#@CALIB_LIST@#${CALIB_LIST}#g" \
    -e "s#@CALIBRATION_STEP@#${CALIB_COUNT}#g" \
    "${CONFIG_TEMPLATE}" > "${CONFIG_PATH}"
fi

"${PYTHON_BIN}" "${ROOT_DIR}/tools/inspect_onnx_graph.py" --model "${MODEL_PATH}" > "${WORK_DIR}/onnx_graph.txt"
if [[ "${XQUANT_MODE}" == "static" ]]; then
  "${PYTHON_BIN}" -m xquant --config "${CONFIG_PATH}"
else
  "${PYTHON_BIN}" -m xquant --input_path "${MODEL_PATH}" --output_path "${WORK_DIR}/${OUTPUT_PREFIX}.onnx"
fi
find "${WORK_DIR}" -maxdepth 2 -type f | sort
