# banana-yolo11-spacemit-demo

Standalone C++ demo repository for Banana Pi BPI-F3 / SpacemiT K1X using the vendor-tested ONNX Runtime stack:

- vendor host runtime: `spacemit-ort.riscv64.2.0.1`
- closed execution provider: `libspacemit_ep.so.2.0.1`
- model family: Ultralytics YOLO11n
- primary optimized path: INT8 ONNX on SpaceMIT EP

The repository is designed to be usable by another engineer from scratch once the canonical K1X toolchain and sysroot overlay are already installed.

## Architecture

- Host build: Ubuntu 24.04 x86_64 cross-build container
- Target board: Banana Pi BPI-F3 / SpacemiT K1X
- Runtime: vendor `spacemit-ort.riscv64.2.0.1` + `libspacemit_ep.so.2.0.1`
- Primary model path:
  - official vendor YOLO11n INT8 320x320 ONNX
- Secondary model path:
  - Ultralytics ONNX export
  - xquant-based INT8 conversion for custom sizes such as 640x640

The application supports:

- single-image inference
- USB camera live inference
- headless and display modes
- forward-only benchmarking
- full pipeline benchmarking
- annotated image/video output
- per-stage metrics logging

The repository is intentionally usable in two modes:

- host-wrapper mode from the x86_64 cross-build container
- board-local mode directly on Banana after deploy

## Project layout

- `src/`, `include/`: C++ application
- `cmake/`: cross toolchain and vendor runtime discovery
- `scripts/`: fetch/build/deploy/run helpers
- `configs/xquant/`: xquant templates
- `third_party_manifest/`: pinned runtime/model metadata
- `docs/`: results and troubleshooting
- `scripts/reference/build_scripts/`: imported local helper scripts

## External references used

- Vendor runtime docs: `https://bianbu.spacemit.com/en/ai/onnxruntime`
- Vendor C++ example docs: `https://bianbu.spacemit.com/en/brdk/Model_deployment/4.3_CPP_Inference_Example`
- Demo overview: `https://bianbu.spacemit.com/en/ai/spacemit-demo`
- Vendor runtime archive: `https://archive.spacemit.com/spacemit-ai/onnxruntime/`
- Ultralytics export docs: `https://docs.ultralytics.com/modes/export/`
- xquant docs: `https://bianbu.spacemit.com/en/brdk/Advanced_development/7.1_Model_Quantization`
- SpacemiT deployment pipeline docs: `https://bianbu.spacemit.com/en/brdk/Model_deployment/4.4_Training_and_Deployment_Pipeline`

## Toolchain prerequisites

This project expects the canonical local K1X environment:

- toolchain root: `/data/SpacemiT/spacemit-toolchain-linux-glibc-x86_64-v1.1.2`
- base sysroot: `${TOOLCHAIN_ROOT}/sysroot`
- overlay sysroot: `/data/sysroots/k1x-gtk3-overlay`

Source the environment first:

```bash
source /data/build_scripts/01-env.sh
```

## Sysroot overlay and local K1X helper scripts

Import the local helper scripts into this repository:

```bash
./scripts/import_local_k1x_scripts.sh
```

Refresh the overlay sysroot from the board:

```bash
./scripts/prepare_overlay_from_local.sh
```

## Vendor runtime

Fetch and stage the vendor runtime:

```bash
./scripts/fetch_vendor_runtime.sh
```

The version is pinned in `third_party_manifest/runtime.lock`.

## Models

Fetch vendor-provided YOLO11n 320x320 models:

```bash
./scripts/fetch_models.sh
```

Outputs land under `models/vendor/yolo11/`.

Notes:

- Official vendor INT8 320x320 is the default production path.
- No official 640x640 vendor INT8 URL is currently pinned, so 640 uses the custom export + xquant path.
- In practice, the fast and reproducible 640 path in this repository is the `xquant` dynamic INT8 fallback. Public static calibration was attempted but remained too slow for a practical demo workflow.

## Optional custom export and quantization

Export YOLO11n from Ultralytics:

```bash
./scripts/export_ultralytics_onnx.sh 640 yolo11n.pt
```

Quantize with xquant static calibration:

```bash
CALIB_COUNT=10 ./scripts/quantize_xquant.sh 640 /path/to/yolo11n_640x640.onnx yolov11n_640x640.q
```

Fast fallback dynamic quantization:

