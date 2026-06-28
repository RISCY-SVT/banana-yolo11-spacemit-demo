# Next Actions

## Day 2

- Run release-candidate soak/regression under the frozen scope.
- Reconfirm image, normal camera, fast-live camera, headless fallback, and loader proof.
- Re-run only bounded performance checks needed for release confidence.
- Keep generated `dynamic640` INT8 on `rt201` as primary production visual branch.
- Do not adopt YOLO26n or a new runtime line without a separate approved task.

## Release Notes To Preserve

- Primary production visual branch: generated `dynamic640` INT8 on `rt201`.
- Fast-live branch: vendor320 INT8 on `rt123`.
- Vendor320 raw `rt201`: benchmark/perf-only.
- FP16: experimental keep_io 640 coverage only.
- Camera recording remains opt-in.
