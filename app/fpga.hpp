// Access to our bitstream's delay register, guarded so it's only touched while our bitstream is
// loaded: writing to an address nothing answers on can hang the board.
#pragma once

#include <cstdint>
#include <string>

// Whether the loaded-FPGA marker (written by fpga.sh) names our design.
bool fpga_loaded(const std::string& name, const std::string& marker = "/tmp/loaded_fpga.inf");

// N of the /dev/uioN device named name, or -1. UIO devices are numbered in creation order.
int uio_find(const std::string& name, const std::string& sysfs = "/sys/class/uio");

// The GPIO's registers, mapped from /dev/uioN.
class Gpio {
public:
    Gpio() = default;
    Gpio(const Gpio&) = delete;
    Gpio& operator=(const Gpio&) = delete;
    ~Gpio() { close(); }

    bool open(int uio, const std::string& dev = "/dev", const std::string& sysfs = "/sys/class/uio");
    void close();
    bool is_open() const { return regs_ != nullptr; }

    // Writes the first register; does nothing if not open.
    void write(uint32_t value);

private:
    int fd_ = -1;
    volatile uint32_t* regs_ = nullptr;
    size_t size_ = 0;
};
