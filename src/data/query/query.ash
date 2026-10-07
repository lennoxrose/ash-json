// query.ash -- read and edit nested JSON values by path.
//   query.get(value, path, fallback)   value at path, or `fallback` if any step is missing
//   query.exists(value, path)          yes/no
//   query.set(value, path, new)        create/replace; missing maps/arrays are created
//   query.remove(value, path)          delete a map key or array element
// `path` is a dotted string ("server.ports[0]", see jpath.ash) or an already
// split segment list. set/remove edit in place AND return the root: use the
// return value, because removing an array element rebuilds that array (Ash has
// no array delete) and the root itself is replaced by set(value, "", new).
// Array segments may also be digit strings ("0") and "-" appends (JSON Pointer style).
// Errors: "query: <message>". Never relies on `and` short-circuiting (vm doesn't).

@import <../../core/path/jpath.ash>;

forge query_segs(path) {
    given type(path) == "array" { yield path; }
    yield jpath.split_path(path);
}

// Array index for a segment, or -1 if the segment isn't an index.
forge query_index(seg) {
    given type(seg) == "number" { yield seg; }
    given jpath.is_index(seg) { yield num(seg); }
    yield -1;
}

// One step down: [found, value].
forge query_child(cur, seg) {
    local t = type(cur);
    given t == "array" {
        local idx = query_index(seg);
        given idx >= 0 {
            given idx < len(cur) { yield [yes, cur[idx]]; }
        }
        yield [no, none];
    }
    given t == "map" {
        given type(seg) == "string" {
            given has(cur, seg) { yield [yes, cur[seg]]; }
        }
    }
    yield [no, none];
}

// Follow the first n segments: [found, value].
forge query_walk(value, segs, n) {
    local cur = value;
    local i = 0;
    during i < n {
        local r = query_child(cur, segs[i]);
        given not r[0] { yield [no, none]; }
        cur = r[1];
        i += 1;
    }
    yield [yes, cur];
}

forge get(value, path, fallback) {
    local segs = query_segs(path);
    local r = query_walk(value, segs, len(segs));
    given r[0] { yield r[1]; }
    yield fallback;
}

forge exists(value, path) {
    local segs = query_segs(path);
    yield query_walk(value, segs, len(segs))[0];
}

// Store `item` under `seg` of container `cur`.
forge query_put(cur, seg, item) {
    local t = type(cur);
    given t == "array" {
        local idx = query_index(seg);
        given type(seg) == "string" {
            given seg == "-" { idx = len(cur); }
        }
        given idx < 0 { raise "query: expected an array index, got '" + seg + "'"; }
        given idx < len(cur) { cur[idx] = item; yield none; }
        given idx == len(cur) { push(cur, item); yield none; }
        raise "query: index " + str(idx) + " is out of range (length " + str(len(cur)) + ")";
    }
    given t == "map" {
        given type(seg) != "string" { raise "query: expected a key, got index " + str(seg); }
        cur[seg] = item;
        yield none;
    }
    raise "query: cannot set into a " + t;
}

forge set(value, path, item) {
    local segs = query_segs(path);
    local n = len(segs);
    given n == 0 { yield item; }
    local cur = value;
    local i = 0;
    during i < n - 1 {
        local r = query_child(cur, segs[i]);
        given r[0] { cur = r[1]; }
        otherwise {
            local made = {};
            given type(segs[i + 1]) == "number" { made = []; }
            query_put(cur, segs[i], made);
            cur = made;
        }
        i += 1;
    }
    query_put(cur, segs[n - 1], item);
    yield value;
}

forge remove(value, path) {
    local segs = query_segs(path);
    local n = len(segs);
    given n == 0 { raise "query: cannot remove the root"; }
    local r = query_walk(value, segs, n - 1);
    given not r[0] { yield value; }
    local parent = r[1];
    local seg = segs[n - 1];
    local t = type(parent);
    given t == "map" {
        given type(seg) == "string" {
            given has(parent, seg) { delete(parent, seg); }
        }
        yield value;
    }
    given t == "array" {
        local idx = query_index(seg);
        given idx < 0 { yield value; }
        given idx >= len(parent) { yield value; }
        local rebuilt = [];
        local i = 0;
        during i < len(parent) {
            given i != idx { push(rebuilt, parent[i]); }
            i += 1;
        }
        local parent_segs = [];
        local k = 0;
        during k < n - 1 {
            push(parent_segs, segs[k]);
            k += 1;
        }
        yield set(value, parent_segs, rebuilt);
    }
    yield value;
}
