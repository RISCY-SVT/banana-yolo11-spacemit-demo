#include "banana_demo/app/options.h"

#include <cstdlib>
#include <sstream>

namespace banana_demo {

namespace {

bool ParseInt(const char* text, int& out)
{
    if (!text)
        return false;
    char* end = nullptr;
    const long value = std::strtol(text, &end, 10);
    if (end == text || (end && *end != '\0'))
        return false;
    out = static_cast<int>(value);
    return true;
}

bool ParseFloat(const char* text, float& out)
{
    if (!text)
        return false;
    char* end = nullptr;
    const float value = std::strtof(text, &end);
    if (end == text || (end && *end != '\0'))
        return false;
    out = value;
    return true;
}

bool NeedValue(int i, int argc)
{
    return i + 1 < argc;
}

}  // namespace

bool ParseAppOptions(int argc, char** argv, AppOptions& options, std::string& error)
{
    for (int i = 1; i < argc; ++i)
    {
        const std::string arg = argv[i];
        if (arg == "--help" || arg == "-h")
        {
            error.clear();
            return false;
        }
        if (arg == "--model" && NeedValue(i, argc))
        {
            options.model = argv[++i];
            continue;
        }
        if (arg == "--labels" && NeedValue(i, argc))
        {
            options.labels = argv[++i];
            continue;
        }
        if (arg == "--input-size" && NeedValue(i, argc) && ParseInt(argv[++i], options.input_size))
            continue;
        if (arg == "--source" && NeedValue(i, argc))
        {
            options.source = argv[++i];
            continue;
        }
        if (arg == "--provider" && NeedValue(i, argc))
        {
            options.provider = argv[++i];
            continue;
        }
        if (arg == "--pin" && NeedValue(i, argc))
        {
            options.pin = argv[++i];
            continue;
        }
        if (arg == "--threads" && NeedValue(i, argc) && ParseInt(argv[++i], options.threads))
            continue;
        if (arg == "--conf" && NeedValue(i, argc) && ParseFloat(argv[++i], options.conf_threshold))
            continue;
        if (arg == "--iou" && NeedValue(i, argc) && ParseFloat(argv[++i], options.iou_threshold))
            continue;
        if (arg == "--display" && NeedValue(i, argc) && ParseInt(argv[++i], options.display))
            continue;
        if (arg == "--save-output" && NeedValue(i, argc))
        {
            options.save_output = argv[++i];
            continue;
        }
        if (arg == "--log-file" && NeedValue(i, argc))
        {
            options.log_file = argv[++i];
            continue;
        }
        if (arg == "--quiet" && NeedValue(i, argc) && ParseInt(argv[++i], options.quiet))
            continue;
        if (arg == "--benchmark-only" && NeedValue(i, argc) && ParseInt(argv[++i], options.benchmark_only))
            continue;
        if (arg == "--headless" && NeedValue(i, argc) && ParseInt(argv[++i], options.headless))
            continue;
        if (arg == "--camera-width" && NeedValue(i, argc) && ParseInt(argv[++i], options.camera_width))
            continue;
        if (arg == "--camera-height" && NeedValue(i, argc) && ParseInt(argv[++i], options.camera_height))
            continue;
        if (arg == "--camera-fps" && NeedValue(i, argc) && ParseInt(argv[++i], options.camera_fps))
            continue;
        if (arg == "--camera-pixfmt" && NeedValue(i, argc))
        {
            options.camera_pixfmt = argv[++i];
            continue;
        }
        if (arg == "--decode-mode" && NeedValue(i, argc))
        {
            options.decode_mode = argv[++i];
            continue;
        }
        if (arg == "--preprocess-mode" && NeedValue(i, argc))
        {
            options.preprocess_mode = argv[++i];
            continue;
        }
        if (arg == "--warmup" && NeedValue(i, argc) && ParseInt(argv[++i], options.warmup))
            continue;
        if (arg == "--runs" && NeedValue(i, argc) && ParseInt(argv[++i], options.runs))
            continue;
        if (arg == "--repeats" && NeedValue(i, argc) && ParseInt(argv[++i], options.repeats))
            continue;
        if (arg == "--strict-omp-env" && NeedValue(i, argc) && ParseInt(argv[++i], options.strict_omp_env))
            continue;
        if (arg == "--benchmark-mode" && NeedValue(i, argc))
        {
            options.benchmark_mode = argv[++i];
            continue;
        }
        if (arg == "--dump-hash" && NeedValue(i, argc) && ParseInt(argv[++i], options.dump_hash))
            continue;
        if (arg == "--dump-out" && NeedValue(i, argc))
        {
            options.dump_out = argv[++i];
            continue;
        }
        if (arg == "--max-frames" && NeedValue(i, argc) && ParseInt(argv[++i], options.max_frames))
            continue;
        if (arg == "--disable-cpu-fallback" && NeedValue(i, argc) && ParseInt(argv[++i], options.disable_cpu_fallback))
            continue;

        error = "unknown or invalid argument: " + arg;
        return false;
    }

    if (options.model.empty())
    {
        error = "--model is required";
        return false;
    }
    if (options.provider != "spacemit" && options.provider != "cpu")
    {
        error = "--provider must be spacemit|cpu";
        return false;
    }
    if (options.benchmark_mode != "forward" && options.benchmark_mode != "full")
    {
        error = "--benchmark-mode must be forward|full";
        return false;
    }
    if (options.preprocess_mode != "auto" &&
        options.preprocess_mode != "letterbox" &&
        options.preprocess_mode != "resize")
    {
        error = "--preprocess-mode must be auto|letterbox|resize";
        return false;
    }
    if (options.source.rfind("image:", 0) != 0 && options.source.rfind("camera:", 0) != 0)
    {
        error = "--source must start with image: or camera:";
        return false;
    }

    return true;
}

std::string BuildUsage()
{
    std::ostringstream oss;
    oss
        << "Usage: banana_yolo11_demo [options]\n"
        << "  --model <path>\n"
        << "  --labels <path>\n"
        << "  --input-size 320|640\n"
        << "  --source image:<path>|camera:auto|camera:/dev/videoN|camera:<index>\n"
        << "  --provider spacemit|cpu\n"
        << "  --pin cluster0|cluster1|none|list:<csv>\n"
        << "  --threads <N>\n"
        << "  --conf <float>\n"
        << "  --iou <float>\n"
        << "  --display 0|1\n"
        << "  --save-output <path>\n"
        << "  --log-file <path>\n"
        << "  --quiet 0|1\n"
        << "  --benchmark-only 0|1\n"
        << "  --benchmark-mode forward|full\n"
        << "  --headless 0|1\n"
        << "  --camera-width <N>\n"
        << "  --camera-height <N>\n"
        << "  --camera-fps <N>\n"
        << "  --camera-pixfmt auto|mjpg|yuyv\n"
        << "  --decode-mode auto|vendor|ultralytics\n"
        << "  --preprocess-mode auto|letterbox|resize\n"
        << "  --warmup <N>\n"
        << "  --runs <N>\n"
        << "  --repeats <N>\n"
        << "  --dump-hash 0|1\n"
        << "  --dump-out <path>\n"
        << "  --max-frames <N>\n"
        << '\n'
        << "Notes:\n"
        << "  - Default visual demo scripts in this repository use the generated 640x640 dynamic INT8 model.\n"
        << "  - The official vendor 320x320 INT8 model remains available as a low-latency benchmark path.\n"
        << "  - On the public tarball 2.0.1 stack, vendor 320x320 is not restored as a trusted visual default.\n"
        << "  - Custom Ultralytics/xquant models should normally use preprocess-mode=letterbox.\n"
        << "  - camera:auto prefers stable /dev/v4l/by-id or /dev/v4l/by-path capture nodes.\n"
        << '\n'
        << "Examples:\n"
        << "  banana_yolo11_demo --model models/generated/xquant_640/yolov11n_640x640.dynamic_int8.onnx "
           "--source image:photo_2024-10-11_10-04-04.jpg --input-size 640 --provider spacemit "
           "--preprocess-mode letterbox\n"
        << "  banana_yolo11_demo --model models/generated/yolov11n_640x640.q.onnx "
           "--source camera:auto --input-size 640 --camera-pixfmt mjpg --display 1 "
           "--preprocess-mode letterbox\n";
    return oss.str();
}

}  // namespace banana_demo
