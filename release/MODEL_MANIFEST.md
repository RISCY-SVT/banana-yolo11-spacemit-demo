# Model Manifest

Model provenance is pinned or described in:

```text
third_party_manifest/models.lock
models/README.md
docs/RESULTS.md
```

## Production Models

| Model | Path | SHA256 | Role |
|---|---|---:|---|
| Dynamic640 INT8 | `models/generated/xquant_640/yolov11n_640x640.dynamic_int8.onnx` | `d028fca47600213be18f876d23aef92ef39c3bb1b4bc6b76963e0be679f5467f` | primary visual |
| Vendor320 INT8 | `models/vendor/yolo11/yolov11n_320x320.q.onnx` | `558011431ba1cd26269af3694abc2ee2fc2d467d7fe043e10df78ed7449d9edc` | trusted visual on `rt123`, perf on `rt201` |

## Experimental Models

| Model | Path | SHA256 | Status |
|---|---|---:|---|
| FP16 640 keep_io | `models/generated/fp16/yolov11n_640x640.fp16_iop32.onnx` | `4742625978c4b5cc25282bf02890837fcea7762d5536fe55e583311ce9b14593` | usable on `rt201`/`rt202b1`, experimental |
| FP16 320 keep_io | `models/generated/fp16/yolov11n_320x320.fp16_iop32.onnx` | `3291474d7a8e40bc0fabf6feb054942675f562dab0c04666bddd47662eb27b69` | known fail on current public stack |

## Non-Production Candidates

YOLO26n remains a P2 candidate. It is not a production path for the 2026-07-02
handoff.
