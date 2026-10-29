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

# ── 1.7.0: fmt racing adopt ─────────────────────────────────────────
# `hapi fmt` rewrites the whole header, so an adopt that appended a row
# between fmt's read and its commit would lose that row. Both take the
# package-directory lock across their read-modify-write; this proves it,
# with the same large body widening the window. One round missed a
# lockless fmt in 5 of 12 runs (2026-10-29 audit, finding 207), so it
# runs several, each from a fresh copy.
FROUNDS=5
echo "1.7.0: $N concurrent adopts racing four fmt loops against one package, $FROUNDS rounds"
HOME2="$WORK/home2"; STATE2="$WORK/state2"; PKG2="$WORK/pkg2"; BODY2="$WORK/pkg2.cyml"
{
    printf '[package]\nversion = "1.0.0"\nname = "conc2"\n\n---\n'
    i=0
    while [ $i -lt $((BODY_MB * 12)) ]; do
        awk 'BEGIN{s="";for(i=0;i<1000;i++)s=s "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy";print s}'
        i=$((i + 1))
    done
} > "$BODY2"
rowsbad=0; movedbad=0; straybad=0; parsebad=0; fmtbad=0; bodybad=0
r=1
while [ $r -le $FROUNDS ]; do
    rm -rf "$HOME2" "$STATE2" "$PKG2"
    mkdir -p "$HOME2" "$STATE2" "$PKG2"
    cp "$BODY2" "$PKG2/hapi.cyml"
    i=1
    while [ $i -le $N ]; do echo "content $i" > "$HOME2/.f$i"; i=$((i + 1)); done
    # Adopts queue on the lock, so they commit one after another over a
    # while; four fmt loops keep rewriting across that whole stretch,
    # rather than all finishing before the first adopt commits.
    i=1
    while [ $i -le $N ]; do
        HOME="$HOME2" XDG_STATE_HOME="$STATE2" "$HAPI" adopt ".f$i" "$PKG2" > /dev/null 2>&1 &
        i=$((i + 1))
    done
    w=1
    while [ $w -le 4 ]; do
        ( k=0; while [ $k -lt 30 ]; do "$HAPI" fmt "$PKG2" > /dev/null 2>&1; k=$((k + 1)); done ) &
        w=$((w + 1))
    done
    wait
    "$HAPI" fmt "$PKG2" > /dev/null 2>&1 || true
    rows3=$(grep -c '^\[\[link\]\]' "$PKG2/hapi.cyml" || true)
    moved3=$(find "$PKG2" -maxdepth 1 -name 'f*' | wc -l | tr -d ' ')
    stray3=$(find "$PKG2" -maxdepth 1 -name '*.tmp*' | wc -l | tr -d ' ')
    [ "$rows3" = "$N" ] || rowsbad=$((rowsbad + 1))
    [ "$rows3" = "$moved3" ] || movedbad=$((movedbad + 1))
    [ "$stray3" = "0" ] || straybad=$((straybad + 1))
    "$HAPI" check "$PKG2" > /dev/null 2>&1 || parsebad=$((parsebad + 1))
    "$HAPI" fmt --check "$PKG2" > /dev/null 2>&1 || fmtbad=$((fmtbad + 1))
    grep -q yyyyy "$PKG2/hapi.cyml" || bodybad=$((bodybad + 1))
    r=$((r + 1))
done
check "rounds short of $N manifest rows"     "$rowsbad"  "0"
check "rounds where rows != files moved"     "$movedbad" "0"
check "rounds leaving a stray tmp file"      "$straybad" "0"
check "rounds whose manifest does not parse" "$parsebad" "0"
check "rounds not formatted after a fmt"     "$fmtbad"   "0"
check "rounds that lost the body"            "$bodybad"  "0"

