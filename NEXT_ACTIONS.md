# Next Actions

## Day 3

- Run release-candidate packaging/mirror verification under the frozen scope.
- Reconfirm that Drive/GitHub/mirror artifacts contain the Day 2 docs and patch.
- Re-run only smoke checks needed after packaging or mirror movement.
- Keep generated `dynamic640` INT8 on `rt201` as primary production visual branch.
- Do not adopt YOLO26n or stable `rt202` without a separate approved task.

## Release Notes To Preserve

- Primary production visual branch: generated `dynamic640` INT8 on `rt201`.
- Fast-live branch: vendor320 INT8 on `rt123`.
- Vendor320 raw `rt201`: benchmark/perf-only.
- FP16: experimental keep_io 640 coverage only on `rt201`/`rt202b1`.
- Stable `rt202`: evaluated on Day 2, not adopted.
- Camera recording remains opt-in.
