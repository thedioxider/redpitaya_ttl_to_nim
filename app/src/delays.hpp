// The delays set in the app, persisted so they're restored on the next load.
#pragma once

#include <cstdint>
#include <string>

#include "design.hpp"

struct Delays {
    uint32_t coarse = 0;
    uint32_t fine = 0;
    bool operator==(const Delays& o) const { return coarse == o.coarse && fine == o.fine; }
    bool operator!=(const Delays& o) const { return !(*this == o); }
};

// Saved delays clamped to the design's widths; zeros for a missing or unreadable file.
Delays load_delays(const std::string& path, const Design& design);

// Saves delays a while after the last change rather than on every slider move, to spare the
// SD card. A save is skipped if nothing changed since the last one.
class DelaySaver {
public:
    DelaySaver(std::string path, Delays saved, uint32_t delay_s);

    void changed(const Delays& delays, uint64_t now_ms);  // (re)starts the wait
    void tick(uint64_t now_ms);                           // saves once the wait is over
    void flush();                                         // saves a pending change now

private:
    void save();

    std::string path_;
    Delays saved_, pending_;
    uint64_t delay_ms_;
    uint64_t due_ms_ = 0;
    bool armed_ = false;
};
