// codec.ash -- the JSON codec behind ash-json. Users normally import json.ash
// (which re-exposes this as json.parse/stringify/...) and reach the rest as codec.*.
//
// parse(text)            JSON text -> Ash values (object -> map, array -> array,
//                        string -> string, number/true/false -> number, null -> none)
// stringify(value)       compact, keys sorted
// pretty(value, indent)  indented, keys sorted
// load(path) / save(path, value)
// parse_lines(text)      JSON Lines: array of the values, one per line (blank lines skipped)
// parse_marked(text)     [value, bools]: bools maps the canonical path (see jpath.ash)
//                        of every true/false in the input to yes
// encode(value, indent, bools)  stringify/pretty that writes the paths in `bools`
//                        back as true/false (what doc.ash uses)
// sorted_keys(map)       keys in a deterministic order (same on every engine)
//
// Ash has no forward declarations, so parsing and encoding each live in ONE
// self-recursive function (codec_value / codec_encode). Errors are raised as
// "json: <message> at line L, column C".

@import <../path/jpath.ash>;

forge codec_ascii() {
    yield " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
}

// 0..15 for a hex digit, -1 otherwise.
forge codec_hex(c) {
    local digits = "0123456789abcdef";
    local lc = lower(c);
    local i = 0;
    during i < 16 {
        given substring(digits, i, i + 1) == lc { yield i; }
        i += 1;
    }
    yield -1;
}

forge codec_fail(s, i, message) {
    local line = 1;
    local col = 1;
    local k = 0;
    during k < i and k < len(s) {
        given substring(s, k, k + 1) == "\n" { line += 1; col = 1; }
        otherwise { col += 1; }
        k += 1;
    }
    raise "json: " + message + " at line " + str(line) + ", column " + str(col);
}

forge codec_skip_ws(s, i) {
    during i < len(s) {
        local c = substring(s, i, i + 1);
        given c == " " or c == "\t" or c == "\n" or c == "\r" {
            i += 1;
            next;
        }
        stop;
    }
    yield i;
}

forge codec_digits_end(s, i) {
    during i < len(s) and jpath.is_index(substring(s, i, i + 1)) { i += 1; }
    yield i;
}

// Number text -> [number, next index]. Strict JSON grammar. The exponent is
// applied here because num() ignores it on kiln.
forge codec_number(s, i) {
    local start = i;
    given substring(s, i, i + 1) == "-" { i += 1; }
    local int_end = codec_digits_end(s, i);
    given int_end == i { codec_fail(s, start, "invalid number"); }
    i = int_end;
    given substring(s, i, i + 1) == "." {
        i += 1;
        local frac_end = codec_digits_end(s, i);
        given frac_end == i { codec_fail(s, start, "invalid number"); }
        i = frac_end;
    }
    local mantissa_end = i;
    local exp = 0;
    local c = substring(s, i, i + 1);
    given c == "e" or c == "E" {
        i += 1;
        local sign = 1;
        given substring(s, i, i + 1) == "+" { i += 1; }
        given substring(s, i, i + 1) == "-" { sign = -1; i += 1; }
        local exp_end = codec_digits_end(s, i);
        given exp_end == i { codec_fail(s, start, "invalid number"); }
        exp = sign * num(substring(s, i, exp_end));
        i = exp_end;
    }
    local value = num(substring(s, start, mantissa_end));
    given exp > 400 or exp < -400 { codec_fail(s, start, "number out of range"); }
    local scale = 1;
    local k = 0;
    during k < abs(exp) {
        scale = scale * 10;
        k += 1;
    }
    given exp > 0 { value = value * scale; }
    given exp < 0 { value = value / scale; }
    yield [value, i];
}

// String -> [text, next index]. Bounded by len(s) so an unterminated string
// raises instead of scanning forever. \uXXXX is decoded for printable ASCII
// (and \n \t \r); any other \u escape, \b and \f raise "unsupported escape"
// because Ash has no chr().
forge codec_string(s, i) {
    local open = i;
    i += 1;
    local buf = "";
    during i < len(s) {
        local c = substring(s, i, i + 1);
        given c == "\"" { yield [buf, i + 1]; }
        given c == "\\" {
            local esc = substring(s, i + 1, i + 2);
            given esc == "n" { buf += "\n"; i += 2; next; }
            given esc == "t" { buf += "\t"; i += 2; next; }
            given esc == "r" { buf += "\r"; i += 2; next; }
            given esc == "\"" { buf += "\""; i += 2; next; }
            given esc == "\\" { buf += "\\"; i += 2; next; }
            given esc == "/" { buf += "/"; i += 2; next; }
            given esc == "b" or esc == "f" { codec_fail(s, i, "unsupported escape \\" + esc); }
            given esc == "u" {
                local code = 0;
                local k = 0;
                during k < 4 {
                    local h = codec_hex(substring(s, i + 2 + k, i + 3 + k));
                    given h < 0 { codec_fail(s, i, "invalid \\u escape"); }
                    code = code * 16 + h;
                    k += 1;
                }
                given code == 9 { buf += "\t"; }
                otherwise {
                    given code == 10 { buf += "\n"; }
                    otherwise {
                        given code == 13 { buf += "\r"; }
                        otherwise {
                            given code < 32 or code > 126 { codec_fail(s, i, "unsupported escape \\u" + substring(s, i + 2, i + 6)); }
                            buf += substring(codec_ascii(), code - 32, code - 31);
                        }
                    }
                }
                i += 6;
                next;
            }
            codec_fail(s, i, "invalid escape");
        }
        buf += c;
        i += 1;
    }
    codec_fail(s, open, "unterminated string");
}

