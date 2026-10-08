# ash-json 0.3.0

JSON for [Ash](../ash): parse, edit, merge, validate and save JSON files from
plain Ash programs. Pure Ash, runs on `ashvm` and `kiln`.

Install with forgepack, then import by package name:

```sh
forgepack add github:lennoxrose/ash-json
```

```ash
@import <ash-json>;              // the only import you need (from a checkout: @import <./ash-json.ash>;)

local cfg = doc.open("config.json");           // true/false are real booleans
given doc.get(cfg, "debug", no) { say "debug on"; }
doc.set(cfg, "server.ports[0]", 8080);
doc.set_bool(cfg, "server.tls", yes);
doc.save("config.json", cfg);                  // pretty, keys in file order, true/false intact
```

> **Needs the current Ash.** 0.3.0 builds on real booleans, insertion-ordered maps,
> forward declarations, `chr`/`ord`,
> `sort`, `rename_file` and the raised function limit; it does not run on older engines.

## Layout

```
ash-json.ash                      the entry point; only imports the modules below
src/core/json/json.ash            the 0.1.0 API: json.parse / stringify / load / save / pretty
src/core/path/jpath.ash           path syntax: dotted ("a.b[0]") and JSON Pointer
src/core/codec/codec.ash          parse / stringify / pretty / JSON Lines
src/data/query/query.ash          get / exists / set / remove by path
src/data/document/doc.ash         load -> edit -> save without losing true/false
src/data/merge/merge.ash          clone / equal / merge / diff / patch
src/validate/schema/schema.ash    validate values against a schema
src/io/files/files.ash            load_or, JSONC config, JSON Lines
tests/                            golden-output tests, run on both engines
```

## API

Every function raises a string beginning with its module name (`json: ...`) on bad input.

**json** (0.1.0 API, unchanged): `parse(text)`, `stringify(value)`, `load(path)`,
`save(path, value)`, plus `pretty(value, indent)`.

**codec**: `parse`, `stringify` (compact, keys in insertion order), `pretty(value, indent)`,
`load`, `save` (writes a temp file, then renames it over the target), `parse_lines(text)`,
`encode(value, indent)`, `sorted_keys(map)`. `true`/`false`/`null` are `yes`/`no`/`none`;
`\uXXXX` (surrogate pairs too), `\b` and `\f` are decoded. Errors read
`json: expected ',' or ']' at line 3, column 9`.

**query**: `get(value, path, fallback)`, `exists(value, path)`, `set(value, path, item)`,
`remove(value, path)`. Paths: `server.ports[0]`, `["odd.key"]`, or a segment list.
`set` creates missing maps/arrays and appends at `[len]`; `set`/`remove` return the
root, so write `v = query.remove(v, "a[0]")`.

**doc**: `open(path)`, `from_text(src)`, `save(path, d)`, `text(d)`, `value(d)`,
`get`, `exists`, `set`, `set_bool(d, path, yes_or_no)`, `remove`. A document is the
map `{"value": data}`; booleans are real, and keys keep the file's order on save.

**merge**: `clone`, `equal`, `merge(a, b)` (deep, `b` wins, arrays replaced),
`diff(a, b)` -> `[{"op","path","value"}]` (JSON Pointer), `patch(v, ops)`
(`add` / `remove` / `replace`). `equal(patch(a, diff(a, b)), b)` always holds.

**schema**: `validate(value, schema)` -> list of `"path: message"` (empty = valid),
`check(value, schema)` raises the first. Keywords: `type`, `enum`, `min`, `max`,
`min_length`, `max_length`, `items`, `required`, `properties`, `additional`.

**files**: `load_or(path, fallback)`, `load_config(path)` / `parse_config(src)` (allows
`//` and `/* */` comments and trailing commas), `read_lines`, `write_lines`, `append_line`.

## Changes in 0.3.0

- The codec was rewritten on the language's new tools (real booleans, `chr`/`ord`, forward declarations), without any compiler support.
- `parse_marked`, the `bools` argument of `encode` and the boolean bookkeeping in `doc` are gone: `true`/`false` parse to `yes`/`no` and print back as `true`/`false`.
- Output keeps the key order of the input instead of sorting (`codec.sorted_keys` is still there).
- `load`/`save` and `doc.save` are atomic (temp file + rename).
- `schema` type `"boolean"` means a real boolean.

## Limitations

- Numbers print with at most 6 fraction digits (Ash's number format), so `3.14159265` comes back as `3.141593`.
- `\u0000` cannot be represented (Ash strings are NUL-terminated) and raises.

## Tests

```sh
tests/scripts/run_tests.sh [name-filter]     # ASH_BIN=<dir with ashvm and kiln>, default ../ash/bin
```

Each `tests/cases/<module>/*.ash` runs on ashvm and kiln; stdout must equal
`tests/expected/<name>.out` on both.
