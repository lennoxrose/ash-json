// ash-json.ash -- the single entry point of ash-json 0.2.0. It defines nothing itself:
// it only imports every module (Ash merges imports into one namespace table, so
// they all become callable). Its own namespace would be "ash-json", which can't be
// written in code (the dash lexes as minus), hence the json.* wrappers live in
// src/core/json/json.ash.
//
//   @import <ash-json>;           // installed: forgepack add github:lennoxrose/ash-json
//   @import <./ash-json.ash>;     // from a checkout
//
//   json.parse / json.stringify / json.pretty / json.load / json.save   (0.1.0 API)
//   codec.*   the codec itself      query.*   get/exists/set/remove by path
//   doc.*     load/edit/save keeping true/false
//   merge.*   clone/equal/merge/diff/patch      schema.*  validate/check
//   files.*   load_or, JSONC config, JSON Lines             jpath.*   path syntax
// See README.md for every function.

@import <./src/core/path/jpath.ash>;
@import <./src/core/codec/codec.ash>;
@import <./src/core/json/json.ash>;
@import <./src/data/query/query.ash>;
@import <./src/data/document/doc.ash>;
@import <./src/data/merge/merge.ash>;
@import <./src/validate/schema/schema.ash>;
@import <./src/io/files/files.ash>;