forge codec_literal(s, i, word) {
    given substring(s, i, i + len(word)) != word { codec_fail(s, i, "invalid literal"); }
    yield i + len(word);
}

// One JSON value starting at s[i] (leading whitespace allowed) -> [value, next index].
// When `track` is set, the canonical path of every true/false is recorded in `bools`.
// Arrays and objects are parsed inline: this function may only recurse into itself.
forge codec_value(s, i, bools, path, track) {
    i = codec_skip_ws(s, i);
    given i >= len(s) { codec_fail(s, i, "unexpected end of input"); }
    local c = substring(s, i, i + 1);

    given c == "\"" { yield codec_string(s, i); }
    given c == "t" {
        given track { bools[path] = yes; }
        yield [yes, codec_literal(s, i, "true")];
    }
    given c == "f" {
        given track { bools[path] = yes; }
        yield [no, codec_literal(s, i, "false")];
    }
    given c == "n" { yield [none, codec_literal(s, i, "null")]; }

    given c == "[" {
        i = codec_skip_ws(s, i + 1);
        local result = [];
        given substring(s, i, i + 1) == "]" { yield [result, i + 1]; }
        during yes {
            local p = path;
            given track { p = jpath.append_index(path, len(result)); }
            local pair = codec_value(s, i, bools, p, track);
            push(result, pair[0]);
            i = codec_skip_ws(s, pair[1]);
            local ch = substring(s, i, i + 1);
            given ch == "," { i += 1; next; }
            given ch == "]" { yield [result, i + 1]; }
            codec_fail(s, i, "expected ',' or ']'");
        }
    }

    given c == "{" {
        i = codec_skip_ws(s, i + 1);
        local result = {};
        given substring(s, i, i + 1) == "}" { yield [result, i + 1]; }
        during yes {
            i = codec_skip_ws(s, i);
            given substring(s, i, i + 1) != "\"" { codec_fail(s, i, "expected string key"); }
            local key_pair = codec_string(s, i);
            i = codec_skip_ws(s, key_pair[1]);
            given substring(s, i, i + 1) != ":" { codec_fail(s, i, "expected ':'"); }
            local p = path;
            given track { p = jpath.append_key(path, key_pair[0]); }
            local val_pair = codec_value(s, i + 1, bools, p, track);
            result[key_pair[0]] = val_pair[0];
            i = codec_skip_ws(s, val_pair[1]);
            local ch = substring(s, i, i + 1);
            given ch == "," { i += 1; next; }
            given ch == "}" { yield [result, i + 1]; }
            codec_fail(s, i, "expected ',' or '}'");
        }
    }

    given c == "-" or jpath.is_index(c) { yield codec_number(s, i); }
    codec_fail(s, i, "unexpected character '" + c + "'");
}

forge codec_parse_all(text, bools, track) {
    given type(text) != "string" { raise "json: parse expects a string"; }
    local pair = codec_value(text, 0, bools, "", track);
    local end = codec_skip_ws(text, pair[1]);
    given end < len(text) { codec_fail(text, end, "unexpected trailing characters"); }
    yield pair[0];
}

forge parse(text) {
    yield codec_parse_all(text, {}, no);
}

// JSON Lines: values separated by line breaks. Errors carry the real line and column.
forge parse_lines(text) {
    given type(text) != "string" { raise "json: parse_lines expects a string"; }
    local out = [];
    local i = codec_skip_ws(text, 0);
    during i < len(text) {
        local pair = codec_value(text, i, {}, "", no);
        push(out, pair[0]);
        local j = pair[1];
        during j < len(text) {
            local c = substring(text, j, j + 1);
            given c == " " or c == "\t" or c == "\r" { j += 1; next; }
            stop;
        }
        given j < len(text) {
            given substring(text, j, j + 1) != "\n" { codec_fail(text, j, "expected end of line"); }
        }
        i = codec_skip_ws(text, j);
    }
    yield out;
}

forge parse_marked(text) {
    local bools = {};
    local value = codec_parse_all(text, bools, yes);
    yield [value, bools];
}

