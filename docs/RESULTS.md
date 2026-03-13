# Results

This file is updated after board validation.

- Image demo
  - Required image: `/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg`
  - Vendor INT8 320x320 path is validated on board with `preprocess=resize`.
  - The required photo produces a stable person detection at the recommended `--conf 0.05`.
  - A synthetic white-wall input is clean at `--conf 0.05` and above.
  - Custom dynamic INT8 640x640 path also works on board.
  - A cleaner 640 sample was captured at `--conf 0.25`.

- Camera demo
  - USB camera `/dev/video20` works in MJPG mode.
  - Headless live inference is stable.
  - Default camera runs no longer create AVI output unless explicitly requested.
  - Display mode requires a valid desktop session plus Wayland/Xwayland session variables.
  - A display probe reached the application branch `display active, press any key to exit`.

- Forward-only benchmark
  - Vendor `onnxruntime_perf_test` 320x320 INT8:
    - `25.1677 ms`
    - `39.7235 FPS`
  - Application forward-only 320x320 INT8:
    - `25.805506 ms`
    - `38.751420 FPS`
  - Application forward-only 320x320 INT8 rerun:
    - `25.926897 ms`
    - `38.569984 FPS`
  - Custom dynamic INT8 640x640 `onnxruntime_perf_test`:
    - `201.07 ms`
    - `4.97323 FPS`
  - Custom dynamic INT8 640x640 application forward-only:
    - `200.732224 ms`
    - `4.981761 FPS`

- Full pipeline benchmark
  - Application full pipeline includes preprocess + inference + postprocess.
  - Application full pipeline 320x320 INT8:
    - `34.473185 ms`
    - `29.008054 FPS`
  - Application full pipeline 640x640 dynamic INT8:
    - `244.256647 ms`
    - `4.094054 FPS`
  - Camera runs around `20-22 FPS` per frame on the inference loop at 320x320, with lower end-to-end FPS once capture and AVI writing are included.
  - A 60-frame MJPG headless camera run completed at:
    - per-frame total around `44-56 ms`
    - end-to-end loop `7.486739 FPS`

- Remediation notes
  - The original vendor 320x320 path was only performance-validated. A remediation pass fixed the decode path and the deployed defaults.
  - The repository now treats `0.05` as the recommended vendor 320x320 demo confidence.
  - `0.01` remains available for debugging but is intentionally no longer the default.

- Quantization notes
  - Official vendor 640x640 INT8 YOLO11n model was not found in the pinned public archive.
  - Public xquant static calibration for 640x640 was attempted, but the tool still entered a `Runtime Calibration(BlockWise) ... /50` path despite a smaller requested calibration budget.
  - For this repository, the practical 640x640 fallback is `xquant` dynamic INT8.
