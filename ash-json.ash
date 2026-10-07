// json.ash -- a JSON codec for Ash.
// API: json.parse(text) / json.stringify(value) / json.load(path) / json.save(path, value)
// Limitations: see this module's README -- no \uXXXX escapes, no distinct
// boolean type (Ash has none; round-tripping `true`/`false` through
// parse+stringify yields 1/0, not true/false), always single-line output.

forge json_skip_ws(s, i) {
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

forge json_is_digit(c) {
    yield c == "0" or c == "1" or c == "2" or c == "3" or c == "4" or
          c == "5" or c == "6" or c == "7" or c == "8" or c == "9";
}

forge json_parse_number(s, i) {
    local start = i;
    given substring(s, i, i + 1) == "-" { i += 1; }
    during i < len(s) and json_is_digit(substring(s, i, i + 1)) { i += 1; }
    given substring(s, i, i + 1) == "." {
        i += 1;
        during i < len(s) and json_is_digit(substring(s, i, i + 1)) { i += 1; }
    }
    given substring(s, i, i + 1) == "e" or substring(s, i, i + 1) == "E" {
        i += 1;
        given substring(s, i, i + 1) == "+" or substring(s, i, i + 1) == "-" { i += 1; }
        during i < len(s) and json_is_digit(substring(s, i, i + 1)) { i += 1; }
    }
    yield [num(substring(s, start, i)), i];
}

// Bounded by `i < len(s)`, not `during yes` -- an unterminated string
// (malformed/truncated JSON) must hit the `raise` below instead of
// scanning forever. Found the hard way: an earlier version of this
// function used `during yes` with only "found a closing quote" as the
// exit condition, so `json.parse("{bad json")` (no closing quote
// anywhere) span forever, OOM-killed on ashvm and segfaulted on kiln
// (its bump allocator has no bounds check once the arena's exhausted).
forge json_parse_string(s, i) {
    i += 1; // skip opening quote
    local buf = "";
    during i < len(s) {
        local c = substring(s, i, i + 1);
        given c == "\"" { i += 1; yield [buf, i]; }
        given c == "\\" {
            local esc = substring(s, i + 1, i + 2);
            given esc == "n" { buf += "\n"; i += 2; next; }
            given esc == "t" { buf += "\t"; i += 2; next; }
            given esc == "r" { buf += "\r"; i += 2; next; }
            given esc == "\"" { buf += "\""; i += 2; next; }
            given esc == "\\" { buf += "\\"; i += 2; next; }
            given esc == "/" { buf += "/"; i += 2; next; }
            buf += esc; // unknown escape -- keep the character as-is rather than erroring
            i += 2;
            next;
        }
        buf += c;
        i += 1;
    }
    raise "json: unterminated string";
}

forge json_parse_bool(s, i) {
    given substring(s, i, i + 4) == "true" { yield [yes, i + 4]; }
    yield [no, i + 5]; // must be "false" -- json_parse_value only gets here for 't' or 'f'
}

forge json_parse_null(s, i) {
    yield [none, i + 4];
}

// Arrays and objects are parsed INLINE here, not farmed out to their own
// json_parse_array/json_parse_object functions. Ash has no forward
// declarations -- a single-pass compiler means a function can only call
// something already declared EARLIER in the file -- so array/object
// parsing (which needs to recursively parse arbitrary nested VALUES,
// including more arrays/objects) can't live in a function defined
// before this one without a genuine two-function mutual-recursion cycle
// neither engine can express. (Found exactly this way: an earlier draft
// had json_parse_array/json_parse_object as separate functions calling
// json_parse_value, which hadn't been declared yet -- "undefined
// function: json_parse_value" from both engines, not a typo.)
// Self-recursion (this function calling itself for a nested value) is
// fine -- its own name is already registered before its own body
// compiles, same as any ordinary recursive function (fib, etc).
forge json_parse_value(s, i) {
    i = json_skip_ws(s, i);
    local c = substring(s, i, i + 1);

    given c == "\"" { yield json_parse_string(s, i); }
    given c == "t" or c == "f" { yield json_parse_bool(s, i); }
    given c == "n" { yield json_parse_null(s, i); }

    given c == "[" {
        i += 1;
        local result = [];
        i = json_skip_ws(s, i);
        given substring(s, i, i + 1) == "]" { yield [result, i + 1]; }
        during yes {
            local pair = json_parse_value(s, i);
            push(result, pair[0]);
            i = json_skip_ws(s, pair[1]);
            local ch = substring(s, i, i + 1);
            given ch == "," { i = json_skip_ws(s, i + 1); next; }
            given ch == "]" { i += 1; stop; }
            raise "json: expected ',' or ']' at position " + str(i);
        }
        yield [result, i];
    }

    given c == "{" {
        i += 1;
        local result = {};
        i = json_skip_ws(s, i);
        given substring(s, i, i + 1) == "}" { yield [result, i + 1]; }
        during yes {
            i = json_skip_ws(s, i);
            local key_pair = json_parse_string(s, i);
            i = json_skip_ws(s, key_pair[1]);
            i += 1; // skip ':'
            i = json_skip_ws(s, i);
            local val_pair = json_parse_value(s, i);
            result[key_pair[0]] = val_pair[0];
            i = json_skip_ws(s, val_pair[1]);
            local ch = substring(s, i, i + 1);
            given ch == "," { i = json_skip_ws(s, i + 1); next; }
            given ch == "}" { i += 1; stop; }
            raise "json: expected ',' or '}' at position " + str(i);
        }
        yield [result, i];
    }

    yield json_parse_number(s, i);
}

forge json_escape_string(s) {
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

// json.parse(text) -- parses a full JSON document into native Ash
// values: object -> map, array -> array, string -> string,
// number/true/false -> number, null -> none.
forge parse(text) {
    local pair = json_parse_value(text, 0);
    yield pair[0];
}

// json.stringify(value) -- the reverse. See this file's header comment
// for what does NOT round-trip (booleans). Same reasoning as
// json_parse_value above: the array/map formatting cases are inline
// (self-recursive), not separate functions, because they'd otherwise
// need to call `stringify` before it's declared.
forge stringify(value) {
    local t = type(value);
    given t == "string" { yield "\"" + json_escape_string(value) + "\""; }
    given t == "number" { yield str(value); }
    given t == "none" { yield "null"; }

    given t == "array" {
        local parts = [];
        local i = 0;
        during i < len(value) {
            push(parts, stringify(value[i]));
            i += 1;
        }
        yield "[" + join(parts, ", ") + "]";
    }

    given t == "map" {
        local ks = keys(value);
        local parts = [];
        local i = 0;
        during i < len(ks) {
            push(parts, "\"" + json_escape_string(ks[i]) + "\": " + stringify(value[ks[i]]));
            i += 1;
        }
        yield "{" + join(parts, ", ") + "}";
    }

    raise "json: cannot stringify a " + t;
}

// json.load(path) / json.save(path, value) -- the file-convenience pair
// that's the actual point of this module existing (per the mission: "use
// json files" from Ash).
forge load(path) {
    yield parse(read_file(path));
}

forge save(path, value) {
    write_file(path, stringify(value));
    yield none;
}
