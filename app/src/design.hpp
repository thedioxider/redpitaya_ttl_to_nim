// The FPGA design's facts from design.info, and the delay register they define.
// gpio_addr/gpio_size are left out: they only go into the overlay; the controller finds the
// GPIO through UIO by name.
#pragma once

#include <cstdint>
#include <map>
#include <string>

struct Design {
    std::string name;  // bitstream, UIO device and loaded-FPGA marker name
    uint32_t tick_ps;  // one coarse step
    uint32_t coarse_bits;
    uint32_t fine_bits;  // fine step = tick_ps / 2^fine_bits
};

// Validates design.info's values; on failure, err names the bad key.
bool parse_design(const std::map<std::string, std::string>& values, Design& out, std::string& err);

// The largest value that fits in bits (bits <= 32).
uint32_t max_steps(uint32_t bits);

uint32_t clamp_steps(uint32_t steps, uint32_t bits);

// The GPIO register value: coarse above fine, each clamped to its width.
uint32_t compose_register(const Design& design, uint32_t coarse, uint32_t fine);
