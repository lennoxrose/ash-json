// codec.ash -- the JSON codec behind ash-json 0.3.0. Users normally import json.ash
// (which re-exposes this as json.parse/stringify/...) and reach the rest as codec.*.
// It is plain Ash built on the language's own tools: real booleans (yes/no),
// insertion-ordered maps, chr/ord, forward declarations (so the parser can be
// several mutually recursive functions), contains/repeat, rename_file, ...
//
// parse(text)            JSON text -> Ash values (object -> map, array -> array,
//                        string -> string, number -> number, true/false -> yes/no,
//                        null -> none)
// stringify(value)       compact, keys in insertion order
// pretty(value, indent)  indented, keys in insertion order
// encode(value, indent)  stringify when indent is 0, else pretty
// load(path) / save(path, value)    save writes a temp file and renames it over the target
// parse_lines(text)      JSON Lines: array of the values, one per line (blank lines skipped)
// sorted_keys(map)       keys in a deterministic (bytewise) order
//
// Errors are raised as "json: <message> at line L, column C"; parse_lines
// reports the line of the offending JSON Lines record as L.

forge codec_fail(s, i, msg) {
    local line = 1;
    local col = 1;
    local k = 0;
    during k < i and k < len(s) {
        given s[k] == "\n" { line += 1; col = 1; } otherwise { col += 1; }
        k += 1;
    }
    raise "json: " + msg + " at line " + str(line) + ", column " + str(col);
}

forge codec_ws(s, i) {
    local n = len(s);
    during i < n {
        local c = s[i];
        given c == " " or c == "\n" or c == "\t" or c == "\r" { i += 1; } otherwise { stop; }
    }
    yield i;
}

// at = where to report a bad escape (the backslash).
forge codec_hex4(s, i, at) {
    local code = 0;
    local k = 0;
    during k < 4 {
        given i + k >= len(s) { codec_fail(s, at, "invalid \\u escape"); }
        local d = indexOf("0123456789abcdef", lower(s[i + k]));
        given d < 0 { codec_fail(s, at, "invalid \\u escape"); }
        code = code * 16 + d;
        k += 1;
    }
    yield code;
}

forge codec_utf8(code) {
    given code < 128 { yield chr(code); }
    given code < 2048 { yield chr(192 + floor(code / 64)) + chr(128 + code % 64); }
    given code < 65536 {
        yield chr(224 + floor(code / 4096)) + chr(128 + floor(code / 64) % 64) + chr(128 + code % 64);
    }
    yield chr(240 + floor(code / 262144)) + chr(128 + floor(code / 4096) % 64) + chr(128 + floor(code / 64) % 64) + chr(128 + code % 64);
}

// String starting at s[i] == "\"" -> [text, index after the closing quote].
forge codec_string(s, i) {
    local n = len(s);
    local parts = [];
    local open = i;
    local start = i + 1;
    i += 1;
    during yes {
        given i >= n { codec_fail(s, open, "unterminated string"); }
        local c = s[i];
        given c == "\"" {
            push(parts, substring(s, start, i));
            yield [join(parts, ""), i + 1];
        }
        given ord(c) < 32 { codec_fail(s, i, "control character in string"); }
        given c == "\\" {
            push(parts, substring(s, start, i));
            given i + 1 >= n { codec_fail(s, open, "unterminated string"); }
            local at = i;
            local e = s[i + 1];
            i += 2;
            given e == "n" { push(parts, "\n"); }
            otherwise { given e == "t" { push(parts, "\t"); }
            otherwise { given e == "r" { push(parts, "\r"); }
            otherwise { given e == "b" { push(parts, chr(8)); }
            otherwise { given e == "f" { push(parts, chr(12)); }
            otherwise { given e == "\"" or e == "\\" or e == "/" { push(parts, e); }
            otherwise { given e == "u" {
                local code = codec_hex4(s, i, at);
                i += 4;
                given code >= 55296 and code < 56320 and i + 1 < n and s[i] == "\\" and s[i + 1] == "u" {
                    local low = codec_hex4(s, i + 2, at);
                    given low >= 56320 and low < 57344 {
                        code = 65536 + (code - 55296) * 1024 + (low - 56320);
                        i += 6;
                    }
                }
                given code == 0 { codec_fail(s, at, "\\u0000 cannot be represented"); }
                push(parts, codec_utf8(code));
            } otherwise { codec_fail(s, at, "invalid escape"); } } } } } } }
            start = i;
        } otherwise { i += 1; }
    }
}

forge codec_literal(s, i, word, value) {
    given substring(s, i, i + len(word)) != word { codec_fail(s, i, "invalid literal"); }
    yield [value, i + len(word)];
}

// Number per the JSON grammar: -? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?
forge codec_digits(s, j) {
    local n = len(s);
    during j < n and contains("0123456789", s[j]) { j += 1; }
    yield j;
}

forge codec_number(s, i) {
    local n = len(s);
    local j = i;
    given s[j] == "-" { j += 1; }
    given j >= n or not contains("0123456789", s[j]) { codec_fail(s, i, "invalid number"); }
    given s[j] == "0" { j += 1; } otherwise { j = codec_digits(s, j); }
    given j < n and s[j] == "." {
        local k = codec_digits(s, j + 1);
        given k == j + 1 { codec_fail(s, i, "invalid number"); }
        j = k;
    }
    given j < n and (s[j] == "e" or s[j] == "E") {
        local k = j + 1;
        given k < n and (s[k] == "+" or s[k] == "-") { k += 1; }
        local e = codec_digits(s, k);
        given e == k { codec_fail(s, i, "invalid number"); }
        j = e;
    }
    yield [num(substring(s, i, j)), j];
}

