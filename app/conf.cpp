#include "conf.hpp"

#include <fstream>

namespace {

bool is_space(char c) { return c == ' ' || c == '\t'; }
bool is_key_char(char c) { return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_'; }
bool is_value_char(char c) { return !is_space(c) && c != '#' && c != '"' && c != '\''; }

void skip_spaces(const std::string& s, size_t& i) {
    while (i < s.size() && is_space(s[i])) i++;
}

// Parses "key = value [# comment]" starting at i; the whole rest of the line must match.
bool parse_setting(const std::string& s, size_t i, std::string& key, std::string& value) {
    skip_spaces(s, i);
    size_t start = i;
    while (i < s.size() && is_key_char(s[i])) i++;
    if (i == start) return false;
    key = s.substr(start, i - start);

    skip_spaces(s, i);
    if (i == s.size() || s[i] != '=') return false;
    i++;
    skip_spaces(s, i);

    start = i;
    while (i < s.size() && is_value_char(s[i])) i++;
    if (i == start) return false;
    value = s.substr(start, i - start);

    skip_spaces(s, i);
    return i == s.size() || s[i] == '#';
}

}  // namespace

ConfLine parse_conf_line(std::string line) {
    if (!line.empty() && line.back() == '\r') line.pop_back();

    ConfLine result{ConfLine::Invalid, "", "", ""};
    size_t i = 0;
    skip_spaces(line, i);
    if (i == line.size()) {
        result.kind = ConfLine::Blank;
    } else if (line[i] == '#') {
        result.kind = ConfLine::Comment;
        std::string value;
        if (!parse_setting(line, i + 1, result.commented_key, value)) result.commented_key.clear();
    } else if (parse_setting(line, i, result.key, result.value)) {
        result.kind = ConfLine::Setting;
    }
    return result;
}

std::vector<std::string> read_lines(const std::string& path) {
    std::vector<std::string> lines;
    std::ifstream file(path);
    std::string line;
    while (std::getline(file, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        lines.push_back(line);
    }
    return lines;
}

std::map<std::string, std::string> read_conf(const std::string& path) {
    std::map<std::string, std::string> values;
    for (const std::string& line : read_lines(path)) {
        ConfLine parsed = parse_conf_line(line);
        if (parsed.kind == ConfLine::Setting) values[parsed.key] = parsed.value;
    }
    return values;
}

bool parse_uint(const std::string& s, uint32_t& out) {
    bool hex = s.size() > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X');
    size_t i = hex ? 2 : 0;
    if (i == s.size()) return false;

    uint64_t value = 0;
    for (; i < s.size(); i++) {
        char c = s[i];
        int digit;
        if (c >= '0' && c <= '9') digit = c - '0';
        else if (hex && c >= 'a' && c <= 'f') digit = c - 'a' + 10;
        else if (hex && c >= 'A' && c <= 'F') digit = c - 'A' + 10;
        else return false;

        value = value * (hex ? 16 : 10) + digit;
        if (value > UINT32_MAX) return false;
    }
    out = static_cast<uint32_t>(value);
    return true;
}
