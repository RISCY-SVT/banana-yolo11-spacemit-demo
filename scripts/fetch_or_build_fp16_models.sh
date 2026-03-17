#!/usr/bin/env bash
## @file fetch_or_build_fp16_models.sh
## @brief Prepare reproducible YOLO11n FP16 ONNX models for 320 and 640 tests.
## @details The helper prefers already-present public float32 ONNX sources,
## converts them deterministically to float16, and prints a compact provenance
## summary (shape, dtype, size, sha256) for each produced model.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/models/generated/fp16"
VENV_DIR="${ROOT_DIR}/.venv/fp16-tools"
IO_MODE="${FP16_IO_MODE:-all}"
SOURCE_320="${FP16_SOURCE_320:-${ROOT_DIR}/models/vendor/yolo11/yolov11n_320x320.onnx}"
SOURCE_640="${FP16_SOURCE_640:-${ROOT_DIR}/models/generated/yolo11n.onnx}"

## @brief Print CLI usage for the FP16 model helper.
usage() {
  cat <<'EOF'
Usage:
  fetch_or_build_fp16_models.sh

Environment overrides:
  FP16_IO_MODE=all|full|keep_io
  FP16_SOURCE_320=<path>
  FP16_SOURCE_640=<path>

Outputs:
  models/generated/fp16/yolov11n_320x320.fp16*.onnx
  models/generated/fp16/yolov11n_640x640.fp16*.onnx
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

## @brief Ensure one fixed-size float32 source model exists before conversion.
ensure_source_model() {
  local size="$1"
  local source_path="$2"
  if [[ -f "${source_path}" ]]; then
    return 0
  fi
  if [[ "${size}" == "640" ]]; then
    (cd "${ROOT_DIR}" && ./scripts/export_ultralytics_onnx.sh 640 yolo11n.pt)
    [[ -f "${source_path}" ]] && return 0
  fi
  echo "ERROR: missing float32 source model for size=${size}: ${source_path}" >&2
  return 2
}

## @brief Convert one float32 ONNX model to float16 and print its provenance.
convert_one_model() {
  local source_path="$1"
  local target_path="$2"
  local keep_io_flag="$3"
  "${VENV_DIR}/bin/python" - "$source_path" "$target_path" "$keep_io_flag" <<'PY'
import hashlib
import os
import sys

import onnx
from onnx import TensorProto
from onnxconverter_common import float16

src, dst, keep_io_flag = sys.argv[1:4]
keep_io = keep_io_flag == "1"

_orig_fromstring = float16.np.fromstring


def _compat_fromstring(data, dtype=float, count=-1, sep="", *, like=None):
    """Restore NumPy binary fromstring behavior removed in Python 3.12."""
    if isinstance(data, (bytes, bytearray, memoryview)) and sep == "":
        return float16.np.frombuffer(data, dtype=dtype, count=count)
    return _orig_fromstring(data, dtype=dtype, count=count, sep=sep, like=like)


float16.np.fromstring = _compat_fromstring


def _compat_convert_tensor_float_to_float16(tensor, min_positive_val=1e-7, max_finite_val=1e4):
    """Port the upstream converter helper to Python 3.12-safe NumPy APIs."""
    if not isinstance(tensor, float16.onnx_proto.TensorProto):
        raise ValueError(f"Expected ONNX TensorProto, got {type(tensor)}")
    if tensor.data_type == float16.onnx_proto.TensorProto.FLOAT:
        tensor.data_type = float16.onnx_proto.TensorProto.FLOAT16
        if tensor.float_data:
            float16_data = float16.convert_np_to_float16(
                float16.np.array(tensor.float_data), min_positive_val, max_finite_val
            )
            tensor.int32_data[:] = float16._npfloat16_to_int(float16_data)
            tensor.float_data[:] = []
        if tensor.raw_data:
            float32_list = float16.np.frombuffer(tensor.raw_data, dtype=float16.np.float32)
            float16_list = float16.convert_np_to_float16(
                float32_list, min_positive_val, max_finite_val
            )
            tensor.raw_data = float16_list.tobytes()
    return tensor


float16.convert_tensor_float_to_float16 = _compat_convert_tensor_float_to_float16

model = onnx.load(src)
converted = float16.convert_float_to_float16(model, keep_io_types=keep_io)
onnx.save(converted, dst)

graph = converted.graph
input0 = graph.input[0]
output0 = graph.output[0]
input_dims = [d.dim_value if d.dim_value else d.dim_param for d in input0.type.tensor_type.shape.dim]
output_dims = [d.dim_value if d.dim_value else d.dim_param for d in output0.type.tensor_type.shape.dim]

initializer_types = {}
for init in graph.initializer:
    initializer_types[TensorProto.DataType.Name(init.data_type)] = initializer_types.get(TensorProto.DataType.Name(init.data_type), 0) + 1

value_info_types = {}
for value in list(graph.value_info) + list(graph.output):
    tensor_type = value.type.tensor_type
    if tensor_type.elem_type:
        name = TensorProto.DataType.Name(tensor_type.elem_type)
        value_info_types[name] = value_info_types.get(name, 0) + 1

with open(dst, "rb") as f:
    digest = hashlib.sha256(f.read()).hexdigest()

print(f"model={dst}")
print(f"source={src}")
print(f"keep_io_types={int(keep_io)}")
print(f"input_dtype={TensorProto.DataType.Name(input0.type.tensor_type.elem_type)}")
print(f"input_shape={input_dims}")
print(f"output0_dtype={TensorProto.DataType.Name(output0.type.tensor_type.elem_type)}")
print(f"output0_shape={output_dims}")
print(f"initializer_dtype_counts={initializer_types}")
print(f"value_info_dtype_counts={value_info_types}")
print(f"size_bytes={os.path.getsize(dst)}")
print(f"sha256={digest}")
PY
}

mkdir -p "${OUT_DIR}"
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/pip" install --upgrade pip >/dev/null
"${VENV_DIR}/bin/pip" install "onnx>=1.16,<1.19" "onnxconverter-common>=1.14,<1.15" >/dev/null

ensure_source_model 320 "${SOURCE_320}"
ensure_source_model 640 "${SOURCE_640}"

emit_variant() {
  local suffix="$1"
  local keep_io_flag="$2"
  convert_one_model "${SOURCE_320}" "${OUT_DIR}/yolov11n_320x320${suffix}" "${keep_io_flag}"
  echo "---"
  convert_one_model "${SOURCE_640}" "${OUT_DIR}/yolov11n_640x640${suffix}" "${keep_io_flag}"
}

case "${IO_MODE}" in
  all)
    emit_variant ".fp16.onnx" 0
    echo "---"
    emit_variant ".fp16_iop32.onnx" 1
    ;;
  full)
    emit_variant ".fp16.onnx" 0
    ;;
  keep_io)
    emit_variant ".fp16_iop32.onnx" 1
    ;;
  *)
    echo "ERROR: unsupported FP16_IO_MODE=${IO_MODE}; use all|full|keep_io" >&2
    exit 2
    ;;
esac
