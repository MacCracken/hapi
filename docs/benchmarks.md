# hapi — Benchmarks

Captured the v1.0-criteria-required `sync` numbers over a realistic
100-package home. Three-point trend per the M7 roadmap entry; this
file refreshes when perf-relevant code lands.

## Methodology

Synthetic home: **100 packages × ~3.5 link rows each = 350 total
symlinks**. Packages laid out as `pkg000` … `pkg099` under a scratch
`/tmp/hapi-bench/packages/`; each `hapi.cyml` declares 2–5 link rows
deterministically (`(i % 4) + 2`); link targets land under a fresh
`/tmp/hapi-bench/home/`; audit trail under
`/tmp/hapi-bench/state/hapi/audit.jsonl`.

Three scenarios:

1. **Cold sync** — empty home, no prior audit trail. Every link
   row is `CREATE`. Measures parse + 350 symlink creates + 350
   audit appends.
2. **Warm sync** — all 350 links already present. Every row is
   `NOOP`. Measures parse + 350 probe-and-skip rounds; the
   audit trail MUST NOT grow (ADR 0002 idempotency contract).
3. **Single-package warm** — 100 invocations of `sync pkg050`
   back-to-back. Spreads per-process-startup cost over a known
   denominator.

Wall-time: `date +%s%N` deltas around the loop, integer ms.
Numbers are single runs on a quiet machine — these are scaling
sanity checks, not statistical benchmarks.

## Environment

| Field | Value |
|-------|-------|
| CPU   | AMD Ryzen 7 5800H |
| OS    | Linux 7.0.9-arch1-1 x86_64 |
| FS    | tmpfs (`/tmp`) |
| Build | stripped, statically linked ELF |

tmpfs eliminates spinning-disk variance — these numbers are
syscall + CPU bound, not IO bound. Numbers will be slower on a
real HDD or under cgroup-throttled IO.

## Results

### Trend (sync over 100 packages / 350 links)

| Release | Cold (ms) | Warm (ms) | Audit grew (warm) | Date       | Notes |
|---------|-----------|-----------|-------------------|------------|-------|
| 0.9.0   | 72        | 54        | 0 bytes           | 2026-05-23 | Baseline. P(-1) hardening repairs (F-001 / F-003) sit outside the sync hot path, so v0.8.0 produces equivalent numbers; comparison row will land when a perf-relevant change ships. |

Per-link cost rolls up:

- Cold: 72 ms / 350 = **205 µs per link** (parse + symlink + audit-append)
- Warm: 54 ms / 350 = **154 µs per probe** (parse + readlink + classify)
- Per-process startup floor: ~0.56 ms (from the single-package
  warm loop: 56 ms / 100 calls)

### Audit-trail growth (cold sync)

- 350 entries / 101,150 bytes ⇒ **289 bytes per entry average**

Falls in the ADR 0002 expected range (typical ~250 bytes, max
~1 KB) — well under PIPE_BUF (4096 bytes) so POSIX append
atomicity holds.

## Acceptance gates

- **Idempotency** — warm sync MUST grow the audit trail by 0
  bytes. ✅ Verified (the `audit grew (warm)` column).
- **Scale** — `sync` over a 100-pkg home completes in <1 s on a
  modern machine. ✅ Cold 72 ms (well under).
- **Per-link** — cold-create cost should stay under 1 ms / link
  on a tmpfs / SSD-class device. ✅ 205 µs/link.

A future regression would surface as a > 2× jump in cold-time
or any non-zero warm audit growth. Re-run this harness on every
release that touches `cmd_link.cyr`, `audit.cyr`, `fs_link.cyr`,
or the manifest parser.

## Reproducing

The harness is a transient shell loop, not a committed script —
the synthetic home is generated and torn down per run. To
reproduce:

```sh
rm -rf /tmp/hapi-bench && mkdir -p /tmp/hapi-bench/{packages,home}
i=0
while [ $i -lt 100 ]; do
  pkg=/tmp/hapi-bench/packages/pkg$(printf "%03d" $i)
  mkdir -p "$pkg"
  rows=$(( (i % 4) + 2 ))
  {
    echo "[package]"
    echo "name = \"pkg$(printf "%03d" $i)\""
    echo "version = \"1.0.0\""
    j=0
    while [ $j -lt $rows ]; do
      echo
      echo "[[link]]"
      echo "source = \"file$j\""
      echo "target = \".pkg$(printf "%03d" $i)-file$j\""
      j=$((j+1))
    done
  } > "$pkg/hapi.cyml"
  j=0
  while [ $j -lt $rows ]; do
    echo "content of pkg $i row $j" > "$pkg/file$j"
    j=$((j+1))
  done
  i=$((i+1))
done

export HOME=/tmp/hapi-bench/home
export XDG_STATE_HOME=/tmp/hapi-bench/state
mkdir -p "$HOME" "$XDG_STATE_HOME"

# Cold:
t0=$(date +%s%N)
for pkg in /tmp/hapi-bench/packages/pkg*; do hapi sync "$pkg" > /dev/null; done
t1=$(date +%s%N)
echo "cold: $(( (t1 - t0) / 1000000 )) ms"

# Warm:
t0=$(date +%s%N)
for pkg in /tmp/hapi-bench/packages/pkg*; do hapi sync "$pkg" > /dev/null; done
t1=$(date +%s%N)
echo "warm: $(( (t1 - t0) / 1000000 )) ms"
```

## See also

- [ADR 0002 — Audit-trail format](adr/0002-audit-trail-format.md) —
  per-entry size + atomicity assumptions.
- [`guides/sync.md`](guides/sync.md) — what `sync` actually does
  per package.
- [`development/state.md`](development/state.md) — test-count +
  source-line + consumer state (live).
