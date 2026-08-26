# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.0.9** — 1.0.x hardening arc, **Tier 2 and Tier 3 closed in one
batch** (2026-08-25). Eleven findings reproduced and fixed together.
Tier 2 (hapi reporting a world that was not on disk): `link` refused a
missing source and `status` now reports BROKEN instead of OK (**F-022**,
one shared predicate so the two cannot drift); `list` uses a global
per-target owner map so a `--force` takeover retires the previous claim
(**F-023** — the naive build measured **41x** and was rejected for a
hashmap index at 1.0x); package-dir arguments are canonicalized so
`link .` no longer breaks `sync`'s idempotency contract (**F-024**, with
the four ownership-proof sites deliberately untouched); `ignore` is
documented reserved-not-honoured and `sync --backup-to` documented inert
(**F-025**, **F-026**, both with v2.0 successors recorded). Tier 3
(write-path and argument hardening): the trail is pre-flighted before
any mutation, appended durably with an fsync and a torn-tail guard, and
a failed append undoes exactly its own link (**F-018**); a flag-shaped
value for `--root` / `--backup-to` is rejected (**F-019**); a package
can no longer steer the `--backup-to` destination (**F-020**); created
parents follow umask while hapi's own state stays 0700 (**F-029**); a
trailing-slash target leaves no residue (**F-032**); `inspect` returns 2
for a flag (**F-033**). Suite 361 / 89. **Two findings remain**, F-027
and F-031, both agnos-target-conditional and blocked on a runner.

**1.0.8** — 1.0.x hardening arc, **Tier 1 closed** (2026-08-25). Fixes
**F-015**, and with it **F-002**, open since the 2026-05-23 audit:
hapi's capability boundary now decides on a target's *physical*
location. `fsl_lexical_normalize` collapses `..` but treats every
component as a plain name, so an ordinary `~/.config -> /mnt/other/etc`
put a row outside the scope on a bare `hapi link` — exit 0, with the
unresolved in-`$HOME` path recorded in the trail — and, where a file was
already there, hapi refused as an ordinary conflict and advised
`--force`, which then **destroyed the file outside `$HOME`** while
`status` reported OK. New `fsl_resolve_path` follows a symlink at every
component (hop-capped at 40; absent components stay literal), and
`cap_target_allowed` decides on the resolved location with the scope
root resolved too. An escape is `LINK_ACT_ESCAPE`, which `--force` does
**not** override; the grant is `HAPI_ALLOWED_ROOTS`, not `--root`.
Crucially the ownership-proof constraint was sidestepped, not solved:
`fsl_compute_relative` and the trail values are untouched, so the four
verbs that byte-compare still compare what they always did. Costs ~10%
cold / ~13% warm, recorded in `../benchmarks.md`. Suite 323 / 84.

**1.0.7** — 1.0.x hardening arc, the rest of the manifest write path
(2026-08-25). Closes **F-021** and **F-028**, and with them the
write-path issue 1.0.6 opened. F-021: the writer emitted `source` /
`target` raw, so adopting `.ev"il` wrote `source = "ev"il"` and
`inspect` read it back as `ev` — declared state describing a file that
does not exist, exit 0. Escaping cannot fix it (the parser has no
un-escape half: `ev\"il` parses back as six characters), and adding one
is an ADR 0001 change, so hapi **refuses** to write a row it cannot
faithfully represent, checking before the rename so nothing moves.
F-028 (detection half): `hapi check` now compares the manifest against
the package directory both ways — a row whose source vanished, and a
file no row claims, which is the signature of an `adopt` interrupted
between the rename and the manifest write. Prevention is an ADR 0004
revision, now a v2.0 roadmap item. Suite 307 / 81.

