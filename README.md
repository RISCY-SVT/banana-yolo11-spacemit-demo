# banana-yolo11-spacemit-demo

Standalone C++ demo repository for Banana Pi BPI-F3 / SpacemiT K1X using the vendor-tested ONNX Runtime stack:

- validated vendor runtimes:
  - `spacemit-ort.riscv64.1.2.3` for trustworthy vendor320 visual inference
  - `spacemit-ort.riscv64.2.0.1` for vendor320 low-latency benchmarking and dynamic640
- closed execution providers:
  - `libspacemit_ep.so.1.2.3`
  - `libspacemit_ep.so.2.0.1`
- model family: Ultralytics YOLO11n
- primary optimized path: INT8 ONNX on SpaceMIT EP

The repository is designed to be usable by another engineer from scratch once the canonical K1X toolchain and sysroot overlay are already installed.

## Architecture

- Host build: Ubuntu 24.04 x86_64 cross-build container
- Target board: Banana Pi BPI-F3 / SpacemiT K1X
- Runtime matrix:
  - vendor320 visual path: `rt123` = `spacemit-ort.riscv64.1.2.3`
  - vendor320 perf path: `rt201` = `spacemit-ort.riscv64.2.0.1`
  - dynamic640 path: `rt201` = `spacemit-ort.riscv64.2.0.1`
- Benchmark model path:
  - official vendor YOLO11n INT8 320x320 ONNX
- Default visual demo path:
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

The validated runtime matrix is pinned in `third_party_manifest/runtime.lock`.
The fetch helper stages both public tarballs required by this repository:

- `rt123` -> `spacemit-ort.riscv64.1.2.3`
- `rt201` -> `spacemit-ort.riscv64.2.0.1`

## Models

Fetch vendor-provided YOLO11n 320x320 models:

```bash
./scripts/fetch_models.sh
```

Outputs land under `models/vendor/yolo11/`.

Notes:

- The official vendor INT8 320x320 model is restored as a trustworthy visual path in this repository, but only on the validated `rt123` stack (`spacemit-ort.riscv64.1.2.3`) with letterbox preprocessing.
- The same vendor320 model remains the low-latency benchmark path on `rt201` (`spacemit-ort.riscv64.2.0.1`).
- A focused EP/runtime pass on 2026-03-15 found a public `rt201` visual workaround for vendor320:
  - `SPACEMIT_EP_DISABLE_FLOAT16_EPILOGUE=1`
  - `SPACEMIT_EP_DISABLE_OP_NAME_FILTER=/model.23/Slice;/model.23/Slice_1;/model.23/Add_1;/model.23/Add_2;/model.23/Sub;/model.23/Sub_1`
  - this restores semantically good vendor320 detections on the canonical photo and on blank-white sanity input
  - it is much slower than `rt123`, so it is not the default visual policy
- The default visual demo path remains the generated 640x640 dynamic INT8 model, because it is the highest-quality user-facing path on the public stack.
- A focused 2026-03-14 root-cause pass showed:
  - the public vendor YOLO11 C++ example is semantically good on `1.2.2` and `1.2.3`
  - the same public example becomes semantically poor on `2.0.1`
  - our repository now mirrors that runtime split explicitly instead of pretending a single tarball version works for every model/path
- A follow-up clean-room runtime-line pass confirmed:
  - `rt201` (`2.0.1`) remains semantically bad for vendor320 even when `/dev/tcm` is clean and no `alloc failed(...)` appears
  - `rt202b1` (`2.0.2+beta1`) behaves like `rt201` for vendor320 and does not restore correct detections
  - public `1.2.4` package line is semantically good for vendor320, but still breaks the dynamic640 path
  - a chain-complete public compatibility pass then tested the official public example path with:
    - exact same `yolov11n_320x320.q.onnx` bundle
    - exact same canonical photo input hash
    - decode contracts `centerwh` and `xyxy`
    - graph optimization levels `0`, `1`, `2`, and `99`
  - result of that pass:
    - no public `2.0.x` combination restored a good vendor320 image result
    - `rt201`, tarball `rt202b1`, and package `pkg202fix` all remained bad on the same public `q.onnx` bundle
    - the public float `yolov11n_320x320.onnx` bundle also failed on `2.0.x` with EP-side reshape/compile errors instead of becoming a viable fallback
  - therefore the repository keeps the current policy:
    - vendor320 visual -> `rt123`
    - vendor320 perf -> `rt201`
    - dynamic640 -> `rt201`
  - a later EP/runtime-localization pass refined that conclusion:
    - `rt201` can be made visually correct only with the explicit public workaround above
    - the workaround is far slower than `rt123`, so `rt123` remains the default vendor320 visual runtime
    - `rt202b1` still remains bad even with the same workaround
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

