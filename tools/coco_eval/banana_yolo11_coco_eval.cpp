/**
 * @file banana_yolo11_coco_eval.cpp
 * @brief Evaluation-only COCO JSON emitter for the Banana YOLO11 detector.
 * @details This tool reuses the production detector implementation but is not
 * part of the default demo path. It iterates a prepared COCO image list on the
 * board, writes COCO-format detection JSON, and leaves mAP calculation to the
 * official pycocotools COCOeval path on the host.
 */

#include "banana_demo/app/options.h"
#include "banana_demo/infer/detector.h"
#include "banana_demo/util/pinning.h"

#include <opencv2/imgcodecs.hpp>

#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct EvalOptions
{
    std::string model;
    std::string labels = "assets/coco80.txt";
    std::string image_root;
    std::string image_list;
    std::string category_map;
    std::string output_json;
    std::string failure_log;
    int input_size = 640;
    std::string provider = "spacemit";
    std::string pin = "cluster0";
    int threads = 4;
    float conf = 0.001f;
    float iou = 0.7f;
    int max_det = 300;
    int max_images = 0;
    int progress_every = 100;
    std::string preprocess_mode = "letterbox";
    int disable_cpu_fallback = 0;
};

struct ImageEntry
{
    int image_id = 0;
    std::string file_name;
    int width = 0;
    int height = 0;
};

bool NeedValue(int i, int argc)
{
    return i + 1 < argc;
}

int ParseInt(const char* value)
{
    char* end = nullptr;
    const long parsed = std::strtol(value, &end, 10);
    if (end == value || (end && *end != '\0'))
        throw std::runtime_error(std::string("invalid integer: ") + value);
    return static_cast<int>(parsed);
}

float ParseFloat(const char* value)
{
    char* end = nullptr;
    const float parsed = std::strtof(value, &end);
    if (end == value || (end && *end != '\0'))
        throw std::runtime_error(std::string("invalid float: ") + value);
    return parsed;
}

std::string Usage()
{
    return R"(Usage:
  banana_yolo11_coco_eval --model <onnx> --labels <coco80.txt>
    --image-root <val2017-dir> --image-list <image_list.tsv>
    --category-map <category_map.tsv> --output-json <predictions.json>

Required:
  --model <path>             ONNX model path
  --image-root <dir>         COCO val2017 image root
  --image-list <tsv>         image_id<TAB>file_name<TAB>width<TAB>height
  --category-map <tsv>       class_index<TAB>category_id<TAB>name
  --output-json <path>       COCO detection JSON path

Optional:
  --labels <path>            label file aligned to model class ids
  --input-size <N>           runtime input size, default 640
  --provider spacemit|cpu    provider, default spacemit
  --pin <policy>             cluster0|cluster1|none|list:<csv>
  --threads <N>              intra-op threads, default 4
  --conf <float>             detection threshold for AP curves, default 0.001
  --iou <float>              NMS IoU, default 0.7
  --max-det <N>              per-image max detections, default 300
  --max-images <N>           zero means all images
  --progress-every <N>       progress interval, default 100
  --preprocess-mode <mode>   auto|letterbox|resize, default letterbox
  --disable-cpu-fallback 0|1 pass through to ORT session config
  --failure-log <path>       optional failed image list
)";
}

