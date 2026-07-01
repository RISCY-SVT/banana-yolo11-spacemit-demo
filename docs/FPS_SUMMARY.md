# Production FPS / Latency Summary

This is the authoritative consolidated FPS/latency view for the
2026-07-02 production handoff. It is compiled from accepted production-week
evidence and does not change the runtime/model policy.

Final post-tag COCO/FPS validation was added on 2026-07-01. For full COCO
val2017 mAP and fresh stable benchmark rows, see `docs/COCO_MAP_FPS_REPORT.md`
and `release/COCO_MAP_FPS_SUMMARY.md`. This historical handoff matrix remains
useful for the broader Day 1/Day 2 variant context.

Source evidence:

- Day 4 final acceptance: `/data/ncnn-logs/ort-logs/2026-06-28_19-47-11/`
- Day 2 RC regression: `/data/ncnn-logs/ort-logs/2026-06-28_17-50-14/`
- Day 1 full regression and YOLO26n gate:
  `/data/ncnn-logs/ort-logs/2026-06-28_16-43-04/`
- FP16 provenance and older matrix details already summarized in
  `docs/RESULTS.md`.

## Metric Taxonomy

Do not compare these metric classes as if they measured the same workload.

| Metric class | Meaning | Comparable with |
| --- | --- | --- |
| `perf_test forward` | Vendor `onnxruntime_perf_test` pure ORT inference ceiling. It excludes application preprocessing, postprocessing, rendering, and camera capture. | Other `perf_test forward` rows with the same benchmark settings. |
| `app forward-only` | Repo app forward benchmark using the app runtime/session path, but still excluding full image pre/post and camera capture. | Other app forward-only rows. |
| `app full image` | Single-image app pipeline: preprocess + inference + postprocess, plus normal app overhead for one still image. | Other app full image rows. |
| `camera effective` | Wall-clock live camera loop rate over N frames. It includes capture/decode, inference, display/headless loop, warmup effects, and any frame I/O. | Other camera effective rows with similar frame counts and display/headless conditions. |
| `camera instantaneous` | Per-frame instantaneous FPS from a reported frame total, usually after warmup. | Other camera instantaneous rows from similar frame positions/settings. |
| `visual sanity` | Semantic quality result, object count, or qualitative pass/fail. It is not a performance metric. | Other visual sanity rows only as correctness evidence. |
| `fail / rejected` | Runtime/model path is not usable or not adopted. Latency/FPS are `N/A` unless a failed feasibility smoke produced a timing before rejection. | Not used for production FPS comparisons. |

## Consolidated Matrix

