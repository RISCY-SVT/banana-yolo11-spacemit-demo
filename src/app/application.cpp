#include "banana_demo/app/application.h"

#include "banana_demo/infer/detector.h"
#include "banana_demo/io/media_source.h"
#include "banana_demo/render/renderer.h"
#include "banana_demo/util/logger.h"
#include "banana_demo/util/pinning.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/videoio.hpp>

#include <chrono>
#include <filesystem>
#include <iostream>
#include <sstream>

namespace banana_demo {

namespace {

bool IsDisplayPossible(const AppOptions& options)
{
    if (!options.display || options.headless)
        return false;
    const char* display = std::getenv("DISPLAY");
    const char* wayland = std::getenv("WAYLAND_DISPLAY");
    return (display && *display) || (wayland && *wayland);
}

std::string FormatFrameMetrics(const FrameMetrics& metrics)
{
    std::ostringstream oss;
    oss.setf(std::ios::fixed);
    oss.precision(3);
    oss << "objects=" << metrics.objects
        << " preprocess_ms=" << metrics.preprocess_ms
        << " inference_ms=" << metrics.inference_ms
        << " postprocess_ms=" << metrics.postprocess_ms
        << " render_ms=" << metrics.render_ms
        << " total_ms=" << metrics.total_ms
        << " fps=" << (metrics.total_ms > 0.0 ? 1000.0 / metrics.total_ms : 0.0);
    return oss.str();
}

std::string ResolveOutputPath(const AppOptions& options, const std::string& default_name)
{
    if (!options.save_output.empty())
        return options.save_output;
    return default_name;
}

}  // namespace

Application::Application(AppOptions options) : options_(std::move(options)) {}

int Application::Run()
{
    if (options_.source.rfind("image:", 0) == 0)
        return RunImageMode();
    if (options_.source.rfind("camera:", 0) == 0)
        return RunCameraMode();
    std::cerr << "ERROR: unsupported source " << options_.source << '\n';
    return 2;
}

int Application::RunImageMode()
{
    Logger logger(options_.quiet != 0, options_.log_file);
    std::string error;
    if (!EnsureStrictOmpEnv(options_.strict_omp_env, error))
    {
        logger.Error(error);
        return 2;
    }

    std::vector<int> pin_cpus;
    std::vector<int> cluster0;
    std::vector<int> cluster1;
    if (!PreparePinCpus(options_.pin, pin_cpus, cluster0, cluster1, error))
    {
        logger.Error(error);
        return 2;
    }
    if (!ApplyProcessAffinity(pin_cpus, error))
    {
        logger.Error(error);
        return 2;
    }

    logger.Info("affinity=" + FormatCpuList(CurrentAffinity()));
    logger.Info("cluster0=" + FormatCpuList(cluster0) + " cluster1=" + FormatCpuList(cluster1));
    if (options_.provider == "spacemit" && options_.source.rfind("image:", 0) == 0 && options_.input_size > 0)
    {
        logger.Info("reference: vendor forward-only numbers should be compared with perf_test, not with full pipeline mode");
    }

    MediaSource source(options_);
    if (!source.Open(error))
    {
        logger.Error(error);
        return 2;
    }

    cv::Mat frame;
    if (!source.Read(frame))
    {
        logger.Error("failed to read image frame");
        return 2;
    }

    Yolo11Detector detector(options_);
    logger.Info(detector.ProviderSummary());

    if (options_.benchmark_only)
    {
        const BenchmarkSummary summary = detector.BenchmarkImage(frame);
        std::cout.setf(std::ios::fixed);
        std::cout.precision(6);
        std::cout << "RESULT provider=" << options_.provider
                  << " model=" << options_.model
                  << " source=" << options_.source
                  << " mode=" << options_.benchmark_mode
                  << " threads=" << options_.threads
                  << " pin=" << options_.pin
                  << " warmup=" << options_.warmup
                  << " runs=" << options_.runs
                  << " repeats=" << options_.repeats
                  << " mean_ms=" << summary.mean_ms
                  << " std_ms=" << summary.std_ms
                  << " fps=" << summary.fps
                  << '\n';
        if (options_.dump_hash)
        {
            std::cout << "HASH output0_sha256=" << summary.output_sha256 << '\n';
            if (!summary.detections_sha256.empty())
                std::cout << "HASH detections_sha256=" << summary.detections_sha256 << '\n';
        }
        return 0;
    }

    Renderer renderer;
    InferenceResult result = detector.ProcessImage(frame, false);
    const auto render_begin = std::chrono::steady_clock::now();
    result.annotated = renderer.Draw(frame, result.detections, detector.Labels(), result.metrics);
    const auto render_end = std::chrono::steady_clock::now();
    result.metrics.render_ms = std::chrono::duration<double, std::milli>(render_end - render_begin).count();
    result.metrics.total_ms += result.metrics.render_ms;

    logger.Info(FormatFrameMetrics(result.metrics));
    logger.Info("output_sha256=" + result.output_sha256);
    logger.Info("detections_sha256=" + result.detections_sha256);

    if (!options_.save_output.empty())
    {
        const std::string output_path = ResolveOutputPath(options_, "annotated.jpg");
        if (!cv::imwrite(output_path, result.annotated))
        {
            logger.Error("failed to save output image: " + output_path);
            return 2;
        }
        logger.Info("saved_output=" + output_path);
    }

    if (IsDisplayPossible(options_))
    {
        if (!renderer.TryShow("banana_yolo11_demo", result.annotated, error))
        {
            logger.Warn("display failed, falling back to headless: " + error);
        }
        else
        {
            logger.Info("display active, press any key to exit");
            cv::waitKey(0);
        }
    }
    else if (options_.display && !options_.headless)
    {
        logger.Warn("display requested but DISPLAY/WAYLAND_DISPLAY is not set; headless fallback engaged");
    }

    return 0;
}

int Application::RunCameraMode()
{
    if (options_.benchmark_only)
    {
        std::cerr << "ERROR: benchmark-only mode is supported for image sources only\n";
        return 2;
    }

    Logger logger(options_.quiet != 0, options_.log_file);
    std::string error;
    if (!EnsureStrictOmpEnv(options_.strict_omp_env, error))
    {
        logger.Error(error);
        return 2;
    }

    std::vector<int> pin_cpus;
    std::vector<int> cluster0;
    std::vector<int> cluster1;
    if (!PreparePinCpus(options_.pin, pin_cpus, cluster0, cluster1, error))
    {
        logger.Error(error);
        return 2;
    }
    if (!ApplyProcessAffinity(pin_cpus, error))
    {
        logger.Error(error);
        return 2;
    }

    MediaSource source(options_);
    if (!source.Open(error))
    {
        logger.Error(error);
        return 2;
    }

    Yolo11Detector detector(options_);
    Renderer renderer;
    logger.Info("camera_source=" + source.Describe());
    logger.Info("camera_size=" + std::to_string(source.FrameWidth()) + "x" + std::to_string(source.FrameHeight()));
    logger.Info("camera_fps=" + std::to_string(source.Fps()));
    logger.Info(detector.ProviderSummary());

    cv::VideoWriter writer;
    if (!options_.save_output.empty())
    {
        const int fourcc = cv::VideoWriter::fourcc('M', 'J', 'P', 'G');
        if (!writer.open(options_.save_output, fourcc,
                         std::max(1, options_.camera_fps),
                         cv::Size(std::max(1, source.FrameWidth()), std::max(1, source.FrameHeight()))))
        {
            logger.Warn("failed to open video writer: " + options_.save_output);
        }
    }

    const bool display_enabled = IsDisplayPossible(options_);
    int frame_index = 0;
    auto loop_start = std::chrono::steady_clock::now();
    while (true)
    {
        cv::Mat frame;
        if (!source.Read(frame))
        {
            logger.Warn("camera read failed or stream ended");
            break;
        }

        InferenceResult result = detector.ProcessImage(frame, false);
        const auto render_begin = std::chrono::steady_clock::now();
        result.annotated = renderer.Draw(frame, result.detections, detector.Labels(), result.metrics);
        const auto render_end = std::chrono::steady_clock::now();
        result.metrics.render_ms = std::chrono::duration<double, std::milli>(render_end - render_begin).count();
        result.metrics.total_ms += result.metrics.render_ms;

        if (writer.isOpened())
            writer.write(result.annotated);

        if (display_enabled)
        {
            if (!renderer.TryShow("banana_yolo11_demo_camera", result.annotated, error))
            {
                logger.Warn("display failed, disabling display: " + error);
            }
            else
            {
                const int key = cv::waitKey(1);
                if (key == 27 || key == 'q' || key == 'Q')
                    break;
            }
        }

        ++frame_index;
        if (frame_index % 10 == 0)
            logger.Info("frame=" + std::to_string(frame_index) + " " + FormatFrameMetrics(result.metrics));

        if (options_.max_frames > 0 && frame_index >= options_.max_frames)
            break;
    }

    const auto loop_end = std::chrono::steady_clock::now();
    const double elapsed_ms = std::chrono::duration<double, std::milli>(loop_end - loop_start).count();
    logger.Info("camera_frames=" + std::to_string(frame_index) +
                " total_loop_ms=" + std::to_string(elapsed_ms) +
                " effective_fps=" + std::to_string(frame_index > 0 && elapsed_ms > 0.0 ? 1000.0 * frame_index / elapsed_ms : 0.0));

    return 0;
}

}  // namespace banana_demo
