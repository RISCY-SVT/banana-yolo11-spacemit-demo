# COCO mAP and Stable FPS Summary

This is the authoritative final production validation summary for the post-tag COCO/FPS pass. The production tag `production-2026-07-02` remains at `9c0933be58ee122389d1a43f45f81e80655d6904`; runtime/model policy is unchanged.

## COCO mAP

|Candidate|Runtime|Status|Images|Detections|AP@[.50:.95]|AP50|AP75|AP_small|AP_medium|AP_large|AR1|AR10|AR100|
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|Primary dynamic640 INT8|rt201|production primary|5000|691410|0.384006|0.539212|0.419599|0.191668|0.420989|0.556876|0.307861|0.505896|0.556047|
|Vendor320 trusted visual|rt123|fast-live / trusted visual|5000|330235|0.211281|0.333139|0.225284|0.037406|0.204024|0.413734|0.209826|0.340494|0.369700|
|Vendor320 rt201 visual workaround|rt201|non-default workaround|5000|514015|0.216324|0.337841|0.234206|0.042726|0.218581|0.400563|0.212091|0.336105|0.364450|

## Stable FPS

|Category|Variant|Runtime|Metric class|Resolution|Mean ms|Std ms|FPS|Status|
|---|---|---|---|---|---:|---:|---:|---|
|production primary|dynamic640 INT8|rt201|perf_test forward|640|187.507000|N/A|5.332970|production primary|
|production primary|dynamic640 INT8|rt201|app forward-only|640|188.257498|0.071248|5.311873|production primary|
|production primary|dynamic640 INT8|rt201|app full image|640|229.651583|0.568951|4.354422|production primary|
|camera|normal camera dynamic640 INT8|rt201|camera effective|1280x720 capture, 640 inference|N/A|N/A|2.400594|production normal camera|
|camera|normal camera dynamic640 INT8|rt201|camera instantaneous|1280x720 capture, 640 inference|239.763000|N/A|4.171000|production normal camera|
|fast-live|vendor320 INT8|rt123|camera effective|640x480 capture, 320 inference|N/A|N/A|10.508203|production fast-live|
|fast-live|vendor320 INT8|rt123|camera instantaneous|640x480 capture, 320 inference|66.492000|N/A|15.039000|production fast-live|
|trusted visual|vendor320 INT8|rt123|perf_test forward|320|48.069200|N/A|20.787800|trusted visual / fast-live|
|trusted visual|vendor320 INT8|rt123|app forward-only|320|48.617629|0.013438|20.568671|trusted visual / fast-live|
|trusted visual|vendor320 INT8|rt123|app full image|320|56.815375|0.106610|17.600870|trusted visual / fast-live|
|perf-only|vendor320 raw INT8|rt201|perf_test forward|320|24.372600|N/A|41.020200|low-latency perf only, not visual default|
|perf-only|vendor320 raw INT8|rt201|app forward-only|320|24.872159|0.019449|40.205597|low-latency perf only, not visual default|
|workaround|vendor320 INT8 visual workaround|rt201|app full image|320|33.007326|0.043991|30.296304|non-default workaround|
|experimental|FP16 keep_io 640|rt201/rt202b1|app forward-only|640|see prior FPS summary|N/A|see prior FPS summary|experimental only|
|rejected|stable rt202|rt202|fail/rejected|N/A|N/A|N/A|N/A|not adopted|
|rejected|YOLO26n|N/A|fail/rejected|640|N/A|N/A|N/A|not production|

Raw artifacts are stored under `/data/ncnn-logs/ort-logs/2026-07-01_10-44-19` and are intentionally not committed when large.
