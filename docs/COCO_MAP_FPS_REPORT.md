# Final Production Report: Banana YOLO11 SpacemiT Demo

## Executive Summary

The frozen production YOLO11 demo for Banana-Pi BPI-F3 / SpacemiT K1X remains release-ready. This pass adds official COCO val2017 mAP evidence and fresh stable FPS measurements without changing the runtime/model policy or the production tag. The primary production visual path is generated dynamic640 INT8 on `rt201` with full COCO AP@[.50:.95] = **0.384006** over 5000 images. The trusted vendor320 `rt123` visual path remains lower-resolution and faster, with AP@[.50:.95] = **0.211281**. The non-default vendor320 `rt201` visual workaround was also evaluated and remains available, not default.

## Hardware and Software Environment

- Board: Banana-Pi BPI-F3 with SpacemiT X60 / K1X, 8 RISC-V cores.
- Board kernel observed in this pass: `Linux bf3 6.6.63 #2.2.7.2`.
- CPU governor during validation: `performance`, observed 1600 MHz.
- Toolchain: `/data/SpacemiT/spacemit-toolchain-linux-glibc-x86_64-v1.1.2` with `-march=rv64gcv_zvfh -mabi=lp64d`.
- Host repo: `/data/banana-yolo11-spacemit-demo`.
- Validation run root: `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19`.

## Production Runtime/Model Policy

| Path | Runtime | Model | Status |
|---|---|---|---|
| Primary image visual | `rt201` | generated dynamic640 INT8 | default production visual |
| Normal camera | `rt201` | generated dynamic640 INT8 | default camera path |
| Fast-live camera | `rt123` | official vendor320 INT8, 320 letterbox | production fast-live path |
| Vendor320 trusted visual | `rt123` | official vendor320 INT8 | trusted visual path |
| Vendor320 low-latency perf | raw `rt201` | official vendor320 INT8 | perf-only, not visual default |
| Vendor320 `rt201` workaround | `rt201` | official vendor320 INT8 + SHA256-guarded EP workaround | available, non-default |
| FP16 | `rt201`/`rt202b1` | keep_io 640 | experimental only |
| Stable `rt202` | `rt202` | current paths | evaluated earlier, not adopted |
| YOLO26n | N/A | R&D only | P2, not production |

## Architecture

![Board-side COCO validation stack](assets/coco_architecture_diagram.svg)

The application uses OpenCV for media input and rendering, ONNX Runtime with the SpaceMIT Execution Provider for inference, and repository-owned preprocessing/decode logic. The COCO evaluation tool added in this pass is separate from default demo execution and reuses the same detector class.

## Dataset and Evaluation Methodology

Full COCO mAP means official COCO val2017 metric from 5000 images. Visual sanity means selected image inspection, not a statistical accuracy metric. Semantic sanity means expected plausible classes on known images, not mAP. Private canonical reference means engineering regression image only, not public benchmark.

- Dataset: COCO 2017 validation, 5000 images.
- Annotation: `/data/datasets/coco2017/annotations/instances_val2017.json`, SHA256 `e8c7f7908f1d7278341fae127d0da654f102f11bd7b21d8aeefa635b8c810b6f`.
- Prediction generation: board-side SpaceMIT runtime stack, not host PyTorch/ONNX approximation.
- Confidence for prediction export: `0.001`.
- Prediction cap: 300 detections per image.
- COCOeval: pycocotools, bbox metrics, standard maxDets `[1,10,100]`.
- Category IDs: derived from annotation category names matched to `assets/coco80.txt`.

## Full COCO mAP Results

