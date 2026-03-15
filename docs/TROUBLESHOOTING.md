# Troubleshooting

## Display does not open

- Ensure GTK/OpenCV runtime is available on the board.
- The board-local image/camera helpers now default to `DISPLAY_FLAG=auto`.
  - if `DISPLAY` / `WAYLAND_DISPLAY` is already exported, they keep it
  - if the shell is a tty but Wayland/X11 sockets are present, they try to reconstruct the local GUI env automatically
  - if that still fails, the app prints an explicit fallback warning and continues headless with periodic progress logs
- If running over SSH without an active desktop session, force headless with `DISPLAY_FLAG=0`.
- If a desktop session is active, you can still force the path explicitly with `DISPLAY_FLAG=1`.
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
- Board-local `./scripts/run_camera_demo.sh` now defaults to:
  - `DISPLAY_FLAG=auto`
  - `HEADLESS_FLAG=auto`
  - `MAX_FRAMES=0`
- Host-wrapper `./scripts/run_camera_demo.sh` keeps:
  - `DISPLAY_FLAG=0`
  - `HEADLESS_FLAG=auto`
  - `MAX_FRAMES=200`
- If the helper appears idle, check the early progress lines:
  - `first frame captured; starting inference now`
  - `frame=...`
  Those are now emitted before waiting for 10 frames, so a slow first inference no longer looks like a hang.

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
  - `1.2.4`: semantically good vendor320 package line, but still bad for dynamic640
  - `2.0.1`: fast vendor320 benchmark path, but not the trusted visual choice
  - `2.0.2+beta1`: same bad vendor320 output family as `2.0.1`
- A later EP/runtime pass found one public `rt201` visual workaround:
  - `SPACEMIT_EP_DISABLE_FLOAT16_EPILOGUE=1`
  - `SPACEMIT_EP_DISABLE_OP_NAME_FILTER=/model.23/Slice;/model.23/Slice_1;/model.23/Add_1;/model.23/Add_2;/model.23/Sub;/model.23/Sub_1`
  - the visual helper scripts auto-apply that workaround when you explicitly force `BANANA_DEMO_RUNTIME_TAG=rt201`
  - the helper now refuses to auto-apply it to an unvalidated 320 model bundle; it is guarded by the official vendor320 model SHA256
  - disable it only when you intentionally want the raw perf path:

```bash
BANANA_DEMO_RUNTIME_TAG=rt201 BANANA_DEMO_VENDOR320_RT201_VISUAL_FIX=0 ./scripts/run_image_demo.sh /path/to/image.jpg models/vendor/yolo11/yolov11n_320x320.q.onnx 320 0.25
```

  - this workaround is much slower than `rt123`, so `rt123` remains the default visual runtime
- If a run shows `alloc failed(...)`, do not use it as evidence for vendor320 correctness.
- A clean-room retest with `/dev/tcm` idle and no `alloc failed(...)` still showed:
  - `rt201` bad for vendor320
  - `rt202b1` bad for vendor320
- A later full-chain public compatibility pass also ruled out the remaining obvious rescue paths on modern 2.0.x:
  - both public decode interpretations (`centerwh` and `xyxy`) were tested on the same raw output family
  - graph optimization levels `0`, `1`, `2`, and `99` were tested on `rt201`, tarball `rt202b1`, and package `pkg202fix`
  - none of those combinations restored a semantically good vendor320 result
  - the public float `yolov11n_320x320.onnx` bundle failed EP reshape/compile on modern 2.0.x instead of becoming a valid fallback
  - a final EP/runtime-localization pass then narrowed the modern 2.0.x behavior further:
    - `rt201` optimized models from `o0/o1/o2/o99` all stayed semantically good when replayed on stable `rt123` CPU
    - so the public 2.0.x host graph rewrite is not the vendor320 corruption point
    - the remaining corruption is in EP execution, specifically the `/model.23` tail on public `rt201`
    - `rt202b1` still remained bad even with the same public workaround that repaired `rt201`
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

## Compact runtime regression check

- Run:

```bash
./scripts/vendor320_runtime_matrix.sh
```

- The helper saves:
  - `rt123`
  - `rt201 raw`
  - `rt201 fixed`
  together with annotated outputs and a compact CSV/Markdown summary.

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
