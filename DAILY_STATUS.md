# Daily Status 2026-06-28_17-50-14

## Goal For This Run

Run Day 2 release-candidate soak/regression and perform a bounded evaluation of
final stable `spacemit-ort.riscv64.2.0.2` without changing production defaults
unless evidence supports it.

## Done

- Verified Day 0 commit `f3f160cd615b02d66a9d3a4b49b1209f8e2df0fb`.
- Verified Day 1 commit `601b1de5e9c7d77d4b06da465c91175e0dd6d9e2`.
- Fetched/staged stable `spacemit-ort.riscv64.2.0.2` as explicit tag `rt202`.
- Rebuilt and redeployed `rt123`, `rt201`, `rt202b1`, and `rt202` variants.
- Verified loader proof for all deployed demo binaries.
- Ran image, camera, fast-live, headless, performance, FP16, and Doxygen checks.
- Rebooted the board and retested stable `rt202` after clean `/dev/tcm` state.
- Kept current production policy unchanged.

## Evidence

```text
/data/ncnn-logs/ort-logs/2026-06-28_17-50-14/
```

Key artifacts:

- `artifacts/image_regression_matrix.md`
- `artifacts/camera_regression_matrix.md`
- `artifacts/performance_regression_matrix.md`
- `artifacts/docs_doxygen_sanity.md`
- `artifacts/stable_rt202_decision.md`

## Open P0

None.

## Open P1

None.

## Risks

- Stable `rt202` aborts on current dynamic640, FP16 640, and vendor320 paths.
- FP16 remains experimental and should not be promoted before separate approval.
- Production performance claims must cite the Day 2 run directory.

## Next Actions

Proceed to Day 3 release-candidate packaging/mirror verification with the
frozen production scope. Do not promote stable `rt202` before a separate
runtime-side fix or vendor guidance.