|Candidate|Runtime|Status|Images|Detections|AP@[.50:.95]|AP50|AP75|AP_small|AP_medium|AP_large|AR1|AR10|AR100|
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|Primary dynamic640 INT8|rt201|production primary|5000|691410|0.384006|0.539212|0.419599|0.191668|0.420989|0.556876|0.307861|0.505896|0.556047|
|Vendor320 trusted visual|rt123|fast-live / trusted visual|5000|330235|0.211281|0.333139|0.225284|0.037406|0.204024|0.413734|0.209826|0.340494|0.369700|
|Vendor320 rt201 visual workaround|rt201|non-default workaround|5000|514015|0.216324|0.337841|0.234206|0.042726|0.218581|0.400563|0.212091|0.336105|0.364450|

![COCO mAP chart](assets/coco_map_bar.png)

## Stable FPS and Latency Results

Metric classes are not interchangeable. `perf_test forward` is a pure ORT inference ceiling. `app forward-only` uses the app harness with cached input. `app full image` includes preprocess, inference, and postprocess. `camera effective` is wall-clock loop FPS. `camera instantaneous` is one-frame total timing.

|Category|Variant|Runtime|Metric class|Resolution|Mean ms|Std ms|FPS|Status|
|---|---|---|---|---|---:|---:|---:|---|
|production primary|dynamic640 INT8|rt201|perf_test forward|640|187.507000|N/A|5.332970|production primary|
|production primary|dynamic640 INT8|rt201|app forward-only|640|188.257498|0.071248|5.311873|production primary|
|production primary|dynamic640 INT8|rt201|app full image|640|229.651583|0.568951|4.354422|production primary|
|camera|normal camera dynamic640 INT8|rt201|camera effective|1280x720 capture, 640 inference|N/A|N/A|2.400594|production normal camera|
|camera|normal camera dynamic640 INT8|rt201|camera instantaneous|1280x720 capture, 640 inference|239.763000|N/A|4.171000|production normal camera|
|fast-live|vendor320 INT8|rt123|camera effective|640x480 capture, 320 inference|N/A|N/A|10.508203|production fast-live|
|fast-live|vendor320 INT8|rt123|camera instantaneous|640x480 capture, 320 inference|66.492000|N/A|15.039000|production fast-live|
|trusted visual|vendor320 INT8|rt123|perf_test forward|320|48.069200|N/A|20.787800|trusted visual / fast-live|
|trusted visual|vendor320 INT8|rt123|app forward-only|320|48.617629|0.013438|20.568671|trusted visual / fast-live|
|trusted visual|vendor320 INT8|rt123|app full image|320|56.815375|0.106610|17.600870|trusted visual / fast-live|
|perf-only|vendor320 raw INT8|rt201|perf_test forward|320|24.372600|N/A|41.020200|low-latency perf only, not visual default|
|perf-only|vendor320 raw INT8|rt201|app forward-only|320|24.872159|0.019449|40.205597|low-latency perf only, not visual default|
|workaround|vendor320 INT8 visual workaround|rt201|app full image|320|33.007326|0.043991|30.296304|non-default workaround|
|experimental|FP16 keep_io 640|rt201/rt202b1|app forward-only|640|see prior FPS summary|N/A|see prior FPS summary|experimental only|
|rejected|stable rt202|rt202|fail/rejected|N/A|N/A|N/A|N/A|not adopted|
|rejected|YOLO26n|N/A|fail/rejected|640|N/A|N/A|N/A|not production|

![FPS chart](assets/fps_metric_class_bar.png)

![Camera FPS chart](assets/camera_fps_bar.png)

## Visual / Correctness / Accuracy Evidence

The release now includes full COCO mAP for the required visual candidates plus visual sanity outputs. No mAP claim is made for FP16 experimental paths, stable `rt202`, or YOLO26n. Selected public COCO output examples are included under `release/assets/coco_sample_primary_*.jpg`. The private canonical image remains a regression reference only.

Representative public examples:

![COCO sample 000000000139](assets/coco_sample_primary_000000000139.jpg)
![COCO sample 000000001000](assets/coco_sample_primary_000000001000.jpg)
![COCO sample 000000005037](assets/coco_sample_primary_000000005037.jpg)