```bash
XQUANT_MODE=dynamic ./scripts/quantize_xquant.sh 640 /path/to/yolo11n_640x640.onnx yolov11n_640x640.dynamic_int8
```

If an existing working xquant environment is available, reuse it explicitly:

```bash
XQUANT_PYTHON=/data/ort-spacemit-track/quant/venv/bin/python3 \
CALIB_COUNT=10 \
./scripts/quantize_xquant.sh 640 /path/to/yolo11n_640x640.onnx yolov11n_640x640.q
```

## Cross-build

```bash
./scripts/build_cross.sh
```

The build helper now checks OpenCV explicitly through `./scripts/ensure_opencv.sh`.
This repository does not vendor OpenCV. It expects the canonical local cross install
at `/data/opencv/install-k1x-gtk3`, and deploy stages the matching runtime libraries
under the board-side repo root.

## Deploy to Banana

```bash
./scripts/deploy_to_banana.sh
```

## Run image demo

```bash
./scripts/run_image_demo.sh
```

The image helper accepts optional positional overrides:

```bash
./scripts/run_image_demo.sh <image> <model> <input_size> <conf>
```

Board-local direct execution after deploy:

```bash
cd /home/svt/banana-yolo11-spacemit-demo
BANANA_DEMO_EXEC_MODE=board ./scripts/run_image_demo.sh
```

## Run camera demo

```bash
./scripts/detect_camera_formats.sh /dev/video0
./scripts/run_camera_demo.sh /dev/video0
```

Useful environment overrides:

```bash
DISPLAY_FLAG=1 CAMERA_PIXFMT=mjpg CONFIDENCE=0.05 ./scripts/run_camera_demo.sh /dev/video20
```

By default the camera helper does not record video. Recording is opt-in:

```bash
SAVE_OUTPUT_REMOTE=/home/svt/banana-yolo11-spacemit-demo/outputs/camera_320.avi ./scripts/run_camera_demo.sh /dev/video20
```

Board-local direct execution after deploy:

```bash
cd /home/svt/banana-yolo11-spacemit-demo
BANANA_DEMO_EXEC_MODE=board DISPLAY_FLAG=1 ./scripts/run_camera_demo.sh /dev/video20
```

## Benchmark

Forward-only:

```bash
./scripts/bench_forward_only.sh
```

Full pipeline:

```bash
./scripts/bench_full_demo.sh
```

The forward-only benchmark compares the application against vendor `onnxruntime_perf_test`, because vendor CV tables exclude preprocess and postprocess.

## CLI highlights

The binary supports:

- `--model`
- `--labels`
- `--input-size 320|640`
- `--source image:<path>|camera:/dev/video0`
- `--provider spacemit|cpu`
- `--pin cluster0|cluster1|none|list:<csv>`
- `--threads`
- `--conf`, `--iou`
- `--display`, `--headless`
- `--save-output`
- `--log-file`
- `--benchmark-only`
- `--benchmark-mode forward|full`
- `--camera-width`, `--camera-height`, `--camera-fps`, `--camera-pixfmt`
- `--decode-mode auto|vendor|ultralytics`
- `--warmup`, `--runs`, `--repeats`

## Known-good defaults

- 320x320 production model:
  - `models/vendor/yolo11/yolov11n_320x320.q.onnx`
- validated demo confidence for this vendor 320x320 path:
  - `0.05`
- Board app root after deploy:
  - `/home/svt/banana-yolo11-spacemit-demo`
- Required photo for reproducible image tests:
  - `/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg`
- USB camera:
  - prefer MJPG if available

## Troubleshooting

- Display over SSH:
  - if a desktop session is active, the run scripts auto-detect Wayland and Xwayland session hints:
    - `XDG_RUNTIME_DIR=/run/user/<uid>`
    - `WAYLAND_DISPLAY=wayland-0` when present
    - `/run/user/<uid>/.mutter-Xwaylandauth.*` plus `DISPLAY=:0`
  - if GUI still fails, fall back to `--display 0 --headless 1`
- Vendor 320x320 detections look wrong or disappear:
  - use `--preprocess-mode resize` for the official vendor model
  - keep the validated default `--conf 0.05`
  - `--conf 0.01` is a debug threshold and is no longer the recommended demo default
- Vendor runtime accidentally replaced by system ORT:
  - the run scripts force `LD_LIBRARY_PATH` to the staged vendor runtime before launching the app

## Licensing and vendor binaries

This repository does not vendor the SpacemiT runtime tarball. It is fetched by script and remains subject to the vendor's licensing terms.
