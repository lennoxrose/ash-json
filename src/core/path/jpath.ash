// jpath.ash -- path syntaxes for ash-json.
// Dotted form users write:  server.ports[0].name   (odd keys: ["a.b"])
// JSON Pointer form (RFC 6901) used by merge.diff/patch:  /server/ports/0/name
// A path is split into segments: strings for keys, numbers for [index].

// A key is written bare (a.b) unless it is empty or contains . [ ] or a quote.
forge jpath_bare(key) {
    given len(key) == 0 { yield no; }
    local i = 0;
    during i < len(key) {
        local c = substring(key, i, i + 1);
        given c == "." or c == "[" or c == "]" or c == "\"" { yield no; }
        i += 1;
    }
    yield yes;
}

forge jpath_quote(key) {
    local out = "";
    local i = 0;
    during i < len(key) {
        local c = substring(key, i, i + 1);
        given c == "\"" or c == "\\" { out += "\\"; }
        out += c;
        i += 1;
    }
    yield "[\"" + out + "\"]";
}

forge jpath_is_digit(c) {
    yield c == "0" or c == "1" or c == "2" or c == "3" or c == "4" or
          c == "5" or c == "6" or c == "7" or c == "8" or c == "9";
}

// jpath.is_index(text) -- true for a non-empty string of digits ("12").
forge is_index(text) {
    given type(text) != "string" or len(text) == 0 { yield no; }
    local i = 0;
    during i < len(text) {
        given not jpath_is_digit(substring(text, i, i + 1)) { yield no; }
        i += 1;
    }
    yield yes;
}

// jpath.append_key(prefix, key) / jpath.append_index(prefix, i) -- extend a
// canonical dotted path by one segment.
forge append_key(prefix, key) {
    given not jpath_bare(key) { yield prefix + jpath_quote(key); }
    given prefix == "" { yield key; }
    yield prefix + "." + key;
}

forge append_index(prefix, i) {
    yield prefix + "[" + str(i) + "]";
}

// jpath.join(segments) -- canonical dotted string for a segment list.
forge join_segments(segments) {
    local out = "";
    local i = 0;
    during i < len(segments) {
        local seg = segments[i];
        given type(seg) == "number" { out = append_index(out, seg); }
        otherwise { out = append_key(out, seg); }
        i += 1;
    }
    yield out;
}

// jpath.split(text) -- dotted string -> segment list. Raises "jpath: ..." on bad syntax.
forge split_path(text) {
    local segs = [];
    local i = 0;
    during i < len(text) {
        local c = substring(text, i, i + 1);
        given c == "." { i += 1; next; }
        given c == "[" {
            i += 1;
            given substring(text, i, i + 1) == "\"" {
                i += 1;
                local key = "";
                local closed = no;
                during i < len(text) {
                    local k = substring(text, i, i + 1);
                    given k == "\\" { key += substring(text, i + 1, i + 2); i += 2; next; }
                    given k == "\"" { closed = yes; i += 1; stop; }
                    key += k;
                    i += 1;
                }
                given not closed or substring(text, i, i + 1) != "]" {
                    raise "jpath: bad quoted key in path '" + text + "'";
                }
                i += 1;
                push(segs, key);
                next;
            }
            local digits = "";
            during i < len(text) and jpath_is_digit(substring(text, i, i + 1)) {
                digits += substring(text, i, i + 1);
                i += 1;
            }
            given digits == "" or substring(text, i, i + 1) != "]" {
                raise "jpath: bad index in path '" + text + "'";
            }
            i += 1;
            push(segs, num(digits));
            next;
        }
        local name = "";
        during i < len(text) and substring(text, i, i + 1) != "." and substring(text, i, i + 1) != "[" {
            name += substring(text, i, i + 1);
            i += 1;
        }
        push(segs, name);
    }
    yield segs;
}

forge pointer_escape(seg) {
    given type(seg) == "number" { yield str(seg); }
    yield replace(replace(seg, "~", "~0"), "/", "~1");
}

// jpath.to_pointer(segments) -> "/a/0/b" ("" for the root).
forge to_pointer(segments) {
    local out = "";
    local i = 0;
    during i < len(segments) {
        out += "/" + pointer_escape(segments[i]);
        i += 1;
    }
    yield out;
}

// jpath.from_pointer(text) -> list of string segments.
forge from_pointer(text) {
    given text == "" { yield []; }
    given substring(text, 0, 1) != "/" { raise "jpath: pointer must start with '/': " + text; }
    local parts = split(substring(text, 1, len(text)), "/");
    local out = [];
    local i = 0;
    during i < len(parts) {
        push(out, replace(replace(parts[i], "~1", "/"), "~0", "~"));
        i += 1;
    }
    yield out;
}
