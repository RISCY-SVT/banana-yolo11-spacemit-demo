#pragma once

#include <opencv2/core.hpp>

#include <string>
#include <vector>

#include "banana_demo/infer/detector.h"

namespace banana_demo {

class Renderer
{
public:
    Renderer();

    cv::Mat Draw(const cv::Mat& image, const std::vector<Detection>& detections,
                 const std::vector<std::string>& labels, const FrameMetrics& metrics) const;
    bool TryShow(const std::string& window_name, const cv::Mat& image, std::string& error);
};

}  // namespace banana_demo

