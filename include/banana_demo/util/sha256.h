#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace banana_demo {

std::string Sha256Hex(const uint8_t* data, size_t len);
std::string Sha256Hex(const std::vector<uint8_t>& data);

}  // namespace banana_demo

