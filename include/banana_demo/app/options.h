/**
 * @file options.h
 * @brief CLI option structures and parsing helpers for the demo executable.
 */

#pragma once

#include <string>

namespace banana_demo {

/**
 * @brief Runtime options parsed from the CLI or helper scripts.
 */
struct AppOptions
{
    /** ONNX model path. */
    std::string model;
    /** Label file path aligned with decoded class ids. */
    std::string labels = "assets/coco80.txt";
    /** Requested square input size used by scripts and fallback logic. */
    int input_size = 320;
    /** Source URI: `image:<path>` or `camera:<path|index|auto>`. */
    std::string source = "image:photo_2024-10-11_10-04-04.jpg";
    /** Runtime provider name, `spacemit` or `cpu`. */
    std::string provider = "spacemit";
    /** CPU pinning policy understood by the K1X helpers. */
    std::string pin = "cluster0";
    /** Intra-op thread count. */
    int threads = 4;
    /** Detection confidence threshold. */
    float conf_threshold = 0.25f;
    /** NMS IoU threshold. */
    float iou_threshold = 0.45f;
    /** Whether display output is requested. */
    int display = 1;
    /** Optional image or video output path. */
    std::string save_output;
    /** Optional log file path. */
    std::string log_file;
    /** Reduce console logging when non-zero. */
    int quiet = 0;
    /** Benchmark-only path for image sources. */
    int benchmark_only = 0;
    /** Force headless mode when non-zero. */
    int headless = 0;
    /** Requested camera width in pixels. */
    int camera_width = 1280;
    /** Requested camera height in pixels. */
    int camera_height = 720;
    /** Requested camera FPS. */
    int camera_fps = 30;
    /** Requested camera pixel format. */
    std::string camera_pixfmt = "auto";
    /** Decode contract selection used for advanced forensics. */
    std::string decode_mode = "auto";
    /** Preprocess contract selection. */
    std::string preprocess_mode = "auto";
    /** Warmup run count for benchmarks. */
    int warmup = 10;
    /** Measured runs per benchmark repeat. */
    int runs = 100;
    /** Repeat count for benchmark statistics. */
    int repeats = 5;
    /** Enforce clean OMP/GOMP state before execution. */
    int strict_omp_env = 1;
    /** Benchmark scope: `forward` or `full`. */
    std::string benchmark_mode = "forward";
    /** Enable raw output hash emission. */
    int dump_hash = 1;
    /** Optional raw output tensor dump path. */
    std::string dump_out;
    /** Maximum processed frames for camera mode, or zero for unbounded. */
    int max_frames = 0;
    /** Disable CPU fallback when the vendor EP should own all supported nodes. */
    int disable_cpu_fallback = 0;
};

/**
 * @brief Parse CLI arguments into @ref AppOptions.
 * @param argc Process argument count.
 * @param argv Process argument vector.
 * @param options Parsed output options.
 * @param error Human-readable error message on failure.
 * @return `true` on success, `false` on error or `--help`.
 */
bool ParseAppOptions(int argc, char** argv, AppOptions& options, std::string& error);
/** @brief Build the executable usage text. */
std::string BuildUsage();

}  // namespace banana_demo
