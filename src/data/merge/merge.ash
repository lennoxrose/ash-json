// merge.ash -- combine and compare JSON values. Nothing here mutates its inputs.
//   merge.clone(v)            deep copy
//   merge.equal(a, b)         deep equality (Ash's == compares maps by identity on vm)
//   merge.merge(a, b)         deep merge: maps merge key by key, otherwise b wins; arrays are replaced
//   merge.diff(a, b)          patch ops turning a into b: [{"op", "path", "value"}] with JSON Pointer paths
//   merge.patch(v, ops)       applies ops "add" / "remove" / "replace" (RFC 6902 subset) to a copy of v
// Invariant: merge.equal(merge.patch(a, merge.diff(a, b)), b).
// Errors: "merge: <message>".

@import <../../core/path/jpath.ash>;
@import <../../core/codec/codec.ash>;
@import <../query/query.ash>;

forge clone(v) {
    local t = type(v);
    given t == "array" {
        local out = [];
        local i = 0;
        during i < len(v) {
            push(out, clone(v[i]));
            i += 1;
        }
        yield out;
    }
    given t == "map" {
        local out = {};
        local ks = keys(v);
        local i = 0;
        during i < len(ks) {
            out[ks[i]] = clone(v[ks[i]]);
            i += 1;
        }
        yield out;
    }
    yield v;
}

forge equal(a, b) {
    local t = type(a);
    given t != type(b) { yield no; }
    given t == "array" {
        given len(a) != len(b) { yield no; }
        local i = 0;
        during i < len(a) {
            given not equal(a[i], b[i]) { yield no; }
            i += 1;
        }
        yield yes;
    }
    given t == "map" {
        local ka = keys(a);
        given len(ka) != len(keys(b)) { yield no; }
        local i = 0;
        during i < len(ka) {
            given not has(b, ka[i]) { yield no; }
            given not equal(a[ka[i]], b[ka[i]]) { yield no; }
            i += 1;
        }
        yield yes;
    }
    yield a == b;
}

forge merge(a, b) {
    given type(a) != "map" { yield clone(b); }
    given type(b) != "map" { yield clone(b); }
    local out = clone(a);
    local ks = keys(b);
    local i = 0;
    during i < len(ks) {
        local k = ks[i];
        given has(out, k) {
            out[k] = merge(out[k], b[k]);
        }
        otherwise {
            out[k] = clone(b[k]);
        }
        i += 1;
    }
    yield out;
}

forge merge_child(segs, seg) {
    local out = clone(segs);
    push(out, seg);
    yield out;
}

forge merge_op(ops, kind, segs, item) {
    local op = {"op": kind, "path": jpath.to_pointer(segs)};
    given kind != "remove" { op["value"] = clone(item); }
    push(ops, op);
}

forge merge_diff(a, b, segs, ops) {
    given equal(a, b) { yield none; }
    local ta = type(a);
    given ta == "map" and type(b) == "map" {
        local ka = codec.sorted_keys(a);
        local i = 0;
        during i < len(ka) {
            local child = merge_child(segs, ka[i]);
            given has(b, ka[i]) { merge_diff(a[ka[i]], b[ka[i]], child, ops); }
            otherwise { merge_op(ops, "remove", child, none); }
            i += 1;
        }
        local kb = codec.sorted_keys(b);
        i = 0;
        during i < len(kb) {
            given not has(a, kb[i]) { merge_op(ops, "add", merge_child(segs, kb[i]), b[kb[i]]); }
            i += 1;
        }
        yield none;
    }
    given ta == "array" and type(b) == "array" {
        local common = len(a);
        given len(b) < common { common = len(b); }
        local i = 0;
        during i < common {
            merge_diff(a[i], b[i], merge_child(segs, i), ops);
            i += 1;
        }
        i = len(a) - 1;
        during i >= common {
            merge_op(ops, "remove", merge_child(segs, i), none);
            i -= 1;
        }
        i = common;
        during i < len(b) {
            merge_op(ops, "add", merge_child(segs, i), b[i]);
            i += 1;
        }
        yield none;
    }
    merge_op(ops, "replace", segs, b);
}

forge diff(a, b) {
    local ops = [];
    merge_diff(a, b, [], ops);
    yield ops;
}

// "add": into an array at an index inside it INSERTS (later elements shift);
// at the end, or with "-", it appends; on a map it sets the key.
forge merge_add(root, segs, item) {
    local n = len(segs);
    given n == 0 { yield item; }
    local parent_segs = [];
    local k = 0;
    during k < n - 1 {
        push(parent_segs, segs[k]);
        k += 1;
    }
    local parent = query.get(root, parent_segs, none);
    given type(parent) == "array" {
        local at = -1;
        given jpath.is_index(segs[n - 1]) { at = num(segs[n - 1]); }
        given at >= 0 {
            given at < len(parent) {
                local rebuilt = [];
                local i = 0;
                during i < len(parent) {
                    given i == at { push(rebuilt, item); }
                    push(rebuilt, parent[i]);
                    i += 1;
                }
                yield query.set(root, parent_segs, rebuilt);
            }
        }
    }
    yield query.set(root, segs, item);
}

forge patch(v, ops) {
    local result = clone(v);
    local i = 0;
    during i < len(ops) {
        local op = ops[i];
        given type(op) != "map" { raise "merge: malformed patch op"; }
        given not has(op, "op") { raise "merge: malformed patch op"; }
        given not has(op, "path") { raise "merge: malformed patch op"; }
        local kind = op["op"];
        local segs = jpath.from_pointer(op["path"]);
        given kind == "add" {
            given not has(op, "value") { raise "merge: malformed patch op"; }
            result = merge_add(result, segs, clone(op["value"]));
        }
        otherwise {
            given kind == "remove" {
                given not query.exists(result, segs) { raise "merge: cannot remove missing path " + op["path"]; }
                result = query.remove(result, segs);
            }
            otherwise {
                given kind == "replace" {
                    given not has(op, "value") { raise "merge: malformed patch op"; }
                    given not query.exists(result, segs) { raise "merge: cannot replace missing path " + op["path"]; }
                    result = query.set(result, segs, clone(op["value"]));
                }
                otherwise {
                    raise "merge: unsupported patch op: " + kind;
                }
            }
        }
        i += 1;
    }
    yield result;
}
