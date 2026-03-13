#pragma once

#include <string>

namespace banana_demo {

struct AppOptions
{
    std::string model;
    std::string labels = "assets/coco80.txt";
    int input_size = 320;
    std::string source = "image:photo_2024-10-11_10-04-04.jpg";
    std::string provider = "spacemit";
    std::string pin = "cluster0";
    int threads = 4;
    float conf_threshold = 0.25f;
    float iou_threshold = 0.45f;
    int display = 1;
    std::string save_output;
    std::string log_file;
    int quiet = 0;
    int benchmark_only = 0;
    int headless = 0;
    int camera_width = 1280;
    int camera_height = 720;
    int camera_fps = 30;
    std::string camera_pixfmt = "auto";
    std::string decode_mode = "auto";
    std::string preprocess_mode = "auto";
    int warmup = 10;
    int runs = 100;
    int repeats = 5;
    int strict_omp_env = 1;
    std::string benchmark_mode = "forward";
    int dump_hash = 1;
    std::string dump_out;
    int max_frames = 0;
    int disable_cpu_fallback = 0;
};

bool ParseAppOptions(int argc, char** argv, AppOptions& options, std::string& error);
std::string BuildUsage();

}  // namespace banana_demo
