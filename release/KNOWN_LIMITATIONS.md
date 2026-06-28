# Known Limitations

See `release/FPS_SUMMARY.md` for the consolidated FPS/latency matrix and the
metric-class caveats. Camera effective FPS, per-frame instantaneous FPS,
app full-image FPS, app forward-only FPS, and vendor `perf_test` FPS are
different measurements.

## Stable rt202

Stable `spacemit-ort.riscv64.2.0.2` is staged and selectable as `rt202`, but it
is not adopted. Day 2 clean retesting showed aborts on dynamic640, FP16 640, and
vendor320 paths.

## Vendor320 on Public 2.0.x

Vendor320 is visually trusted on `rt123`. Raw `rt201` remains the low-latency
perf branch only. The `rt201` visual workaround is SHA256-guarded and non-default.

## FP16

FP16 is experimental. Only keep_io FP16 640 on `rt201`/`rt202b1` is usable
coverage. FP16 320 remains unsupported.

## YOLO26n

YOLO26n is P2 only. Current evidence is insufficient for production adoption.

## Camera Architecture

The current camera path is stable and documented. Latest-frame/drop-old-frames
pipeline work is explicitly out of scope for this release candidate.
