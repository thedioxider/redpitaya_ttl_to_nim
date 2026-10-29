#include "delays.hpp"

#include <sys/stat.h>

#include <cstdio>
#include <fstream>
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

void make_dirs(const std::string& path) {
    for (size_t i = path.find('/', 1); i != std::string::npos; i = path.find('/', i + 1)) {
        mkdir(path.substr(0, i).c_str(), 0755);
    }
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

    // Written to a temp file and renamed over the old one, so a power loss mid-write can't
    // leave a truncated file.
    make_dirs(path_);
    std::string tmp = path_ + ".tmp";
    {
        std::ofstream file(tmp);
        file << "# Last delays set in the app, restored when it loads.\n"
             << "coarse = " << pending_.coarse << "\n"
             << "fine = " << pending_.fine << "\n";
        if (!file.flush()) {
            std::fprintf(stderr, "ttl2nim: can't write %s\n", tmp.c_str());
            return;
        }
    }
    if (std::rename(tmp.c_str(), path_.c_str()) != 0) {
        std::fprintf(stderr, "ttl2nim: can't replace %s\n", path_.c_str());
        return;
    }
    saved_ = pending_;
}
