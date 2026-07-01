# Финальный production-отчет: Banana YOLO11 SpacemiT Demo

## Краткое резюме

Замороженный production-демо YOLO11 для Banana-Pi BPI-F3 / SpacemiT K1X остается готовым к передаче. Этот проход добавляет официальные метрики COCO val2017 mAP и свежие стабильные FPS-измерения без изменения runtime/model policy и без перемещения production tag. Основной production visual path — generated dynamic640 INT8 на `rt201`; полный COCO AP@[.50:.95] = **0.384006** на 5000 изображениях. Trusted vendor320 `rt123` visual path остается более быстрым низкоразрешенным путем, AP@[.50:.95] = **0.211281**. Non-default vendor320 `rt201` visual workaround также измерен и остается доступным, но не является default.

## Аппаратная и программная среда

- Плата: Banana-Pi BPI-F3 со SpacemiT X60 / K1X, 8 RISC-V ядер.
- Kernel платы в этом проходе: `Linux bf3 6.6.63 #2.2.7.2`.
- CPU governor при validation: `performance`, наблюдаемая частота 1600 MHz.
- Toolchain: `/data/SpacemiT/spacemit-toolchain-linux-glibc-x86_64-v1.1.2` с `-march=rv64gcv_zvfh -mabi=lp64d`.
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

## Архитектура

![Board-side COCO validation stack](assets/coco_architecture_diagram.svg)

Приложение использует OpenCV для media input и rendering, ONNX Runtime со SpaceMIT Execution Provider для inference, а также preprocessing/decode logic из репозитория. COCO evaluation tool, добавленный в этом проходе, отделен от default demo execution и переиспользует тот же detector class.

## Dataset and Evaluation Methodology

Full COCO mAP означает официальную метрику COCO val2017 по 5000 изображениям. Visual sanity означает выборочную визуальную проверку, а не статистическую accuracy metric. Semantic sanity означает ожидаемые правдоподобные классы на известных изображениях, а не mAP. Private canonical reference — это инженерное regression image, а не public benchmark.

- Dataset: COCO 2017 validation, 5000 images.
- Annotation: `/data/datasets/coco2017/annotations/instances_val2017.json`, SHA256 `e8c7f7908f1d7278341fae127d0da654f102f11bd7b21d8aeefa635b8c810b6f`.
- Prediction generation: board-side SpaceMIT runtime stack, не host PyTorch/ONNX approximation.
- Confidence для prediction export: `0.001`.
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

Metric classes нельзя сравнивать как один и тот же workload. `perf_test forward` — это pure ORT inference ceiling. `app forward-only` использует app harness с cached input. `app full image` включает preprocess, inference и postprocess. `camera effective` — wall-clock live loop FPS. `camera instantaneous` — one-frame total timing.

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

Теперь релиз содержит full COCO mAP для required visual candidates плюс visual sanity outputs. Никаких mAP claims не делается для FP16 experimental paths, stable `rt202` или YOLO26n. Selected public COCO output examples находятся в `release/assets/coco_sample_primary_*.jpg`. Private canonical image остается только regression reference.

Representative public examples:

![COCO sample 000000000139](assets/coco_sample_primary_000000000139.jpg)
![COCO sample 000000001000](assets/coco_sample_primary_000000001000.jpg)
![COCO sample 000000005037](assets/coco_sample_primary_000000005037.jpg)

## Camera Demo Behavior

Normal camera default использует generated dynamic640 INT8 on `rt201`. В этом проходе он обработал 30 headless frames через stable `/dev/v4l/by-id/...video-index0`, effective FPS **2.400594**, frame-30 instantaneous FPS **4.171**. Fast-live использует vendor320 INT8 on `rt123`, 320 letterbox, обработал 60 frames, effective FPS **10.508203**, frame-60 instantaneous FPS **15.039**.

## Fast-live Mode

Fast-live остается рекомендуемым режимом, когда responsiveness важнее 640-resolution visual detail. Он сохраняет trusted vendor320 `rt123` visual stack и не переключается на raw `rt201` perf behavior.

## Deployment and Reproducibility Evidence

- Current validation source HEAD before this report commit: `1dfb734a83f9740eee1dda36b9541478e2ee6d5a`.
- Production tag target remained `9c0933be58ee122389d1a43f45f81e80655d6904`.
- GitHub source: `git@github.com:RISCY-SVT/banana-yolo11-spacemit-demo.git`.
- GitLab mirror: `git@gitlab.itglobal.com:riscy/sw/banana-yolo11-spacemit-demo.git`.
- Drive mirror status from closeout: verified-quick-by-operator.
- Board dataset path: `/home/svt/datasets/coco2017/val2017`.
- Raw COCO predictions and COCOeval JSON are stored in the run root, not in git.

## Known Limitations

- COCO mAP измерен только для production visual candidates; FP16 остается experimental.
- Vendor320 raw `rt201` остается perf-only и не является visual default.
- Stable `rt202` был evaluated earlier и not adopted.
- YOLO26n остается отдельной P2 R&D line, не production.
- Camera FPS зависит от camera backend, pixel format, display/headless mode и live-loop conditions.

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
