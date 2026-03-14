# Troubleshooting

## Display does not open

- Ensure GTK/OpenCV runtime is available on the board.
- If running over SSH without an active desktop session, use `--display 0 --headless 1`.
- If a desktop session is active, try `DISPLAY=:0`.
- On GNOME Wayland, also export the Xwayland auth file, for example:

```bash
export DISPLAY=:0
export XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.ACWRK3
```

## Vendor runtime not found

- Run `./scripts/fetch_vendor_runtime.sh`.
- Verify both validated runtime trees exist:
  - `third_party/vendor/spacemit-ort.riscv64.1.2.3/include/spacemit_ort_env.h`
  - `third_party/vendor/spacemit-ort.riscv64.2.0.1/include/spacemit_ort_env.h`

## Cross build cannot find OpenCV

- Run `./scripts/ensure_opencv.sh` first.
- Ensure `/data/opencv/install-k1x-gtk3/lib/cmake/opencv4/OpenCVConfig.cmake` exists.
- Rebuild the local K1X OpenCV install if needed.
- The repository stages matching OpenCV runtime libraries under the deployed board repo, so do not rely on an accidental system OpenCV match.

## Camera open fails

- Run `./scripts/detect_camera_formats.sh` first and use the reported resolved capture node if needed.
- Try `--camera-pixfmt mjpg` or `--camera-pixfmt yuyv`.
- Prefer MJPG if the camera supports it at higher FPS.

## Vendor 320x320 detections are missing or look suspicious

- Use runtime `rt123` for trustworthy vendor320 image/camera inference:

```bash
BANANA_DEMO_RUNTIME_TAG=rt123 ./scripts/run_image_demo.sh /path/to/image.jpg models/vendor/yolo11/yolov11n_320x320.q.onnx 320 0.25
```

- Use runtime `rt201` only when you explicitly want the low-latency benchmark path:

```bash
BANANA_DEMO_RUNTIME_TAG=rt201 ./scripts/bench_forward_only.sh models/vendor/yolo11/yolov11n_320x320.q.onnx 320
```

- Do not assume that raising or lowering the threshold alone will fix vendor320 on the wrong runtime.
- The validated public runtime split is:
  - `1.2.2` / `1.2.3`: semantically good vendor320 references
  - `2.0.1`: fast vendor320 benchmark path, but not the trusted visual choice
- Use `--conf 0.01` only for debugging or score-distribution inspection.
- If you need to inspect decode behavior, set:

```bash
BANANA_DEMO_DEBUG_DECODE=1
```

- If you want to reproduce the tarball-vs-system distinction, compare:

```bash
BANANA_DEMO_RUNTIME_TAG=rt201 ./scripts/bench_forward_only.sh models/vendor/yolo11/yolov11n_320x320.q.onnx 320
```

against:

```bash
BANANA_DEMO_RUNTIME_TAG=rt123 ./scripts/run_image_demo.sh /path/to/photo.jpg models/vendor/yolo11/yolov11n_320x320.q.onnx 320 0.25
```

## xquant is slow or pulls a huge dependency chain

- Prefer reusing an existing working xquant environment:

```bash
XQUANT_PYTHON=/data/ort-spacemit-track/quant/venv/bin/python3 ./scripts/quantize_xquant.sh 640 /path/to/model.onnx demo_640
```

- Use a smaller practical calibration count for demo iteration:

```bash
CALIB_COUNT=10 ./scripts/quantize_xquant.sh 640 /path/to/model.onnx demo_640
```

- If full static calibration is too slow, use the documented dynamic fallback:

```bash
XQUANT_MODE=dynamic ./scripts/quantize_xquant.sh 640 /path/to/model.onnx demo_640_dynamic
```