## Camera Demo Behavior

Normal camera default uses generated dynamic640 INT8 on `rt201`. In this pass it processed 30 headless frames through the stable `/dev/v4l/by-id/...video-index0` path, with effective FPS **2.400594** and frame-30 instantaneous FPS **4.171**. Fast-live uses vendor320 INT8 on `rt123`, 320 letterbox, processed 60 frames, with effective FPS **10.508203** and frame-60 instantaneous FPS **15.039**.

## Fast-live Mode

Fast-live remains the recommended mode when responsiveness matters more than 640-resolution visual detail. It preserves the trusted vendor320 `rt123` visual stack and does not switch to raw `rt201` perf behavior.

## Deployment and Reproducibility Evidence

- Current validation source HEAD before this report commit: `1dfb734a83f9740eee1dda36b9541478e2ee6d5a`.
- Production tag target remained `9c0933be58ee122389d1a43f45f81e80655d6904`.
- GitHub source: `git@github.com:RISCY-SVT/banana-yolo11-spacemit-demo.git`.
- GitLab mirror: `git@gitlab.itglobal.com:riscy/sw/banana-yolo11-spacemit-demo.git`.
- Drive mirror status from closeout: verified-quick-by-operator.
- Board dataset path: `/home/svt/datasets/coco2017/val2017`.
- Raw COCO predictions and COCOeval JSON are stored in the run root, not in git.

## Known Limitations

- COCO mAP was measured for production visual candidates only; FP16 remains experimental.
- Vendor320 raw `rt201` remains perf-only and is not a visual default.
- Stable `rt202` was evaluated earlier and not adopted.
- YOLO26n remains a separate P2 R&D line, not production.
- Camera FPS depends on camera backend, pixel format, display/headless mode, and live-loop conditions.

## Rejected / Experimental Paths

| Path | Status | Reason |
|---|---|---|
| Stable `rt202` | not adopted | earlier current-path aborts/regressions |
| YOLO26n | P2 R&D only | not production policy |
| FP16 640 keep_io | experimental | usable coverage, not production default |
| FP16 320 keep_io | unsupported | known fail/caveat |
| Vendor320 raw `rt201` visual | not default | perf-only unless workaround enabled |

## Reproduction Commands

```bash
./scripts/fetch_vendor_runtime.sh
./scripts/fetch_models.sh
./scripts/build_cross.sh
./scripts/deploy_to_banana.sh
./scripts/run_image_demo.sh
./scripts/run_camera_demo.sh
./scripts/run_camera_demo_fast.sh
HEADLESS_FLAG=1 ./scripts/run_camera_demo.sh
./scripts/bench_forward_only.sh
./scripts/bench_full_demo.sh
```

COCO evaluation-only flow:

```bash
python3 tools/coco_eval/prepare_and_eval_coco.py prepare \
  --annotation /data/datasets/coco2017/annotations/instances_val2017.json \
  --labels assets/coco80.txt \
  --image-root /data/datasets/coco2017/val2017 \
  --image-list <run>/artifacts/coco_val2017_image_list.tsv \
  --category-map <run>/artifacts/coco_category_map.tsv \
  --provenance <run>/artifacts/coco_prepare_provenance.json

# Board-side prediction generation uses banana_yolo11_coco_eval_<runtime-tag>.
python3 tools/coco_eval/prepare_and_eval_coco.py evaluate \
  --annotation /data/datasets/coco2017/annotations/instances_val2017.json \
  --predictions <run>/outputs/coco_predictions_<candidate>_full.json \
  --eval-max-det 100 --prediction-max-det 300 \
  --summary-json <run>/outputs/coco_eval_<candidate>_full.json \
  --summary-md <run>/tables/coco_map_<candidate>_full.md \
  --stdout <run>/outputs/coco_eval_<candidate>_full.txt
```


## Release References