EvalOptions ParseArgs(int argc, char** argv)
{
    EvalOptions options;
    for (int i = 1; i < argc; ++i)
    {
        const std::string arg = argv[i];
        if (arg == "--help" || arg == "-h")
        {
            std::cout << Usage();
            std::exit(0);
        }
        if (arg == "--model" && NeedValue(i, argc))
            options.model = argv[++i];
        else if (arg == "--labels" && NeedValue(i, argc))
            options.labels = argv[++i];
        else if (arg == "--image-root" && NeedValue(i, argc))
            options.image_root = argv[++i];
        else if (arg == "--image-list" && NeedValue(i, argc))
            options.image_list = argv[++i];
        else if (arg == "--category-map" && NeedValue(i, argc))
            options.category_map = argv[++i];
        else if (arg == "--output-json" && NeedValue(i, argc))
            options.output_json = argv[++i];
        else if (arg == "--failure-log" && NeedValue(i, argc))
            options.failure_log = argv[++i];
        else if (arg == "--input-size" && NeedValue(i, argc))
            options.input_size = ParseInt(argv[++i]);
        else if (arg == "--provider" && NeedValue(i, argc))
            options.provider = argv[++i];
        else if (arg == "--pin" && NeedValue(i, argc))
            options.pin = argv[++i];
        else if (arg == "--threads" && NeedValue(i, argc))
            options.threads = ParseInt(argv[++i]);
        else if (arg == "--conf" && NeedValue(i, argc))
            options.conf = ParseFloat(argv[++i]);
        else if (arg == "--iou" && NeedValue(i, argc))
            options.iou = ParseFloat(argv[++i]);
        else if (arg == "--max-det" && NeedValue(i, argc))
            options.max_det = ParseInt(argv[++i]);
        else if (arg == "--max-images" && NeedValue(i, argc))
            options.max_images = ParseInt(argv[++i]);
        else if (arg == "--progress-every" && NeedValue(i, argc))
            options.progress_every = ParseInt(argv[++i]);
        else if (arg == "--preprocess-mode" && NeedValue(i, argc))
            options.preprocess_mode = argv[++i];
        else if (arg == "--disable-cpu-fallback" && NeedValue(i, argc))
            options.disable_cpu_fallback = ParseInt(argv[++i]);
        else
            throw std::runtime_error("unknown or invalid argument: " + arg);
    }

    if (options.model.empty() || options.image_root.empty() || options.image_list.empty() ||
        options.category_map.empty() || options.output_json.empty())
        throw std::runtime_error("missing required argument\n" + Usage());
    if (options.provider != "spacemit" && options.provider != "cpu")
        throw std::runtime_error("--provider must be spacemit|cpu");
    if (options.max_det <= 0)
        throw std::runtime_error("--max-det must be positive");
    return options;
}

std::vector<std::string> SplitTab(const std::string& line)
{
    std::vector<std::string> fields;
    size_t start = 0;
    while (start <= line.size())
    {
        const size_t pos = line.find('\t', start);
        if (pos == std::string::npos)
        {
            fields.push_back(line.substr(start));
            break;
        }
        fields.push_back(line.substr(start, pos - start));
        start = pos + 1;
    }
    return fields;
}

std::vector<ImageEntry> LoadImageList(const std::string& path)
{
    std::ifstream ifs(path);
    if (!ifs)
        throw std::runtime_error("failed to open image list: " + path);
    std::vector<ImageEntry> entries;
    std::string line;
    while (std::getline(ifs, line))
    {
        if (line.empty() || line[0] == '#')
            continue;
        const auto fields = SplitTab(line);
        if (fields.size() < 4)
            throw std::runtime_error("invalid image-list line: " + line);
        ImageEntry entry;
        entry.image_id = std::stoi(fields[0]);
        entry.file_name = fields[1];
        entry.width = std::stoi(fields[2]);
        entry.height = std::stoi(fields[3]);
        entries.push_back(std::move(entry));
    }
    return entries;
}

std::map<int, int> LoadCategoryMap(const std::string& path)
{
    std::ifstream ifs(path);
    if (!ifs)
        throw std::runtime_error("failed to open category map: " + path);
    std::map<int, int> mapping;
    std::string line;
    while (std::getline(ifs, line))
    {
        if (line.empty() || line[0] == '#')
            continue;
        const auto fields = SplitTab(line);
        if (fields.size() < 2)
            throw std::runtime_error("invalid category-map line: " + line);
        mapping[std::stoi(fields[0])] = std::stoi(fields[1]);
    }
    return mapping;
}

void WriteJsonDetection(std::ostream& os,
                        bool& first,
                        int image_id,
                        int category_id,
                        const banana_demo::Detection& det)
{
    if (!first)
        os << ",\n";
    first = false;
    const float x = det.x1;
    const float y = det.y1;
    const float w = std::max(0.0f, det.x2 - det.x1);
    const float h = std::max(0.0f, det.y2 - det.y1);
    os << std::fixed << std::setprecision(6)
       << "{\"image_id\":" << image_id
       << ",\"category_id\":" << category_id
       << ",\"bbox\":[" << x << ',' << y << ',' << w << ',' << h << ']'
       << ",\"score\":" << det.score << '}';
}

banana_demo::AppOptions BuildDetectorOptions(const EvalOptions& eval)
{
    banana_demo::AppOptions options;
    options.model = eval.model;
    options.labels = eval.labels;
    options.input_size = eval.input_size;
    options.source = "image:unused.jpg";
    options.provider = eval.provider;
    options.pin = eval.pin;
    options.threads = eval.threads;
    options.conf_threshold = eval.conf;
    options.iou_threshold = eval.iou;
    options.display = 0;
    options.headless = 1;
    options.quiet = 1;
    options.preprocess_mode = eval.preprocess_mode;
    options.disable_cpu_fallback = eval.disable_cpu_fallback;
    return options;
}

}  // namespace

