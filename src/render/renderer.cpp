#include "banana_demo/render/renderer.h"

#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>

#include <array>
#include <sstream>

namespace banana_demo {

namespace {

cv::Scalar ColorForClass(int class_id)
{
    static const std::array<cv::Scalar, 10> kPalette = {
        cv::Scalar(255, 99, 71), cv::Scalar(60, 179, 113), cv::Scalar(30, 144, 255),
        cv::Scalar(255, 215, 0), cv::Scalar(138, 43, 226), cv::Scalar(255, 105, 180),
        cv::Scalar(0, 206, 209), cv::Scalar(255, 140, 0), cv::Scalar(46, 139, 87),
        cv::Scalar(70, 130, 180),
    };
    return kPalette[static_cast<size_t>(class_id >= 0 ? class_id : 0) % kPalette.size()];
}

std::string LabelForDetection(const Detection& det, const std::vector<std::string>& labels)
{
    std::ostringstream oss;
    if (det.class_id >= 0 && det.class_id < static_cast<int>(labels.size()))
        oss << labels[det.class_id];
    else
        oss << "class_" << det.class_id;
    oss.setf(std::ios::fixed);
    oss.precision(2);
    oss << " " << det.score;
    return oss.str();
}

}  // namespace

Renderer::Renderer() = default;

cv::Mat Renderer::Draw(const cv::Mat& image, const std::vector<Detection>& detections,
                       const std::vector<std::string>& labels, const FrameMetrics& metrics) const
{
    cv::Mat out = image.clone();
    for (const auto& det : detections)
    {
        const cv::Scalar color = ColorForClass(det.class_id);
        const cv::Point p1(static_cast<int>(det.x1), static_cast<int>(det.y1));
        const cv::Point p2(static_cast<int>(det.x2), static_cast<int>(det.y2));
        cv::rectangle(out, p1, p2, color, 2);
        const std::string text = LabelForDetection(det, labels);
        cv::putText(out, text, cv::Point(p1.x, std::max(18, p1.y - 6)),
                    cv::FONT_HERSHEY_SIMPLEX, 0.55, color, 2, cv::LINE_AA);
    }

    std::ostringstream oss;
    oss.setf(std::ios::fixed);
    oss.precision(2);
    oss << "obj=" << metrics.objects
        << " pre=" << metrics.preprocess_ms
        << " inf=" << metrics.inference_ms
        << " post=" << metrics.postprocess_ms
        << " total=" << metrics.total_ms
        << " fps=" << (metrics.total_ms > 0.0 ? 1000.0 / metrics.total_ms : 0.0);
    cv::putText(out, oss.str(), cv::Point(20, 30), cv::FONT_HERSHEY_SIMPLEX, 0.6,
                cv::Scalar(0, 255, 255), 2, cv::LINE_AA);

    return out;
}

bool Renderer::TryShow(const std::string& window_name, const cv::Mat& image, std::string& error)
{
    try
    {
        cv::namedWindow(window_name, cv::WINDOW_NORMAL);
        cv::imshow(window_name, image);
        return true;
    }
    catch (const cv::Exception& e)
    {
        error = e.what();
        return false;
    }
}

}  // namespace banana_demo