The no-argument image demo uses the default visual path:

- model: `models/generated/xquant_640/yolov11n_640x640.dynamic_int8.onnx`
- input size: `640`
- confidence: `0.25`
- runtime tag: `rt201`

If you explicitly override the model to `models/vendor/yolo11/yolov11n_320x320.q.onnx`, the script auto-selects runtime `rt123` and restores the validated vendor320 visual path. If you explicitly force `BANANA_DEMO_RUNTIME_TAG=rt201`, the script now auto-enables the validated public workaround for visual correctness. Disable that workaround only when you intentionally want the raw low-latency perf path:

```bash
BANANA_DEMO_RUNTIME_TAG=rt201 BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=0 ./scripts/run_image_demo.sh /path/to/image.jpg models/vendor/yolo11/yolov11n_320x320.q.onnx 320
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
./scripts/detect_camera_formats.sh
./scripts/run_camera_demo.sh
```

Useful environment overrides:

```bash
DISPLAY_FLAG=1 CAMERA_PIXFMT=mjpg CONFIDENCE=0.25 ./scripts/run_camera_demo.sh /dev/video20
```

Runtime override:

```bash
BANANA_DEMO_RUNTIME_TAG=rt123 ./scripts/run_camera_demo.sh auto /home/svt/banana-yolo11-spacemit-demo/models/vendor/yolo11/yolov11n_320x320.q.onnx 320
```

By default the camera helper does not record video. Recording is opt-in:

```bash
SAVE_OUTPUT_REMOTE=/home/svt/banana-yolo11-spacemit-demo/outputs/camera_320.avi ./scripts/run_camera_demo.sh /dev/video20
```

Board-local direct execution after deploy:

```bash
cd /home/svt/banana-yolo11-spacemit-demo
BANANA_DEMO_EXEC_MODE=board DISPLAY_FLAG=1 ./scripts/run_camera_demo.sh
```

If you explicitly override the model to the vendor 320x320 INT8 ONNX, the script auto-selects `rt123`. If you explicitly force `BANANA_DEMO_RUNTIME_TAG=rt201`, the visual helpers now auto-enable the validated public workaround. Disable it with `BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=0` only when you intentionally want the raw low-latency perf stack.

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

Benchmark runtime policy:

- `bench_forward_only.sh` defaults to the low-latency `rt201` stack for vendor320 benchmarking
- `bench_full_demo.sh` defaults to the validated visual stack (`rt123` for vendor320, `rt201` otherwise)
- override either script with `BANANA_DEMO_RUNTIME_TAG=rt123|rt201` when you need a specific matrix entry
- only the visual helpers auto-enable the slower vendor320 `rt201` workaround; forward-only benchmarking keeps the raw perf stack unless you export the workaround variables yourself

## CLI highlights

The binary supports:

- `--model`
- `--labels`
- `--input-size 320|640`
- `--source image:<path>|camera:auto|camera:/dev/videoN|camera:<index>`
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

- Default visual demo model:
  - `models/generated/xquant_640/yolov11n_640x640.dynamic_int8.onnx`
- Default visual demo confidence:
  - `0.25`
- Vendor low-latency benchmark model:
  - `models/vendor/yolo11/yolov11n_320x320.q.onnx`
- Vendor320 trustworthy visual runtime:
  - `rt123` = `spacemit-ort.riscv64.1.2.3`
- Vendor320 low-latency benchmark runtime:
  - `rt201` = `spacemit-ort.riscv64.2.0.1`
- Vendor320 `rt201` visual workaround:
  - auto-enabled only for visual helpers when you explicitly force `BANANA_DEMO_RUNTIME_TAG=rt201`
  - disable with `BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=0`
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
  - use `rt123` for trustworthy vendor320 image/camera inference:
    - `BANANA_DEMO_RUNTIME_TAG=rt123`
  - if you explicitly force `rt201` in the visual helpers, the scripts now auto-enable the validated public workaround
  - disable that workaround only when you intentionally want the raw perf stack:
    - `BANANA_DEMO_RUNTIME_TAG=rt201 BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=0`
  - a clean-room recheck on 2026-03-14 showed that raw `rt201` remains wrong even without any `/dev/tcm` contention
  - `rt202b1` still does not fix vendor320 even with the same public workaround
  - public `1.2.4` is good for vendor320, but it still breaks dynamic640, so it is not the repo default
  - keep the default 640x640 dynamic INT8 path for the best user-facing visual quality
- Vendor runtime accidentally replaced by system ORT:
  - the run scripts force `LD_LIBRARY_PATH` to the staged vendor runtime before launching the app

## Licensing and vendor binaries

This repository does not vendor the SpacemiT runtime tarball. It is fetched by script and remains subject to the vendor's licensing terms.
