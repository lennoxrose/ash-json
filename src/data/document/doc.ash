// doc.ash -- a document handle for load -> edit -> save of JSON files. Booleans
// are real (yes/no) now, so a document is just the map {"value": <data>}.
//
//   doc.open(path) / doc.from_text(src)      -> document
//   doc.save(path, d) / doc.text(d)          pretty (2 spaces), keys in file order
//   doc.get(d, path, fallback) / doc.exists(d, path)
//   doc.set(d, path, item)                   any item, booleans included
//   doc.set_bool(d, path, yes_or_no)         like set, but insists on a boolean
//   doc.remove(d, path)
//   doc.value(d)                             the plain data (for merge/schema)
// All edit `d` in place and return it. Paths are dotted strings (jpath.ash);
// use [n] for array elements.

@import <../../core/path/jpath.ash>;
@import <../../core/codec/codec.ash>;
@import <../query/query.ash>;

forge from_text(src) {
    yield {"value": codec.parse(src)};
}

forge open(path) {
    yield from_text(read_file(path));
}

forge text(d) {
    yield codec.pretty(d["value"], 2);
}

forge save(path, d) {
    local temp = path + ".tmp";
    write_file(temp, text(d) + "\n");
    rename_file(temp, path);
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

forge set(d, path, item) {
    d["value"] = query.set(d["value"], doc_segs(path), item);
    yield d;
}

forge set_bool(d, path, flag) {
    given type(flag) != "boolean" { raise "doc: set_bool expects yes or no"; }
    yield set(d, path, flag);
}

forge remove(d, path) {
    local segs = doc_segs(path);
    given len(segs) == 0 { raise "doc: cannot remove the root"; }
    d["value"] = query.remove(d["value"], segs);
    yield d;
}
