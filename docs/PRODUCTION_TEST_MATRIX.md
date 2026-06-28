# Production Test Matrix

## Day 1 Full Regression

Run directory:

```text
/data/ncnn-logs/ort-logs/2026-06-28_16-43-04/
```

| Area | Case | Required result | Day 1 result |
| --- | --- | --- | --- |
| Build | `./scripts/build_cross.sh` | pass | pass |
| Deploy | `./scripts/deploy_to_banana.sh` | pass | pass |
| Loader | `app/bin/banana_yolo11_demo`, `bin/banana_yolo11_demo_rt201`, `bin/banana_yolo11_demo_rt123` | local repo runtime/OpenCV resolution | pass |
| Image | default generated dynamic640 INT8 on `rt201` | semantically reasonable | pass |
| Image | vendor320 trusted visual on `rt123` | semantically reasonable | pass |
| Image | vendor320 raw `rt201` perf path | forward-only/perf sanity | pass |
| Image | vendor320 `rt201` workaround | semantically reasonable and SHA256-guarded | pass |
| Image | FP16 keep_io 640 on `rt201` | experimental smoke | pass |
| Image | FP16 keep_io 640 on `rt202b1` | experimental smoke | pass |
| Camera | normal camera default | runs without crash | pass |
| Camera | fast-live | runs without crash | pass |
| Camera | forced headless normal | progress logs, no hang | pass |
| Camera | forced headless fast-live | progress logs, no hang | pass |
| Camera | still save normal | JPEG artifact created | pass |
| Camera | still save fast-live | JPEG artifact created | pass |
| Performance | vendor320/dynamic640/FP16 matrix | fresh Day 1 numbers captured | pass |
| Docs | Doxygen coverage/generation | `missing_at_file=0`, warnings checked | see Day 1 logs |
| Feasibility | YOLO26n 640 INT8 gate | candidate only unless all gates pass | not adopted; P2 |

## Required Release Gates

| Priority | Gate | Blocking condition |
| --- | --- | --- |
| P0 | Build/deploy | Any failure blocks release. |
| P0 | Loader | Any demo binary resolving system `/lib/libonnxruntime.so.1` blocks release. |
| P0 | Default image visual | Any crash or clearly wrong default output blocks release. |
| P0 | Normal camera | Any crash or undocumented manual edit blocks release. |
| P0 | Fast-live camera | Any crash or undocumented manual edit blocks release. |
| P1 | Documentation | Policy/result mismatch must be fixed before final release. |
| P1 | Doxygen | Missing coverage or warnings should be fixed unless explicitly accepted. |
| P2 | YOLO26n | Non-blocking unless separately approved for production evaluation. |

## Production Paths To Regress

| Path | Script/helper | Runtime policy |
| --- | --- | --- |
| Default image visual | `./scripts/run_image_demo.sh` | `dynamic640` INT8 on `rt201` |
| Normal camera | `./scripts/run_camera_demo.sh` | `dynamic640` INT8 on `rt201` |
| Fast-live camera | `./scripts/run_camera_demo_fast.sh` | vendor320 INT8 on `rt123` |
| Forward-only benchmark | `./scripts/bench_forward_only.sh` | explicit model/runtime per case |
| Full pipeline benchmark | `./scripts/bench_full_demo.sh` | explicit model/runtime per case |
| FP16 matrix | `./scripts/bench_fp16_matrix.sh` | experimental keep_io 640 |
