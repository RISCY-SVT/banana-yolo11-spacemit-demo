#pragma once

#include <onnxruntime_cxx_api.h>

#include <opencv2/core.hpp>

#include <string>
#include <unordered_map>
#include <vector>

#include "banana_demo/app/options.h"

namespace banana_demo {

struct Detection
{
    float x1 = 0.f;
    float y1 = 0.f;
    float x2 = 0.f;
    float y2 = 0.f;
    int class_id = -1;
    float score = 0.f;
};

struct FrameMetrics
{
    double preprocess_ms = 0.0;
    double inference_ms = 0.0;
    double postprocess_ms = 0.0;
    double render_ms = 0.0;
    double total_ms = 0.0;
    int objects = 0;
};

struct BenchmarkSummary
{
    double mean_ms = 0.0;
    double std_ms = 0.0;
    double fps = 0.0;
    std::string output_sha256;
    std::string detections_sha256;
};

struct InferenceResult
{
    std::vector<Detection> detections;
    FrameMetrics metrics;
    std::string output_sha256;
    std::string detections_sha256;
    cv::Mat annotated;
};

class Yolo11Detector
{
public:
    explicit Yolo11Detector(const AppOptions& options);

    InferenceResult ProcessImage(const cv::Mat& bgr, bool render_output);
    BenchmarkSummary BenchmarkImage(const cv::Mat& bgr);

    const std::vector<std::string>& Labels() const;
    int InputWidth() const;
    int InputHeight() const;
    const std::string& InputName() const;
    std::string ProviderSummary() const;

private:
    struct PreprocessInfo
    {
        int src_w = 0;
        int src_h = 0;
        int dst_w = 0;
        int dst_h = 0;
        float ratio = 1.f;
        float dw = 0.f;
        float dh = 0.f;
    };

    struct OutputTensor
    {
        std::vector<float> data;
        std::vector<int64_t> shape;
    };

    void LoadLabels();
    void ResolveInputShape();
    void BuildSession();
    bool PreprocessToNchw(const cv::Mat& bgr, std::vector<float>& nchw, PreprocessInfo& info) const;
    OutputTensor RunSingle(const std::vector<float>& nchw) const;
    std::vector<Detection> Decode(const OutputTensor& output, const PreprocessInfo& info) const;

    AppOptions options_;
    Ort::Env env_;
    Ort::SessionOptions session_options_;
    std::unique_ptr<Ort::Session> session_;
    Ort::AllocatorWithDefaultOptions allocator_;
    std::string input_name_;
    std::vector<std::string> output_names_;
    std::vector<const char*> output_name_ptrs_;
    std::vector<int64_t> input_shape_;
    int input_width_ = 0;
    int input_height_ = 0;
    std::vector<std::string> labels_;
};

}  // namespace banana_demo

