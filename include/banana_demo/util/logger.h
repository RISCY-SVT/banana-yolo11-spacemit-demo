#pragma once

#include <fstream>
#include <string>

namespace banana_demo {

class Logger
{
public:
    Logger(bool quiet, const std::string& log_path);

    void Info(const std::string& message);
    void Warn(const std::string& message);
    void Error(const std::string& message);

private:
    void Write(const char* level, const std::string& message);

    bool quiet_ = false;
    std::ofstream file_;
};

}  // namespace banana_demo

