// The "key = value" format shared by design.info, settings.conf and the saved delays:
// one setting per line, spaces around "=" optional, key of [a-z0-9_], value a single token
// without spaces or quotes; "#" starts a comment.
#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <vector>

struct ConfLine {
    enum Kind { Blank, Comment, Setting, Invalid };
    Kind kind;
    std::string key, value;     // Setting only
    std::string commented_key;  // Comment only: the key of a commented-out setting ("# key=value")
};

// Classifies one line; a trailing "\r" is ignored.
ConfLine parse_conf_line(std::string line);

// The file's lines without line endings; empty if it can't be read.
std::vector<std::string> read_lines(const std::string& path);

// Atomic write (temp file + rename); creates missing directories.
bool write_lines(const std::string& path, const std::vector<std::string>& lines);

// The file's settings, the last one winning for repeated keys; empty if it can't be read.
std::map<std::string, std::string> read_conf(const std::string& path);

// Parses a decimal or 0x-prefixed hex number that fits 32 bits.
bool parse_uint(const std::string& s, uint32_t& out);
