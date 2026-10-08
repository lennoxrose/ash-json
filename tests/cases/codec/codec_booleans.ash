@import <../../../src/core/codec/codec.ash>;

local v = codec.parse("{\"debug\": true, \"n\": 1, \"off\": false, \"list\": [true, 1, false], \"a.b\": {\"x\": true}}");
say v["debug"];
say v["off"];
say type(v["debug"]);
say v["n"] == 1;
say v["debug"] == 1;
say codec.stringify(v);
say codec.pretty(v, 2);
say codec.stringify(codec.sorted_keys(v));
say codec.encode(v, 0);
say codec.encode(v, 2);
say codec.stringify(codec.parse("true"));
say codec.stringify([yes, no, 1, 0, none]);

local path = "tests/tmp/codec_save.json";
codec.save(path, {"k": [1, 2], "a": "x"});
say read_file(path);
say file_exists(path + ".tmp");
say codec.stringify(codec.load(path));
