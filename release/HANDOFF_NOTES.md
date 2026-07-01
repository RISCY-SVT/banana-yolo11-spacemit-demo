# Handoff Notes

## Operator Summary

Use dynamic640 INT8 on `rt201` for production visual quality. Use fast-live
vendor320 on `rt123` when responsiveness matters more than 640 visual quality.
For the consolidated FPS/latency matrix and metric-class caveats, read
`release/FPS_SUMMARY.md`. For final post-tag full COCO mAP and stable FPS
evidence, read `release/COCO_MAP_FPS_SUMMARY.md` and the bilingual final
production reports.

## Logs and Mirror

Production-readiness logs use:

```text
/data/ncnn-logs/ort-logs/YYYY-MM-DD_HH-MM-SS/
```

The expected Google Drive managed mirror path is:

```text
bf3-ncnn/data/banana-yolo11-spacemit-demo
```

Drive sync should preserve repo docs, release artifacts, and the timestamped log
run directories without exporting private local agent state.

Container-side acceptance does not prove the Google Drive mirror by itself. The
host operator must run the host-side rclone sync/check and record the result.
The current expected status before that host action is
`pending-host-verification`.

## Rollback

If a Day 3 handoff commit causes an issue, roll back to the Day 2 baseline:

```text
d202cdf76ce3e0742a665396a6eb157e5b3efe5e
```

Then rerun build/deploy and the bounded smoke matrix before handoff.
