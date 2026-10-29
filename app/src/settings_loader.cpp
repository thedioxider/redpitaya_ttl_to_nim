#include "settings_loader.hpp"

#include <set>

#include "conf.hpp"

namespace {

const SettingDef* find_def(const SettingDef* defs, size_t n_defs, const std::string& key) {
    for (size_t i = 0; i < n_defs; i++) {
        if (key == defs[i].key) return &defs[i];
    }
    return nullptr;
}

}  // namespace

LoadedSettings load_settings(const std::vector<std::string>& lines,
                             const SettingDef* defs, size_t n_defs) {
    LoadedSettings result{{}, {}, false};
    for (size_t i = 0; i < n_defs; i++) result.values[defs[i].key] = defs[i].def;

    std::set<std::string> present;  // known keys mentioned, set or commented out
    for (std::string line : lines) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        ConfLine parsed = parse_conf_line(line);

        switch (parsed.kind) {
            case ConfLine::Setting:
                if (find_def(defs, n_defs, parsed.key)) {
                    result.values[parsed.key] = parsed.value;
                    present.insert(parsed.key);
                } else {
                    line = "# " + line + "   # unknown key, ignored";
                    result.changed = true;
                }
                break;
            case ConfLine::Comment:
                if (find_def(defs, n_defs, parsed.commented_key)) present.insert(parsed.commented_key);
                break;
            case ConfLine::Invalid:
                line = "# " + line + "   # unparsable, ignored";
                result.changed = true;
                break;
            case ConfLine::Blank:
                break;
        }
        result.lines.push_back(line);
    }

    for (size_t i = 0; i < n_defs; i++) {
        if (present.count(defs[i].key)) continue;
        std::string line = std::string("# ") + defs[i].key + "=" + defs[i].def;
        if (*defs[i].desc) line += std::string("   # ") + defs[i].desc;
        result.lines.push_back(line);
        result.changed = true;
    }
    return result;
}

uint32_t setting_uint(const LoadedSettings& settings, const SettingDef* defs, size_t n_defs,
                      const std::string& key) {
    uint32_t value = 0;
    auto it = settings.values.find(key);
    if (it != settings.values.end() && parse_uint(it->second, value)) return value;

    const SettingDef* def = find_def(defs, n_defs, key);
    if (def) parse_uint(def->def, value);
    return value;
}
