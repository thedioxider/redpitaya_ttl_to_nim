// Loads the user's settings.conf over the built-in defaults (settings_defaults.hpp).
#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <string>
#include <vector>

// One known setting; the default is a string in the settings.conf value format.
struct SettingDef {
    const char* key;
    const char* def;
    const char* desc;  // "" if none
};

struct LoadedSettings {
    std::vector<std::string> lines;             // settings.conf content after the fix-up
    std::map<std::string, std::string> values;  // every known key: the user's value, or its default
    bool changed;                               // lines differ from the input (line endings aside)
};

// Applies settings.conf's lines over the defaults and fixes the file up without losing
// anything the user wrote:
//   - known keys that don't appear at all, not even commented out, are appended commented
//     at their default;
//   - settings with unknown keys and unparsable lines are commented out with a note.
// A repeated key takes its last value. Running it on its own output changes nothing.
// Commented lines are never rewritten, even if a default changed: they may be the user's own
// disabled values.
LoadedSettings load_settings(const std::vector<std::string>& lines,
                             const SettingDef* defs, size_t n_defs);

// The setting's value as a number, or its default if the user's value isn't one.
uint32_t setting_uint(const LoadedSettings& settings, const SettingDef* defs, size_t n_defs,
                      const std::string& key);
