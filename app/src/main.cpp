// The app's controller, loaded by Red Pitaya's nginx; talks to the page via the parameters below.
#include <dlfcn.h>

#include <chrono>
#include <climits>
#include <cstdio>
#include <memory>
#include <mutex>
#include <string>

#include "CustomParameters.h"
#include "DataManager.h"
#include "conf.hpp"
#include "delays.hpp"
#include "design.hpp"
#include "fpga.hpp"
#include "settings_defaults.hpp"
#include "settings_loader.hpp"

namespace {

const char* const kDelaysPath = "/root/.config/redpitaya/apps/ttl2nim/delays.conf";
const uint64_t kLoadedCheckMs = 1000;  // periodic recheck of the loaded bitstream

// Ranges are set in rp_app_init.
CBooleanParameter running_param("RUNNING", CBaseParameter::RO, false, 0);
CIntParameter coarse_param("COARSE", CBaseParameter::RW, 0, 0, 0, 0);
CIntParameter fine_param("FINE", CBaseParameter::RW, 0, 0, 0, 0);
CIntParameter tick_ps_param("TICK_PS", CBaseParameter::RO, 0, 0, 0, INT_MAX);
CIntParameter coarse_bits_param("COARSE_BITS", CBaseParameter::RO, 0, 0, 0, 32);
CIntParameter fine_bits_param("FINE_BITS", CBaseParameter::RO, 0, 0, 0, 32);

// nginx calls into the controller from more than one thread.
std::mutex mutex;
bool design_ok = false;
Design design;
Gpio gpio;
// Also destroyed at exit(): the WebSocket server exits the process when a page disconnects,
// without calling rp_app_exit.
std::unique_ptr<DelaySaver> saver;
uint64_t last_check_ms = 0;

uint64_t now_ms() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count();
}

// The directory controllerhf.so was loaded from: the app's folder.
std::string app_dir() {
    Dl_info info;
    if (!dladdr(reinterpret_cast<void*>(&app_dir), &info) || !info.dli_fname) return ".";
    std::string path = info.dli_fname;
    size_t slash = path.rfind('/');
    return slash == std::string::npos ? "." : path.substr(0, slash);
}

Delays current_delays() {
    return {static_cast<uint32_t>(coarse_param.Value()), static_cast<uint32_t>(fine_param.Value())};
}

void write_delays() {
    Delays d = current_delays();
    gpio.write(compose_register(design, d.coarse, d.fine));
}

// Maps the GPIO while our bitstream is loaded, unmaps it otherwise.
void check_loaded() {
    bool loaded = design_ok && fpga_loaded(design.name);
    if (loaded && !gpio.is_open()) {
        int uio = uio_find(design.name);
        if (uio >= 0 && gpio.open(uio)) {
            write_delays();
        }
    } else if (!loaded && gpio.is_open()) {
        gpio.close();
    }
    running_param.Value() = loaded && gpio.is_open();
}

}  // namespace

extern "C" const char* rp_app_desc(void) {
    return "TTL to NIM converter with adjustable delay.\n";
}

extern "C" int rp_app_init(void) {
    std::lock_guard<std::mutex> lock(mutex);
    std::string dir = app_dir();

    std::string err;
    design_ok = parse_design(read_conf(dir + "/design.info"), design, err);
    if (!design_ok) {
        // Stay loaded so the page can show that the converter isn't running.
        std::fprintf(stderr, "ttl2nim: bad %s/design.info: %s\n", dir.c_str(), err.c_str());
        return 0;
    }

    std::string settings_path = dir + "/settings.conf";
    LoadedSettings settings = load_settings(read_lines(settings_path), kSettingDefaults, kSettingDefaultsCount);
    if (settings.changed && !write_lines(settings_path, settings.lines)) {
        std::fprintf(stderr, "ttl2nim: can't write %s\n", settings_path.c_str());
    }
    uint32_t save_delay_s = setting_uint(settings, kSettingDefaults, kSettingDefaultsCount, "save_delay_s");

    Delays delays = load_delays(kDelaysPath, design);
    saver.reset(new DelaySaver(kDelaysPath, delays, save_delay_s));

    tick_ps_param.Value() = design.tick_ps;
    coarse_bits_param.Value() = design.coarse_bits;
    fine_bits_param.Value() = design.fine_bits;
    coarse_param.SetMax(max_steps(design.coarse_bits));
    fine_param.SetMax(max_steps(design.fine_bits));
    coarse_param.Value() = delays.coarse;
    fine_param.Value() = delays.fine;

    check_loaded();
    last_check_ms = now_ms();
    return 0;
}

extern "C" int rp_app_exit(void) {
    std::lock_guard<std::mutex> lock(mutex);
    saver.reset();
    gpio.close();
    return 0;
}

// Unused, but required by nginx.
extern "C" int rp_set_params(void*, int) { return 0; }
extern "C" int rp_get_params(void**) { return 0; }
extern "C" int rp_get_signals(float***, int*, int*) { return 0; }

// Called before each parameter update sent to the page.
void UpdateParams(void) {
    std::lock_guard<std::mutex> lock(mutex);
    uint64_t now = now_ms();
    if (now - last_check_ms >= kLoadedCheckMs) {
        last_check_ms = now;
        check_loaded();
    }
    if (saver) saver->tick(now);
}

// Called when the page sent new values.
void OnNewParams(void) {
    std::lock_guard<std::mutex> lock(mutex);
    coarse_param.Update();  // clamps to the parameter's range
    fine_param.Update();
    if (!design_ok) return;

    check_loaded();  // never write on a stale "loaded"
    if (gpio.is_open()) write_delays();
    if (saver) saver->changed(current_delays(), now_ms());
}

void UpdateSignals(void) {}
void PostUpdateSignals(void) {}
void OnNewSignals(void) {}
