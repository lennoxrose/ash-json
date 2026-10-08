@import <../../../src/core/codec/codec.ash>;
@import <../../../src/data/document/doc.ash>;

local src = "{\"name\": \"app\", \"debug\": true, \"retries\": 3, \"flags\": [true, false, 1], \"net\": {\"tls\": false, \"ports\": [80, 443]}}";
local d = doc.from_text(src);

// Booleans are real yes/no values, so they work in conditions.
given doc.get(d, "debug", no) { say "debug is on"; }
given not doc.get(d, "net.tls", yes) { say "tls is off"; }
say doc.get(d, "retries", 0) + 1;

say doc.text(d);

// An untouched document reproduces itself (modulo whitespace and key order).
say codec.stringify(codec.parse(doc.text(d))) == codec.stringify(codec.parse(src));

doc.set(d, "retries", 5);
doc.set_bool(d, "net.verify", yes);
doc.set_bool(d, "debug", no);
doc.set(d, "net.tls", 1);
say codec.stringify(doc.value(d));

// Removing an array element keeps the booleans behind it.
doc.remove(d, "flags[0]");
say codec.stringify(doc.value(d));
doc.remove(d, "net");
say codec.stringify(doc.value(d));

// Save and re-open.
local path = "tests/tmp/doc_config.json";
doc.save(path, d);
say read_file(path);
local again = doc.open(path);
say doc.text(again) == doc.text(d);

forge fails(thunk) {
    attempt { thunk(); say "no error"; } handle (e) { say e; }
}
fails(forge() { doc.set_bool(d, "x", 2); });
fails(forge() { doc.remove(d, ""); });
