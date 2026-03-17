/**
 * @file detector.h
 * @brief YOLO11 inference and post-processing interfaces.
 * @details Declares the detector-facing data structures that are shared between
 * the inference, rendering, benchmarking, and application layers.
 */

#pragma once

#include <onnxruntime_cxx_api.h>

#include <opencv2/core.hpp>

#include <string>
#include <unordered_map>
#include <vector>

#include "banana_demo/app/options.h"

namespace banana_demo {

/**
 * @brief Single decoded object detection in source-image coordinates.
 */
struct Detection
{
    /** Left edge of the bounding box in source-image pixels. */
    float x1 = 0.f;
    /** Top edge of the bounding box in source-image pixels. */
    float y1 = 0.f;
    /** Right edge of the bounding box in source-image pixels. */
    float x2 = 0.f;
    /** Bottom edge of the bounding box in source-image pixels. */
    float y2 = 0.f;
    /** Zero-based class index after decode. */
    int class_id = -1;
    /** Final confidence score after decode and before/after NMS. */
    float score = 0.f;
};

/**
 * @brief Per-frame timing breakdown used by live mode and rendered overlays.
 */
struct FrameMetrics
{
    /** Camera capture plus backend decode time in milliseconds. */
    double capture_ms = 0.0;
    /** Input preprocessing time in milliseconds. */
    double preprocess_ms = 0.0;
    /** Runtime inference latency in milliseconds. */
    double inference_ms = 0.0;
    /** Decode plus NMS latency in milliseconds. */
    double postprocess_ms = 0.0;
    /** Rendering and display overlay time in milliseconds. */
    double render_ms = 0.0;
    /** End-to-end frame latency in milliseconds. */
    double total_ms = 0.0;
    /** Number of detections kept after decode and NMS. */
    int objects = 0;
};

/**
 * @brief Aggregate benchmark result across all repeats.
 */
struct BenchmarkSummary
{
    /** Mean latency in milliseconds across repeats. */
    double mean_ms = 0.0;
    /** Standard deviation of repeat means in milliseconds. */
    double std_ms = 0.0;
    /** Reciprocal throughput derived from @ref mean_ms. */
    double fps = 0.0;
    /** SHA256 of the final raw output tensor bytes. */
    std::string output_sha256;
    /** SHA256 of the final decoded detection list. */
    std::string detections_sha256;
};

/**
 * @brief Full result of one inference pass.
 */
struct InferenceResult
{
    /** Final decoded detections. */
    std::vector<Detection> detections;
    /** Timing breakdown for the processed frame. */
    FrameMetrics metrics;
    /** SHA256 of the raw output tensor bytes. */
    std::string output_sha256;
    /** SHA256 of the decoded detections. */
    std::string detections_sha256;
    /** Annotated frame produced by the renderer, if requested. */
    cv::Mat annotated;
};

/**
 * @brief Thin ONNX Runtime based YOLO11 detector wrapper.
 * @details The detector owns the runtime session, enforces the repository's
 * preprocess contract, and converts raw output tensors into semantic
 * detections.
 */
class Yolo11Detector
{
public:
    /**
     * @brief Construct the detector and build its runtime session.
     * @param options Immutable application options snapshot.
     */
    explicit Yolo11Detector(const AppOptions& options);

    /**
     * @brief Run one full inference pass on a BGR frame.
     * @param bgr Input frame in OpenCV BGR layout.
     * @param render_output Reserved compatibility flag for future render-side
     *     paths.
     * @return Raw output hashes, decoded detections, and timing metrics.
     */
    InferenceResult ProcessImage(const cv::Mat& bgr, bool render_output);
    /**
     * @brief Benchmark the detector on one image.
     * @param bgr Input frame in OpenCV BGR layout.
     * @return Aggregate latency statistics and final output hashes.
     */
    BenchmarkSummary BenchmarkImage(const cv::Mat& bgr);

    /** @brief Access the loaded class labels. */
    const std::vector<std::string>& Labels() const;
    /** @brief Return the resolved runtime input width. */
    int InputWidth() const;
    /** @brief Return the resolved runtime input height. */
    int InputHeight() const;
    /** @brief Return the runtime input tensor name. */
    const std::string& InputName() const;
    /** @brief Format a short provider/runtime summary for logs. */
    std::string ProviderSummary() const;

private:
    /**
     * @brief Supported preprocessing contracts.
     * @details Vendor320 and the dynamic640 path both use letterbox as the
     * repository truth source unless the caller forces resize explicitly.
     */
    enum class PreprocessMode
    {
        /** Keep aspect ratio and pad to the runtime input size. */
        kLetterbox,
        /** Force a direct resize to the runtime input size. */
        kResize,
    };

