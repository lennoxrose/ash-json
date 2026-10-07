@import <../../../src/core/codec/codec.ash>;
@import <../../../src/data/merge/merge.ash>;

forge j(text) { yield codec.parse(text); }
forge s(v) { yield codec.stringify(v); }

// clone is independent
local orig = j("{\"a\": [1, {\"b\": 2}]}");
local copy = merge.clone(orig);
push(copy["a"], 3);
say s(orig) + " " + s(copy);

// equal
say merge.equal(j("{\"a\": [1, 2], \"b\": null}"), j("{\"b\": null, \"a\": [1, 2]}"));
say merge.equal(j("[1, 2]"), j("[1, 2, 3]"));
say merge.equal(j("{\"a\": 1}"), j("{\"a\": 2}"));
say merge.equal(j("{\"a\": 1}"), j("{\"b\": 1}"));
say merge.equal(1, "1");
say merge.equal(none, none);
say merge.equal(j("[]"), j("{}"));

// merge: deep, b wins, arrays replaced, inputs untouched
local base = j("{\"server\": {\"host\": \"a\", \"port\": 80}, \"tags\": [1, 2], \"keep\": true}");
local over = j("{\"server\": {\"port\": 8080, \"tls\": 1}, \"tags\": [9], \"extra\": null}");
say s(merge.merge(base, over));
say s(base);
say s(merge.merge(base, 5));
say s(merge.merge(5, over));

// diff + patch
local a = j("{\"name\": \"x\", \"gone\": 1, \"list\": [1, 2, 3, 4], \"n\": {\"p\": 1, \"q\": [1]}}");
local b = j("{\"name\": \"y\", \"new\": [true], \"list\": [1, 5], \"n\": {\"p\": 1, \"q\": [1, 2, 3]}}");
local ops = merge.diff(a, b);
local i = 0;
during i < len(ops) { say s(ops[i]); i += 1; }
say merge.equal(merge.patch(a, ops), b);
say s(a);
say s(merge.diff(a, a));
say s(merge.diff(1, 2));
say s(merge.patch(1, merge.diff(1, 2)));
say s(merge.diff(j("[1, [2]]"), j("[1, [2, 3], 4]")));

// hand-written patch: insert into the middle, append with "-", pointer escapes
local p = j("{\"a/b\": [1, 3], \"m~n\": 0}");
say s(merge.patch(p, j("[{\"op\": \"add\", \"path\": \"/a~1b/1\", \"value\": 2}, {\"op\": \"add\", \"path\": \"/a~1b/-\", \"value\": 4}, {\"op\": \"replace\", \"path\": \"/m~0n\", \"value\": 1}, {\"op\": \"remove\", \"path\": \"/a~1b/0\"}]")));

forge fails(thunk) {
    attempt { thunk(); say "no error"; } handle (e) { say e; }
}
fails(forge() { merge.patch({}, j("[{\"op\": \"remove\", \"path\": \"/x\"}]")); });
fails(forge() { merge.patch({}, j("[{\"op\": \"replace\", \"path\": \"/x\", \"value\": 1}]")); });
fails(forge() { merge.patch({}, j("[{\"op\": \"move\", \"path\": \"/x\"}]")); });
fails(forge() { merge.patch({}, j("[{\"op\": \"add\", \"path\": \"/x\"}]")); });
fails(forge() { merge.patch({}, j("[5]")); });
