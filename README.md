# ash-json 0.2.0

JSON for [Ash](../ash): parse, edit, merge, validate and save JSON files from
plain Ash programs. Pure Ash, runs on `ashvm` and `kiln`.

Install with forgepack, then import by package name:

```sh
forgepack add github:lennoxrose/ash-json
```

```ash
@import <ash-json>;              // the only import you need (from a checkout: @import <./ash-json.ash>;)

local cfg = doc.open("config.json");           // keeps true/false when saved again
given doc.get(cfg, "debug", no) { say "debug on"; }
doc.set(cfg, "server.ports[0]", 8080);
doc.set_bool(cfg, "server.tls", yes);
doc.save("config.json", cfg);                  // pretty, keys sorted, true/false intact
```

> **Needs a raised function limit.** Ash currently allows 64 functions per
> program and ash-json defines 87, so `@import <ash-json>;` only works on
> engines built with `MAX_VM_FUNCS` / `MAX_KILN_FUNCS` raised. See `needs.md`.
> Until then import single modules, e.g. `@import <./src/data/query/query.ash>;`.

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
needs.md                          what Ash is missing for this library
```

## API

Every function raises a string beginning with its module name (`json: ...`) on bad input.

**json** (0.1.0 API, unchanged): `parse(text)`, `stringify(value)`, `load(path)`,
`save(path, value)`, plus `pretty(value, indent)`.

**codec**: `parse`, `stringify` (compact, keys sorted), `pretty(value, indent)`,
`load`, `save`, `parse_lines(text)`, `parse_marked(text)` -> `[value, bools]`,
`encode(value, indent, bools)`, `sorted_keys(map)`. Errors read
`json: expected ',' or ']' at line 3, column 9`.

**query**: `get(value, path, fallback)`, `exists(value, path)`, `set(value, path, item)`,
`remove(value, path)`. Paths: `server.ports[0]`, `["odd.key"]`, or a segment list.
`set` creates missing maps/arrays and appends at `[len]`; `set`/`remove` return the
root, so write `v = query.remove(v, "a[0]")`.

**doc**: `open(path)`, `from_text(src)`, `save(path, d)`, `text(d)`, `value(d)`,
`get`, `exists`, `set`, `set_bool(d, path, yes_or_no)`, `remove`. Values are plain
`1`/`0` (usable in `given`); the document remembers which paths were `true`/`false`
and writes them back.

**merge**: `clone`, `equal`, `merge(a, b)` (deep, `b` wins, arrays replaced),
`diff(a, b)` -> `[{"op","path","value"}]` (JSON Pointer), `patch(v, ops)`
(`add` / `remove` / `replace`). `equal(patch(a, diff(a, b)), b)` always holds.

**schema**: `validate(value, schema)` -> list of `"path: message"` (empty = valid),
`check(value, schema)` raises the first. Keywords: `type`, `enum`, `min`, `max`,
`min_length`, `max_length`, `items`, `required`, `properties`, `additional`.

**files**: `load_or(path, fallback)`, `load_config(path)` / `parse_config(src)` (allows
`//` and `/* */` comments and trailing commas), `read_lines`, `write_lines`, `append_line`.

## Limitations (Ash, not the library -- see needs.md)

- No boolean type: plain `parse` turns `true`/`false` into `1`/`0`; use `doc` to keep them.
- Map keys come out sorted (Ash's key order differs between engines); original order is lost.
- `\uXXXX` decodes only printable ASCII; other `\u` escapes, `\b` and `\f` raise. Raw UTF-8 passes through.
- No atomic save (no file rename), and `str(number)` for huge/tiny numbers differs between engines.

## Tests

```sh
tests/scripts/run_tests.sh [name-filter]     # ASH_BIN=<dir with ashvm and kiln>, default ../ash/bin
```

Each `tests/cases/<module>/*.ash` runs on ashvm and kiln; stdout must equal
`tests/expected/<name>.out` on both.