int main(int argc, char** argv)
{
    try
    {
        const EvalOptions eval = ParseArgs(argc, argv);
        std::vector<int> pin_cpus;
        std::vector<int> cluster0;
        std::vector<int> cluster1;
        std::string error;
        if (!banana_demo::EnsureStrictOmpEnv(1, error))
            throw std::runtime_error(error);
        if (!banana_demo::PreparePinCpus(eval.pin, pin_cpus, cluster0, cluster1, error))
            throw std::runtime_error(error);
        if (!banana_demo::ApplyProcessAffinity(pin_cpus, error))
            throw std::runtime_error(error);

        const auto images = LoadImageList(eval.image_list);
        const auto category_map = LoadCategoryMap(eval.category_map);
        const size_t image_count = eval.max_images > 0
            ? std::min<size_t>(images.size(), static_cast<size_t>(eval.max_images))
            : images.size();

        const auto app_options = BuildDetectorOptions(eval);
        banana_demo::Yolo11Detector detector(app_options);
        std::filesystem::create_directories(std::filesystem::path(eval.output_json).parent_path());
        std::ofstream out(eval.output_json);
        if (!out)
            throw std::runtime_error("failed to open output JSON: " + eval.output_json);

        std::ofstream failures;
        if (!eval.failure_log.empty())
        {
            std::filesystem::create_directories(std::filesystem::path(eval.failure_log).parent_path());
            failures.open(eval.failure_log);
        }

        std::cerr << "coco_eval_start"
                  << " provider=" << eval.provider
                  << " model=" << eval.model
                  << " image_root=" << eval.image_root
                  << " images=" << image_count
                  << " conf=" << eval.conf
                  << " iou=" << eval.iou
                  << " max_det=" << eval.max_det
                  << " threads=" << eval.threads
                  << " pin=" << eval.pin
                  << '\n';
        std::cerr << detector.ProviderSummary() << '\n';

        out << "[\n";
        bool first_json = true;
        size_t processed = 0;
        size_t failed = 0;
        size_t total_detections = 0;
        const auto start = std::chrono::steady_clock::now();

        for (size_t idx = 0; idx < image_count; ++idx)
        {
            const auto& entry = images[idx];
            const std::filesystem::path image_path = std::filesystem::path(eval.image_root) / entry.file_name;
            cv::Mat image = cv::imread(image_path.string(), cv::IMREAD_COLOR);
            if (image.empty())
            {
                ++failed;
                if (failures)
                    failures << entry.image_id << '\t' << entry.file_name << "\tread_failed\n";
                continue;
            }

            banana_demo::InferenceResult result = detector.ProcessImage(image, false);
            auto detections = std::move(result.detections);
            std::sort(detections.begin(), detections.end(), [](const auto& a, const auto& b) {
                return a.score > b.score;
            });
            if (detections.size() > static_cast<size_t>(eval.max_det))
                detections.resize(static_cast<size_t>(eval.max_det));

            for (const auto& det : detections)
            {
                auto mapped = category_map.find(det.class_id);
                if (mapped == category_map.end())
                    continue;
                WriteJsonDetection(out, first_json, entry.image_id, mapped->second, det);
                ++total_detections;
            }
            ++processed;

            if (eval.progress_every > 0 && (processed == 1 || processed % static_cast<size_t>(eval.progress_every) == 0))
            {
                const auto now = std::chrono::steady_clock::now();
                const double elapsed_s = std::chrono::duration<double>(now - start).count();
                std::cerr << "progress processed=" << processed
                          << " failed=" << failed
                          << " detections=" << total_detections
                          << " elapsed_s=" << std::fixed << std::setprecision(3) << elapsed_s
                          << '\n';
            }
        }

        out << "\n]\n";
        const auto end = std::chrono::steady_clock::now();
        const double elapsed_s = std::chrono::duration<double>(end - start).count();
        std::cerr << "coco_eval_done processed=" << processed
                  << " failed=" << failed
                  << " detections=" << total_detections
                  << " elapsed_s=" << std::fixed << std::setprecision(3) << elapsed_s
                  << " images_per_s=" << (elapsed_s > 0.0 ? static_cast<double>(processed) / elapsed_s : 0.0)
                  << '\n';
        return failed == 0 ? 0 : 3;
    }
    catch (const Ort::Exception& ex)
    {
        std::cerr << "ORT exception: " << ex.what() << '\n';
        return 2;
    }
    catch (const std::exception& ex)
    {
        std::cerr << "ERROR: " << ex.what() << '\n';
        return 2;
    }
}
