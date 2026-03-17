Model artifacts are intentionally not committed.

Use the repository scripts instead:

- `./scripts/fetch_models.sh` for the official vendor 320x320 INT8 path
- `./scripts/export_ultralytics_onnx.sh` for custom FP32 ONNX export
- `./scripts/fetch_or_build_fp16_models.sh` for reproducible YOLO11n FP16 conversions
- `./scripts/quantize_xquant.sh` for custom INT8 conversion

Generated and fetched model files are ignored by git on purpose.

FP16 note:

- the repository now validates two generated FP16 model families:
  - `*.fp16.onnx` = true FP16 I/O
  - `*.fp16_iop32.onnx` = internal FP16 with FP32 I/O
- current public vendor runtimes only have partial coverage for those models
- see `docs/RESULTS.md` for the current runtime matrix and recommendations
