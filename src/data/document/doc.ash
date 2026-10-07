// doc.ash -- a document handle that keeps JSON true/false through load -> edit -> save.
// Values inside stay plain Ash data (true/false are 1/0, fine in `given`); the
// handle also records which paths were booleans so save writes them back as
// true/false. A document is the map {"value": <data>, "bools": {path: yes}}.
//
//   doc.open(path) / doc.from_text(src)      -> document
//   doc.save(path, d) / doc.text(d)          pretty (2 spaces), keys sorted
//   doc.get(d, path, fallback) / doc.exists(d, path)
//   doc.set(d, path, item)                   plain item; clears any boolean mark there
//   doc.set_bool(d, path, yes_or_no)         stores 1/0 and marks the path boolean
//   doc.remove(d, path)                      shifts the marks of later array siblings
//   doc.value(d)                             the plain data (for merge/schema)
// All edit `d` in place and return it. Paths are dotted strings (jpath.ash);
// use [n] for array elements.

@import <../../core/path/jpath.ash>;
@import <../../core/codec/codec.ash>;
@import <../query/query.ash>;

forge from_text(src) {
    local pair = codec.parse_marked(src);
    yield {"value": pair[0], "bools": pair[1]};
}

forge open(path) {
    yield from_text(read_file(path));
}

forge text(d) {
    yield codec.encode(d["value"], 2, d["bools"]);
}

forge save(path, d) {
    write_file(path, text(d) + "\n");
    yield none;
}

forge value(d) {
    yield d["value"];
}

forge doc_segs(path) {
    given type(path) == "array" { yield path; }
    yield jpath.split_path(path);
}

forge get(d, path, fallback) {
    yield query.get(d["value"], path, fallback);
}

forge exists(d, path) {
    yield query.exists(d["value"], path);
}

// Marks at `key` or anywhere below it ("" is everything).
forge doc_is_under(mark, key) {
    given key == "" { yield yes; }
    given mark == key { yield yes; }
    yield substring(mark, 0, len(key) + 1) == key + "." or substring(mark, 0, len(key) + 1) == key + "[";
}

forge doc_drop(bools, key) {
    local out = {};
    local ks = keys(bools);
    local i = 0;
    during i < len(ks) {
        given not doc_is_under(ks[i], key) { out[ks[i]] = yes; }
        i += 1;
    }
    yield out;
}

// After removing element `idx` of the array at `prefix`: drop its marks and
// renumber the marks of the elements behind it.
forge doc_shift(bools, prefix, idx) {
    local out = {};
    local marker = prefix + "[";
    local ks = keys(bools);
    local i = 0;
    during i < len(ks) {
        local k = ks[i];
        local keep = yes;
        given substring(k, 0, len(marker)) == marker {
            local rest = substring(k, len(marker), len(k));
            local d = 0;
            during d < len(rest) and jpath.is_index(substring(rest, d, d + 1)) { d += 1; }
            given d > 0 {
                local n = num(substring(rest, 0, d));
                local tail = substring(rest, d, len(rest));
                given n == idx { keep = no; }
                given n > idx {
                    out[marker + str(n - 1) + tail] = yes;
                    keep = no;
                }
            }
        }
        given keep { out[k] = yes; }
        i += 1;
    }
    yield out;
}

forge set(d, path, item) {
    local segs = doc_segs(path);
    d["value"] = query.set(d["value"], segs, item);
    d["bools"] = doc_drop(d["bools"], jpath.join_segments(segs));
    yield d;
}

forge set_bool(d, path, flag) {
    given type(flag) != "number" { raise "doc: set_bool expects yes or no"; }
    given flag != 0 and flag != 1 { raise "doc: set_bool expects yes or no"; }
    local segs = doc_segs(path);
    set(d, segs, flag);
    local marks = d["bools"];
    marks[jpath.join_segments(segs)] = yes;
    yield d;
}

forge remove(d, path) {
    local segs = doc_segs(path);
    local n = len(segs);
    given n == 0 { raise "doc: cannot remove the root"; }
    local parent_segs = [];
    local k = 0;
    during k < n - 1 {
        push(parent_segs, segs[k]);
        k += 1;
    }
    local parent = query.get(d["value"], parent_segs, none);
    local idx = -1;
    given type(segs[n - 1]) == "number" { idx = segs[n - 1]; }
    d["value"] = query.remove(d["value"], segs);
    given type(parent) == "array" {
        given idx >= 0 {
            d["bools"] = doc_shift(d["bools"], jpath.join_segments(parent_segs), idx);
            yield d;
        }
    }
    d["bools"] = doc_drop(d["bools"], jpath.join_segments(segs));
    yield d;
}