// --- encoding -------------------------------------------------------------

forge codec_escape(s) {
    local out = "";
    local i = 0;
    during i < len(s) {
        local c = substring(s, i, i + 1);
        given c == "\"" { out += "\\\""; i += 1; next; }
        given c == "\\" { out += "\\\\"; i += 1; next; }
        given c == "\n" { out += "\\n"; i += 1; next; }
        given c == "\t" { out += "\\t"; i += 1; next; }
        given c == "\r" { out += "\\r"; i += 1; next; }
        out += c;
        i += 1;
    }
    yield out;
}

forge codec_pad(n) {
    local out = "";
    local i = 0;
    during i < n {
        out += " ";
        i += 1;
    }
    yield out;
}

// Ash has no string `<`, so keys are ordered by ASCII code via this table
// (bytes outside it sort last, all equal to each other).
forge codec_code_table() {
    local table = {};
    local ascii = codec_ascii();
    local i = 0;
    during i < len(ascii) {
        table[substring(ascii, i, i + 1)] = i + 32;
        i += 1;
    }
    table["\t"] = 9;
    table["\n"] = 10;
    table["\r"] = 13;
    yield table;
}

forge codec_code(table, c) {
    given has(table, c) { yield table[c]; }
    yield 1000;
}

forge codec_key_less(a, b, table) {
    local n = len(a);
    given len(b) < n { n = len(b); }
    local i = 0;
    during i < n {
        local ca = codec_code(table, substring(a, i, i + 1));
        local cb = codec_code(table, substring(b, i, i + 1));
        given ca != cb { yield ca < cb; }
        i += 1;
    }
    yield len(a) < len(b);
}

// codec.sorted_keys(map) -> keys in ASCII order, identical on every engine.
forge sorted_keys(m) {
    local ks = keys(m);
    given len(ks) < 2 { yield ks; }
    local table = codec_code_table();
    local out = [];
    local i = 0;
    during i < len(ks) {
        push(out, ks[i]);
        local j = len(out) - 1;
        during j > 0 {
            given not codec_key_less(out[j], out[j - 1], table) { stop; }
            local tmp = out[j];
            out[j] = out[j - 1];
            out[j - 1] = tmp;
            j -= 1;
        }
        i += 1;
    }
    yield out;
}

// Single-recursive serializer. indent 0 = compact ("[1, 2]", "{"a": 1}"),
// indent > 0 = one element per line. `track` + `bools` turn 1/0 at the
// recorded paths back into true/false.
forge codec_encode(value, indent, level, bools, path, track) {
    local t = type(value);
    given t == "string" { yield "\"" + codec_escape(value) + "\""; }
    given t == "none" { yield "null"; }
    given t == "number" {
        given track and has(bools, path) and (value == 1 or value == 0) {
            yield value == 1 ? "true" : "false";
        }
        yield str(value);
    }

    local inner = codec_pad(indent * (level + 1));
    local outer = codec_pad(indent * level);

    given t == "array" {
        given len(value) == 0 { yield "[]"; }
        local parts = [];
        local i = 0;
        during i < len(value) {
            local p = path;
            given track { p = jpath.append_index(path, i); }
            local item = codec_encode(value[i], indent, level + 1, bools, p, track);
            given indent > 0 { item = inner + item; }
            push(parts, item);
            i += 1;
        }
        given indent > 0 { yield "[\n" + join(parts, ",\n") + "\n" + outer + "]"; }
        yield "[" + join(parts, ", ") + "]";
    }

    given t == "map" {
        local ks = sorted_keys(value);
        given len(ks) == 0 { yield "{}"; }
        local parts = [];
        local i = 0;
        during i < len(ks) {
            local p = path;
            given track { p = jpath.append_key(path, ks[i]); }
            local item = "\"" + codec_escape(ks[i]) + "\": " + codec_encode(value[ks[i]], indent, level + 1, bools, p, track);
            given indent > 0 { item = inner + item; }
            push(parts, item);
            i += 1;
        }
        given indent > 0 { yield "{\n" + join(parts, ",\n") + "\n" + outer + "}"; }
        yield "{" + join(parts, ", ") + "}";
    }

    raise "json: cannot stringify a " + t;
}

forge stringify(value) {
    yield codec_encode(value, 0, 0, {}, "", no);
}

forge pretty(value, indent) {
    yield codec_encode(value, indent, 0, {}, "", no);
}

// bools: a map from canonical path to yes (as returned by parse_marked), or none.
forge encode(value, indent, bools) {
    given type(bools) == "map" { yield codec_encode(value, indent, 0, bools, "", yes); }
    yield codec_encode(value, indent, 0, {}, "", no);
}

forge load(path) {
    yield parse(read_file(path));
}

forge save(path, value) {
    write_file(path, stringify(value));
    yield none;
}
