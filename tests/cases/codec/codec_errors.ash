@import <../../../src/core/codec/codec.ash>;

forge try_parse(text) {
    attempt { say codec.stringify(codec.parse(text)); } handle (e) { say e; }
}

try_parse("{bad json");
try_parse("\"never closed");
try_parse("[1, 2");
try_parse("[1 2]");
try_parse("{\"a\" 1}");
try_parse("{\"a\": 1,}");
try_parse("tru");
try_parse("nul");
try_parse("[1] x");
try_parse("");
try_parse("-");
try_parse("1.");
try_parse("1e");
try_parse("{\n  \"a\": ?\n}");
try_parse("\"bad \\q escape\"");
try_parse("\"\\u00e9\"");
try_parse("\"\\u12\"");
try_parse("\"\\b\"");
attempt { codec.stringify(forge(x) { yield x; }); } handle (e) { say e; }
attempt { codec.parse(5); } handle (e) { say e; }
