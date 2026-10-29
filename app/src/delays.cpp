#include "delays.hpp"

#include <cstdio>
#include <map>

#include "conf.hpp"

namespace {

uint32_t saved_steps(const std::map<std::string, std::string>& values, const std::string& key,
                     uint32_t bits) {
    auto it = values.find(key);
    uint32_t steps = 0;
    if (it == values.end() || !parse_uint(it->second, steps)) return 0;
    return clamp_steps(steps, bits);
}

}  // namespace

Delays load_delays(const std::string& path, const Design& design) {
    auto values = read_conf(path);
    return {saved_steps(values, "coarse", design.coarse_bits),
            saved_steps(values, "fine", design.fine_bits)};
}

DelaySaver::DelaySaver(std::string path, Delays saved, uint32_t delay_s)
    : path_(std::move(path)), saved_(saved), pending_(saved), delay_ms_(uint64_t{delay_s} * 1000) {}

void DelaySaver::changed(const Delays& delays, uint64_t now_ms) {
    pending_ = delays;
    due_ms_ = now_ms + delay_ms_;
    armed_ = true;
}

void DelaySaver::tick(uint64_t now_ms) {
    if (armed_ && now_ms >= due_ms_) save();
}

void DelaySaver::flush() {
    if (armed_) save();
}

void DelaySaver::save() {
    armed_ = false;
    if (pending_ == saved_) return;

    bool ok = write_lines(path_, {
        "# Last delays set in the app, restored when it loads.",
        "coarse = " + std::to_string(pending_.coarse),
        "fine = " + std::to_string(pending_.fine),
    });
    if (!ok) {
        std::fprintf(stderr, "ttl2nim: can't write %s\n", path_.c_str());
        return;
    }
    saved_ = pending_;
}
