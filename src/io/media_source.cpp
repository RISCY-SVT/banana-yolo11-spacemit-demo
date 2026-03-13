#include "banana_demo/io/media_source.h"

#include <algorithm>
#include <chrono>
#include <cctype>
#include <filesystem>
#include <system_error>

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
        return "camera:" + (camera_display_name_.empty() ? camera_path_ : camera_display_name_);
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

std::string MediaSource::PixelFormat() const
{
    return camera_pixfmt_actual_;
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
    if (!ResolveCameraTarget(error))
        return false;

    int api = ResolveCameraApi();
    bool opened = false;
    if (camera_index_ >= 0)
        opened = capture_.open(camera_index_, api);

    if (!opened && !camera_resolved_path_.empty())
        opened = capture_.open(camera_resolved_path_, api);

    if (!opened && !capture_.open(camera_path_, api))
    {
        if (!capture_.open(camera_path_))
        {
            error = "failed to open camera: " + camera_display_name_;
            return false;
        }
    }

    ApplyCameraProperties();
    camera_pixfmt_actual_ = FourccToString(static_cast<int>(capture_.get(cv::CAP_PROP_FOURCC)));
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

bool MediaSource::ResolveCameraTarget(std::string& error)
{
    camera_resolved_path_.clear();
    camera_display_name_.clear();
    camera_index_ = -1;

    std::string target = camera_path_;
    if (target.empty() || target == "auto")
    {
        static const char* kGlobs[] = {
            "/dev/v4l/by-id",
            "/dev/v4l/by-path",
        };
        for (const char* base : kGlobs)
        {
            std::error_code ec;
            if (!std::filesystem::exists(base, ec))
                continue;
            for (const auto& entry : std::filesystem::directory_iterator(base, ec))
            {
                const std::string candidate = entry.path().filename().string();
                if (candidate.find("video-index0") == std::string::npos)
                    continue;
                target = entry.path().string();
                break;
            }
            if (!target.empty() && target != "auto")
                break;
        }
        if (target.empty() || target == "auto")
        {
            error = "failed to auto-select camera: no stable /dev/v4l/by-id or /dev/v4l/by-path capture node found";
            return false;
        }
    }

    if (!target.empty() && std::all_of(target.begin(), target.end(), [](unsigned char ch) { return std::isdigit(ch); }))
    {
        camera_index_ = std::stoi(target);
        camera_resolved_path_ = "/dev/video" + target;
        camera_display_name_ = camera_resolved_path_ + " (index=" + target + ")";
        camera_path_ = target;
        return true;
    }

    camera_path_ = target;
    camera_display_name_ = target;
    camera_resolved_path_ = target;

    std::error_code ec;
    if (std::filesystem::exists(target, ec))
    {
        const std::filesystem::path canonical = std::filesystem::canonical(target, ec);
        if (!ec)
        {
            camera_resolved_path_ = canonical.string();
            camera_display_name_ = target == camera_resolved_path_ ? target : target + " -> " + camera_resolved_path_;
        }
    }

    const int parsed_index = ParseVideoIndex(camera_resolved_path_);
    if (parsed_index >= 0)
        camera_index_ = parsed_index;

    return true;
}

int MediaSource::ParseVideoIndex(const std::string& path)
{
    const std::filesystem::path fs_path(path);
    const std::string name = fs_path.filename().string();
    if (name.rfind("video", 0) != 0 || name.size() <= 5)
        return -1;

    for (size_t i = 5; i < name.size(); ++i)
    {
        if (!std::isdigit(static_cast<unsigned char>(name[i])))
            return -1;
    }

    return std::stoi(name.substr(5));
}

std::string MediaSource::FourccToString(int fourcc)
{
    if (fourcc == 0)
        return "auto";

    std::string out(4, '\0');
    out[0] = static_cast<char>(fourcc & 0xff);
    out[1] = static_cast<char>((fourcc >> 8) & 0xff);
    out[2] = static_cast<char>((fourcc >> 16) & 0xff);
    out[3] = static_cast<char>((fourcc >> 24) & 0xff);
    for (char& ch : out)
    {
        if (!std::isprint(static_cast<unsigned char>(ch)))
            ch = '?';
    }
    return out;
}

}  // namespace banana_demo
