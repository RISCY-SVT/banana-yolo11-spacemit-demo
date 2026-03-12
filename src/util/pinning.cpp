#include "banana_demo/util/pinning.h"

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fstream>
#include <sched.h>
#include <set>
#include <string>
#include <unistd.h>
#include <vector>

extern char** environ;

namespace banana_demo {

namespace {

bool ParseInt(const std::string& text, int& out)
{
    if (text.empty())
        return false;
    char* end = nullptr;
    const long value = std::strtol(text.c_str(), &end, 10);
    if (end == text.c_str() || (end && *end != '\0'))
        return false;
    out = static_cast<int>(value);
    return true;
}

bool ParseCpuListString(const std::string& text, std::vector<int>& cpus, std::string& error)
{
    cpus.clear();
    size_t i = 0;
    while (i < text.size())
    {
        while (i < text.size() && (text[i] == ',' || std::isspace(static_cast<unsigned char>(text[i]))))
            ++i;
        if (i >= text.size())
            break;

        size_t j = i;
        while (j < text.size() && text[j] != ',')
            ++j;
        std::string token = text.substr(i, j - i);
        token.erase(token.begin(), std::find_if(token.begin(), token.end(), [](unsigned char ch) { return !std::isspace(ch); }));
        token.erase(std::find_if(token.rbegin(), token.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), token.end());
        if (token.empty())
        {
            error = "empty cpu token";
            return false;
        }

        const size_t dash = token.find('-');
        if (dash != std::string::npos)
        {
            int a = 0;
            int b = 0;
            if (!ParseInt(token.substr(0, dash), a) || !ParseInt(token.substr(dash + 1), b) || a < 0 || b < a)
            {
                error = "invalid cpu range: " + token;
                return false;
            }
            for (int cpu = a; cpu <= b; ++cpu)
                cpus.push_back(cpu);
        }
        else
        {
            int cpu = 0;
            if (!ParseInt(token, cpu) || cpu < 0)
            {
                error = "invalid cpu id: " + token;
                return false;
            }
            cpus.push_back(cpu);
        }

        i = j + 1;
    }

    if (cpus.empty())
    {
        error = "cpu list resolved empty";
        return false;
    }

    std::sort(cpus.begin(), cpus.end());
    cpus.erase(std::unique(cpus.begin(), cpus.end()), cpus.end());
    return true;
}

bool ReadFirstLine(const std::string& path, std::string& out, std::string& error)
{
    std::ifstream ifs(path);
    if (!ifs)
    {
        error = "failed to open " + path + ": " + std::strerror(errno);
        return false;
    }
    std::getline(ifs, out);
    if (ifs.fail())
    {
        error = "failed to read " + path;
        return false;
    }
    while (!out.empty() && std::isspace(static_cast<unsigned char>(out.back())))
        out.pop_back();
    return true;
}

bool ReadCpu0L2SharedList(std::string& out, std::string& error)
{
    const char* base = "/sys/devices/system/cpu/cpu0/cache";
    DIR* dir = opendir(base);
    if (!dir)
    {
        error = std::string("opendir failed: ") + base + ": " + std::strerror(errno);
        return false;
    }

    bool found = false;
    dirent* ent = nullptr;
    while ((ent = readdir(dir)) != nullptr)
    {
        if (std::strncmp(ent->d_name, "index", 5) != 0)
            continue;

        std::string level;
        std::string read_error;
        const std::string level_path = std::string(base) + "/" + ent->d_name + "/level";
        if (!ReadFirstLine(level_path, level, read_error))
            continue;
        if (level != "2")
            continue;

        const std::string shared_path = std::string(base) + "/" + ent->d_name + "/shared_cpu_list";
        if (!ReadFirstLine(shared_path, out, error))
        {
            closedir(dir);
            return false;
        }

        found = true;
        break;
    }

    closedir(dir);
    if (!found)
    {
        error = "L2 shared_cpu_list for cpu0 not found";
        return false;
    }

    return true;
}

bool ReadOnlineCpuList(std::vector<int>& cpus, std::string& error)
{
    std::string online;
    if (!ReadFirstLine("/sys/devices/system/cpu/online", online, error))
        return false;
    return ParseCpuListString(online, cpus, error);
}

}  // namespace

bool EnsureStrictOmpEnv(int strict_mode, std::string& error)
{
    if (!strict_mode)
        return true;

    if (!environ)
        return true;

    std::vector<std::string> vars;
    for (char** env = environ; *env; ++env)
    {
        const char* e = *env;
        if (std::strncmp(e, "OMP_", 4) == 0 || std::strncmp(e, "GOMP_", 5) == 0)
            vars.emplace_back(e);
    }

    if (vars.empty())
        return true;

    error = "OMP_/GOMP_ environment variables are set:";
    for (const auto& var : vars)
        error += " " + var;
    return false;
}

bool PreparePinCpus(const std::string& pin_spec,
                    std::vector<int>& pin_cpus,
                    std::vector<int>& cluster0_cpus,
                    std::vector<int>& cluster1_cpus,
                    std::string& error)
{
    pin_cpus.clear();
    cluster0_cpus.clear();
    cluster1_cpus.clear();

    std::string cluster0_list;
    if (!ReadCpu0L2SharedList(cluster0_list, error))
        return false;
    if (!ParseCpuListString(cluster0_list, cluster0_cpus, error))
        return false;

    std::vector<int> online;
    if (!ReadOnlineCpuList(online, error))
        return false;

    const std::set<int> c0(cluster0_cpus.begin(), cluster0_cpus.end());
    for (int cpu : online)
    {
        if (c0.find(cpu) == c0.end())
            cluster1_cpus.push_back(cpu);
    }

    if (pin_spec == "none")
        return true;
    if (pin_spec == "cluster0")
    {
        pin_cpus = cluster0_cpus;
        return true;
    }
    if (pin_spec == "cluster1")
    {
        if (cluster1_cpus.empty())
        {
            error = "cluster1 resolved empty";
            return false;
        }
        pin_cpus = cluster1_cpus;
        return true;
    }

    std::string list = pin_spec;
    if (list.rfind("list:", 0) == 0)
        list = list.substr(5);
    return ParseCpuListString(list, pin_cpus, error);
}

bool ApplyProcessAffinity(const std::vector<int>& cpus, std::string& error)
{
    if (cpus.empty())
        return true;

    cpu_set_t set;
    CPU_ZERO(&set);
    for (int cpu : cpus)
    {
        if (cpu < 0 || cpu >= CPU_SETSIZE)
        {
            error = "cpu id out of range: " + std::to_string(cpu);
            return false;
        }
        CPU_SET(cpu, &set);
    }

    if (sched_setaffinity(0, sizeof(set), &set) != 0)
    {
        error = std::string("sched_setaffinity failed: ") + std::strerror(errno);
        return false;
    }

    return true;
}

std::vector<int> CurrentAffinity()
{
    std::vector<int> cpus;
    cpu_set_t set;
    CPU_ZERO(&set);
    if (sched_getaffinity(0, sizeof(set), &set) != 0)
        return cpus;

    for (int i = 0; i < CPU_SETSIZE; ++i)
    {
        if (CPU_ISSET(i, &set))
            cpus.push_back(i);
    }
    return cpus;
}

std::string FormatCpuList(const std::vector<int>& cpus)
{
    if (cpus.empty())
        return "(none)";

    std::string text;
    for (size_t i = 0; i < cpus.size(); ++i)
    {
        if (i)
            text += ",";
        text += std::to_string(cpus[i]);
    }
    return text;
}

}  // namespace banana_demo
