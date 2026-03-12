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
- Verify `third_party/vendor/spacemit-ort.riscv64.2.0.1/include/spacemit_ort_env.h` exists.

## Cross build cannot find OpenCV

- Ensure `/data/opencv/install-k1x-gtk3/lib/cmake/opencv4/OpenCVConfig.cmake` exists.
- Rebuild the local K1X OpenCV install if needed.

## Camera open fails

- Run `./scripts/detect_camera_formats.sh /dev/video0`.
- Try `--camera-pixfmt mjpg` or `--camera-pixfmt yuyv`.
- Prefer MJPG if the camera supports it at higher FPS.

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
