// schema.ash -- validate a JSON value against a schema written as a plain Ash map.
//   schema.validate(value, schema)  -> array of "<path>: <message>" (empty = valid)
//   schema.check(value, schema)     raises "schema: <first error>" when invalid
//
// Schema keywords (all optional):
//   "type"        "string" "number" "integer" "boolean" "array" "object" "null" "any"
//   "enum"        array of allowed values (deep equality)
//   "min" "max"   bounds for numbers
//   "min_length" "max_length"   bounds for strings and arrays
//   "items"       schema for every array element
//   "required"    array of keys an object must have
//   "properties"  key -> schema for the keys that are present
//   "additional"  no = reject keys not listed in "properties"
// "boolean" accepts exactly 0 or 1 (Ash's true/false). Paths use the dotted
// form of jpath.ash; the root is "$". Errors come out in a fixed order
// (type, enum, bounds, items, required, properties by name, unknown keys by name).

@import <../../core/path/jpath.ash>;
@import <../../core/codec/codec.ash>;
@import <../../data/merge/merge.ash>;

forge schema_name(value) {
    local t = type(value);
    given t == "map" { yield "object"; }
    given t == "none" { yield "null"; }
    yield t;
}

forge schema_type_ok(value, want) {
    local t = type(value);
    given want == "any" { yield yes; }
    given want == "string" { yield t == "string"; }
    given want == "array" { yield t == "array"; }
    given want == "object" { yield t == "map"; }
    given want == "null" { yield t == "none"; }
    given want == "number" { yield t == "number"; }
    given want == "integer" {
        given t != "number" { yield no; }
        yield floor(value) == value;
    }
    given want == "boolean" { yield t == "boolean"; }
    raise "schema: unknown type '" + want + "'";
}

forge schema_fail(errs, path, message) {
    local where = path;
    given path == "" { where = "$"; }
    push(errs, where + ": " + message);
}

forge schema_check(value, sch, path, errs) {
    local t = type(value);

    given has(sch, "type") {
        given not schema_type_ok(value, sch["type"]) {
            schema_fail(errs, path, "expected " + sch["type"] + ", got " + schema_name(value));
            yield none;
        }
    }

    given has(sch, "enum") {
        local allowed = sch["enum"];
        local found = no;
        local i = 0;
        during i < len(allowed) {
            given merge.equal(allowed[i], value) { found = yes; }
            i += 1;
        }
        given not found { schema_fail(errs, path, "not one of the allowed values"); }
    }

    given t == "number" {
        given has(sch, "min") {
            given value < sch["min"] { schema_fail(errs, path, "must be >= " + str(sch["min"])); }
        }
        given has(sch, "max") {
            given value > sch["max"] { schema_fail(errs, path, "must be <= " + str(sch["max"])); }
        }
    }

    given t == "string" or t == "array" {
        given has(sch, "min_length") {
            given len(value) < sch["min_length"] { schema_fail(errs, path, "length must be >= " + str(sch["min_length"])); }
        }
        given has(sch, "max_length") {
            given len(value) > sch["max_length"] { schema_fail(errs, path, "length must be <= " + str(sch["max_length"])); }
        }
    }

    given t == "array" {
        given has(sch, "items") {
            local i = 0;
            during i < len(value) {
                schema_check(value[i], sch["items"], jpath.append_index(path, i), errs);
                i += 1;
            }
        }
    }

    given t == "map" {
        given has(sch, "required") {
            local need = sch["required"];
            local i = 0;
            during i < len(need) {
                given not has(value, need[i]) { schema_fail(errs, path, "missing required key '" + need[i] + "'"); }
                i += 1;
            }
        }
        local props = {};
        given has(sch, "properties") { props = sch["properties"]; }
        local pk = codec.sorted_keys(props);
        local i = 0;
        during i < len(pk) {
            given has(value, pk[i]) {
                schema_check(value[pk[i]], props[pk[i]], jpath.append_key(path, pk[i]), errs);
            }
            i += 1;
        }
        given has(sch, "additional") {
            given not sch["additional"] {
                local vk = codec.sorted_keys(value);
                i = 0;
                during i < len(vk) {
                    given not has(props, vk[i]) { schema_fail(errs, path, "unexpected key '" + vk[i] + "'"); }
                    i += 1;
                }
            }
        }
    }
}

forge validate(value, sch) {
    local errs = [];
    schema_check(value, sch, "", errs);
    yield errs;
}

forge check(value, sch) {
    local errs = validate(value, sch);
    given len(errs) > 0 { raise "schema: " + errs[0]; }
    yield none;
}
