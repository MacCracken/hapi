#!/bin/sh
# concurrency-test.sh — regression harness for F-012 (the unlocked
# manifest read-modify-write) and the write-path integrity around it.
#
# WHY THIS IS A SHELL SCRIPT AND NOT A .tcyr GROUP
# The defect only appears with two hapi PROCESSES racing. The `.tcyr`
# harness cannot fork, and hapi is syscall-only by rule (CLAUDE.md:
# "No process spawning from inside command handlers"), so there is no
# honest way to express this inside `cyrius test`. This lives alongside
# it instead, the way docs/benchmarks.md's harness does.
#
# Usage:  sh scripts/concurrency-test.sh [path-to-hapi]
# Exit:   0 all checks pass, 1 otherwise.

set -e

HAPI="${1:-./build/hapi}"
if [ ! -x "$HAPI" ]; then
    echo "FAIL: no hapi binary at $HAPI"
    echo "  build one with: cyrius build src/main.cyr build/hapi"
    exit 1
fi
HAPI=$(cd "$(dirname "$HAPI")" && pwd)/$(basename "$HAPI")

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAIL=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then
        echo "  ok    $1: $2"
    else
        echo "  FAIL  $1: got $2, expected $3"
        FAIL=1
    fi
}

# ── F-012 ────────────────────────────────────────────────────────────
# N concurrent `hapi adopt` against ONE package. Every adopt commits a
# rename, a symlink and a trail entry, so every one of them MUST also
# leave a manifest row behind. Before the fix this produced 16 files
# moved, 16 symlinks, 16 trail entries — and ONE manifest row.
#
# The manifest carries a large ADR-0001 body on purpose: it widens the
# read-modify-write window, which is what makes the race observable
# rather than merely present. With a tiny manifest the window is short
# enough that 12 concurrent adopts can all land by luck.
N=16
BODY_MB=3

echo "F-012: $N concurrent adopts against one package (${BODY_MB}MB manifest body)"

HOME_DIR="$WORK/home"; STATE_DIR="$WORK/state"; PKG="$WORK/pkg"
mkdir -p "$HOME_DIR" "$STATE_DIR" "$PKG"

{
    printf '[package]\nname = "conc"\nversion = "1.0.0"\n\n---\n'
    i=0
    while [ $i -lt $((BODY_MB * 12)) ]; do
        # ~87 KB per iteration
        awk 'BEGIN{s="";for(i=0;i<1000;i++)s=s "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";print s}'
        i=$((i + 1))
    done
} > "$PKG/hapi.cyml"

i=1
while [ $i -le $N ]; do echo "content $i" > "$HOME_DIR/.conf$i"; i=$((i + 1)); done

i=1
while [ $i -le $N ]; do
    HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_DIR" "$HAPI" adopt ".conf$i" "$PKG" > /dev/null 2>&1 &
    i=$((i + 1))
done
wait

rows=$(grep -c '^\[\[link\]\]' "$PKG/hapi.cyml" || true)
moved=$(find "$PKG" -maxdepth 1 -name 'conf*' | wc -l | tr -d ' ')
links=$(find "$HOME_DIR" -maxdepth 1 -type l | wc -l | tr -d ' ')
trail=$(wc -l < "$STATE_DIR/hapi/audit.jsonl" | tr -d ' ')
stray=$(find "$PKG" -maxdepth 1 -name '*.tmp*' | wc -l | tr -d ' ')
body=$(grep -c 'xxxxx' "$PKG/hapi.cyml" || true)

check "manifest rows"      "$rows"  "$N"
check "files moved"        "$moved" "$N"
check "symlinks planted"   "$links" "$N"
check "trail entries"      "$trail" "$N"
check "stray tmp files"    "$stray" "0"
[ "$body" -gt 0 ] && echo "  ok    body preserved" || { echo "  FAIL  body lost"; FAIL=1; }

# The invariant that actually matters: the declarative state and the
# filesystem must agree. A row count that merely matches N is not enough
# if the two drifted in opposite directions.
check "rows == files moved" "$rows" "$moved"

# ── crash-leftover staging file ──────────────────────────────────────
# A `.tmp` left by a killed run must not be silently reused (O_EXCL).
# Same pid is not reproducible here, so this asserts the weaker but
# checkable property: a stale tmp does not corrupt the next write.
echo "write path: a stale staging file does not corrupt the next adopt"
echo "GARBAGE" > "$PKG/hapi.cyml.99999.tmp"
echo "late" > "$HOME_DIR/.late"
HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_DIR" "$HAPI" adopt ".late" "$PKG" > /dev/null 2>&1
rows2=$(grep -c '^\[\[link\]\]' "$PKG/hapi.cyml" || true)
check "row appended past the stale tmp" "$rows2" "$((N + 1))"
grep -q GARBAGE "$PKG/hapi.cyml" && { echo "  FAIL  stale tmp content leaked into the manifest"; FAIL=1; } || echo "  ok    stale tmp content did not leak"

if [ $FAIL -eq 0 ]; then
    echo "PASS: concurrency harness"
else
    echo "FAIL: concurrency harness"
fi
exit $FAIL
