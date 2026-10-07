// files.ash -- JSON files in practice.
//   files.load_or(path, fallback)      parsed file, or `fallback` if it doesn't exist
//   files.load_config(path)            like codec.load, but allows // and /* */ comments and trailing commas
//   files.parse_config(src)            same, from a string
//   files.read_lines(path)             JSON Lines: one value per non-blank line
//   files.write_lines(path, values)    JSON Lines, one compact value per line
//   files.append_line(path, value)     append one line
// A bad JSON Lines line raises the codec error with its real line and column.

@import <../../core/codec/codec.ash>;

// Copy of `src` without comments. Strings are copied verbatim (including
// escaped quotes), so "//" inside a string survives.
forge files_strip_comments(src) {
    local out = "";
    local i = 0;
    during i < len(src) {
        local c = substring(src, i, i + 1);
        local two = substring(src, i, i + 2);
        given c == "\"" {
            out += c;
            i += 1;
            during i < len(src) {
                local k = substring(src, i, i + 1);
                out += k;
                i += 1;
                given k == "\\" { out += substring(src, i, i + 1); i += 1; next; }
                given k == "\"" { stop; }
            }
            next;
        }
        given two == "//" {
            during i < len(src) and substring(src, i, i + 1) != "\n" { i += 1; }
            next;
        }
        given two == "/*" {
            i += 2;
            during i < len(src) and substring(src, i, i + 2) != "*/" { i += 1; }
            i += 2;
            out += " ";
            next;
        }
        out += c;
        i += 1;
    }
    yield out;
}

// Copy of `src` without commas that directly precede (ignoring whitespace) a } or ].
forge files_strip_trailing_commas(src) {
    local out = "";
    local i = 0;
    during i < len(src) {
        local c = substring(src, i, i + 1);
        given c == "\"" {
            out += c;
            i += 1;
            during i < len(src) {
                local k = substring(src, i, i + 1);
                out += k;
                i += 1;
                given k == "\\" { out += substring(src, i, i + 1); i += 1; next; }
                given k == "\"" { stop; }
            }
            next;
        }
        given c == "," {
            local j = i + 1;
            during j < len(src) {
                local w = substring(src, j, j + 1);
                given w == " " or w == "\t" or w == "\n" or w == "\r" { j += 1; next; }
                stop;
            }
            local after = substring(src, j, j + 1);
            given after == "}" or after == "]" { i += 1; next; }
        }
        out += c;
        i += 1;
    }
    yield out;
}

forge parse_config(src) {
    yield codec.parse(files_strip_trailing_commas(files_strip_comments(src)));
}

forge load_config(path) {
    yield parse_config(read_file(path));
}

forge load_or(path, fallback) {
    given file_exists(path) { yield codec.load(path); }
    yield fallback;
}

forge read_lines(path) {
    yield codec.parse_lines(read_file(path));
}

forge write_lines(path, values) {
    local out = "";
    local i = 0;
    during i < len(values) {
        out += codec.stringify(values[i]) + "\n";
        i += 1;
    }
    write_file(path, out);
    yield none;
}

forge append_line(path, value) {
    append_file(path, codec.stringify(value) + "\n");
    yield none;
}
