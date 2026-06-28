# Production Checklist

## Required Before Handoff

- [ ] Day 0 commit present: `f3f160cd615b02d66a9d3a4b49b1209f8e2df0fb`
- [ ] Day 1 commit present: `601b1de5e9c7d77d4b06da465c91175e0dd6d9e2`
- [ ] Day 2 commit present: `d202cdf76ce3e0742a665396a6eb157e5b3efe5e`
- [ ] Build from canonical container environment passes.
- [ ] Deploy to `svt@banana` passes.
- [ ] Loader proof shows repo-local ONNX Runtime and SpaceMIT EP libraries.
- [ ] Default image smoke passes.
- [ ] Normal camera smoke passes.
- [ ] Fast-live camera smoke passes.
- [ ] Forced headless camera smoke passes.
- [ ] Performance smoke has fresh Day 3 logs.
- [ ] Doxygen coverage has `missing_at_file=0`.
- [ ] Doxygen generation has zero warnings or documented accepted warnings.
- [ ] `git diff --check` passes.
- [ ] No secrets, private agent state, or large accidental artifacts are staged.
- [ ] Result packet is exported through `/exchange/results/outbox`.

## Push Gate

`git push origin master` is allowed only when:

- open P0: none
- open P1: none, or explicitly accepted non-blocking
- fresh clone validation passes, or failure is classified as non-repo and
  documented
- final commit contains only intended release/handoff changes
- final summary and artifacts are written
