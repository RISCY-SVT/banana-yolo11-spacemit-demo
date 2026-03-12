#pragma once

#include <string>
#include <vector>

namespace banana_demo {

bool EnsureStrictOmpEnv(int strict_mode, std::string& error);
bool PreparePinCpus(const std::string& pin_spec,
                    std::vector<int>& pin_cpus,
                    std::vector<int>& cluster0_cpus,
                    std::vector<int>& cluster1_cpus,
                    std::string& error);
bool ApplyProcessAffinity(const std::vector<int>& cpus, std::string& error);
std::vector<int> CurrentAffinity();
std::string FormatCpuList(const std::vector<int>& cpus);

}  // namespace banana_demo

