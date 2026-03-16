/**
 * @file sha256.h
 * @brief Small SHA256 helpers used for reproducibility and output hashing.
 */

#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace banana_demo {

/**
 * @brief Hash a raw byte range to lowercase hexadecimal SHA256.
 * @param data Input byte pointer, or `nullptr` when `len == 0`.
 * @param len Number of bytes to hash.
 * @return Lowercase hexadecimal SHA256 text.
 */
std::string Sha256Hex(const uint8_t* data, size_t len);
/**
 * @brief Hash a byte vector to lowercase hexadecimal SHA256.
 * @param data Input bytes.
 * @return Lowercase hexadecimal SHA256 text.
 */
std::string Sha256Hex(const std::vector<uint8_t>& data);

}  // namespace banana_demo
