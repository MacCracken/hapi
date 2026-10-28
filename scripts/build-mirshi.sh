#!/bin/sh
# build-mirshi.sh — build mirshi, the agnos runner for scripts/agnos-smoke.sh.
#
# WHY THIS EXISTS
# Through 1.1.0 the CI `agnos smoke` step always exited 2 (SKIP): there was
# no mirshi on the runner, so hapi's `#ifdef CYRIUS_TARGET_AGNOS` arms were
# compiled in CI and never executed — and cyrius 6.7.16 dropped upstream's
# own run-under-mirshi gates, so nothing else ran them either (F-043). This
# script is how CI gets a mirshi, and how a dev box gets the same one.
#
# Usage:  sh scripts/build-mirshi.sh <work-dir>
#         -> <work-dir>/mirshi/build/mirshi
# Exit:   0 built, non-zero otherwise. Run from the hapi repo root.
#
# The mirshi tag is pinned here (MIRSHI_REF overrides it). It is a test
# runner, not hapi's toolchain, which stays pinned in cyrius.cyml alone.
#
# mirshi is built with HAPI's toolchain pin, not its own: mirshi 1.11.3 pins
# cyrius 6.6.2, and its tracked lib/ does not build from a clean clone (the
# vendored stdlib is older than its source — CLOCK_MONOTONIC and SYS_OPEN
# come up undefined). Re-pinning and re-vendoring keeps one toolchain on the
# runner and builds clean. When a hapi pin bump breaks this build, move
# MIRSHI_REF forward; do not drop the step.

set -e

MIRSHI_REF="${MIRSHI_REF:-1.11.3}"
WORK="${1:?usage: sh scripts/build-mirshi.sh <work-dir>}"
PIN="$(grep '^cyrius = ' cyrius.cyml | head -1 | sed 's/cyrius = "\(.*\)"/\1/')"
[ -n "$PIN" ] || { echo "build-mirshi: no cyrius pin in ./cyrius.cyml (run from the hapi repo root)" >&2; exit 1; }

DEST="$WORK/mirshi"
rm -rf "$DEST"
mkdir -p "$WORK"
echo "build-mirshi: mirshi $MIRSHI_REF with cyrius $PIN"
git clone -q -c advice.detachedHead=false --depth 1 --branch "$MIRSHI_REF" \
    https://github.com/MacCracken/mirshi "$DEST"
cd "$DEST"
sed "s/^cyrius = \".*\"/cyrius = \"$PIN\"/" cyrius.cyml > cyrius.cyml.hapi
mv cyrius.cyml.hapi cyrius.cyml
cyrius deps
cyrius build src/main.cyr build/mirshi
test -x build/mirshi
echo "build-mirshi: ok -> $DEST/build/mirshi"
