@import <../../../src/core/codec/codec.ash>;

say codec.stringify(codec.parse("{\"b\": [1, 2.5, -3], \"a\": {\"z\": null, \"y\": \"hi\"}}"));
say codec.stringify(codec.parse("  [ ]  "));
say codec.stringify(codec.parse("{}"));
say codec.stringify(codec.parse("\"line\\nbreak \\\"q\\\" \\\\ \\/ tab\\t\""));
say codec.stringify(codec.parse("\"A\\u0041\\u007e\\u0020!\""));
say codec.stringify(codec.parse("[1e2, 1E+2, 1.5e-1, -0.5, 0, 12345]"));
say codec.stringify(codec.parse("[true, false, null]"));
say codec.stringify(["x", 1, none, {"k": [1, 2]}]);
say codec.pretty({"b": [1, {"c": 2}], "a": [], "d": {}}, 2);
say codec.pretty([1, 2], 4);
say codec.pretty("s", 2);
say codec.stringify(codec.parse("{\"m\": 1, \"B\": 2, \"a\": 3, \"ab\": 4, \"_\": 5, \"2\": 6}"));