- `production-2026-07-02` remains the frozen production tag.
- This task may create a post-tag validation/report commit; the tag is intentionally not moved.
- Result packet: `/exchange/results/outbox/BANANA-YOLO11-PRODUCTION-COCO-MAP-FPS-FINAL-REPORT-001`.

## Appendix: Full FPS Table

|Category|Variant|Runtime|Metric class|Resolution|Mean ms|Std ms|FPS|Status|
|---|---|---|---|---|---:|---:|---:|---|
|production primary|dynamic640 INT8|rt201|perf_test forward|640|187.507000|N/A|5.332970|production primary|
|production primary|dynamic640 INT8|rt201|app forward-only|640|188.257498|0.071248|5.311873|production primary|
|production primary|dynamic640 INT8|rt201|app full image|640|229.651583|0.568951|4.354422|production primary|
|camera|normal camera dynamic640 INT8|rt201|camera effective|1280x720 capture, 640 inference|N/A|N/A|2.400594|production normal camera|
|camera|normal camera dynamic640 INT8|rt201|camera instantaneous|1280x720 capture, 640 inference|239.763000|N/A|4.171000|production normal camera|
|fast-live|vendor320 INT8|rt123|camera effective|640x480 capture, 320 inference|N/A|N/A|10.508203|production fast-live|
|fast-live|vendor320 INT8|rt123|camera instantaneous|640x480 capture, 320 inference|66.492000|N/A|15.039000|production fast-live|
|trusted visual|vendor320 INT8|rt123|perf_test forward|320|48.069200|N/A|20.787800|trusted visual / fast-live|
|trusted visual|vendor320 INT8|rt123|app forward-only|320|48.617629|0.013438|20.568671|trusted visual / fast-live|
|trusted visual|vendor320 INT8|rt123|app full image|320|56.815375|0.106610|17.600870|trusted visual / fast-live|
|perf-only|vendor320 raw INT8|rt201|perf_test forward|320|24.372600|N/A|41.020200|low-latency perf only, not visual default|
|perf-only|vendor320 raw INT8|rt201|app forward-only|320|24.872159|0.019449|40.205597|low-latency perf only, not visual default|
|workaround|vendor320 INT8 visual workaround|rt201|app full image|320|33.007326|0.043991|30.296304|non-default workaround|
|experimental|FP16 keep_io 640|rt201/rt202b1|app forward-only|640|see prior FPS summary|N/A|see prior FPS summary|experimental only|
|rejected|stable rt202|rt202|fail/rejected|N/A|N/A|N/A|N/A|not adopted|
|rejected|YOLO26n|N/A|fail/rejected|640|N/A|N/A|N/A|not production|

## Appendix: COCO mAP Table

|Candidate|Runtime|Status|Images|Detections|AP@[.50:.95]|AP50|AP75|AP_small|AP_medium|AP_large|AR1|AR10|AR100|
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|Primary dynamic640 INT8|rt201|production primary|5000|691410|0.384006|0.539212|0.419599|0.191668|0.420989|0.556876|0.307861|0.505896|0.556047|
|Vendor320 trusted visual|rt123|fast-live / trusted visual|5000|330235|0.211281|0.333139|0.225284|0.037406|0.204024|0.413734|0.209826|0.340494|0.369700|
|Vendor320 rt201 visual workaround|rt201|non-default workaround|5000|514015|0.216324|0.337841|0.234206|0.042726|0.218581|0.400563|0.212091|0.336105|0.364450|

## Appendix: Artifact Index

- COCO provenance: `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19/COCO_DATASET_PROVENANCE.md`.
- COCO summary table: `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19/tables/coco_map_summary.md`.
- FPS summary table: `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19/tables/fps_stable_summary.md`.
- Full raw predictions: `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19/outputs/coco_predictions_*_full.json`.
- Official COCOeval outputs: `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19/outputs/coco_eval_*_full.*`.
- Build/deploy/camera/FPS logs: `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19/run_logs/`.
