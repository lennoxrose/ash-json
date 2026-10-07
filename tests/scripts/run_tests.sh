#!/bin/sh
# Runs every tests/cases/<module>/<name>.ash on ashvm and on kiln and compares
# stdout with tests/expected/<name>.out. Usage: tests/scripts/run_tests.sh [name-filter]
# ASH_BIN points at the directory holding ashvm and kiln (default: ../ash/bin).
cd "$(dirname "$0")/../.." || exit 1
BIN="${ASH_BIN:-../ash/bin}"
TMP=tests/tmp
mkdir -p "$TMP"
pass=0; fail=0
for f in tests/cases/*/*.ash; do
    name=$(basename "$f" .ash)
    case "$name" in *"$1"*) ;; *) continue ;; esac
    exp="tests/expected/$name.out"
    "$BIN/ashvm" "$f" > "$TMP/$name.vm" 2>&1
    if "$BIN/kiln" "$f" -o "$TMP/$name.bin" > "$TMP/$name.kiln" 2>&1; then
        "$TMP/$name.bin" > "$TMP/$name.kiln" 2>&1
    fi
    for eng in vm kiln; do
        if cmp -s "$TMP/$name.$eng" "$exp"; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            echo "FAIL $name ($eng)"
            diff "$exp" "$TMP/$name.$eng" | head -10
        fi
    done
done
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
