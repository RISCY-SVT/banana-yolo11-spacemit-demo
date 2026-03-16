/**
 * @file application.cpp
 * @brief Top-level image and camera execution flow for the demo binary.
 */

#include "banana_demo/app/application.h"

#include "banana_demo/infer/detector.h"
#include "banana_demo/io/media_source.h"
#include "banana_demo/render/renderer.h"
#include "banana_demo/util/logger.h"
#include "banana_demo/util/pinning.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/videoio.hpp>

#include <chrono>
#include <filesystem>
#include <iostream>
#include <sstream>

namespace banana_demo {

namespace {

/** @brief Return whether the current run may attempt HighGUI display output. */
bool IsDisplayPossible(const AppOptions& options)
{
    if (!options.display || options.headless)
        return false;
    const char* display = std::getenv("DISPLAY");
    const char* wayland = std::getenv("WAYLAND_DISPLAY");
    return (display && *display) || (wayland && *wayland);
}

/** @brief Render booleans as `0` or `1` for compact logs. */
std::string BoolWord(bool value)
{
    return value ? "1" : "0";
}

/** @brief Return an environment variable or `<unset>` for diagnostics. */
std::string EnvOrUnset(const char* name)
{
    const char* value = std::getenv(name);
    return value && *value ? value : "<unset>";
}

/** @brief Query the active HighGUI backend, if OpenCV exposes one. */
std::string CurrentUiBackend()
{
    try
    {
        const std::string backend = cv::currentUIFramework();
        return backend.empty() ? "<none>" : backend;
    }
    catch (const cv::Exception&)
    {
        return "<error>";
    }
}

/** @brief Format a one-line display environment summary. */
std::string FormatDisplaySummary(const AppOptions& options, bool display_enabled)
{
    std::ostringstream oss;
    oss << "display_requested=" << options.display
        << " headless_requested=" << options.headless
        << " display_enabled=" << BoolWord(display_enabled)
        << " ui_backend=" << CurrentUiBackend()
        << " DISPLAY=" << EnvOrUnset("DISPLAY")
        << " WAYLAND_DISPLAY=" << EnvOrUnset("WAYLAND_DISPLAY")
        << " XDG_SESSION_TYPE=" << EnvOrUnset("XDG_SESSION_TYPE");
    return oss.str();
}

/** @brief Format per-frame metrics for logs and summaries. */
std::string FormatFrameMetrics(const FrameMetrics& metrics)
{
    std::ostringstream oss;
    oss.setf(std::ios::fixed);
    oss.precision(3);
    oss << "objects=" << metrics.objects
        << " capture_ms=" << metrics.capture_ms
        << " preprocess_ms=" << metrics.preprocess_ms
        << " inference_ms=" << metrics.inference_ms
        << " postprocess_ms=" << metrics.postprocess_ms
        << " render_ms=" << metrics.render_ms
        << " total_ms=" << metrics.total_ms
        << " fps=" << (metrics.total_ms > 0.0 ? 1000.0 / metrics.total_ms : 0.0);
    return oss.str();
}

/** @brief Pick the effective output path for image mode. */
std::string ResolveOutputPath(const AppOptions& options, const std::string& default_name)
{
    if (!options.save_output.empty())
        return options.save_output;
    return default_name;
}

/** @brief Return whether a camera save path should be treated as a still image. */
bool IsStillImagePath(const std::string& path)
{
    if (path.empty())
        return false;
    const std::string ext = std::filesystem::path(path).extension().string();
    return ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".bmp";
}

/**
 * @brief Show an immediate preview frame while the first inference is still warming up.
 */
bool ShowWarmupPreview(Renderer& renderer, const cv::Mat& frame, std::string& error)
{
    cv::Mat preview = frame.clone();
    cv::putText(preview, "Warming up inference...", cv::Point(20, 40),
                cv::FONT_HERSHEY_SIMPLEX, 0.9, cv::Scalar(0, 255, 255), 2, cv::LINE_AA);
    return renderer.TryShow("banana_yolo11_demo_camera", preview, error);
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
        // Benchmark mode bypasses rendering so results stay comparable with perf_test.
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
    bool display_enabled = IsDisplayPossible(options_);
    // The image path always performs one full process + render pass and then optionally shows it.
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

    logger.Info(FormatDisplaySummary(options_, display_enabled));

    if (display_enabled)
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
    logger.Info("camera_open_method=" + source.OpenMethod());
    logger.Info("camera_backend=" + source.BackendName());
    logger.Info("camera_size=" + std::to_string(source.FrameWidth()) + "x" + std::to_string(source.FrameHeight()));
    logger.Info("camera_fps=" + std::to_string(source.Fps()));
    logger.Info("camera_pixfmt=" + source.PixelFormat());
    logger.Info(detector.ProviderSummary());
    bool display_enabled = IsDisplayPossible(options_);
    logger.Info(FormatDisplaySummary(options_, display_enabled));
    if (display_enabled)
        logger.Info("camera display mode active; press ESC/q in the preview window to exit");
    else if (options_.display && !options_.headless)
        logger.Warn("display requested but GUI session variables are missing; switching to headless progress logging");
    else
        logger.Info("camera running in headless mode; periodic progress logs enabled and Ctrl-C stops the loop");
    logger.Info("camera max_frames=" + std::to_string(options_.max_frames) +
                " save_output=" + (options_.save_output.empty() ? std::string("<disabled>") : options_.save_output));
    logger.Info("camera warmup note: the first inference can take noticeably longer while the runtime prepares the graph");

    cv::VideoWriter writer;
    cv::Mat saved_still_frame;
    const bool save_still_frame = IsStillImagePath(options_.save_output);
    if (!options_.save_output.empty())
    {
        // Camera mode keeps video recording opt-in, but also supports a single
        // annotated still when the requested output path has an image suffix.
        if (save_still_frame)
        {
            logger.Info("camera save_output mode=still-image");
        }
        else
        {
            const int fourcc = cv::VideoWriter::fourcc('M', 'J', 'P', 'G');
            if (!writer.open(options_.save_output, fourcc,
                             std::max(1, options_.camera_fps),
                             cv::Size(std::max(1, source.FrameWidth()), std::max(1, source.FrameHeight()))))
            {
                logger.Warn("failed to open video writer: " + options_.save_output);
            }
        }
    }

    int frame_index = 0;
    auto loop_start = std::chrono::steady_clock::now();
    auto last_progress_log = loop_start;
    bool first_frame_notice_emitted = false;
    bool display_ready_logged = false;
    bool warmup_preview_logged = false;
    while (true)
    {
        cv::Mat frame;
        if (!source.Read(frame))
        {
            logger.Warn("camera read failed or stream ended");
            break;
        }

        if (!first_frame_notice_emitted)
        {
            logger.Info("first frame captured; starting inference now");
            first_frame_notice_emitted = true;
            if (display_enabled)
            {
                if (!ShowWarmupPreview(renderer, frame, error))
                {
                    logger.Warn("display failed before first inference, disabling display: " + error);
                    display_enabled = false;
                }
                else if (!warmup_preview_logged)
                {
                    logger.Info("warmup preview shown while inference initializes");
                    warmup_preview_logged = true;
                }
            }
        }

        InferenceResult result = detector.ProcessImage(frame, false);
        result.metrics.capture_ms = source.LastReadMs();
        const auto render_begin = std::chrono::steady_clock::now();
        result.annotated = renderer.Draw(frame, result.detections, detector.Labels(), result.metrics);
        const auto render_end = std::chrono::steady_clock::now();
        result.metrics.render_ms = std::chrono::duration<double, std::milli>(render_end - render_begin).count();
        result.metrics.total_ms += result.metrics.render_ms;

        if (writer.isOpened())
            writer.write(result.annotated);
        if (save_still_frame)
            // Retain only the latest annotated frame so `MAX_FRAMES=1` can
            // produce a deterministic still capture without enabling video I/O.
            saved_still_frame = result.annotated.clone();

        if (display_enabled)
        {
            // Interactive mode keeps the preview responsive and exits on q/ESC.
            if (!renderer.TryShow("banana_yolo11_demo_camera", result.annotated, error))
            {
                logger.Warn("display failed, disabling display: " + error);
                display_enabled = false;
            }
            else
            {
                if (!display_ready_logged)
                {
                    logger.Info("display active, live preview should now be visible; press ESC/q to exit");
                    display_ready_logged = true;
                }
                const int key = cv::waitKey(1);
                if (key == 27 || key == 'q' || key == 'Q')
                    break;
            }
        }

        ++frame_index;
        const auto now = std::chrono::steady_clock::now();
        // Headless mode still emits progress so a slow first inference never looks like a hang.
        const bool timed_progress = !display_enabled &&
                                    std::chrono::duration_cast<std::chrono::seconds>(now - last_progress_log).count() >= 5;
        if (frame_index == 1 || frame_index % 10 == 0 || timed_progress)
        {
            logger.Info("frame=" + std::to_string(frame_index) + " " + FormatFrameMetrics(result.metrics));
            last_progress_log = now;
        }

        if (options_.max_frames > 0 && frame_index >= options_.max_frames)
            break;
    }

    const auto loop_end = std::chrono::steady_clock::now();
    const double elapsed_ms = std::chrono::duration<double, std::milli>(loop_end - loop_start).count();
    logger.Info("camera_frames=" + std::to_string(frame_index) +
                " total_loop_ms=" + std::to_string(elapsed_ms) +
                " effective_fps=" + std::to_string(frame_index > 0 && elapsed_ms > 0.0 ? 1000.0 * frame_index / elapsed_ms : 0.0));

    if (save_still_frame)
    {
        if (saved_still_frame.empty())
        {
            logger.Warn("save_output requested a still image but no annotated frame was captured");
        }
        else if (!cv::imwrite(options_.save_output, saved_still_frame))
        {
            logger.Warn("failed to save still image: " + options_.save_output);
        }
        else
        {
            logger.Info("saved_output=" + options_.save_output);
        }
    }

    return 0;
}

}  // namespace banana_demo
