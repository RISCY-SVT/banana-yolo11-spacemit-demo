# Production FPS / Latency Summary

This release-package copy points management and operators to the same
authoritative matrix as `docs/FPS_SUMMARY.md`. It is intentionally included in
`release/` so a handoff bundle can be read without scanning raw logs.

The consolidated matrix was generated from accepted production-week evidence:

- Day 4 final acceptance: `/data/ncnn-logs/ort-logs/2026-06-28_19-47-11/`
- Day 2 RC regression: `/data/ncnn-logs/ort-logs/2026-06-28_17-50-14/`
- Day 1 full regression and YOLO26n gate:
  `/data/ncnn-logs/ort-logs/2026-06-28_16-43-04/`
- FP16 provenance and older matrix details summarized in `docs/RESULTS.md`

## Key Production Numbers

| Branch | Runtime | Metric class | Mean latency ms | FPS | Status |
| --- | --- | --- | ---: | ---: | --- |
| Primary visual dynamic640 INT8 | `rt201` | `app forward-only` | 190.567794 | 5.247476 | production |
| Primary visual dynamic640 INT8 | `rt201` | `app full image` | 233.480423 | 4.283014 | production |
| Normal camera dynamic640 INT8 | `rt201` | `camera effective` | N/A | 2.069 | production, Day 4 bounded smoke |
| Normal camera dynamic640 INT8 | `rt201` | `camera instantaneous` | 238.716 | 4.189 | production, Day 4 frame-10 timing |
| Fast-live vendor320 INT8 | `rt123` | `camera effective` | N/A | 9.382 | production, Day 4 bounded smoke |
| Fast-live vendor320 INT8 | `rt123` | `camera instantaneous` | 67.121 | 14.898 | production, Day 4 frame-20 timing |
| Vendor320 trusted visual | `rt123` | `app full image` | 57.540777 | 17.378980 | production visual branch for vendor320 |
| Vendor320 low-latency perf | `rt201` | `app forward-only` | 24.210065 | 41.305136 | production perf-only branch |
| Vendor320 rt201 workaround | `rt201` | `app full image` | 178.049 | 5.616 | non-default, SHA256-guarded |
| FP16 keep_io 640 | `rt201` | `app forward-only` | 273.265611 | 3.659443 | experimental |
| FP16 keep_io 640 | `rt202b1` | `app forward-only` | 294.988206 | 3.389966 | experimental |

## Full Variant Matrix

