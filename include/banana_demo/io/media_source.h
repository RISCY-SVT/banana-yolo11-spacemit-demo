#pragma once

#include <opencv2/core.hpp>
#include <opencv2/videoio.hpp>

#include <string>

#include "banana_demo/app/options.h"

namespace banana_demo {

class MediaSource
{
public:
    explicit MediaSource(const AppOptions& options);
    ~MediaSource();

    bool Open(std::string& error);
    bool IsImage() const;
    bool IsCamera() const;
    std::string Describe() const;
    bool Read(cv::Mat& frame);
    double LastReadMs() const;
    int FrameWidth() const;
    int FrameHeight() const;
    double Fps() const;
    std::string PixelFormat() const;

private:
    bool OpenImage(std::string& error);
    bool OpenCamera(std::string& error);
    int ResolveCameraApi() const;
    bool ResolveCameraTarget(std::string& error);
    void ApplyCameraProperties();
    int ResolveFourcc() const;
    static int ParseVideoIndex(const std::string& path);
    static std::string FourccToString(int fourcc);

    AppOptions options_;
    bool is_image_ = false;
    bool is_camera_ = false;
    std::string image_path_;
    std::string camera_path_;
    std::string camera_resolved_path_;
    std::string camera_display_name_;
    std::string camera_pixfmt_actual_ = "unknown";
    int camera_index_ = -1;
    cv::Mat image_;
    cv::VideoCapture capture_;
    double last_read_ms_ = 0.0;
};

}  // namespace banana_demo
