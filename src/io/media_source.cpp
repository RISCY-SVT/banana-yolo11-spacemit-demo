#include "banana_demo/io/media_source.h"

#include <chrono>
#include <filesystem>

#include <opencv2/imgcodecs.hpp>

namespace banana_demo {

MediaSource::MediaSource(const AppOptions& options) : options_(options) {}

MediaSource::~MediaSource()
{
    if (capture_.isOpened())
        capture_.release();
}

bool MediaSource::Open(std::string& error)
{
    if (options_.source.rfind("image:", 0) == 0)
    {
        is_image_ = true;
        image_path_ = options_.source.substr(6);
        return OpenImage(error);
    }

    if (options_.source.rfind("camera:", 0) == 0)
    {
        is_camera_ = true;
        camera_path_ = options_.source.substr(7);
        return OpenCamera(error);
    }

    error = "unsupported source: " + options_.source;
    return false;
}

bool MediaSource::IsImage() const
{
    return is_image_;
}

bool MediaSource::IsCamera() const
{
    return is_camera_;
}

std::string MediaSource::Describe() const
{
    if (is_image_)
        return "image:" + image_path_;
    if (is_camera_)
        return "camera:" + camera_path_;
    return options_.source;
}

bool MediaSource::Read(cv::Mat& frame)
{
    const auto start = std::chrono::steady_clock::now();
    if (is_image_)
    {
        frame = image_.clone();
    }
    else if (is_camera_)
    {
        if (!capture_.read(frame))
            return false;
    }
    else
    {
        return false;
    }
    const auto end = std::chrono::steady_clock::now();
    last_read_ms_ = std::chrono::duration<double, std::milli>(end - start).count();
    return !frame.empty();
}

double MediaSource::LastReadMs() const
{
    return last_read_ms_;
}

int MediaSource::FrameWidth() const
{
    if (is_image_)
        return image_.cols;
    if (is_camera_)
        return static_cast<int>(capture_.get(cv::CAP_PROP_FRAME_WIDTH));
    return 0;
}

int MediaSource::FrameHeight() const
{
    if (is_image_)
        return image_.rows;
    if (is_camera_)
        return static_cast<int>(capture_.get(cv::CAP_PROP_FRAME_HEIGHT));
    return 0;
}

double MediaSource::Fps() const
{
    if (is_camera_)
        return capture_.get(cv::CAP_PROP_FPS);
    return 0.0;
}

bool MediaSource::OpenImage(std::string& error)
{
    image_ = cv::imread(image_path_, cv::IMREAD_COLOR);
    if (image_.empty())
    {
        error = "failed to read image: " + image_path_;
        return false;
    }
    return true;
}

bool MediaSource::OpenCamera(std::string& error)
{
    int api = ResolveCameraApi();
    if (!capture_.open(camera_path_, api))
    {
        if (!capture_.open(camera_path_))
        {
            error = "failed to open camera: " + camera_path_;
            return false;
        }
    }

    ApplyCameraProperties();
    return true;
}

int MediaSource::ResolveCameraApi() const
{
    return cv::CAP_V4L2;
}

void MediaSource::ApplyCameraProperties()
{
    capture_.set(cv::CAP_PROP_FRAME_WIDTH, options_.camera_width);
    capture_.set(cv::CAP_PROP_FRAME_HEIGHT, options_.camera_height);
    capture_.set(cv::CAP_PROP_FPS, options_.camera_fps);

    const int fourcc = ResolveFourcc();
    if (fourcc != 0)
        capture_.set(cv::CAP_PROP_FOURCC, fourcc);
}

int MediaSource::ResolveFourcc() const
{
    if (options_.camera_pixfmt == "mjpg")
        return cv::VideoWriter::fourcc('M', 'J', 'P', 'G');
    if (options_.camera_pixfmt == "yuyv")
        return cv::VideoWriter::fourcc('Y', 'U', 'Y', 'V');
    return 0;
}

}  // namespace banana_demo
