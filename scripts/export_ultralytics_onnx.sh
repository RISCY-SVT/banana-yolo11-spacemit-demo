#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIZE="${1:-640}"
MODEL_NAME="${2:-yolo11n.pt}"
OUT_DIR="${ROOT_DIR}/models/generated"
VENV_DIR="${ROOT_DIR}/.venv/ultralytics-export"
mkdir -p "${OUT_DIR}"

python3 -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"
python3 -m pip install --upgrade pip
python3 -m pip install "ultralytics==8.3.233" "onnx>=1.16,<1.19"

python3 - <<PY
from ultralytics import YOLO
model = YOLO("${MODEL_NAME}")
path = model.export(format="onnx", imgsz=${SIZE}, dynamic=False, simplify=False, opset=13)
print(path)
PY

find . -maxdepth 1 -type f -name "*.onnx" -print0 | while IFS= read -r -d '' file; do
  mv -f "${file}" "${OUT_DIR}/"
done
find "${OUT_DIR}" -maxdepth 1 -type f -name "*.onnx" -print | sort