| Category | Variant | Runtime | Model/config | Mode / metric class | Resolution | Mean latency ms | FPS | Object count / visual status | Production status | Caveats | Evidence source |
| --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- | --- | --- |
| Supported production | Primary visual forward ceiling | `rt201` | generated dynamic640 INT8 | `perf_test forward` | 640x640 | 190.024 | 5.2623 | visual status from full/image rows: reasonable | primary production visual branch | Pure ORT ceiling only; no app pre/post. | Day 2 `performance_regression_matrix.md` |
| Supported production | Primary visual app forward | `rt201` | generated dynamic640 INT8 | `app forward-only` | 640x640 | 190.567794 | 5.247476 | reasonable in image regression | primary production visual branch | Forward-only, not full image/camera. | Day 2 `performance_regression_matrix.md` |
| Supported production | Primary visual full image | `rt201` | generated dynamic640 INT8 | `app full image` | 640x640 | 233.480423 | 4.283014 | 14 objects, reasonable | primary production visual branch | Use for still-image app pipeline; Day 4 final smoke also passed at 854.707 ms one-shot acceptance run. | Day 2 `performance_regression_matrix.md`; Day 4 `final_smoke_matrix.md` |
| Supported production | Normal camera effective | `rt201` | generated dynamic640 INT8 | `camera effective` | model 640x640; camera 1280x720 MJPG | N/A | 2.069 | pass; stable by-id camera | primary normal camera | Day 4 bounded final smoke over 10 frames; includes warmup/live loop overhead. | Day 4 `PRODUCTION_FINAL_ACCEPTANCE_REPORT.md` |
| Supported production | Normal camera instantaneous | `rt201` | generated dynamic640 INT8 | `camera instantaneous` | model 640x640; camera 1280x720 MJPG | 238.716 | 4.189 | pass at frame 10 | primary normal camera | Single frame timing from Day 4 camera smoke, not wall-clock loop FPS. | Day 4 `final_smoke_matrix.md` |
| Supported production | Fast-live camera effective | `rt123` | vendor320 INT8 letterbox | `camera effective` | model 320x320; camera 640x480 | N/A | 9.382 | pass; stable by-id camera | fast-live production branch | Day 4 bounded final smoke over 20 frames; includes warmup/live loop overhead. | Day 4 `PRODUCTION_FINAL_ACCEPTANCE_REPORT.md` |
| Supported production | Fast-live camera instantaneous | `rt123` | vendor320 INT8 letterbox | `camera instantaneous` | model 320x320; camera 640x480 | 67.121 | 14.898 | pass at frame 20 | fast-live production branch | Single frame timing; best responsiveness path, not highest-detail visual path. | Day 4 `final_smoke_matrix.md` |
| Supported production | Vendor320 trusted visual perf_test | `rt123` | official vendor320 INT8 | `perf_test forward` | 320x320 | 48.3266 | 20.6767 | visual branch reasonable | trusted vendor320 visual | Pure ORT ceiling only. | Day 2 `performance_regression_matrix.md` |
| Supported production | Vendor320 trusted visual app forward | `rt123` | official vendor320 INT8 | `app forward-only` | 320x320 | 49.095494 | 20.368468 | visual branch reasonable | trusted vendor320 visual | Forward-only. | Day 2 `performance_regression_matrix.md` |
| Supported production | Vendor320 trusted visual full image | `rt123` | official vendor320 INT8 | `app full image` | 320x320 | 57.540777 | 17.378980 | 8 objects, reasonable | trusted vendor320 visual | Full image benchmark; Day 4 final smoke also passed with 8 objects. | Day 2 `performance_regression_matrix.md`; Day 4 `final_smoke_matrix.md` |
| Supported production | Vendor320 low-latency perf perf_test | `rt201` | official vendor320 INT8 raw | `perf_test forward` | 320x320 | 24.4143 | 40.9483 | perf only | low-latency benchmark branch | Raw rt201 path is not a production visual default. | Day 2 `performance_regression_matrix.md` |
| Supported production | Vendor320 low-latency perf app forward | `rt201` | official vendor320 INT8 raw | `app forward-only` | 320x320 | 24.210065 | 41.305136 | perf only | low-latency benchmark branch | Raw rt201 path is benchmark/perf only; visual semantics are not trusted without workaround. | Day 2 `performance_regression_matrix.md` |
| Supported non-default | Vendor320 rt201 visual workaround | `rt201` | official vendor320 INT8 + SHA256-guarded EP workaround | `app full image` | 320x320 | 178.049 | 5.616 | 9 objects, reasonable | non-default available workaround | Much slower than trusted rt123 benchmark path; only enabled deliberately/guarded. | Day 2 `image_regression_matrix.md` |
| Experimental FP16 | FP16 keep_io 640 perf_test | `rt201` | `yolov11n_640x640.fp16_iop32.onnx` | `perf_test forward` | 640x640 | 270.867 | 3.69176 | experimental pass | experimental usable | Not production default; FP32 I/O with internal FP16 weights. | Day 2 `performance_regression_matrix.md` |
| Experimental FP16 | FP16 keep_io 640 app forward | `rt201` | `yolov11n_640x640.fp16_iop32.onnx` | `app forward-only` | 640x640 | 273.265611 | 3.659443 | experimental pass | experimental usable | Not production default. | Day 2 `performance_regression_matrix.md` |
| Experimental FP16 | FP16 keep_io 640 full image | `rt201` | `yolov11n_640x640.fp16_iop32.onnx` | `app full image` | 640x640 | 485.721 | 2.059 | 13 objects, reasonable | experimental usable | Canonical-photo visual sanity only; not production path. | Day 2 `image_regression_matrix.md` |
| Experimental FP16 | FP16 keep_io 640 perf_test | `rt202b1` | `yolov11n_640x640.fp16_iop32.onnx` | `perf_test forward` | 640x640 | 293.060863 | 3.41212 | experimental pass | experimental usable fallback | Stable rt202 does not replace rt202b1. | Day 2 `performance_regression_matrix.md` |
| Experimental FP16 | FP16 keep_io 640 app forward | `rt202b1` | `yolov11n_640x640.fp16_iop32.onnx` | `app forward-only` | 640x640 | 294.988206 | 3.389966 | experimental pass | experimental usable fallback | Not production default. | Day 2 `performance_regression_matrix.md` |
| Experimental FP16 | FP16 keep_io 640 full image | `rt202b1` | `yolov11n_640x640.fp16_iop32.onnx` | `app full image` | 640x640 | 503.659 | 1.985 | 13 objects, reasonable | experimental usable fallback | Canonical-photo visual sanity only; not production path. | Day 2 `image_regression_matrix.md` |
| Experimental FP16 | FP16 keep_io 320 | `rt201` / `rt202b1` | `yolov11n_320x320.fp16_iop32.onnx` | `fail / rejected` | 320x320 | N/A | N/A | expected fail | unsupported | EP reshape/compile failure; documented unsupported. | `docs/RESULTS.md` FP16 matrix |
| Experimental FP16 | True FP16 I/O models | `rt123` / `rt201` / `rt202b1` | `yolov11n_320x320.fp16.onnx`; `yolov11n_640x640.fp16.onnx` | `fail / rejected` | 320x320 and 640x640 | N/A | N/A | dtype-correct but not runnable | unsupported board path | Retained as dtype evidence, not usable board runtime chain. | `docs/RESULTS.md` FP16 model provenance |
| Rejected / P2 | Stable rt202 dynamic640 candidate | `rt202` | generated dynamic640 INT8 | `fail / rejected` | 640x640 | N/A | N/A | abort | rejected; not adopted | Aborts even after clean board reboot; does not replace rt201. | Day 2 `stable_rt202_decision.md` |
| Rejected / P2 | Stable rt202 FP16 640 candidate | `rt202` | FP16 keep_io 640 | `fail / rejected` | 640x640 | N/A | N/A | abort | rejected; not adopted | Aborts; does not replace rt202b1. | Day 2 `stable_rt202_decision.md` |
| Rejected / P2 | Stable rt202 vendor320 candidate | `rt202` | official vendor320 INT8 | `fail / rejected` | 320x320 | N/A | N/A | abort | rejected; not adopted | No stable rt202 vendor320 fix. | Day 2 `stable_rt202_decision.md` |
| Rejected / P2 | YOLO26n float 640 | `rt201` | YOLO26n float ONNX | `app full image feasibility` | 640x640 | 600.287 | 1.666 | giant false refrigerator box | P2 only; rejected for production | Timing exists only from failed feasibility smoke; semantic failure blocks adoption. | Day 1 `yolo26n_feasibility.md` / `docs/RESULTS.md` |
| Rejected / P2 | YOLO26n dynamic INT8 640 | `rt201` | YOLO26n dynamic INT8 ONNX | `app full image feasibility` | 640x640 | 1147.946 | 0.871 | giant false refrigerator box | P2 only; rejected for production | Slower than current dynamic640 and semantically bad. | Day 1 `yolo26n_feasibility.md` / `docs/RESULTS.md` |
| Rejected / P2 | rt202b1 production replacement | `rt202b1` | 2.0.2+beta1 runtime line | `visual sanity` | various | N/A | N/A | not adopted as production runtime | P2/historical-experimental | Still kept for FP16 keep_io 640 experimental because stable rt202 failed replacement. | Day 2 `stable_rt202_decision.md` |
| Rejected / P2 | Official public 640 INT8 artifact | N/A | official vendor YOLO11n 640 INT8 | `fail / rejected` | 640x640 | N/A | N/A | not found | P2 search only | No pinned official public artifact found; production uses generated dynamic640 INT8. | `docs/RESULTS.md` quantization notes |
| Rejected / P2 | Latest-frame/drop-old-frames pipeline | N/A | camera architecture R&D | `fail / rejected` | camera | N/A | N/A | not implemented | P2 R&D | Out of scope for 2026-07-02 production handoff. | `release/KNOWN_LIMITATIONS.md` |

## Reading Notes

- The fastest number in the table is the raw vendor320 `rt201` forward path, but
  that branch is performance-only and not a production visual default.
- The primary production visual branch remains generated dynamic640 INT8 on
  `rt201` because it gives the accepted production visual behavior.
- The responsive live branch is `run_camera_demo_fast.sh`, using vendor320 on
  `rt123`. It is a separate product branch, not a replacement for the
  highest-detail dynamic640 branch.
- Stable `rt202` and YOLO26n are explicitly rejected for production in this
  scope. They remain P2 follow-up items only.
