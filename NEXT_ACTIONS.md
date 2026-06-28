# Next Actions

## Final Acceptance

- Push the Day 3 release/handoff commit only after Doxygen, hygiene,
  fresh-clone recovery, and result-packet export pass.
- Verify the Google Drive mirror or remote snapshot for:
  - repository docs
  - `release/` handoff files
  - Day 3 log directory `/data/ncnn-logs/ort-logs/2026-06-28_18-57-22/`
- Use `release/DEMO_COMMANDS.md` for operator smoke commands.

## Release Notes To Preserve

- Primary production visual branch: generated `dynamic640` INT8 on `rt201`.
- Normal camera branch: generated `dynamic640` INT8 on `rt201`.
- Fast-live branch: vendor320 INT8 on `rt123`.
- Vendor320 raw `rt201`: benchmark/perf-only.
- Vendor320 `rt201` workaround: SHA256-guarded, non-default.
- FP16: experimental keep_io 640 coverage only on `rt201`/`rt202b1`.
- Stable `rt202`: evaluated on Day 2, not adopted.
- YOLO26n: P2 candidate only.
- Camera recording remains opt-in.

## Post-Release Backlog

- Stable `rt202` runtime-side abort follow-up with vendor guidance.
- YOLO26n decode/contract/quantization investigation.
- Latest-frame/drop-old-frames camera pipeline R&D.
- Official public 640 INT8 artifact search.
- Public 320 FP16 chain investigation.
