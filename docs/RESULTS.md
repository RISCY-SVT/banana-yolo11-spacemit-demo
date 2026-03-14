# Results

This file is updated after board validation.

- Image demo
  - Required image: `/home/svt/ncnn-k1x-int8-smoke/models/photo_2024-10-11_10-04-04.jpg`
  - Vendor INT8 320x320 is now validated as a trustworthy visual path on runtime `rt123` (`spacemit-ort.riscv64.1.2.3`) with letterbox preprocessing.
  - Vendor INT8 320x320 remains the low-latency benchmark path on runtime `rt201` (`spacemit-ort.riscv64.2.0.1`).
  - The default visual demo path remains the custom dynamic INT8 640x640 path because it is still the best user-facing quality path.
  - A cleaner 640 sample was captured at `--conf 0.25`.

- Camera demo
  - Default camera auto-selection resolves the USB camera through `/dev/v4l/by-id/... -> /dev/video20`.
  - The default camera auto mode chooses MJPG for `1280x720` because it offers `60 FPS` on the connected USB camera, versus `7.5 FPS` for YUYV.
  - Headless live inference is stable.
  - Default camera runs no longer create AVI output unless explicitly requested.
  - Display mode requires a valid desktop session plus Wayland/Xwayland session variables.
  - A display probe reached the application branch `display active, press any key to exit`.

- Forward-only benchmark
  - Vendor320 perf stack (`rt201`) `onnxruntime_perf_test`:
    - `25.4561 ms`
    - `39.2748 FPS`
  - Vendor320 perf stack (`rt201`) application forward-only:
    - `25.821000 ms`
    - `38.728167 FPS`
  - Vendor320 visual stack (`rt123`) `onnxruntime_perf_test`:
    - `49.4587 ms`
    - `20.2038 FPS`
  - Vendor320 visual stack (`rt123`) application forward-only:
    - `50.248301 ms`
    - `19.901171 FPS`
  - Custom dynamic INT8 640x640 `onnxruntime_perf_test`:
    - `201.162 ms`
    - `4.97096 FPS`
  - Custom dynamic INT8 640x640 application forward-only:
    - `203.832438 ms`
    - `4.905990 FPS`

- Full pipeline benchmark
  - Application full pipeline includes preprocess + inference + postprocess.
  - Vendor320 visual stack (`rt123`) application full pipeline:
    - `60.926593 ms`
    - `16.413194 FPS`
  - Application full pipeline 640x640 dynamic INT8:
    - `241.812077 ms`
    - `4.135443 FPS`
  - A corrected vendor320 camera run on the real USB camera with default settings:
    - auto-selected `/dev/v4l/by-id/... -> /dev/video20`
    - auto-selected `MJPG`
    - produced `objects=0` at frame 10 and frame 20 on the captured white-wall scene
    - did not create any new AVI output unless explicitly requested

- Remediation notes
  - The decisive root-cause pass showed that vendor320 is runtime-version-sensitive on the public stack:
    - public vendor example + `1.2.2` = semantically good
    - public vendor example + `1.2.3` = semantically good
    - public vendor example + `2.0.1` = semantically poor
  - The repository now encodes that matrix explicitly instead of pretending one tarball is correct for every path:
    - vendor320 visual path -> `rt123`
    - vendor320 low-latency benchmark path -> `rt201`
    - dynamic640 path -> `rt201`
  - Demo defaults still use sane auto camera selection, sane auto MJPG selection, and no AVI recording unless explicitly requested.

- Quantization notes
  - Official vendor 640x640 INT8 YOLO11n model was not found in the pinned public archive.
  - Public xquant static calibration for 640x640 was attempted, but the tool still entered a `Runtime Calibration(BlockWise) ... /50` path despite a smaller requested calibration budget.
  - For this repository, the practical 640x640 fallback is `xquant` dynamic INT8.
