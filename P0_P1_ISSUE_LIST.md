# P0/P1 Issue List

Run: `PRODUCTION-DAY2-RC-SOAK-AND-STABLE-RT202-EVALUATION-001`

Log directory:

```text
/data/ncnn-logs/ort-logs/2026-06-28_17-50-14/
```

## P0

No open P0 after Day 2 RC regression.

Validated:

- Cross-build passes.
- Deploy passes.
- Loader proof resolves repo-local runtime/OpenCV libraries.
- Default image visual path passes.
- Normal camera passes.
- Fast-live camera passes.
- Forced headless normal and fast-live camera modes pass.
- Stable `rt202` failed its evaluation gate, but it is not part of the
  production default policy and therefore is not a P0 release blocker.

## P1

No open P1 at Day 2 close.

Fixed/updated during Day 2:

- Stable public `spacemit-ort.riscv64.2.0.2` is pinned and selectable as
  `rt202` for reproducible evaluation.
- Documentation now records that stable `rt202` is not adopted and does not
  replace `rt201` or `rt202b1`.

## P2

- Stable public `spacemit-ort 2.0.2` runtime-side TCM abort follow-up if vendor
  guidance becomes available.
- YOLO26n 640 remains a candidate only; current export/quantized smoke produces giant false boxes and is not production-ready.
- Investigate latest-frame/drop-old-frames camera pipeline after release.
- Search for an official public 640 INT8 artifact after release.
- Investigate public 320 FP16 chain after release.
