# P0/P1 Issue List

Run: `PRODUCTION-DAY3-PACKAGING-MIRROR-VERIFICATION-AND-RC-HANDOFF-001`

Log directory:

```text
/data/ncnn-logs/ort-logs/2026-06-28_18-57-22/
```

## P0

No open P0 after Day 3 release-candidate packaging checks.

Validated:

- Day 0, Day 1, and Day 2 production-week commits are present.
- `origin/master` matched local Day 2 baseline at the start of Day 3.
- Cross-build passes.
- Deploy passes.
- Loader proof resolves repo-local ONNX Runtime, SpaceMIT EP, and staged OpenCV
  libraries.
- Default image visual path passes.
- Normal camera passes with explicit headless fallback under SSH/TTY.
- Fast-live camera passes.
- Forced headless camera passes.
- Release manifests were generated under `release/`.

## P1

No open P1 at Day 3 close.

Fixed during Day 3:

- `third_party_manifest/runtime.lock` now URL-encodes the public `rt202b1`
  archive path as `%2Bbeta1`. A fresh GitHub clone exposed the raw `+beta1`
  URL as a 404 on the vendor archive, while the encoded URL returns the pinned
  artifact and matches the existing SHA256.

## P2

- Stable public `spacemit-ort 2.0.2` runtime-side abort follow-up if vendor
  guidance becomes available.
- YOLO26n 640 remains a candidate only; current export/quantized smoke produces
  giant false boxes and is not production-ready.
- Investigate latest-frame/drop-old-frames camera pipeline after release.
- Search for an official public 640 INT8 artifact after release.
- Investigate public 320 FP16 chain after release.
