@import <../../../ash-json.ash>;

// This file imports ONLY json.ash. Everything below must resolve through it
// (transitive imports are visible: a compiler change that breaks this fails here).
local v = json.parse("{\"b\": [1, 2], \"a\": {\"on\": true}}");
say json.stringify(v);
say json.pretty(v, 2);
say query.get(v, "b[1]", 0);
say codec.stringify(codec.sorted_keys({"z": 1, "y": 2}));
say json.stringify(jpath.split_path("a.b[0]"));
say json.stringify(merge.merge(v, {"b": [9]}));
say json.stringify(schema.validate(v, {"type": "array"}));
say json.stringify(files.parse_config("[1, 2,] // c"));

local d = doc.from_text("{\"x\": false}");
doc.set(d, "y", 1);
say doc.text(d);

// 0.1.0 API: load/save
json.save("tests/tmp/entry_v01.json", {"k": [1, none, "s"]});
say read_file("tests/tmp/entry_v01.json");
say json.stringify(json.load("tests/tmp/entry_v01.json"));
