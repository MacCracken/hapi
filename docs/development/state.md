# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.4.0** — M3 (`unlink` + `rollback`) shipped 2026-05-20.
M2 (`link` + audit trail) and M1 (manifest + `inspect`) shipped
same day. M0 scaffold landed 2026-05-19.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Argv dispatcher. Four real verbs at 0.4.0;
`--version` / `--help` / `-v` / `-h` round out the surface.
M4 → M6 verbs (`adopt`, `list`, `sync`, `status`) plug into
the same dispatch table.

### Current command surface

| verb              | exit codes              | status     |
|-------------------|-------------------------|------------|
| `hapi inspect`    | 0 ok / 1 parse / 2 args | M1         |
| `hapi link`       | 0 ok / 1 fail / 2 args  | M2         |
| `hapi unlink`     | 0 ok / 1 refused / 2 args| M3        |
| `hapi rollback`   | 0 ok / 1 IO error       | M3         |
| `hapi --version`  | 0                       | M1         |
| `hapi --help`     | 0                       | M1         |
| `hapi adopt`      | —                       | M4 pending |
| `hapi list`       | —                       | M5 pending |
| `hapi sync`       | —                       | M5 pending |
| `hapi status`     | —                       | M5 pending |

## Source

- `src/main.cyr` — entry point + argv dispatcher
- `src/manifest.cyr` — `hapi.cyml` parser
- `src/audit.cyr` — JSONL audit-trail writer (link / unlink /
  rollback-marker entries; manifest hash; XDG path resolution
  with test override hook)
- `src/audit_reader.cyr` — JSONL reader; hand-rolled scanner
  over the ADR 0002 field set
- `src/fs_link.cyr` — symlink primitives (probe / compute
  relative / create with mkdir-parents)
- `src/cmd/inspect.cyr` — manifest dump
- `src/cmd/link.cyr` — pre-flight + create + audit
- `src/cmd/unlink.cyr` — trail-driven removal
- `src/cmd/rollback.cyr` — reverse-replay to most recent marker

M4 onward fills:

- `src/cmd/adopt.cyr` (M4)
- `src/cmd/list.cyr` / `sync.cyr` / `status.cyr` (M5)

## Audit trail

- **Location**: `$XDG_STATE_HOME/hapi/audit.jsonl` (or
  `$HOME/.local/state/hapi/audit.jsonl` when unset)
- **Format**: JSONL, append-only, ADR 0002
- **Hash**: `sha1:` + 40 hex; raw-file-bytes hash in M2;
  canonical variant reserved as `sha1c:` for v1.0
- **Entry ops**: `link`, `unlink`, `rollback-marker`
- **Readers**: `unlink` (filters live entries by package),
  `rollback` (reverse-walks to most recent marker)
- **Future consumers**: M5 `status` / `sync` / `list`

## Tests

- `tests/hapi.tcyr` — primary suite. 100 assertions across
  22 test groups:
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

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, slice, syscalls,
  assert, bench, args, fs, result, toml, cyml, sha1, chrono

Future M6 may add a kavach capability-check dep once kavach
exposes the surface.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Examples shipped

- `docs/examples/dotfiles-zsh/` — 3-file package used across
  the M1 / M2 / M3 acceptance tests.

## Next

See [`roadmap.md`](roadmap.md) for the M4 → v1.0 plan. Next
ship is M4 (`hapi adopt`), targeting v0.5.0.
