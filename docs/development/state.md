# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.5.0** — M4 (`adopt`) shipped 2026-05-20. M3 (`unlink` +
`rollback`), M2 (`link` + audit trail), M1 (manifest +
`inspect`) shipped same day. M0 scaffold landed 2026-05-19.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Argv dispatcher. Five real verbs at 0.5.0;
`--version` / `--help` / `-v` / `-h` round out the surface.
M5 → M6 verbs (`list`, `sync`, `status`, `checkpoint`,
`check --strict`) plug into the same dispatch table.

### Current command surface

| verb              | exit codes              | status     |
|-------------------|-------------------------|------------|
| `hapi inspect`    | 0 ok / 1 parse / 2 args | M1         |
| `hapi link`       | 0 ok / 1 fail / 2 args  | M2         |
| `hapi unlink`     | 0 ok / 1 refused / 2 args| M3        |
| `hapi rollback`   | 0 ok / 1 IO error       | M3         |
| `hapi adopt`      | 0 ok / 1 refused / 2 args| M4        |
| `hapi --version`  | 0                       | M1         |
| `hapi --help`     | 0                       | M1         |
| `hapi list`       | —                       | M5 pending |
| `hapi sync`       | —                       | M5 pending |
| `hapi status`     | —                       | M5 pending |
| `hapi checkpoint` | —                       | M5 pending (carried forward from M3) |
| `hapi check --strict` | —                   | M5 pending (carried forward from M1) |

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

M5 onward fills:

- `src/cmd/list.cyr` / `sync.cyr` / `status.cyr` (M5)
- `src/cmd/checkpoint.cyr` (M5, carried forward from M3)
- `src/cmd/check.cyr` with `--strict` mode (M5, carried forward from M1)

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

- `tests/hapi.tcyr` — primary suite. 127 assertions across
  29 test groups:
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

See [`roadmap.md`](roadmap.md) for the M5 → v1.0 plan. Next
ship is M5 (`list` + `sync` + `status`, plus the
carried-forward `checkpoint` and `check --strict` verbs),
targeting v0.6.0.
