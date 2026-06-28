# Production Scope 2026-07-02

## Supported Production Paths

| Path | Runtime | Model | Status | Notes |
| --- | --- | --- | --- | --- |
| Primary image visual | `rt201` | `models/generated/xquant_640/yolov11n_640x640.dynamic_int8.onnx` | supported | Main production visual branch. |
| Primary normal camera | `rt201` | generated dynamic640 INT8 | supported | Best production visual quality branch. |
| Fast-live camera | `rt123` | `models/vendor/yolo11/yolov11n_320x320.q.onnx` | supported | Responsive live branch, `320x320` letterbox, camera requested at `640x480`. |
| Vendor320 visual | `rt123` | official vendor320 INT8 | supported | Trusted visual runtime for vendor320. |
| Vendor320 low-latency benchmark | `rt201` | official vendor320 INT8 | supported as perf-only | Do not use as default visual path. |
| Vendor320 rt201 visual workaround | `rt201` | official vendor320 INT8 | available | SHA256-guarded, slower than `rt123`; not default. |

## Experimental Paths

| Path | Runtime | Status | Notes |
| --- | --- | --- | --- |
| FP16 keep_io 640 | `rt201` | experimental usable | Board-side coverage path, not production default. |
| FP16 keep_io 640 | `rt202b1` | experimental usable | Slightly slower than `rt201`, not production default. |
| Stable runtime evaluation | `rt202` | not adopted | Final public `spacemit-ort 2.0.2` is fetchable/selectable, but Day 2 clean retest aborted on current paths. |
| FP16 keep_io 320 | `rt201`/`rt202b1` | known fail | Keep documented as unsupported. |

## Explicitly Out Of Scope Before 2026-07-02

- Adopting stable public `spacemit-ort 2.0.2` as production runtime.
  Day 2 already evaluated it and found it non-adoptable for this release.
- Replacing the current runtime/model policy.
- Rewriting the camera pipeline architecture.
- Introducing latest-frame/drop-old-frames pipeline behavior.
- Deep FP16 runtime debugging.
- Broad model-zoo search.
- YOLO26n adoption without a separate full regression approval.

## Day 1 Decision

Day 1 regression keeps the current product policy and formalizes generated
`dynamic640` INT8 on `rt201` as the primary production visual branch.

## Day 2 Decision

Day 2 RC soak/regression keeps the same production policy. Stable public
`spacemit-ort.riscv64.2.0.2` is pinned for reproducible evaluation as `rt202`,
but it does not replace `rt201` or `rt202b1` because it aborted on dynamic640,
FP16 640, and vendor320 checks, including after a clean board reboot.
