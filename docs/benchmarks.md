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
| OS    | Linux 7.0.9-arch1-1 x86_64 (0.9.0 row) · 7.1.9-arch1-2 (1.0.4 row) · 7.2.11-arch1-1 (1.0.12 row) |
| FS    | tmpfs (`/tmp`) |
| Build | stripped, statically linked ELF, `CYRIUS_DCE=1` — cyrius emits it already stripped. **Do not run GNU `strip` on it**: at 1.0.12 that produced a binary whose every `sync` dies with `alloc_init: mmap failed`. |

tmpfs eliminates spinning-disk variance — these numbers are
syscall + CPU bound, not IO bound. Numbers will be slower on a
real HDD or under cgroup-throttled IO.

## Results

### Trend (sync over 100 packages / 350 links)

| Release | Cold (ms) | Warm (ms) | Audit grew (warm) | Date       | Notes |
|---------|-----------|-----------|-------------------|------------|-------|
| 0.9.0   | 72        | 54        | 0 bytes           | 2026-05-23 | Baseline. P(-1) hardening repairs (F-001 / F-003) sit outside the sync hot path, so v0.8.0 produces equivalent numbers; comparison row will land when a perf-relevant change ships. |
| 1.0.4   | 84        | 68        | 0 bytes           | 2026-08-25 | Toolchain refresh (cyrius `6.4.22` → `6.5.35`) + the agnos `readlink` work in `fs_link.cyr`. Best of four consecutive runs; spread was tight (cold 84–87, warm 68–71). ⚠ **The +17 % / +26 % against 0.9.0 is not attributable to this release** — see the note below. |

| 1.0.5   | 91        | 76        | 0 bytes           | 2026-08-25 | P(-1) sweep. The ~8% cold / ~12% warm cost against 1.0.4 is attributable and expected: F-014 and F-008 added a size-computation pass over the manifest strings and the audit values before each write. Best of three; spread ±1 ms. ⭐ The trail is **byte-identical** at 101,150 bytes / 350 entries — the audit-format rewrite shifted nothing. |

| 1.0.8   | 100       | 86        | 0 bytes           | 2026-08-25 | F-015: every target's parent is now resolved component-by-component before hapi will write to it, so the capability boundary holds against a symlinked parent directory. ~10% cold / ~13% warm against 1.0.7 — attributable and expected (a `link_probe` per component per row), well inside the >2x gate. Trail byte-identical at 101,150 bytes. |

| 1.0.9   | 106       | 87        | 0 bytes           | 2026-08-25 | Tier 2 + Tier 3 batch. ~6% cold against 1.0.8, from F-018's `fsync` before the trail lock is dropped — the durability the finding was about. Warm is unchanged (a warm sync writes nothing). ⭐ F-023's owner map is the number that matters here: the naive per-package build measured **41x** (0.665 s vs 0.016 s) and was rejected; the shipped hashmap build is 1.0x. Trail byte-identical at 101,150 bytes. |

| 1.0.10  | 107       | 87        | 0 bytes           | 2026-08-26 | F-027 / F-031. Flat against 1.0.9 within noise (best of three; the middle run read 113/94 on a busier box). The Linux hot path is untouched — F-027's `PWD` lookup is inside the agnos `#ifdef` arm, and `hapi_open_nofollow` compiles to the same `O_NOFOLLOW` open it replaced. Row recorded because `fs_link.cyr` changed, which is the trigger, not because anything moved. |

| 1.0.12  | 90        | 72        | 0 bytes           | 2026-10-28 | Toolchain refresh (cyrius `6.6.2` → `6.6.20`). Measured before the release's one source fix (an aarch64 `O_NOFOLLOW` literal), which compiles to the same constant on x86_64. **Controlled A/B this time**: 1.0.11-on-6.6.2 built from `HEAD` and interleaved with 1.0.12 on one kernel, three pairs — old 91–93 / 72–75, new 90–91 / 72. Flat within noise. The drop against the 1.0.10 row is the machine (new kernel, 7.2.11), not the toolchain. Trail byte-identical at 101,150 bytes / 350 entries. DCE binary 188,552 → 194,744 bytes. |

| 1.1.0   | 90        | 72        | 0 bytes           | 2026-10-28 | Toolchain refresh (cyrius `6.6.20` → `6.7.18`). Interleaved A/B against 1.0.12-on-6.6.20, three pairs — old 91–92 / 73–74, new 90 / 72–73. Flat. Trail byte-identical at 101,150 bytes / 350 entries. ⚠ **DCE binary 194,744 → 542,520 bytes (2.8×), all of it data**: the code segment is flat (+2.5 KB), the data segment went 38.7 KB → 382 KB because 6.7.18's `bayan` unconditionally includes the Unicode casefold / category / normalization tables, which DCE cannot drop. hapi never touches those pages, which is why the timings do not move. |

