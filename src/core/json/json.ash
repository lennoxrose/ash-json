// json.ash -- the 0.1.0 API (json.parse / stringify / load / save) plus json.pretty.
// One-line wrappers over codec.ash, kept so existing `json.parse(...)` code works.
// You normally don't import this file: ash-json.ash (the package entry) loads it.

@import <../path/jpath.ash>;
@import <../codec/codec.ash>;

forge parse(text) { yield codec.parse(text); }
forge stringify(value) { yield codec.stringify(value); }
forge pretty(value, indent) { yield codec.pretty(value, indent); }
forge load(path) { yield codec.load(path); }
forge save(path, value) { yield codec.save(path, value); }
