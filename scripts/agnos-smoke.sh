#!/bin/sh
# agnos-smoke.sh — run hapi's `--agnos` build under mirshi.
#
# WHY THIS EXISTS
# Several audit findings (F-027, F-031/F-039, F-038, F-040, F-044, and
# ADR 0002's append-atomicity rationale) are target-conditional: they are
# properties of the agnos syscall ABI and cannot be observed from a Linux
# build. The 2026-08-25
# audit recorded them as "blocked on an agnos runner" — which was wrong.
# mirshi, the AGNOS->Linux syscall-translation supervisor, builds in this
# tree and runs an agnos-compiled static ELF as a native Linux process.
# There was no missing runner; nobody had wired it up.
#
# Usage:  sh scripts/agnos-smoke.sh [mirshi] [agnos-elf] [agnos-tests-elf]
# Exit:   0 all checks pass, 1 otherwise, 2 prerequisites missing (skip).
#
# Exit 2 is a SKIP, not a pass. Through 1.1.0 CI accepted it as a warning,
# and since the runner had no mirshi that meant every run skipped (F-043).
# CI now builds mirshi (scripts/build-mirshi.sh) and fails on any non-zero
# exit; the SKIP exists for dev boxes without a mirshi checkout.
#
# The tests ELF is tests/agnos.tcyr built with `--agnos` — the target-
# neutral suite that exercises hapi's agnos-conditional code paths directly.
# The verbs themselves cannot run here (see check 2), so that suite is where
# F-031/F-039, F-038, F-040 and F-044 are proven on this target.

set -e

MIRSHI="${1:-/home/macro/Repos/mirshi/build/mirshi}"
ELF="${2:-./build/hapi-agnos}"
TESTS="${3:-./build/hapi-agnos-tests}"

if [ ! -x "$MIRSHI" ]; then
    echo "SKIP: no mirshi at $MIRSHI"
    echo "  build it with: sh scripts/build-mirshi.sh <work-dir>   (as CI does)"
    exit 2
fi
if [ ! -x "$ELF" ]; then
    echo "SKIP: no agnos build at $ELF"
    echo "  build it with: cyrius build --agnos src/main.cyr build/hapi-agnos"
    exit 2
fi
if [ ! -x "$TESTS" ]; then
    echo "SKIP: no agnos test build at $TESTS"
    echo "  build it with: cyrius build --agnos tests/agnos.tcyr build/hapi-agnos-tests"
    exit 2
fi

FAIL=0
# Everything this script makes in /tmp goes when it exits, however it exits.
PKG=""; SMOKE_HOME=""; TLOG="${TMPDIR:-/tmp}/hapi-agnos-tests.$$"
trap 'rm -rf "$PKG" "$SMOKE_HOME" "$TLOG"' EXIT
run() { "$MIRSHI" "$ELF" "$@" 2>&1 | grep -v '^mirshi:' || true; }

echo "agnos smoke — $ELF under $MIRSHI"

# 1. The binary loads and the agnos arg reader works at all. This is the
#    floor: args_agnos.cyr reads argv off the SysV init stack through r15,
#    a scheme that has broken twice upstream, so proving argv arrives is
#    worth its own check.
ver=$(run --version | head -1)
case "$ver" in
    "hapi "*) echo "  ok    --version under mirshi: $ver" ;;
    *)        echo "  FAIL  --version returned: '$ver'"; FAIL=1 ;;
esac

# 2. The environment gap, asserted rather than assumed.
#    Real agnos stages `HOME=/ PWD=/` into the init envp at exec
#    (lib/args_agnos.cyr's header). mirshi passes NO envp, so hapi cannot
#    resolve a scope root under it. That is a supervisor gap, not a hapi
#    defect — but it bounds what this harness can check, so it is
#    recorded here instead of being rediscovered.
PKG=$(mktemp -d)
printf '[package]\nname = "smoke"\nversion = "1.0.0"\n\n[[link]]\nsource = "f"\ntarget = ".f"\n' > "$PKG/hapi.cyml"
echo x > "$PKG/f"
SMOKE_HOME=$(mktemp -d)
out=$(HOME="$SMOKE_HOME" XDG_STATE_HOME="$SMOKE_HOME/state" run link "$PKG" | head -1)
case "$out" in
    *"HOME is unset"*)
        echo "  ok    env gap present and correctly diagnosed (mirshi passes no envp)"
        echo "        -> scope-rooted verbs cannot be exercised under mirshi yet" ;;
    *)
        echo "  note  env reaches the child ('$out')"
        echo "        -> mirshi gained envp support; widen this harness" ;;
esac
rm -rf "$PKG" "$SMOKE_HOME"; PKG=""; SMOKE_HOME=""

# 3. F-027 — a relative package argument must never yield a non-absolute
#    `abs_source`. agnos has no getcwd; hapi prefers PWD and REFUSES when
#    it cannot determine the cwd, rather than writing a trail entry that
#    violates ADR 0002. Whichever way it goes here, it must not succeed
#    silently.
out=$(run link ./relative-pkg | head -2)
case "$out" in
    *"cannot resolve a relative package path"*|*"HOME is unset"*|*"could not read manifest"*|*"no such"*)
        echo "  ok    relative package argument refused, not silently mis-resolved" ;;
    *)
        echo "  FAIL  relative argument produced: '$out'"; FAIL=1 ;;
esac

# 4. Exit-code contract holds on agnos too.
"$MIRSHI" "$ELF" bogusverb > /dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" = "2" ]; then echo "  ok    unknown verb exits 2 on agnos"
else echo "  FAIL  unknown verb exited $rc, expected 2"; FAIL=1; fi

# 5. The agnos-conditional code paths, run on the target (tests/agnos.tcyr).
#    The summary line must report zero failures AND the binary must exit 0;
#    a crash mid-suite prints no summary, so neither alone is enough.
"$MIRSHI" "$TESTS" > "$TLOG" 2>&1 && trc=0 || trc=$?
summary=$(grep -E '^[0-9]+ passed, [0-9]+ failed' "$TLOG" | tail -1)
case "$trc:$summary" in
    "0:"*" passed, 0 failed"*)
        echo "  ok    agnos-conditional paths on agnos: $summary" ;;
    *)
        echo "  FAIL  tests/agnos.tcyr under mirshi (exit $trc): '${summary:-no summary}'"
        grep -E 'FAIL:' "$TLOG" | sed 's/^/        /'
        FAIL=1 ;;
esac

if [ $FAIL -eq 0 ]; then echo "PASS: agnos smoke"; else echo "FAIL: agnos smoke"; fi
exit $FAIL
