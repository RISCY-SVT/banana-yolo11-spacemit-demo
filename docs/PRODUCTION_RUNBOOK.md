# Production Runbook

## Environment

Always start from the canonical K1X container environment:

```bash
cd /data
source /data/build_scripts/01-env.sh
cd /data/banana-yolo11-spacemit-demo
```

Do not modify the base sysroot. Use the existing base plus overlay layout.

## Build And Deploy

```bash
./scripts/build_cross.sh
./scripts/deploy_to_banana.sh
```

After deployment, verify loader resolution on the board:

```bash
ssh "${BANANA_SSH_TARGET:-svt@banana}" \
  'cd ~/banana-yolo11-spacemit-demo && readelf -d app/bin/banana_yolo11_demo && ldd app/bin/banana_yolo11_demo'
```

The demo must resolve repo-local runtime/OpenCV libraries, not system
`/lib/libonnxruntime.so.1`.

## Image Demo

Default production visual path:

```bash
./scripts/run_image_demo.sh
```

This uses generated `dynamic640` INT8 on `rt201`.

Trusted vendor320 visual path:

```bash
BANANA_DEMO_RUNTIME_TAG=rt123 \
  ./scripts/run_image_demo.sh \
  /path/to/photo.jpg \
  models/vendor/yolo11/yolov11n_320x320.q.onnx \
  320
```

Host-wrapper local output can be requested with the positional `save_output`
argument:

```bash
./scripts/run_image_demo.sh /path/to/photo.jpg /path/to/model.onnx 640 0.25 0 1 /tmp/output.jpg
```

## Camera Demo

Normal camera:

```bash
./scripts/run_camera_demo.sh
```

Fast-live camera:

```bash
./scripts/run_camera_demo_fast.sh
```

Forced headless normal smoke:

```bash
HEADLESS_FLAG=1 DISPLAY_FLAG=0 MAX_FRAMES=20 ./scripts/run_camera_demo.sh
```

Forced headless fast-live smoke:

```bash
HEADLESS_FLAG=1 DISPLAY_FLAG=0 MAX_FRAMES=50 ./scripts/run_camera_demo_fast.sh
```

Save one camera still:

```bash
SAVE_OUTPUT=/home/svt/banana-yolo11-spacemit-demo/output_examples/camera.jpg \
MAX_FRAMES=1 \
./scripts/run_camera_demo.sh
```

Camera recording is off by default. Enable it only with the explicit recording
environment/settings documented by the script help.

## Benchmark Helpers

Forward-only:

```bash
./scripts/bench_forward_only.sh
```

Full image pipeline:

```bash
./scripts/bench_full_demo.sh
```

Day 1 added explicit benchmark sizing overrides:

```bash
BENCH_PERF_REPEATS=20 BENCH_WARMUP=3 BENCH_RUNS=10 BENCH_REPEATS=3 \
  ./scripts/bench_forward_only.sh /path/to/model.onnx 640 /path/to/photo.jpg
```

## FP16 Experimental Matrix

```bash
FP16_MODEL_VARIANT=keep_io ./scripts/bench_fp16_matrix.sh
```

Only keep_io FP16 `640x640` on `rt201`/`rt202b1` is currently useful as an
experimental board-side path.

## Issue Policy

- P0 blocks production.
- P1 must be resolved or explicitly accepted before final release.
- P2 is non-blocking post-release work.

YOLO26n remains P2 after Day 1: export and dynamic INT8 conversion are possible,
but current repo decode/quantized outputs are not semantically acceptable.
