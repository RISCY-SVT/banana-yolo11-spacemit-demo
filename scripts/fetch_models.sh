#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${ROOT_DIR}/third_party_manifest/models.lock"
OUT_DIR="${ROOT_DIR}/models/vendor/yolo11"
mkdir -p "${OUT_DIR}"

fetch_file() {
  local key="$1"
  local output_name="$2"
  local url
  url="$(awk -F= -v k="${key}" '$1==k{print $2}' "${LOCK_FILE}")"
  if [[ -z "${url}" ]]; then
    echo "Missing URL for ${key}" >&2
    exit 1
  fi
  local dst="${OUT_DIR}/${output_name}"
  if [[ -f "${dst}" ]]; then
    echo "Exists: ${dst}"
  else
    curl -L --fail --output "${dst}" "${url}"
  fi
  sha256sum "${dst}"
}

fetch_file "vendor_yolo11_fp32_320_url" "yolov11n_320x320.onnx"
fetch_file "vendor_yolo11_int8_320_url" "yolov11n_320x320.q.onnx"
fetch_file "vendor_yolo11_xquant_config_url" "xquant_config_vendor_320.json"

cp -f "${ROOT_DIR}/assets/coco80.txt" "${OUT_DIR}/coco80.txt"
echo "Note: no official vendor 640x640 INT8 YOLO11n model URL is currently pinned in third_party_manifest/models.lock."
echo "Use scripts/export_ultralytics_onnx.sh + scripts/quantize_xquant.sh for the 640x640 custom path."
echo "Prepared vendor models in ${OUT_DIR}"
