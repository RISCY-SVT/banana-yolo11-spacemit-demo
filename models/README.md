Model artifacts are intentionally not committed.

Use the repository scripts instead:

- `./scripts/fetch_models.sh` for the official vendor 320x320 path
- `./scripts/export_ultralytics_onnx.sh` for custom ONNX export
- `./scripts/quantize_xquant.sh` for custom INT8 conversion

Generated and fetched model files are ignored by git on purpose.
