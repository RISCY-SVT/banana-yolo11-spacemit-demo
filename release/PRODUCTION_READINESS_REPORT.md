# Production Readiness Report

## Scope

This release-candidate package covers the Banana-Pi BPI-F3 / SpacemiT K1X
`banana-yolo11-spacemit-demo` repository for the 2026-07-02 handoff.

Day 3 packaging baseline commit:

```text
d202cdf76ce3e0742a665396a6eb157e5b3efe5e
```

The final Day 3 handoff commit is recorded in the Day 3 run summary and git
history.

## Production Policy

| Branch | Runtime | Model | Status |
|---|---:|---|---|
| Primary image visual | `rt201` | generated dynamic640 INT8 | supported |
| Primary normal camera | `rt201` | generated dynamic640 INT8 | supported |
| Fast-live camera | `rt123` | vendor320 INT8, 320 letterbox | supported |
| Vendor320 trusted visual | `rt123` | official vendor320 INT8 | supported |
| Vendor320 low-latency perf | raw `rt201` | official vendor320 INT8 | perf-only |
| Vendor320 rt201 visual workaround | `rt201` | official vendor320 INT8 | SHA256-guarded, non-default |
| FP16 | `rt201`/`rt202b1` | keep_io 640 | experimental |
| Stable `rt202` | `2.0.2` | current paths | evaluated, not adopted |
| YOLO26n | n/a | n/a | P2 only |

## Day 3 Gate

Day 3 is a release-candidate packaging and handoff-readiness gate. It does not
change runtime/model policy unless a P0 blocker requires a minimal emergency
fix.

Required evidence is stored under the Day 3 run directory:

```text
/data/ncnn-logs/ort-logs/YYYY-MM-DD_HH-MM-SS/
```
