# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

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

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Argv dispatcher. Ten real verbs frozen at v1.0.0;
`--version` / `--help` / `-v` / `-h` round out the surface.
Three global flags plug into per-verb arg parsers:
`--root <path>` (link / adopt / sync / status / list, M6),
`--dry-run` (link / unlink / adopt / sync / rollback /
checkpoint, M6), and `--backup-to <dir>` (link / sync /
adopt, v0.8.0) — opt-in pre-`--force` snapshot.

### Current command surface

| verb                  | exit codes               | status |
|-----------------------|--------------------------|--------|
| `hapi inspect`        | 0 ok / 1 parse / 2 args  | M1     |
| `hapi link`           | 0 ok / 1 fail / 2 args   | M2     |
| `hapi unlink`         | 0 ok / 1 refused / 2 args| M3     |
| `hapi rollback`       | 0 ok / 1 IO error        | M3     |
| `hapi adopt`          | 0 ok / 1 refused / 2 args| M4     |
| `hapi list`           | 0 ok / 1 env error       | M5     |
| `hapi sync`           | 0 ok / 1 fail / 2 args   | M5     |
| `hapi status`         | 0 ok / 1 drift / 2 args  | M5     |
| `hapi checkpoint`     | 0 ok / 1 IO error        | M5     |
| `hapi check --strict` | 0 ok / 1 parse / 2 args  | M5     |
| `hapi --version`      | 0                        | M1     |
| `hapi --help`         | 0                        | M1     |

## Source

- `src/main.cyr` — entry point + argv dispatcher
- `src/manifest.cyr` — `hapi.cyml` parser + canonical
  re-serializer. `hapi_mf_canonicalize(m, out, cap)` emits
  the fixed byte form used by the v0.8.0 `sha1c:`
  manifest_hash variant: `[package]` fields in fixed order,
  `[[link]]` rows sorted by `target`, no comments, single
  blank line between sections.
- `src/manifest_write.cyr` — append + remove `[[link]]` rows
  atomically via `tmp+rename`
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
  via the M3 audit helper
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
  Symlink-aware resolution deferred per F-002 to the kavach
  migration.
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

M7 onward fills:

- maintainer's actual dotfiles migrate to hapi packages (M7)
- P(-1) hardening pass + security audit (M7)
- per-package manifest discovery for a no-arg `hapi sync`
  (post-M5; needs a way to recover pkg_dir from a live
  audit entry — deferred until kavach lands, or a
  trail-format additive field carries it)
- kavach swap inside `src/cap.cyr` once kavach exposes a
  stable capability API (post-M6 — internal-only refactor,
  no caller changes)

## Audit trail

- **Location**: `$XDG_STATE_HOME/hapi/audit.jsonl` (or
  `$HOME/.local/state/hapi/audit.jsonl` when unset)
- **Format**: JSONL, append-only, ADR 0002
- **Hash**: `sha1c:` + 40 hex (v0.8.0; canonical variant —
  parses, re-serializes the manifest to a fixed byte form, then
  hashes). Pre-v0.8.0 entries used `sha1:` over raw file bytes;
  readers tolerate both prefixes during M7 → M8.
  `audit_manifest_hash_raw(path)` kept for diagnostics.
- **Entry ops**: `link`, `unlink`, `adopt`, `unadopt`,
  `rollback-marker`
- **Additive fields (v0.8.0)**: `backup_path` on
  `link` / `adopt` entries when `--backup-to <dir>` is set.
  Readers from v0.7.0 tolerate the new field per ADR 0002's
  growth contract.
- **Readers**: `unlink` (filters live entries by package),
  `rollback` (reverse-walks to most recent marker, handles
  link / unlink / adopt)
- **Future consumers**: M5 `status` / `sync` / `list` / `checkpoint`

## Tests

- `tests/hapi.tcyr` — primary suite. 235 assertions across
  65 test groups (v1.0.0; unchanged from v0.9.0):
  - Manifest (7 groups): minimal, M1 acceptance, validation,
    path traversal, comments, on-disk parse, missing file
  - Audit writer (2 groups): link entry format, JSON escaping
  - Audit reader (3 groups): round trip, torn-line drop,
    malformed drop
  - fs_link (2 groups): relative computation, probe
  - link (3 groups): happy/M2 acceptance, conflict refusal,
    --force refuses directory
  - unlink (2 groups): M3 acceptance round-trip,
    user-mutation refusal
  - rollback (4 groups): full reverse, link/unlink/link →
    clean, idempotent, stops at marker
  - manifest_write (2 groups): append row, remove row
  - adopt (5 groups): M4 acceptance happy path, refuse
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
  - sync (2 groups): M5 acceptance (clean tree -> no audit
    growth), re-creates a missing link
  - cap (4 groups): path-within matcher (exact / subdir /
    boundary / empty), deny outside $HOME + allowlist,
    allow inside $HOME, allow listed root (+ byte-prefix
    collision rejection)
  - dry-run (6 groups): link / unlink / adopt / sync /
    rollback / checkpoint each write zero audit + zero
    filesystem state under `hapi_set_dry_run(1)`
  - backup-to (5 groups; v0.8.0): compose_path filename
    layout (dir + ts + pkg + basename, no doubled separator),
    link --force snapshots regular-file conflicts with the
    original bytes recoverable from the audit's
    `backup_path` field, symlink conflicts skip the snapshot,
    dry-run writes no snapshot file, adopt snapshots before
    sys_rename
  - canonical hash (4 groups; v0.8.0): writer emits
    `sha1c:` prefix, cosmetic edits (comments + whitespace)
    yield identical hash, `[[link]]` row reorder yields
    identical hash, target rename diverges
  - audit-repair (4 groups; v0.9.0): lexical normalize
    collapses `..` / `.`; cap-check rejects `..` escape from
    `$HOME` (F-001); allowlist entries lex-normalized;
    `hapi_backup_copy` refuses symlink source under
    `O_NOFOLLOW` (F-003)

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, slice, syscalls,
  assert, bench, args, fs, result, toml, cyml, sha1, chrono

Pending upstream stdlib work tracked in proposals:
- `cyrius/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md`
  (`sys_rename` lives there)
- `cyrius/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md`
  (`sys_fsync` + `sys_fdatasync`)

M6 ships the env-var allowlist stopgap (`HAPI_ALLOWED_ROOTS`);
the kavach capability-check dep lands inside `src/cap.cyr`
once kavach exposes a stable surface.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Examples shipped

- `docs/examples/dotfiles-zsh/` — 3-file package used across
  the M1 / M2 / M3 acceptance tests.

## Next

**v1.0.0 has shipped.** The contract (command surface, manifest
schema, audit-trail format) is frozen. The roadmap from here
forward is the **post-v1.0 / v1.x** backlog — additive growth
only, with each item tracked to either an open issue, an ADR
deferral, or a roadmap *Deferred* entry.

Candidate post-v1.0 work (ordered loosely by maturity):

- **kavach migration** — internal swap inside `src/cap.cyr`
  when the kavach capability service ships. Closes F-002
  (`issues/2026-05-23-cap-check-symlink-escape.md`) without
  touching the `cap_check_root_r` API.
- **stdlib syscall wrappers** — `sys_rename` / `sys_fsync` /
  `sys_fdatasync` once the cyrius proposals land. Quality-of-
  life patch; no behavior change.
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
