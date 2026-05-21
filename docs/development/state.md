# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.6.0** — M5 (`list` + `sync` + `status` + `checkpoint` +
`check --strict`) shipped 2026-05-20, same day as M0–M4. M4
(`adopt`), M3 (`unlink` + `rollback`), M2 (`link` + audit
trail), M1 (manifest + `inspect`) all landed earlier the same
day. M0 scaffold landed 2026-05-19.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Argv dispatcher. Ten real verbs at 0.6.0;
`--version` / `--help` / `-v` / `-h` round out the surface.
M6+ verbs (`--root`, `--dry-run`) plug into the same dispatch
table.

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
- `src/manifest.cyr` — `hapi.cyml` parser
- `src/manifest_write.cyr` — append + remove `[[link]]` rows
  atomically via `tmp+rename`
- `src/audit.cyr` — JSONL audit-trail writer (link / unlink /
  adopt / unadopt / rollback-marker entries; manifest hash;
  XDG path resolution with test override hook)
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

M6 onward fills:

- `--root <path>` capability gate (M6)
- `--dry-run` flag (M6)
- per-package manifest discovery for a no-arg `hapi sync`
  (post-M5; needs a way to recover pkg_dir from a live
  audit entry — deferred until kavach lands, or a
  trail-format additive field carries it)

## Audit trail

- **Location**: `$XDG_STATE_HOME/hapi/audit.jsonl` (or
  `$HOME/.local/state/hapi/audit.jsonl` when unset)
- **Format**: JSONL, append-only, ADR 0002
- **Hash**: `sha1:` + 40 hex; raw-file-bytes hash;
  canonical variant `sha1c:` reserved for M7 migration
- **Entry ops**: `link`, `unlink`, `adopt`, `unadopt`,
  `rollback-marker`
- **Readers**: `unlink` (filters live entries by package),
  `rollback` (reverse-walks to most recent marker, handles
  link / unlink / adopt)
- **Future consumers**: M5 `status` / `sync` / `list` / `checkpoint`

## Tests

- `tests/hapi.tcyr` — primary suite. 163 assertions across
  41 test groups:
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

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, slice, syscalls,
  assert, bench, args, fs, result, toml, cyml, sha1, chrono

Pending upstream stdlib work tracked in proposals:
- `cyrius/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md`
  (`sys_rename` lives there)
- `cyrius/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md`
  (`sys_fsync` + `sys_fdatasync`)

Future M6 may add a kavach capability-check dep once kavach
exposes the surface.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Examples shipped

- `docs/examples/dotfiles-zsh/` — 3-file package used across
  the M1 / M2 / M3 acceptance tests.

## Next

See [`roadmap.md`](roadmap.md) for the M6 → v1.0 plan. Next
ship is M6 (`--root` capability gate + `--dry-run`), targeting
v0.7.0. Depends on the kavach capability API; ships with a
CLI-level allowlist until that surface stabilizes.
