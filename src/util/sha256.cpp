#include "banana_demo/util/sha256.h"

#include <array>
#include <cstring>

namespace banana_demo {

namespace {

struct Sha256State
{
    uint32_t h[8];
    uint64_t bit_len;
    uint8_t buffer[64];
    size_t buffer_len;
};

constexpr uint32_t kSha256K[64] = {
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
    0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u, 0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
    0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu, 0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
    0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
    0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u, 0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u, 0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
    0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
    0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u, 0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u,
};

inline uint32_t Rotr32(uint32_t x, uint32_t n)
{
    return (x >> n) | (x << (32 - n));
}

void Sha256Init(Sha256State& s)
{
    s.h[0] = 0x6a09e667u;
    s.h[1] = 0xbb67ae85u;
    s.h[2] = 0x3c6ef372u;
    s.h[3] = 0xa54ff53au;
    s.h[4] = 0x510e527fu;
    s.h[5] = 0x9b05688cu;
    s.h[6] = 0x1f83d9abu;
    s.h[7] = 0x5be0cd19u;
    s.bit_len = 0;
    s.buffer_len = 0;
}

void Sha256Transform(Sha256State& s, const uint8_t* block)
{
    uint32_t w[64];
    for (int i = 0; i < 16; ++i)
    {
        w[i] = (static_cast<uint32_t>(block[i * 4]) << 24)
             | (static_cast<uint32_t>(block[i * 4 + 1]) << 16)
             | (static_cast<uint32_t>(block[i * 4 + 2]) << 8)
             | (static_cast<uint32_t>(block[i * 4 + 3]));
    }

    for (int i = 16; i < 64; ++i)
    {
        const uint32_t s0 = Rotr32(w[i - 15], 7) ^ Rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3);
        const uint32_t s1 = Rotr32(w[i - 2], 17) ^ Rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }

    uint32_t a = s.h[0];
    uint32_t b = s.h[1];
    uint32_t c = s.h[2];
    uint32_t d = s.h[3];
    uint32_t e = s.h[4];
    uint32_t f = s.h[5];
    uint32_t g = s.h[6];
    uint32_t h = s.h[7];

    for (int i = 0; i < 64; ++i)
    {
        const uint32_t s1 = Rotr32(e, 6) ^ Rotr32(e, 11) ^ Rotr32(e, 25);
        const uint32_t ch = (e & f) ^ ((~e) & g);
        const uint32_t temp1 = h + s1 + ch + kSha256K[i] + w[i];
        const uint32_t s0 = Rotr32(a, 2) ^ Rotr32(a, 13) ^ Rotr32(a, 22);
        const uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        const uint32_t temp2 = s0 + maj;

        h = g;
        g = f;
        f = e;
        e = d + temp1;
        d = c;
        c = b;
        b = a;
        a = temp1 + temp2;
    }

    s.h[0] += a;
    s.h[1] += b;
    s.h[2] += c;
    s.h[3] += d;
    s.h[4] += e;
    s.h[5] += f;
    s.h[6] += g;
    s.h[7] += h;
}

void Sha256Update(Sha256State& s, const uint8_t* data, size_t len)
{
    if (!data || len == 0)
        return;

    for (size_t i = 0; i < len; ++i)
    {
        s.buffer[s.buffer_len++] = data[i];
        if (s.buffer_len == 64)
        {
            Sha256Transform(s, s.buffer);
            s.bit_len += 512;
            s.buffer_len = 0;
        }
    }
}

std::array<uint8_t, 32> Sha256Final(Sha256State& s)
{
    std::array<uint8_t, 32> out{};
    size_t i = s.buffer_len;

    if (s.buffer_len < 56)
    {
        s.buffer[i++] = 0x80u;
        while (i < 56)
            s.buffer[i++] = 0;
    }
    else
    {
        s.buffer[i++] = 0x80u;
        while (i < 64)
            s.buffer[i++] = 0;
        Sha256Transform(s, s.buffer);
        std::memset(s.buffer, 0, 56);
    }

    s.bit_len += static_cast<uint64_t>(s.buffer_len) * 8ull;
    s.buffer[63] = static_cast<uint8_t>(s.bit_len);
    s.buffer[62] = static_cast<uint8_t>(s.bit_len >> 8);
    s.buffer[61] = static_cast<uint8_t>(s.bit_len >> 16);
    s.buffer[60] = static_cast<uint8_t>(s.bit_len >> 24);
    s.buffer[59] = static_cast<uint8_t>(s.bit_len >> 32);
    s.buffer[58] = static_cast<uint8_t>(s.bit_len >> 40);
    s.buffer[57] = static_cast<uint8_t>(s.bit_len >> 48);
    s.buffer[56] = static_cast<uint8_t>(s.bit_len >> 56);
    Sha256Transform(s, s.buffer);

    for (int j = 0; j < 4; ++j)
    {
        for (int k = 0; k < 8; ++k)
            out[j + k * 4] = static_cast<uint8_t>((s.h[k] >> (24 - j * 8)) & 0xffu);
    }

    return out;
}

}  // namespace

std::string Sha256Hex(const uint8_t* data, size_t len)
{
    Sha256State state;
    Sha256Init(state);
    Sha256Update(state, data, len);
    const auto out = Sha256Final(state);
    static const char kHex[] = "0123456789abcdef";
    std::string text;
    text.resize(64);
    for (size_t i = 0; i < out.size(); ++i)
    {
        text[i * 2] = kHex[(out[i] >> 4) & 0x0f];
        text[i * 2 + 1] = kHex[out[i] & 0x0f];
    }
    return text;
}

std::string Sha256Hex(const std::vector<uint8_t>& data)
{
    return Sha256Hex(data.empty() ? nullptr : data.data(), data.size());
}

}  // namespace banana_demo

