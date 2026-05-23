# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.9.0** — M7 close shipped 2026-05-23: P(-1) security
audit pass with `docs/audit/2026-05-23-audit.md` filed
(F-001 HIGH + F-003 LOW landed; F-002 MEDIUM deferred to
kavach via `issues/2026-05-23-cap-check-symlink-escape.md`)
and `docs/benchmarks.md` baseline captured (sync over a
100-pkg / 350-link home; cold 72 ms, warm 54 ms with 0
audit growth). v0.8.0 (M7 issue-repair sweep — status guide,
upstream-drift, `--backup-to`, sha1c canonicalization)
shipped the same day. v0.7.0 (M6 — `--root` + `--dry-run`)
2026-05-20; v0.6.0 (M5), v0.5.0 (M4), v0.4.0 (M3),
v0.3.0 (M2), v0.2.0 (M1) all landed the same day. M0
scaffold 2026-05-19.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Argv dispatcher. Ten real verbs at 0.9.0;
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
  65 test groups (v0.9.0; was 218 / 61 at v0.8.0):
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

See [`roadmap.md`](roadmap.md) for the M7 → v1.0 plan. M7
is now closed; v0.9.0 ships the audit + benchmarks pair.

M7 close (v0.9.0, 2026-05-23):
- ✅ P(-1) hardening pass + `docs/audit/2026-05-23-audit.md`
  (F-001 HIGH + F-003 LOW landed; F-002 MEDIUM deferred to
  kavach via
  [`issues/2026-05-23-cap-check-symlink-escape.md`](issues/2026-05-23-cap-check-symlink-escape.md))
- ✅ `docs/benchmarks.md` first baseline (sync over 100-pkg /
  350-link synthetic home; cold 72 ms / warm 54 ms / 0
  audit growth; methodology + reproduction inlined)

M7 issue-repair sweep (v0.8.0, 2026-05-23):
- ✅ `docs/guides/status.md` exit-1 clarification
- ✅ `docs/guides/upstream-drift.md` new guide
- ✅ `--backup-to <dir>` flag on link / sync / adopt
- ✅ Manifest-hash canonicalization `sha1:` → `sha1c:`

**Next ship is M8 — the v1.0.0 freeze.** Command surface,
manifest schema, and audit-trail format all become contractual.
See the roadmap M8 section + the *v1.0 criteria* checklist.
