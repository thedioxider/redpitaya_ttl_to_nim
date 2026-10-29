#include "fpga.hpp"

#include <dirent.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <cstdio>
#include <fstream>
#include <iterator>

#include "conf.hpp"

namespace {

std::string read_file(const std::string& path) {
    std::ifstream file(path);
    return std::string(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
}

std::string first_line(const std::string& path) {
    std::string text = read_file(path);
    return text.substr(0, text.find('\n'));
}

}  // namespace

bool fpga_loaded(const std::string& name, const std::string& marker) {
    return !name.empty() && first_line(marker) == name;
}

int uio_find(const std::string& name, const std::string& sysfs) {
    DIR* dir = opendir(sysfs.c_str());
    if (!dir) return -1;

    int found = -1;
    while (dirent* entry = readdir(dir)) {
        int n;
        char rest;
        if (std::sscanf(entry->d_name, "uio%d%c", &n, &rest) != 1) continue;
        if (first_line(sysfs + "/" + entry->d_name + "/name") == name) {
            found = n;
            break;
        }
    }
    closedir(dir);
    return found;
}

bool Gpio::open(int uio, const std::string& dev, const std::string& sysfs) {
    close();
    std::string id = "uio" + std::to_string(uio);

    uint32_t size;
    if (!parse_uint(first_line(sysfs + "/" + id + "/maps/map0/size"), size) || size < sizeof(uint32_t)) {
        return false;
    }

    int fd = ::open((dev + "/" + id).c_str(), O_RDWR | O_SYNC);
    if (fd < 0) return false;

    void* regs = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (regs == MAP_FAILED) {
        ::close(fd);
        return false;
    }
    fd_ = fd;
    regs_ = static_cast<volatile uint32_t*>(regs);
    size_ = size;
    return true;
}

void Gpio::close() {
    if (regs_) munmap(const_cast<uint32_t*>(regs_), size_);
    if (fd_ >= 0) ::close(fd_);
    regs_ = nullptr;
    fd_ = -1;
    size_ = 0;
}

void Gpio::write(uint32_t value) {
    if (regs_) regs_[0] = value;
}
