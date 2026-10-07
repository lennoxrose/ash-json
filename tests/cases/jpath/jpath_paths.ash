@import <../../../src/core/path/jpath.ash>;

say jpath.split_path("server.ports[0].name");
say jpath.split_path("a[\"x.y\"].b");
say jpath.split_path("");
say jpath.join_segments(["server", "ports", 0, "name"]);
say jpath.join_segments(["a", "x.y", "b"]);
say jpath.join_segments([]);
say jpath.join_segments(jpath.split_path("a[\"q\\\"r\"][2]"));
say jpath.to_pointer(["a", 0, "b/c", "d~e"]);
say jpath.to_pointer([]);
say jpath.from_pointer("/a/0/b~1c/d~0e");
say jpath.from_pointer("");
say jpath.is_index("12");
say jpath.is_index("1a");
say jpath.is_index("");
attempt { jpath.split_path("a[x]"); } handle (e) { say e; }
attempt { jpath.split_path("a[\"x"); } handle (e) { say e; }
attempt { jpath.from_pointer("a/b"); } handle (e) { say e; }
