@import <../../../src/core/codec/codec.ash>;
@import <../../../src/data/query/query.ash>;

local doc = codec.parse("{\"server\": {\"ports\": [80, 443], \"name\": \"web\"}, \"a.b\": 1, \"list\": [{\"id\": 1}, {\"id\": 2}]}");

say query.get(doc, "server.name", "?");
say query.get(doc, "server.ports[1]", "?");
say query.get(doc, "server.ports[5]", "?");
say query.get(doc, "server.nope.deeper", "?");
say query.get(doc, "a[\"b\"]", "?");
say query.get(doc, "[\"a.b\"]", "?");
say query.get(doc, "list[1].id", "?");
say query.get(doc, "server.name.x", "?");
say query.get(doc, ["server", "ports", 0], "?");
say codec.stringify(query.get({"r": 1}, "", "?"));
say query.exists(doc, "server.ports[0]");
say query.exists(doc, "server.ports[2]");

doc = query.set(doc, "server.name", "api");
doc = query.set(doc, "server.ports[2]", 8080);
doc = query.set(doc, ["server", "ports", "-"], 9090);
doc = query.set(doc, "new.deep[0]", "x");
doc = query.set(doc, "list[0].id", 10);
say codec.stringify(doc);

doc = query.remove(doc, "server.name");
doc = query.remove(doc, "server.ports[1]");
doc = query.remove(doc, "list[1]");
doc = query.remove(doc, "missing.path");
doc = query.remove(doc, "new");
say codec.stringify(doc);

say codec.stringify(query.set(doc, "", [1]));
say codec.stringify(query.remove([1, 2, 3], "[0]"));

forge fails(label, thunk) {
    attempt { thunk(); say label + ": no error"; } handle (e) { say e; }
}
fails("range", forge() { query.set([1], "[5]", 0); });
fails("scalar", forge() { query.set({"a": 1}, "a.b", 0); });
fails("root", forge() { query.remove({}, ""); });
fails("syntax", forge() { query.get({}, "a[", 0); });
fails("array-key", forge() { query.set([1], "k", 0); });