| Category | Variant | Runtime | Model/config | Mode / metric class | Resolution | Mean latency ms | FPS | Object count / visual status | Production status | Caveats |
| --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- | --- |
| Supported production | Primary visual forward ceiling | `rt201` | generated dynamic640 INT8 | `perf_test forward` | 640x640 | 190.024 | 5.2623 | visual status from full/image rows: reasonable | primary production visual branch | Pure ORT ceiling only; no app pre/post. |
| Supported production | Primary visual app forward | `rt201` | generated dynamic640 INT8 | `app forward-only` | 640x640 | 190.567794 | 5.247476 | reasonable in image regression | primary production visual branch | Forward-only, not full image/camera. |
| Supported production | Primary visual full image | `rt201` | generated dynamic640 INT8 | `app full image` | 640x640 | 233.480423 | 4.283014 | 14 objects, reasonable | primary production visual branch | Use for still-image app pipeline; Day 4 final smoke also passed at 854.707 ms one-shot acceptance run. |
| Supported production | Normal camera effective | `rt201` | generated dynamic640 INT8 | `camera effective` | model 640x640; camera 1280x720 MJPG | N/A | 2.069 | pass; stable by-id camera | primary normal camera | Day 4 bounded final smoke over 10 frames; includes warmup/live loop overhead. |
| Supported production | Normal camera instantaneous | `rt201` | generated dynamic640 INT8 | `camera instantaneous` | model 640x640; camera 1280x720 MJPG | 238.716 | 4.189 | pass at frame 10 | primary normal camera | Single frame timing from Day 4 camera smoke, not wall-clock loop FPS. |
| Supported production | Fast-live camera effective | `rt123` | vendor320 INT8 letterbox | `camera effective` | model 320x320; camera 640x480 | N/A | 9.382 | pass; stable by-id camera | fast-live production branch | Day 4 bounded final smoke over 20 frames; includes warmup/live loop overhead. |
| Supported production | Fast-live camera instantaneous | `rt123` | vendor320 INT8 letterbox | `camera instantaneous` | model 320x320; camera 640x480 | 67.121 | 14.898 | pass at frame 20 | fast-live production branch | Single frame timing; best responsiveness path, not highest-detail visual path. |
| Supported production | Vendor320 trusted visual perf_test | `rt123` | official vendor320 INT8 | `perf_test forward` | 320x320 | 48.3266 | 20.6767 | visual branch reasonable | trusted vendor320 visual | Pure ORT ceiling only. |
| Supported production | Vendor320 trusted visual app forward | `rt123` | official vendor320 INT8 | `app forward-only` | 320x320 | 49.095494 | 20.368468 | visual branch reasonable | trusted vendor320 visual | Forward-only. |
| Supported production | Vendor320 trusted visual full image | `rt123` | official vendor320 INT8 | `app full image` | 320x320 | 57.540777 | 17.378980 | 8 objects, reasonable | trusted vendor320 visual | Full image benchmark; Day 4 final smoke also passed with 8 objects. |
| Supported production | Vendor320 low-latency perf perf_test | `rt201` | official vendor320 INT8 raw | `perf_test forward` | 320x320 | 24.4143 | 40.9483 | perf only | low-latency benchmark branch | Raw rt201 path is not a production visual default. |
| Supported production | Vendor320 low-latency perf app forward | `rt201` | official vendor320 INT8 raw | `app forward-only` | 320x320 | 24.210065 | 41.305136 | perf only | low-latency benchmark branch | Raw rt201 path is benchmark/perf only; visual semantics are not trusted without workaround. |
| Supported non-default | Vendor320 rt201 visual workaround | `rt201` | official vendor320 INT8 + SHA256-guarded EP workaround | `app full image` | 320x320 | 178.049 | 5.616 | 9 objects, reasonable | non-default available workaround | Much slower than trusted rt123 benchmark path; only enabled deliberately/guarded. |
| Experimental FP16 | FP16 keep_io 640 perf_test | `rt201` | `yolov11n_640x640.fp16_iop32.onnx` | `perf_test forward` | 640x640 | 270.867 | 3.69176 | experimental pass | experimental usable | Not production default; FP32 I/O with internal FP16 weights. |
| Experimental FP16 | FP16 keep_io 640 app forward | `rt201` | `yolov11n_640x640.fp16_iop32.onnx` | `app forward-only` | 640x640 | 273.265611 | 3.659443 | experimental pass | experimental usable | Not production default. |
| Experimental FP16 | FP16 keep_io 640 full image | `rt201` | `yolov11n_640x640.fp16_iop32.onnx` | `app full image` | 640x640 | 485.721 | 2.059 | 13 objects, reasonable | experimental usable | Canonical-photo visual sanity only; not production path. |
| Experimental FP16 | FP16 keep_io 640 perf_test | `rt202b1` | `yolov11n_640x640.fp16_iop32.onnx` | `perf_test forward` | 640x640 | 293.060863 | 3.41212 | experimental pass | experimental usable fallback | Stable rt202 does not replace rt202b1. |
| Experimental FP16 | FP16 keep_io 640 app forward | `rt202b1` | `yolov11n_640x640.fp16_iop32.onnx` | `app forward-only` | 640x640 | 294.988206 | 3.389966 | experimental pass | experimental usable fallback | Not production default. |
| Experimental FP16 | FP16 keep_io 640 full image | `rt202b1` | `yolov11n_640x640.fp16_iop32.onnx` | `app full image` | 640x640 | 503.659 | 1.985 | 13 objects, reasonable | experimental usable fallback | Canonical-photo visual sanity only; not production path. |
| Experimental FP16 | FP16 keep_io 320 | `rt201` / `rt202b1` | `yolov11n_320x320.fp16_iop32.onnx` | `fail / rejected` | 320x320 | N/A | N/A | expected fail | unsupported | EP reshape/compile failure; documented unsupported. |
| Experimental FP16 | True FP16 I/O models | `rt123` / `rt201` / `rt202b1` | `yolov11n_320x320.fp16.onnx`; `yolov11n_640x640.fp16.onnx` | `fail / rejected` | 320x320 and 640x640 | N/A | N/A | dtype-correct but not runnable | unsupported board path | Retained as dtype evidence, not usable board runtime chain. |
| Rejected / P2 | Stable rt202 dynamic640 candidate | `rt202` | generated dynamic640 INT8 | `fail / rejected` | 640x640 | N/A | N/A | abort | rejected; not adopted | Aborts even after clean board reboot; does not replace rt201. |
| Rejected / P2 | Stable rt202 FP16 640 candidate | `rt202` | FP16 keep_io 640 | `fail / rejected` | 640x640 | N/A | N/A | abort | rejected; not adopted | Aborts; does not replace rt202b1. |
| Rejected / P2 | Stable rt202 vendor320 candidate | `rt202` | official vendor320 INT8 | `fail / rejected` | 320x320 | N/A | N/A | abort | rejected; not adopted | No stable rt202 vendor320 fix. |
| Rejected / P2 | YOLO26n float 640 | `rt201` | YOLO26n float ONNX | `app full image feasibility` | 640x640 | 600.287 | 1.666 | giant false refrigerator box | P2 only; rejected for production | Timing exists only from failed feasibility smoke; semantic failure blocks adoption. |
| Rejected / P2 | YOLO26n dynamic INT8 640 | `rt201` | YOLO26n dynamic INT8 ONNX | `app full image feasibility` | 640x640 | 1147.946 | 0.871 | giant false refrigerator box | P2 only; rejected for production | Slower than current dynamic640 and semantically bad. |
| Rejected / P2 | rt202b1 production replacement | `rt202b1` | 2.0.2+beta1 runtime line | `visual sanity` | various | N/A | N/A | not adopted as production runtime | P2/historical-experimental | Still kept for FP16 keep_io 640 experimental because stable rt202 failed replacement. |
| Rejected / P2 | Official public 640 INT8 artifact | N/A | official vendor YOLO11n 640 INT8 | `fail / rejected` | 640x640 | N/A | N/A | not found | P2 search only | No pinned official public artifact found; production uses generated dynamic640 INT8. |
| Rejected / P2 | Latest-frame/drop-old-frames pipeline | N/A | camera architecture R&D | `fail / rejected` | camera | N/A | N/A | not implemented | P2 R&D | Out of scope for 2026-07-02 production handoff. |

## Caveats

- `perf_test forward`, `app forward-only`, `app full image`, and camera FPS are
  different metric classes. Do not compare them as a single leaderboard.
- Raw vendor320 on `rt201` is the low-latency benchmark branch only. It is not
  the default visual path.
- Fast-live is intentionally a separate responsive camera branch:
  vendor320 INT8 on `rt123`, 320 letterbox.
- FP16 remains experimental. Only keep_io 640 on `rt201`/`rt202b1` is usable
  coverage.
- Stable `rt202`, YOLO26n, FP16 320, official public 640 INT8 artifact search,
  and latest-frame camera pipeline work are rejected/P2 for this release scope.

For the full matrix with evidence source per row, see `docs/FPS_SUMMARY.md`.