**1.0.6** — 1.0.x hardening arc, Tier 1 item 1 (2026-08-25). Closes
**F-007**, **F-016** and **F-017**, all in `audit_read`. F-007 was the
sharpest defect the 2026-08-25 sweep found: the reader took the *first*
256 KB of an append-only file, so once the trail outgrew that,
`rollback` could not see the most recent checkpoint marker, fell back to
`start = 0`, and reversed the **oldest still-live links** while leaving
the recent work in place — measured at **637 settled links destroyed**
on an 800-entry trail, exit 0. The read is now sized from the file;
`ENOENT` is distinguished from every other open failure; an interior
malformed line is refused (a trailing partial one is still dropped —
that is the writer's atomic-append contract). `rollback` / `unlink` /
`list` consume `audit_read_default_r` and exit 1 with a diagnostic
rather than acting on a partial view.

Also closes **F-012**, the other open Tier 1 item: the manifest
read-modify-write was unsynchronized and staged through a fixed
`hapi.cyml.tmp`, so 16 concurrent adopts on a 3 MB manifest committed
16 renames, 16 symlinks and 16 trail entries while leaving **one**
manifest row. Now `LOCK_EX` on the package directory (the manifest is
replaced by rename, so flocking it by path excludes nobody) plus a
pid-unique `O_EXCL` staging file; 16/16 after. Its regression is
`scripts/concurrency-test.sh` — the defect needs two processes, which
`.tcyr` cannot express — and CI runs it.

Suite 295 / 79 plus the shell harness. No surface change — the v1.0
contract stays frozen.

**1.0.5** — P(-1) hardening sweep + repairs (2026-08-25). **Six
HIGH-severity defects fixed**: two heap overflows reachable from an
ordinary manifest (`hapi_mf_canonicalize` and the audit entry
composers both accepted a `cap` argument and never read it — the
first took `link` / `sync` / `--dry-run` down with SIGSEGV, the
second wrote ~42 KB of attacker-chosen bytes past a 4 KB allocation
and destroyed the trail); two silent destructions of user bytes (a
manifest past 256 KB truncated and the truncation committed by
`adopt`; `--backup-to` overwriting a snapshot when two rows shared a
target basename); one capability escape (`adopt` moved files from
outside `$HOME` with no `--root`); and one argument-parsing bug that
made `hapi rollback <pkg>` reverse the **entire** trail at exit 0.
Each fix carries a mutation-proven regression test. **Twenty findings
remain open** — see
[`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md), which
also re-scopes F-002 (the kavach dependency gate is void; kavach is a
sandbox-execution framework with no capability API). CI now compiles
aarch64 and agnos, not just x86_64. Suite 280 / 76; `cyrius lint`
clean tree-wide. No surface change — the v1.0 contract stays frozen
and byte-identical.

**1.0.4** — toolchain/vendored-stdlib refresh + agnos symlink
introspection (2026-08-25). Cyrius pin `6.4.22` → `6.5.35`; `lib/`
resynced to the 6.5.35 snapshot (108 files — 67 updated, 10 new, the
stale scaffold-era `lib/agnosys.cyr` pruned). The declared
`[deps] stdlib` set is unchanged and no symbol hapi calls moved across
the span. Closes 1.0.3's agnos gap: `link_probe` probes agnos
`readlink`#70 first (dangling links included) and `hapi_readlink`
rides the snapshot's **native** `sys_readlink` peer, retiring the
locally-declared syscall number. Fixes a latent defect dating to
0.8.0 — `rollback` reversing an `unlink` passed seven
arguments to the eight-argument `audit_append_link_r`, so the replay
entry could carry a junk `backup_path`; it now passes `0` (no
snapshot), locked by a mutation-proven regression group. That was a
*warning* until cyrius 6.5.1 promoted a wrong argument count to an
error, which is why it shipped unnoticed in 0.8.0 → 1.0.3 and why
this refresh is what surfaced it. Also fixes `cyrius build
--aarch64`, which did not compile: `fs_link.cyr`'s `link_probe`
used a bare `SYS_OPEN`, a constant aarch64 Linux does not define.
**All three targets now build: x86_64, aarch64 and agnos.**
`hapi --version` reads `CYRIUS_PKG_VERSION` instead of a hand-synced
literal, so `VERSION` is the only place the number lives. Suite
246 / 71, all passing. No surface change — the v1.0 contract stays
frozen.

**1.0.3** — agnos target + toolchain/vendored-stdlib refresh
(2026-07-08). Cyrius pin `6.2.24` → `6.4.22`; `lib/` resynced to the
6.4.22 snapshot (98 files). hapi now builds `--agnos` and runs under
mirshi (>= 1.10.2), unblocking it in the agnos-dev docker image. New
`src/agnos_compat.cyr` shims the syscall-ABI divergences
(`hapi_unlink`/`hapi_rename`/`hapi_fsync`/`hapi_symlink`/`hapi_mkdir`,
Linux-verbatim on non-agnos); `fs_link.cyr` `link_probe` classifies
via `stat` (#33) on agnos and `_fsl_getcwd` returns `"."`. The
refresh brought the peer's native `sys_symlink` (#63, now called
directly) and an agnos-aware `file_append_locked` (LOCK_EX +
SEEK_END). Known gap at the time: agnos exposed no `lstat`/`readlink`
to ring-3 and its `stat` follows symlinks, so hapi could create but not
introspect symlinks there — **closed in 1.0.4** by agnos `readlink`#70.
Suite still 242 / 70, all passing. No surface change — the v1.0
contract stays frozen.

**1.0.2** — toolchain + vendored-stdlib refresh (2026-06-19).
Cyrius pin `6.0.1` → `6.2.24`; `lib/` resynced to the 6.2.24
snapshot. Tracks the upstream stdlib carves — `cyml` (with
`toml` / `json` / `base64` / `csv` / `bigint` / `u128`) folded
into the bundled **`bayan`** module, `matrix` / `linalg` /
`math_advanced` into **`ganita`** (v6.1.25 carve). hapi's only
moved-module dependency is `cyml`; `src/manifest.cyr` now
includes `lib/bayan.cyr` and the three `cyml_*` call sites ride
`bayan`'s `_compat` shims unchanged. Suite still 242 / 66, all
passing. No surface change — the v1.0 contract stays frozen.

**1.0.1** — 1.0.x-final hardening patch (2026-05-24). Closes the
1.0.x line: internal syscall naming (`HapiSysno` enum +
stdlib `SYS_OPEN`/`SYS_CLOSE`), a trail-loss recovery regression
test (suite now 242 / 70), and the 1.0.x-final P(-1) audit pass
([`../audit/2026-05-24-audit.md`](../audit/2026-05-24-audit.md);
new F-006 accepted boundary). No surface change — the v1.0
contract stays frozen.

**1.0.0** — M8 / v1.0 freeze shipped 2026-05-23. Contract
locked: command surface (ten verbs + five global flags),
`hapi.cyml` manifest schema (ADR 0001), audit-trail format
(ADR 0002). All five ADRs now carry *Frozen at v1.0.0*. Full
write-up at
[`release-notes/1.0.0.md`](release-notes/1.0.0.md).

Earlier ships (all 2026-05-23 unless noted):
v0.9.0 (M7 close — P(-1) audit + benchmarks),
v0.8.0 (M7 sweep — status guide, upstream-drift, `--backup-to`,
sha1c canonicalization),
v0.7.0 (M6 — `--root` + `--dry-run`, 2026-05-20),
v0.6.0 (M5), v0.5.0 (M4), v0.4.0 (M3), v0.3.0 (M2), v0.2.0
(M1) all 2026-05-20, M0 scaffold 2026-05-19.

## Toolchain

- **Cyrius pin**: `6.5.35` (in `cyrius.cyml [package].cyrius`)
- **Vendored `lib/`**: 108 files, the 6.5.35 full snapshot
  (`cyrius lib sync --full`). Mirrors the pin exactly — nothing
  hand-edited, nothing left over from an earlier snapshot.

## Shape

Binary (`hapi`). Argv dispatcher. Ten real verbs frozen at v1.0.0;
`--version` / `--help` / `-v` / `-h` round out the surface.
Three global flags plug into per-verb arg parsers:
`--root <path>` (link / adopt / sync / status / list),
`--dry-run` (link / unlink / adopt / sync / rollback /
checkpoint), and `--backup-to <dir>` (parsed on link / sync / adopt; effective
on `link --force` / `adopt` only — `sync` has no `--force`, so it
is inert there) —
opt-in pre-`--force` snapshot.

### Current command surface (frozen at v1.0)

| verb                  | exit codes               |
|-----------------------|--------------------------|
| `hapi inspect`        | 0 ok / 1 parse / 2 args  |
| `hapi link`           | 0 ok / 1 fail / 2 args   |
| `hapi unlink`         | 0 ok / 1 refused / 2 args|
| `hapi rollback`       | 0 ok / 1 IO error        |
| `hapi adopt`          | 0 ok / 1 refused / 2 args|
| `hapi list`           | 0 ok / 1 env error       |
| `hapi sync`           | 0 ok / 1 fail / 2 args   |
| `hapi status`         | 0 ok / 1 drift / 2 args  |
| `hapi checkpoint`     | 0 ok / 1 IO error        |
| `hapi check --strict` | 0 ok / 1 parse / 2 args  |
| `hapi --version`      | 0                        |
| `hapi --help`         | 0                        |

## Source

- `src/main.cyr` — entry point + argv dispatcher. `--version`
  prints `hapi <X.Y.Z>` from the compile-time
  `CYRIUS_PKG_VERSION` constant (cyrius resolves it from
  `[package].version` = `${file:VERSION}`), so `VERSION` is the
  only place the number lives — the hand-synced literal was
  retired in 1.0.4.
- `src/agnos_compat.cyr` — target-portability shims for the agnos
  userland (`hapi_unlink` / `hapi_rename` / `hapi_fsync` /
  `hapi_symlink` / `hapi_readlink` / `hapi_mkdir`). Each forwards
  verbatim on Linux/macOS; the agnos branch absorbs the
  syscall-ABI divergence (explicit path lengths, `sync` for
  `fsync`, `mkdir`'s length-not-mode second argument). Every
  wrapper now rides a native cyrius peer — the last locally
  declared syscall number, `AGNOS_SYS_READLINK`#70, went away in
  1.0.4 when the 6.5.35 snapshot shipped `sys_readlink`.
- `src/manifest.cyr` — `hapi.cyml` parser + canonical
  re-serializer. `hapi_mf_canonicalize(m, out, cap)` emits
  the fixed byte form used by the v0.8.0 `sha1c:`
  manifest_hash variant: `[package]` fields in fixed order,
  `[[link]]` rows sorted by `target`, no comments, single
  blank line between sections.
- `src/manifest_write.cyr` — append + remove `[[link]]` rows
  atomically via `tmp+rename`. Uses the stdlib `sys_rename` /
  `sys_fsync` wrappers (landed in cyrius 6.2.x) — shared by
  `adopt` / `rollback`. The 1.0.1-era `HapiSysno` enum
  (`HAPI_SYS_RENAME` / `HAPI_SYS_FSYNC`, x86_64-only literal
  numbers) was retired in 1.0.2; the wrappers are arch-correct.
  `fs_link.cyr`'s open/close already use the stdlib `SYS_OPEN` /
  `SYS_CLOSE`.
- `src/audit.cyr` — JSONL audit-trail writer (link / unlink /
  adopt / unadopt / rollback-marker entries; manifest hash via
  `hapi_mf_canonicalize` + sha1 with `sha1c:` prefix as of
  v0.8.0; XDG path resolution with test override hook).
  `audit_manifest_hash_raw(path)` retains the v0.x `sha1:`
  raw-bytes variant for trail-format diagnostics.
- `src/audit_reader.cyr` — JSONL reader; hand-rolled scanner
  over the ADR 0002 field set
- `src/fs_link.cyr` — symlink primitives (probe / compute
  relative / create with mkdir-parents)
- `src/cmd/inspect.cyr` — manifest dump
- `src/cmd/link.cyr` — pre-flight + create + audit
- `src/cmd/unlink.cyr` — trail-driven removal
- `src/cmd/adopt.cyr` — file-into-package move + symlink +
  manifest edit + audit
- `src/cmd/rollback.cyr` — reverse-replay; handles
  link / unlink / adopt entries
- `src/cmd/checkpoint.cyr` — appends `op:rollback-marker`
  via `audit_append_rollback_marker_r`
- `src/cmd/status.cyr` — read-only drift classifier over
  manifest [[link]] rows
- `src/cmd/list.cyr` — trail walker; per-package live-link
  counter (link/adopt = create, unlink/unadopt = clear)
- `src/cmd/check.cyr` — inspect with `--strict` (rejects
  unknown sections / keys via the `_hapi_mf_strict` flag
  added to `manifest.cyr`)
- `src/cmd/sync.cyr` — thin wrapper over `cmd_link` (link
  without `--force`); the verb communicates intent while
  the engine is shared
- `src/cap.cyr` — `--root` capability check. Owns
  `cap_check_root_r(path)`; resolves the arg to absolute,
  lex-normalizes via `fsl_lexical_normalize` (collapses `.`
  / `..`; closes the F-001 bypass — see
  [`docs/audit/2026-05-23-audit.md`](../audit/2026-05-23-audit.md)),
  implicitly allows `$HOME`, otherwise prefix-matches
  against `HAPI_ALLOWED_ROOTS` (path-component boundary,
  not byte boundary; each entry also lex-normalized). Test
  hooks `cap_set_home` and `cap_set_allowlist` for unit tests.
  Symlink-aware resolution is still open as F-002 — hapi-owned
  work as of the 2026-08-25 audit, not a kavach dep gate. Also
  owns `cap_within_scope(path, scope_root)`, the containment
  predicate for a path hapi is about to WRITE (added 1.0.5 for
  F-011; `adopt`'s `<file>` argument is a write target).
- `src/cli.cyr` — owns the process-wide `_hapi_dry_run`
  flag. Setter `hapi_set_dry_run(0|1)` and getter
  `hapi_dry_run()`. Every mutating cmd checks the flag
  before its first syscall / audit write.
- `src/backup.cyr` — owns the process-wide
  `_hapi_backup_dir` cstring (set by `--backup-to <dir>`),
  the `<YYYYMMDD-HHMMSS>-<pkg>-<basename>` filename
  composer, and the byte-copy primitive used by link's
  `--force` path and adopt's pre-rename step. Setter
  `hapi_set_backup_dir(cstr|0)` and getter
  `hapi_backup_dir()` mirror the dry-run pattern.

Post-v1.0 implementation work (additive only; tracked in
[`roadmap.md`](roadmap.md)):

- per-package manifest discovery for a no-arg `hapi sync` —
  needs a way to recover pkg_dir from a live audit entry
  (additive trail field, or a tree-walk heuristic). Internal;
  no signature change to `cmd_sync`.
- per-component symlink-aware resolution inside `src/cap.cyr`,
  replacing the lexical-only normalization. Closes F-002 and
  F-015. **No longer a kavach dep gate** — kavach 3.12.3 is a
  sandbox-execution framework with no capability API, so this is
  hapi's own work; the primitive it needs (`hapi_readlink`) is
  portable across all three targets as of 1.0.4.
  `cap_check_root_r(path) -> Result` signature unchanged. See
  [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md).

_(Done in 1.0.2: the stdlib `sys_rename` / `sys_fsync` /
`sys_fdatasync` wrappers landed in cyrius 6.2.x and replaced the
in-source magic-number `syscall(N, ...)` calls.)_

## Audit trail

- **Location**: `$XDG_STATE_HOME/hapi/audit.jsonl` (or
  `$HOME/.local/state/hapi/audit.jsonl` when unset)
- **Format**: JSONL, append-only, ADR 0002
- **Hash**: `sha1c:` + 40 hex — canonical variant: parse the
  manifest, re-serialize to fixed byte form, sha1 the result.
  Pre-v0.8.0 entries written under the legacy `sha1:` raw-bytes
  prefix continue to be tolerated by readers per the migration
  contract. `audit_manifest_hash_raw(path)` retains the legacy
  computation for diagnostics.
- **Entry ops**: `link`, `unlink`, `adopt`, `unadopt`,
  `rollback-marker`
- **Additive fields**: `backup_path` on `link` / `adopt` entries
  when `--backup-to <dir>` is set. Pre-v0.8.0 readers tolerate
  the field per ADR 0002's growth contract.
- **Readers**: `unlink`, `rollback`, `list`, `status`, `sync`
  — every verb that consults the trail walks via
  `src/audit_reader.cyr`.
- **Recovery boundary (F-006)**: the trail is ephemeral local
  state — a wiped `$XDG_STATE_HOME` (e.g. a drive move) leaves it
  empty even when the relative links survive, and an idempotent
  re-`sync` does not rebuild it. `status` is the post-recovery
  source of truth, not `list` / `rollback`. Accepted boundary —
  [`docs/audit/2026-05-24-audit.md`](../audit/2026-05-24-audit.md),
  [`issues/2026-05-24-audit-trail-lost-on-state-dir-wipe.md`](issues/2026-05-24-audit-trail-lost-on-state-dir-wipe.md).

## Tests

- `tests/hapi.tcyr` — primary suite. 361 assertions across
  89 test groups (the group figure read `66` from 1.0.1 through
  1.0.3 — a stale header; the per-tier breakdown below has always
  summed to the real count):
  - Manifest (7 groups): minimal, three-link acceptance,
    validation, path traversal, comments, on-disk parse,
    missing file
  - Audit writer (2 groups): link entry format, JSON escaping
  - Audit reader (3 groups): round trip, torn-line drop,
    malformed drop
  - fs_link (2 groups): relative computation, probe
  - link (3 groups): happy path, conflict refusal,
    --force refuses directory
  - unlink (2 groups): round-trip, user-mutation refusal
  - rollback (5 groups): full reverse, link/unlink/link →
    clean, idempotent, stops at marker, replayed link entry
    carries no `backup_path`
  - trail reader (3 groups, 1.0.6): refuses an interior malformed
    line (F-016), reads a trail past the old 256 KB cap (F-007),
    absent trail is empty vs unreadable is an error (F-017)
  - P(-1) 1.0.5 buffer/capability regressions (5 groups):
    canonicalize refuses rather than overflowing (F-014), audit
    entry composer refuses rather than overflowing (F-008), a
    manifest past 256 KB survives a row append (F-009), colliding
    backup basenames get distinct snapshots (F-010), adopt refuses
    a target outside the scoped root (F-011)
  - manifest_write (2 groups): append row, remove row
  - adopt (5 groups): happy path, refuse
    symlink / directory / absent / duplicate target
  - rollback-of-adopt (1 group): three-step reversal
  - checkpoint (1 group): marker bounds subsequent rollback
  - status (4 groups): clean post-link, missing target,
    wrong target, no-audit-writes invariant
  - list (3 groups): live-link count after link/unlink cycle,
    empty trail, unique-pkgs first-seen order
  - strict-mode (4 groups): rejects unknown section, unknown
    key in [package], unknown key in [[link]], accepts clean
  - check (1 group): --strict flag does not leak across
    parser invocations
  - sync (3 groups): clean tree → no audit growth,
    re-creates a missing link, recovers after a wiped
    state dir (drive-move scenario; F-006 boundary)
  - cap (4 groups): path-within matcher (exact / subdir /
    boundary / empty), deny outside $HOME + allowlist,
    allow inside $HOME, allow listed root (+ byte-prefix
    collision rejection)
  - dry-run (6 groups): link / unlink / adopt / sync /
    rollback / checkpoint each write zero audit + zero
    filesystem state under `hapi_set_dry_run(1)`
  - backup-to (5 groups): compose_path filename
    layout (dir + ts + pkg + basename, no doubled separator),
    link --force snapshots regular-file conflicts with the
    original bytes recoverable from the audit's
    `backup_path` field, symlink conflicts skip the snapshot,
    dry-run writes no snapshot file, adopt snapshots before
    sys_rename
  - canonical hash (4 groups): writer emits
    `sha1c:` prefix, cosmetic edits (comments + whitespace)
    yield identical hash, `[[link]]` row reorder yields
    identical hash, target rename diverges
  - audit-repair (4 groups): lexical normalize
    collapses `..` / `.`; cap-check rejects `..` escape from
    `$HOME` (F-001); allowlist entries lex-normalized;
    `hapi_backup_copy` refuses symlink source under
    `O_NOFOLLOW` (F-003)

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, slice, syscalls,
  assert, bench, args, fs, result, bayan, sha1, chrono
  (`bayan` supplies `cyml`; the standalone `toml` / `cyml`
  modules were folded into it in the v6.1.25 stdlib carve)

Previously-pending stdlib syscall wrappers **landed in cyrius
6.2.x** and are now consumed directly (1.0.2): `sys_rename`
(proposal `2026-05-17-syscalls-at-family-stdlib.md`) and
`sys_fsync` / `sys_fdatasync`
(`2026-05-20-syscalls-fsync-stdlib.md`). The hand-rolled
`HapiSysno` enum that stood in for them is retired — though one
bare `syscall(SYS_OPEN, ...)` in `fs_link.cyr` survived that sweep
and was only caught at 1.0.4, when it turned out to be the single
constant the aarch64 table does not define. The remaining raw sites
(`SYS_GETDENTS64`, `SYS_CLOSE`, `SYS_GETCWD`, all in `fs_link.cyr`)
are defined on every target hapi builds for, so they compile;
`cyrius lint` recommends `lib/io.cyr`'s `xgetdents` for the first as
agnos-bound dir-code hygiene. Post-1.0.4 cleanup, tracked with the
other post-upgrade items in the CHANGELOG's 1.0.4 section (`cyrius
fmt --check`, the unused `fs` / `slice` deps, the `bayan` `cyml_*`
deprecation shims).

The agnos syscall peers followed the same arc: `sys_symlink`#63
landed in the 6.4.x stdlib (consumed at 1.0.3) and
`sys_readlink`#70 in 6.5.x (consumed at 1.0.4). hapi declares no
syscall numbers of its own on any target as of 1.0.4. Still
absent on agnos and not needed: `lstat` (readlink no-follows the
final component) and `getcwd` (`_fsl_getcwd` returns `"."`).

v1.0 ships the env-var allowlist stopgap (`HAPI_ALLOWED_ROOTS`)
for non-`$HOME` roots. It was to be replaced by "the kavach
capability service"; the 2026-08-25 audit established there is no
such service to wait for, so the replacement — per-component
symlink-aware resolution — is hapi's own work in the 1.0.x
hardening arc. Internal-only swap either way:
`cap_check_root_r(path) -> Result` is frozen.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Examples shipped

- `docs/examples/dotfiles-zsh/` — 3-file package used across
  the M1 / M2 / M3 acceptance tests.

## Next

⚠ **The 1.0.x hardening arc is open, and it comes first.** The
2026-08-25 P(-1) sweep fixed six HIGH defects in 1.0.5 and left
**twenty findings live in the shipped tree**. They are enumerated
in [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md),
bucketed by blast radius in
[`roadmap.md`](roadmap.md#v10x--hardening-arc-open-from-the-2026-08-25-p-1-sweep),
and the Tier 1 items carry their own issue files:

- [`issues/2026-08-25-manifest-write-integrity.md`](issues/2026-08-25-manifest-write-integrity.md)
  — F-012 / F-021 / F-028: the unlocked manifest read-modify-write.
- [`issues/2026-05-23-cap-check-symlink-escape.md`](issues/2026-05-23-cap-check-symlink-escape.md)
  — F-002 / F-015, re-scoped: per-component symlink resolution, now
  hapi-owned since the kavach dep gate turned out to be void.
- [`issues/2026-08-25-reporting-and-idempotency.md`](issues/2026-08-25-reporting-and-idempotency.md)
  — Tier 2: `status` / `list` / `sync` reporting a world that is not
  on disk.

**v1.0.0 has shipped** and the contract (command surface, manifest
schema, audit-trail format) is frozen. The additive **v1.x** backlog
below is on hold behind the arc's exit criteria — growth does not
resume while a Tier 1 finding is open.

Candidate post-v1.0 work (ordered loosely by maturity):

- **per-component symlink resolution** — internal swap inside
  `src/cap.cyr`, closing F-002 and F-015 without touching the
  `cap_check_root_r` API. Was filed as the "kavach migration";
  the dep gate is void (see the 2026-08-25 audit), so this is
  Tier 1 of the 1.0.x hardening arc.
  (`issues/2026-05-23-cap-check-symlink-escape.md`)
- ~~**stdlib syscall wrappers** — `sys_rename` / `sys_fsync` /
  `sys_fdatasync`~~ **(done, 1.0.2)** — landed in cyrius 6.2.x;
  the in-source `syscall(N, ...)` calls and the `HapiSysno`
  stand-in enum were replaced with the named wrappers. No
  behavior change on x86_64. The "arch-correct on aarch64" half
  of that claim only became true at 1.0.4 — one bare `SYS_OPEN`
  was missed in `fs_link.cyr`, and it is the one constant the
  aarch64 table does not define, so `--aarch64` did not build.
- **`hapi sync --prune`** — re-evaluate if the
  full-rotation workaround keeps biting in dogfood. Tracked
  at `issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`.
- **`docs/architecture/NNN-upstream-drift-pattern.md`** —
  earned when a second drifting-upstream consumer (sway /
  fish / kitty) hits the pattern documented in
  [`guides/upstream-drift.md`](../guides/upstream-drift.md).
- **`docs/benchmarks.md` trend rows** — append on any release
  that touches `cmd_link.cyr` / `audit.cyr` / `fs_link.cyr` /
  the manifest parser. Regression gate per the file: > 2×
  cold-time jump or any non-zero warm audit growth.

The complete v1.0-shipped scope plus the full deferred set
lives in [`roadmap.md`](roadmap.md). The v1.0 contract itself
is documented in
[`release-notes/1.0.0.md`](release-notes/1.0.0.md).