# ── 1.7.1: adopts deriving one package-side name (F-071) ────────────
# adopt's checks ran before the package lock, and its move was a plain
# rename(2): two adopts whose files derive one name in the package both
# passed, and the second replaced the first one's file, the user's only
# copy (34 losses in 200 runs on 1.7.0). Each round, both contents must
# survive, in the package or where they were, and exactly one adopt win.
ROUNDS=40
echo "1.7.1: two adopts deriving one package-side name, $ROUNDS rounds"
HOME3="$WORK/home3"; STATE3="$WORK/state3"; PKG3="$WORK/pkg3"
lost=0; notone=0
r=1
while [ $r -le $ROUNDS ]; do
    rm -rf "$HOME3" "$STATE3" "$PKG3"
    mkdir -p "$HOME3/.config/a" "$HOME3/.config/b" "$STATE3" "$PKG3"
    printf '[package]\nname = "conc3"\nversion = "1.0.0"\n' > "$PKG3/hapi.cyml"
    echo "A $r" > "$HOME3/.config/a/config"
    echo "B $r" > "$HOME3/.config/b/config"
    HOME="$HOME3" XDG_STATE_HOME="$STATE3" "$HAPI" adopt "$HOME3/.config/a/config" "$PKG3" > /dev/null 2>&1 &
    HOME="$HOME3" XDG_STATE_HOME="$STATE3" "$HAPI" adopt "$HOME3/.config/b/config" "$PKG3" > /dev/null 2>&1 &
    wait
    # grep -r reads regular files and skips symlinks, so each content
    # counts only where its bytes really are.
    grep -rqsx "A $r" "$HOME3" "$PKG3" || lost=$((lost + 1))
    grep -rqsx "B $r" "$HOME3" "$PKG3" || lost=$((lost + 1))
    rows=$(grep -c '^\[\[link\]\]' "$PKG3/hapi.cyml" || true)
    [ "$rows" = "1" ] || notone=$((notone + 1))
    r=$((r + 1))
done
check "contents lost"                    "$lost"   "0"
check "rounds without exactly one adopt" "$notone" "0"

# ── 1.7.1: readers racing appends (F-102) ───────────────────────────
# A reader took no lock, so `list` during another hapi's append saw a
# trail that grew mid-read and refused it as unreadable. Readers take a
# shared lock now. Sixteen packages link while four `list` loops read.
echo "1.7.1: four list loops racing sixteen links"
HOME4="$WORK/home4"; STATE4="$WORK/state4"
mkdir -p "$HOME4" "$STATE4"
i=1
while [ $i -le 16 ]; do
    mkdir -p "$WORK/p4/$i"
    printf '[package]\nname = "p%s"\nversion = "1.0.0"\n' "$i" > "$WORK/p4/$i/hapi.cyml"
    k=1
    while [ $k -le 20 ]; do
        printf '\n[[link]]\nsource = "f%s"\ntarget = ".p%s-f%s"\n' "$k" "$i" "$k" >> "$WORK/p4/$i/hapi.cyml"
        echo "$i $k" > "$WORK/p4/$i/f$k"
        k=$((k + 1))
    done
    i=$((i + 1))
done
HOME="$HOME4" XDG_STATE_HOME="$STATE4" "$HAPI" checkpoint > /dev/null 2>&1
: > "$WORK/list_fail"
w=1
while [ $w -le 4 ]; do
    ( k=0; while [ $k -lt 40 ]; do
        HOME="$HOME4" XDG_STATE_HOME="$STATE4" "$HAPI" list > /dev/null 2>&1 || echo x >> "$WORK/list_fail"
        k=$((k + 1)); done ) &
    w=$((w + 1))
done
i=1
while [ $i -le 16 ]; do
    HOME="$HOME4" XDG_STATE_HOME="$STATE4" "$HAPI" link "$WORK/p4/$i" > /dev/null 2>&1 &
    i=$((i + 1))
done
wait
check "list runs that failed mid-append" "$(wc -l < "$WORK/list_fail" | tr -d ' ')" "0"

# ── 1.7.1: a closed output pipe (F-085) ─────────────────────────────
# Two processes again: hapi, and a reader that has gone. At SIGPIPE's
# default action hapi died there (exit 141), mid-run for unlink, prune
# and rollback. It ignores SIGPIPE now and finishes. The delay makes the
# reader gone before hapi writes.
echo "1.7.1: hapi writing to a pipe whose reader has gone"
( sleep 0.2; "$HAPI" --help 2> /dev/null && rc=0 || rc=$?; echo "$rc" > "$WORK/pipe_rc" ) | true
sleep 0.5
check "exit status with its reader gone" "$(cat "$WORK/pipe_rc" 2>/dev/null)" "0"

if [ $FAIL -eq 0 ]; then
    echo "PASS: concurrency harness"
else
    echo "FAIL: concurrency harness"
fi
exit $FAIL
