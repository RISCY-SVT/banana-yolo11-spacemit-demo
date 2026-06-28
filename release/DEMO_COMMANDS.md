# Demo Commands

Run commands from the repository root on the Banana board unless noted.

## Default Image Demo

```bash
./scripts/run_image_demo.sh
```

Uses generated dynamic640 INT8 on `rt201`.

## Normal Camera Demo

```bash
./scripts/run_camera_demo.sh
```

Uses generated dynamic640 INT8 on `rt201`. Display mode is auto-detected; if no
GUI is available, the script switches to headless mode and logs progress.

## Fast-Live Camera Demo

```bash
./scripts/run_camera_demo_fast.sh
```

Uses trusted vendor320 INT8 on `rt123` with 320 letterbox preprocessing and a
camera request optimized for responsiveness.

## Headless Smoke

```bash
HEADLESS_FLAG=1 DISPLAY_FLAG=0 MAX_FRAMES=30 ./scripts/run_camera_demo.sh
```

## Vendor320 Trusted Visual

```bash
BANANA_DEMO_RUNTIME_TAG=rt123 \
  ./scripts/run_image_demo.sh \
  models/vendor/yolo11/yolov11n_320x320.q.onnx 320 0.25
```

## Vendor320 Perf-Only

```bash
BANANA_DEMO_RUNTIME_TAG=rt201 \
  ./scripts/bench_forward_only.sh \
  models/vendor/yolo11/yolov11n_320x320.q.onnx 320
```

## FP16 Experimental

```bash
FP16_RUNTIME_TAGS=rt201,rt202b1 FP16_MODEL_VARIANT=keep_io \
  ./scripts/bench_fp16_matrix.sh
```
