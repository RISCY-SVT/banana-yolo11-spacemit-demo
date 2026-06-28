# P0/P1 Issue List

Run: `PRODUCTION-DAY1-FULL-REGRESSION-AND-640-YOLO26-FEASIBILITY-001`

Log directory:

```text
/data/ncnn-logs/ort-logs/2026-06-28_16-43-04/
```

## P0

No open P0 after Day 1 regression.

Validated:

- Cross-build passes.
- Deploy passes.
- Loader proof resolves repo-local runtime/OpenCV libraries.
- Default image visual path passes.
- Normal camera passes.
- Fast-live camera passes.
- Forced headless normal and fast-live camera modes pass.

## P1

No open P1 at Day 1 close.

Fixed during Day 1:

- Host-wrapper `SAVE_OUTPUT` handling for camera stills and image outputs now creates requested artifacts without manual board-path edits.
- Benchmark helpers now expose repeat/warmup/run overrides so production smoke and full regression can use bounded settings without editing scripts.

## P2

- Evaluate stable public `spacemit-ort 2.0.2` after release.
- YOLO26n 640 remains a candidate only; current export/quantized smoke produces giant false boxes and is not production-ready.
- Investigate latest-frame/drop-old-frames camera pipeline after release.
- Search for an official public 640 INT8 artifact after release.
- Investigate public 320 FP16 chain after release.