// One value starting at s[i] (leading whitespace allowed) -> [value, next index].
forge codec_value(s, i) {
    local n = len(s);
    i = codec_ws(s, i);
    given i >= n { codec_fail(s, i, "unexpected end of input"); }
    local c = s[i];
    given c == "\"" { yield codec_string(s, i); }
    given c == "t" { yield codec_literal(s, i, "true", yes); }
    given c == "f" { yield codec_literal(s, i, "false", no); }
    given c == "n" { yield codec_literal(s, i, "null", none); }
    given c == "[" {
        local out = [];
        i = codec_ws(s, i + 1);
        given i < n and s[i] == "]" { yield [out, i + 1]; }
        during yes {
            local pair = codec_value(s, i);
            push(out, pair[0]);
            i = codec_ws(s, pair[1]);
            given i < n and s[i] == "," { i += 1; next; }
            given i < n and s[i] == "]" { yield [out, i + 1]; }
            codec_fail(s, i, "expected ',' or ']'");
        }
    }
    given c == "{" {
        local out = {};
        i = codec_ws(s, i + 1);
        given i < n and s[i] == "}" { yield [out, i + 1]; }
        during yes {
            i = codec_ws(s, i);
            given i >= n or s[i] != "\"" { codec_fail(s, i, "expected string key"); }
            local key = codec_string(s, i);
            i = codec_ws(s, key[1]);
            given i >= n or s[i] != ":" { codec_fail(s, i, "expected ':'"); }
            local pair = codec_value(s, i + 1);
            out[key[0]] = pair[0];
            i = codec_ws(s, pair[1]);
            given i < n and s[i] == "," { i += 1; next; }
            given i < n and s[i] == "}" { yield [out, i + 1]; }
            codec_fail(s, i, "expected ',' or '}'");
        }
    }
    given c == "-" or contains("0123456789", c) { yield codec_number(s, i); }
    codec_fail(s, i, "unexpected character '" + c + "'");
}

forge parse_text(text) {
    local pair = codec_value(text, 0);
    local i = codec_ws(text, pair[1]);
    given i < len(text) { codec_fail(text, i, "unexpected trailing characters"); }
    yield pair[0];
}

forge codec_quote(text) {
    local parts = ["\""];
    local start = 0;
    local i = 0;
    local n = len(text);
    during i < n {
        local c = text[i];
        local code = ord(c);
        given c == "\"" or c == "\\" or code < 32 {
            push(parts, substring(text, start, i));
            given c == "\"" { push(parts, "\\\""); }
            otherwise { given c == "\\" { push(parts, "\\\\"); }
            otherwise { given c == "\n" { push(parts, "\\n"); }
            otherwise { given c == "\t" { push(parts, "\\t"); }
            otherwise { given c == "\r" { push(parts, "\\r"); }
            otherwise {
                local hex = "0123456789abcdef";
                push(parts, "\\u00" + hex[floor(code / 16)] + hex[code % 16]);
            } } } } }
            start = i + 1;
        }
        i += 1;
    }
    push(parts, substring(text, start, n));
    push(parts, "\"");
    yield join(parts, "");
}

forge codec_encode(v, indent, level) {
    local t = type(v);
    given t == "string" { yield codec_quote(v); }
    given t == "none" { yield "null"; }
    given t == "boolean" { yield v ? "true" : "false"; }
    given t == "number" {
        local text = str(v);
        given contains(text, "n") { raise "json: cannot stringify a non-finite number"; } // "nan", "inf", "-inf"
        yield text;
    }
    local inner = "";
    local outer = "";
    given indent > 0 { inner = repeat(" ", indent * (level + 1)); outer = repeat(" ", indent * level); }
    given t == "array" {
        given len(v) == 0 { yield "[]"; }
        local parts = [];
        each item in v { push(parts, inner + codec_encode(item, indent, level + 1)); }
        given indent > 0 { yield "[\n" + join(parts, ",\n") + "\n" + outer + "]"; }
        yield "[" + join(parts, ", ") + "]";
    }
    given t == "map" {
        local ks = keys(v);
        given len(ks) == 0 { yield "{}"; }
        local parts = [];
        each k in ks { push(parts, inner + codec_quote(k) + ": " + codec_encode(v[k], indent, level + 1)); }
        given indent > 0 { yield "{\n" + join(parts, ",\n") + "\n" + outer + "}"; }
        yield "{" + join(parts, ", ") + "}";
    }
    raise "json: cannot stringify a " + t;
}

forge parse(text) {
    given type(text) != "string" { raise "json: parse expects a string"; }
    yield parse_text(text);
}

forge parse_lines(text) {
    given type(text) != "string" { raise "json: parse_lines expects a string"; }
    local out = [];
    local n = 0;
    each line in split(text, "\n") {
        n += 1;
        given len(trim(line)) > 0 {
            attempt { push(out, parse_text(line)); } handle (e) { raise replace(e, " at line 1, column ", " at line " + str(n) + ", column "); }
        }
    }
    yield out;
}

forge stringify(value) { yield codec_encode(value, 0, 0); }
forge pretty(value, indent) { yield codec_encode(value, indent, 0); }

forge encode(value, indent) {
    yield codec_encode(value, indent, 0);
}

forge sorted_keys(m) { yield sort(keys(m)); }

forge load(path) {
    yield parse(read_file(path));
}

forge save(path, value) {
    local temp = path + ".tmp";
    write_file(temp, stringify(value));
    rename_file(temp, path);
    yield none;
}
