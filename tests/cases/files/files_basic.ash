@import <../../../src/io/files/files.ash>;

local dir = "tests/tmp/";

// comments and trailing commas, but never inside strings
local cfg = "// header\n{\n  \"url\": \"http://x.y/a//b\", /* inline */\n  \"quote\": \"say \\\"/* no */\\\"\",\n  \"list\": [1, 2, 3,],\n  \"obj\": {\"k\": 1,},\n}\n";
write_file(dir + "files_config.jsonc", cfg);
say codec.stringify(files.load_config(dir + "files_config.jsonc"));
say codec.stringify(files.parse_config("[1,\n // c\n 2 , ]"));
say codec.stringify(files.parse_config("{\"a\": \"x,]\", }"));
say codec.stringify(files.parse_config("[1, 2] // tail"));

// load_or
say codec.stringify(files.load_or(dir + "files_missing.json", {"default": 1}));
codec.save(dir + "files_present.json", {"present": 2});
say codec.stringify(files.load_or(dir + "files_present.json", {"default": 1}));

// JSON Lines
files.write_lines(dir + "files_log.jsonl", [{"id": 1, "msg": "a\nb"}, [1, 2], "s", none]);
say read_file(dir + "files_log.jsonl");
files.append_line(dir + "files_log.jsonl", {"id": 5});
local rows = files.read_lines(dir + "files_log.jsonl");
say len(rows);
say codec.stringify(rows);

write_file(dir + "files_bad.jsonl", "{\"ok\": 1}\n\n{broken\n");
attempt { files.read_lines(dir + "files_bad.jsonl"); } handle (e) { say e; }
write_file(dir + "files_bad2.jsonl", "1 2\n");
attempt { files.read_lines(dir + "files_bad2.jsonl"); } handle (e) { say e; }
write_file(dir + "files_empty.jsonl", "");
say codec.stringify(files.read_lines(dir + "files_empty.jsonl"));
