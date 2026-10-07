@import <../../../src/core/codec/codec.ash>;
@import <../../../src/validate/schema/schema.ash>;

forge j(text) { yield codec.parse(text); }
forge show(value, sch) { say codec.stringify(schema.validate(value, sch)); }

local config = j("{\"type\": \"object\", \"required\": [\"name\", \"port\"], \"additional\": 0, \"properties\": {\"name\": {\"type\": \"string\", \"min_length\": 1, \"max_length\": 8}, \"port\": {\"type\": \"integer\", \"min\": 1, \"max\": 65535}, \"debug\": {\"type\": \"boolean\"}, \"mode\": {\"enum\": [\"fast\", \"safe\"]}, \"tags\": {\"type\": \"array\", \"max_length\": 2, \"items\": {\"type\": \"string\"}}, \"net\": {\"type\": \"object\", \"required\": [\"host\"], \"properties\": {\"host\": {\"type\": \"string\"}}}}}");

show(j("{\"name\": \"app\", \"port\": 8080, \"debug\": true, \"mode\": \"fast\", \"tags\": [\"a\"], \"net\": {\"host\": \"h\"}}"), config);
show(j("{}"), config);
show(j("{\"name\": \"\", \"port\": 0}"), config);
show(j("{\"name\": \"waytoolongname\", \"port\": 70000.5}"), config);
show(j("{\"name\": 5, \"port\": \"x\", \"debug\": 2, \"mode\": \"slow\"}"), config);
show(j("{\"name\": \"a\", \"port\": 1, \"tags\": [\"a\", 2, \"c\"], \"net\": {}, \"extra\": 1, \"another\": 2}"), config);
show(j("[1]"), config);
show(j("{\"net\": {\"host\": null}, \"name\": \"a\", \"port\": 1}"), config);
show(5, j("{\"type\": \"any\"}"));
show(none, j("{\"type\": \"null\"}"));
show([1, [2, "x"]], j("{\"type\": \"array\", \"items\": {\"type\": \"array\", \"items\": {\"type\": \"number\"}}}"));
show(j("{\"k\": [{\"v\": 1}, {\"v\": \"s\"}]}"), j("{\"properties\": {\"k\": {\"items\": {\"properties\": {\"v\": {\"type\": \"number\"}}}}}}"));
show(5, {});

schema.check(j("{\"name\": \"ok\", \"port\": 1}"), config);
say "check passed";
attempt { schema.check(j("{\"name\": \"ok\"}"), config); } handle (e) { say e; }
attempt { schema.validate(1, {"type": "nope"}); } handle (e) { say e; }