    /**
     * @brief Geometry metadata describing how preprocessing transformed a frame.
     */
    struct PreprocessInfo
    {
        /** Original source width in pixels. */
        int src_w = 0;
        /** Original source height in pixels. */
        int src_h = 0;
        /** Final tensor width in pixels. */
        int dst_w = 0;
        /** Final tensor height in pixels. */
        int dst_h = 0;
        /** X-axis scaling factor to map tensor coordinates back to source space. */
        float scale_x = 1.f;
        /** Y-axis scaling factor to map tensor coordinates back to source space. */
        float scale_y = 1.f;
        /** Horizontal padding inserted by letterbox preprocessing. */
        float pad_x = 0.f;
        /** Vertical padding inserted by letterbox preprocessing. */
        float pad_y = 0.f;
        /** Active preprocess mode for this frame. */
        PreprocessMode mode = PreprocessMode::kLetterbox;
    };

    /**
     * @brief Raw output tensor materialized in host memory.
     */
    struct OutputTensor
    {
        /** Flattened tensor data in float32. */
        std::vector<float> data;
        /** Runtime-reported tensor shape. */
        std::vector<int64_t> shape;
    };

    /** @brief Load class labels from @ref AppOptions::labels. */
    void LoadLabels();
    /** @brief Resolve the runtime input tensor shape after session creation. */
    void ResolveInputShape();
    /** @brief Build the ONNX Runtime session and provider chain. */
    void BuildSession();
    /** @brief Resolve the effective preprocess contract from user options. */
    PreprocessMode ResolvePreprocessMode() const;
    /**
     * @brief Convert a BGR frame to normalized NCHW float input.
     * @param bgr Input frame in OpenCV BGR layout.
     * @param nchw Output tensor buffer in NCHW float layout.
     * @param info Output preprocessing geometry metadata.
     * @return `true` on success, `false` for empty input.
     */
    bool PreprocessToNchw(const cv::Mat& bgr, std::vector<float>& nchw, PreprocessInfo& info) const;
    /**
     * @brief Execute one runtime inference pass.
     * @param nchw Input tensor prepared by @ref PreprocessToNchw.
     * @return First output tensor from the runtime session.
     */
    OutputTensor RunSingle(const std::vector<float>& nchw) const;
    /**
     * @brief Decode one raw runtime output tensor to final detections.
     * @param output Raw output tensor from @ref RunSingle.
     * @param info Preprocessing geometry used to restore source coordinates.
     * @return NMS-filtered detections in source-image coordinates.
     */
    std::vector<Detection> Decode(const OutputTensor& output, const PreprocessInfo& info) const;

    /** Immutable per-run configuration snapshot. */
    AppOptions options_;
    /** Global ONNX Runtime environment. */
    Ort::Env env_;
    /** Session configuration including provider wiring and graph options. */
    Ort::SessionOptions session_options_;
    /** Active inference session. */
    std::unique_ptr<Ort::Session> session_;
    /** Convenience allocator for runtime-owned strings. */
    Ort::AllocatorWithDefaultOptions allocator_;
    /** Cached runtime input tensor name. */
    std::string input_name_;
    /** Cached output tensor names. */
    std::vector<std::string> output_names_;
    /** Stable `const char*` view of @ref output_names_ for ORT APIs. */
    std::vector<const char*> output_name_ptrs_;
    /** Runtime-reported input tensor shape. */
    std::vector<int64_t> input_shape_;
    /** Runtime-reported input tensor element type. */
    ONNXTensorElementDataType input_element_type_ = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
    /** Runtime-reported first output tensor element type. */
    ONNXTensorElementDataType output_element_type_ = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
    /** Resolved input tensor width in pixels. */
    int input_width_ = 0;
    /** Resolved input tensor height in pixels. */
    int input_height_ = 0;
    /** Whether the runtime metadata had to be repaired from a known model contract. */
    bool metadata_fallback_applied_ = false;
    /** Human-readable explanation of the applied metadata fallback, if any. */
    std::string metadata_fallback_reason_;
    /** Loaded label list aligned with decoded class ids. */
    std::vector<std::string> labels_;
};

}  // namespace banana_demo
