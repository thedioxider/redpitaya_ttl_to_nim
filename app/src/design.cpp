#include "design.hpp"

#include "conf.hpp"

namespace {

bool get_uint(const std::map<std::string, std::string>& values, const std::string& key,
              uint32_t& out, std::string& err) {
    auto it = values.find(key);
    if (it == values.end()) {
        err = "missing " + key;
        return false;
    }
    if (!parse_uint(it->second, out)) {
        err = "invalid " + key + ": " + it->second;
        return false;
    }
    return true;
}

}  // namespace

bool parse_design(const std::map<std::string, std::string>& values, Design& out, std::string& err) {
    auto name = values.find("name");
    if (name == values.end() || name->second.empty()) {
        err = "missing name";
        return false;
    }
    out.name = name->second;

    if (!get_uint(values, "tick_ps", out.tick_ps, err) ||
        !get_uint(values, "coarse_bits", out.coarse_bits, err) ||
        !get_uint(values, "fine_bits", out.fine_bits, err)) {
        return false;
    }

    if (out.tick_ps == 0) {
        err = "tick_ps must be positive";
        return false;
    }
    if (out.coarse_bits == 0) {
        err = "coarse_bits must be positive";
        return false;
    }
    if (out.fine_bits == 0) {
        err = "fine_bits must be positive";
        return false;
    }
    if (uint64_t{out.coarse_bits} + out.fine_bits > 32) {
        err = "coarse_bits + fine_bits must fit the 32-bit register";
        return false;
    }
    return true;
}

uint32_t max_steps(uint32_t bits) {
    return static_cast<uint32_t>((uint64_t{1} << bits) - 1);
}

uint32_t clamp_steps(uint32_t steps, uint32_t bits) {
    uint32_t max = max_steps(bits);
    return steps > max ? max : steps;
}

uint32_t compose_register(const Design& design, uint32_t coarse, uint32_t fine) {
    return (clamp_steps(coarse, design.coarse_bits) << design.fine_bits) |
           clamp_steps(fine, design.fine_bits);
}