| 1.1.1   | —         | —         | 0 bytes           | 2026-10-28 | P(-1) repairs. **Relative row**: the harness ran under a deeper scratch path than `/tmp/hapi-bench`, which lengthens every path and puts both builds near 120 / 95 ms, so the absolute numbers are not comparable to the rows above. Interleaved A/B against 1.1.0 at the same path, three pairs — old 118 / 94–95, new 125–127 / 101–102: **+6 % cold, +7 % warm**, attributable and expected. Each row now does three more path resolutions: F-045's into-the-package guard resolves the target's parent and the package directory, and F-046's link text resolves the parent again. Trail byte-identical between the two builds (153,650 bytes / 350 entries at that path). DCE binary 542,520 → 552,488 bytes. |

| 1.2.0   | —         | —         | 0 bytes           | 2026-10-28 | cmdit (argument parsing). **Relative row**, again under a scratch path deeper than `/tmp/hapi-bench`. Interleaved A/B against 1.1.1, five pairs — old 132–135 / 107–109, new 131–133 / 108–110: **flat**. The per-process floor is flat too: 100 × `sync pkg050`, old 115–117 ms, new 113–116 ms, so a parse on two cmdit handles is lost in process startup. There was no 2 MB allocation to save: 1.1.1's `main()` called `args_init()` once, and 1.2.0 reads the command line once through `cmdit_argv`; dropping `main()`'s own call is what keeps it from being twice. Trail byte-identical (157,850 bytes / 350 entries at that path). DCE binary 552,488 → 580,928 bytes: code +26,264, data +3,864. Unlike 1.1.0's growth, this is code: cmdit's. |

| 1.3.0   | —         | —         | 0 bytes           | 2026-10-28 | `sync` with no package, and `--prune`; `cmd_link` split into plan and execute. **Relative row**, same scratch path as 1.2.0's. Interleaved A/B against 1.2.1, eight pairs across two runs — old 133–136 / 109–111, new 131–134 / 107–110: **flat**, and the per-process floor too (100 × `sync pkg050`, old 117–119 ms, new 115–116). Trail byte-identical (157,850 bytes / 350 entries at that path). ⭐ **The new form:** one `hapi sync` with `HAPI_PACKAGE_ROOTS` pointed at the harness's 100 packages takes **80–84 ms cold / 63–67 ms warm**, where the 100-process loop it replaces takes ~133 / ~109, about 38 % less, and it writes the same trail byte for byte. DCE binary 580,928 → 603,424 bytes. |

⚠ **On the 0.9.0 → 1.0.4 delta.** Three things changed at once between
the two rows: the compiler (6.0.1 → 6.5.35), the kernel (7.0.9 → 7.1.9),
and hapi's own `link_probe`. The 0.9.0 row is a single run; the 1.0.4 row
is best-of-four with a ±3 ms spread. No controlled A/B was run, so the
honest reading is *"84/68 is the current number on this machine"*, not
*"the refresh cost 12 ms"*. Both remain far inside the acceptance gates,
and the byte-for-byte identical audit output (101,150 bytes / 350 entries,
exactly as at 0.9.0) says the work performed per link is unchanged. A
release that wants to claim a perf delta should interleave the two builds
on one kernel.

Per-link cost rolls up (1.0.4 row):

- Cold: 84 ms / 350 = **240 µs per link** (parse + symlink + audit-append)
- Warm: 68 ms / 350 = **194 µs per probe** (parse + readlink + classify)
- Per-process startup floor: ~0.67 ms (from the single-package
  warm loop: 67 ms / 100 calls)

### Audit-trail growth (cold sync)

- 350 entries / 101,150 bytes ⇒ **289 bytes per entry average**

Falls in the ADR 0002 expected range (typical ~250 bytes, max
~1 KB). Entry size is not what makes the append atomic, though —
PIPE_BUF bounds pipes, not regular files; `O_APPEND` plus the trail's
`flock` does (ADR 0002, 1.1.1 addendum).

## Acceptance gates

- **Idempotency** — warm sync MUST grow the audit trail by 0
  bytes. ✅ Verified at every row, 1.0.4 included (the
  `audit grew (warm)` column).
- **Scale** — `sync` over a 100-pkg home completes in <1 s on a
  modern machine. ✅ Cold 91 ms at 1.0.5 (well under).
- **Per-link** — cold-create cost should stay under 1 ms / link
  on a tmpfs / SSD-class device. ✅ 260 µs/link at 1.0.5.

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
