@import <../../../src/core/codec/codec.ash>;

local pair = codec.parse_marked("{\"debug\": true, \"n\": 1, \"off\": false, \"list\": [true, 1, false], \"a.b\": {\"x\": true}}");
say codec.stringify(pair[0]);
say codec.stringify(codec.sorted_keys(pair[1]));
say codec.stringify(pair[1]);
say codec.encode(pair[0], 0, pair[1]);
say codec.encode(pair[0], 2, pair[1]);
say codec.encode(pair[0], 0, none);

local root = codec.parse_marked("true");
say codec.encode(root[0], 0, root[1]);

local path = "tests/tmp/codec_save.json";
codec.save(path, {"k": [1, 2], "a": "x"});
say read_file(path);
say codec.stringify(codec.load(path));
