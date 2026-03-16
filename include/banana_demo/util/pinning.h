/**
 * @file pinning.h
 * @brief CPU affinity and strict OpenMP environment helpers for K1X runs.
 */

#pragma once

#include <string>
#include <vector>

namespace banana_demo {

/**
 * @brief Refuse execution when stray OMP/GOMP variables would break reproducibility.
 * @param strict_mode Enable strict checking when non-zero.
 * @param error Human-readable failure reason.
 * @return `true` if the environment is acceptable.
 */
bool EnsureStrictOmpEnv(int strict_mode, std::string& error);
/**
 * @brief Resolve the requested CPU pinning specification.
 * @param pin_spec Pinning selector such as `cluster0`, `cluster1`, `none`, or
 *     `list:<csv>`.
 * @param pin_cpus Output CPU list to pin the process to.
 * @param cluster0_cpus Output list describing the low-power cluster.
 * @param cluster1_cpus Output list describing the remaining online CPUs.
 * @param error Human-readable failure reason.
 * @return `true` on success.
 */
bool PreparePinCpus(const std::string& pin_spec,
                    std::vector<int>& pin_cpus,
                    std::vector<int>& cluster0_cpus,
                    std::vector<int>& cluster1_cpus,
                    std::string& error);
/**
 * @brief Apply process affinity to the requested CPUs.
 * @param cpus CPU ids to keep in the affinity mask.
 * @param error Human-readable failure reason.
 * @return `true` on success.
 */
bool ApplyProcessAffinity(const std::vector<int>& cpus, std::string& error);
/** @brief Return the current process CPU affinity mask. */
std::vector<int> CurrentAffinity();
/** @brief Format a CPU list for logs. */
std::string FormatCpuList(const std::vector<int>& cpus);

}  // namespace banana_demo
