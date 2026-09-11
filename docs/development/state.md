# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.0.10** (2026-08-26). The 1.0.x hardening arc is closed — all
twenty findings of the 2026-08-25 P(-1) sweep are fixed. The v1.0
contract (command surface, manifest schema, audit-trail format) stayed
frozen across the whole arc.

Release-by-release detail lives in
[`../../CHANGELOG.md`](../../CHANGELOG.md), and the findings with their
resolutions in [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md).
This file is the *snapshot*, not a second changelog — it says what is
true now, not how it got here.

Milestone index, for tracing an ADR or a guide back to its ship:
v1.0.0 = M8 / v1.0 freeze (2026-05-23), v0.9.0 = M7 close, v0.8.0 = M7
sweep, v0.7.0 = M6, v0.6.0 = M5, v0.5.0 = M4, v0.4.0 = M3, v0.3.0 = M2,
v0.2.0 = M1, M0 scaffold 2026-05-19.


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

ADR 0005's usage contract, tightened in 1.0.9: **every** verb rejects an
extra positional with exit 2 (`hapi rollback <pkg>` used to ignore the
argument and reverse the entire trail); a verb that takes no flags still
owes 2 for one rather than 1 (F-033, `inspect`); and a flag-shaped value
for `--root` / `--backup-to` is refused rather than consumed (F-019 —
`link --root --dry-run pkg` used to create a directory named
`--dry-run`). `status` exits 1 on drift, which is an assertion, not a
predicate.

Two accepted keys do nothing, and a state snapshot is the right place to
say so: `--backup-to` is **inert on `sync`** (no `--force` there, so no
destructive step to snapshot — F-026), and `package.ignore` is parsed,
echoed by `inspect` and folded into the manifest hash but honoured by no
verb (**reserved until v2.0** — F-025, ADR 0001).

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

- `tests/hapi.tcyr` — primary suite. **365 assertions across 92 test
  groups.** Re-derive rather than recount by hand — these figures have
  rotted twice, and the per-tier breakdown below drifted 16 groups
  short before the 2026-08-26 sweep:

  ```sh
  cyrius test                                   # assertions
  grep -c 'test_group(' tests/hapi.tcyr         # groups
  cyrius test 2>&1 | grep '^=== ' | sed 's/^=== //;s/:.*//' \
    | sort | uniq -c | sort -rn                 # per-tier breakdown
  ```

  Groups by tier, as measured: manifest 7, cap 7, backup 7, rollback 6,
  link 6, dry-run 6, adopt 6, status 5, canonical 5, audit_reader 5,
  manifest_write 4, fs_link 4, check 4+2, audit-repair 4, audit 4,
  sync 3, list 3, unlink 2, checkpoint 1, agnos_compat 1.

### Harnesses

`cyrius test` cannot express two of hapi's regressions, so they live
beside it as shell harnesses. **CI runs both.**

- `scripts/concurrency-test.sh` — F-012's regression. The defect needs
  two hapi *processes* racing on one manifest, and `.tcyr` cannot fork
  while hapi is syscall-only by rule. Measured before the fix: 16
  concurrent adopts → 16 files moved, 16 symlinks, 16 trail entries and
  **1** manifest row; 16/16 after.
- `scripts/agnos-smoke.sh` — runs the `--agnos` build under mirshi.
  Four checks: the binary loads and the agnos arg reader delivers argv,
  the envp gap is asserted rather than assumed, a relative package
  argument is refused rather than silently mis-resolved (F-027,
  verified on-target), and the exit-code contract holds there too. A
  missing mirshi exits **2 = SKIP** and CI warns — never green.

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

The 1.0.x hardening arc is **closed** — all twenty findings of the
2026-08-25 P(-1) sweep are fixed (1.0.5 → 1.0.10).

One thing is owed before the arc is formally signed off: a **P(-1)
re-walk** over the repaired write paths. Thirteen fixes landed across
1.0.9 and 1.0.10 and between them touched a path argument, a syscall
and the audit-trail write path — all three of CLAUDE.md's re-run
triggers. That re-walk is what reopens the additive v1.x bucket.

Forward-looking work is **not** listed here — it lives in
[`roadmap.md`](roadmap.md), which carries only work that has not
shipped. Open dogfood papercuts are in
[`issues/`](issues/) (3 open, 7 archived).
