# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.3.0** — M2 (`link` + audit trail) shipped 2026-05-20.
M1 (manifest format + `inspect`) shipped same day. M0 scaffold
landed 2026-05-19.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Argv dispatcher. Two real verbs at 0.3.0;
`--version` / `--help` / `-v` / `-h` round out the surface.
M3 → M6 verbs (`unlink`, `adopt`, `list`, `sync`, `status`,
`rollback`) plug into the same dispatch table.

### Current command surface

| verb              | exit codes              | status     |
|-------------------|-------------------------|------------|
| `hapi inspect`    | 0 ok / 1 parse / 2 args | M1         |
| `hapi link`       | 0 ok / 1 fail / 2 args  | M2         |
| `hapi --version`  | 0                       | M1         |
| `hapi --help`     | 0                       | M1         |
| `hapi unlink`     | —                       | M3 pending |
| `hapi rollback`   | —                       | M3 pending |
| `hapi adopt`      | —                       | M4 pending |
| `hapi list`       | —                       | M5 pending |
| `hapi sync`       | —                       | M5 pending |
| `hapi status`     | —                       | M5 pending |

## Source

- `src/main.cyr` — entry point + argv dispatcher
- `src/manifest.cyr` — `hapi.cyml` parser (`hapi_mf_*` API,
  `HapiMfError` variants)
- `src/audit.cyr` — JSONL audit-trail writer; `audit_append_link_r`,
  `audit_manifest_hash`, scope override via `audit_set_trail_path`
- `src/fs_link.cyr` — symlink primitives: `link_probe`,
  `fsl_compute_relative`, `link_create`, mkdir-parents helper
- `src/cmd/inspect.cyr` — `hapi inspect` handler
- `src/cmd/link.cyr` — `hapi link` handler, scope override via
  `link_set_scope_root`

M3 onward fills:

- `src/cmd/unlink.cyr` / `rollback.cyr` (M3)
- `src/cmd/adopt.cyr` (M4)
- `src/cmd/list.cyr` / `sync.cyr` / `status.cyr` (M5)

## Audit trail

- **Location**: `$XDG_STATE_HOME/hapi/audit.jsonl` (or
  `$HOME/.local/state/hapi/audit.jsonl` when unset)
- **Format**: JSONL, append-only, ADR 0002
- **Hash**: `sha1:` + 40 hex; raw-file-bytes hash in M2; canonical
  variant reserved as `sha1c:` for v1.0
- **Consumers**: M3 `unlink` (reads), M3 `rollback` (reads + appends),
  M5 `status` / `sync` (reads), M5 `list` (reads)

## Tests

- `tests/hapi.tcyr` — primary suite. 69 assertions across
  14 test groups:
  - Manifest: minimal happy, 3-link M1 acceptance, validation
    errors, path traversal, comments/blanks, on-disk parse,
    missing file
  - Audit: link entry format, JSON escaping
  - fs_link: relative path computation, link_probe classification
  - link: happy path + M2 acceptance (re-run no-op), conflict
    refusal, --force refuses directory
- `tests/hapi.bcyr` — benchmark stub
- `tests/hapi.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, slice, syscalls,
  assert, bench, args, fs, result, toml, cyml, sha1, chrono

`lib/cyml.cyr` handles the file-level CYML split; `src/manifest.cyr`
hand-rolls the section-aware TOML parsing for `[package]` /
`[[link]]`. `lib/sha1.cyr` hashes the raw manifest bytes for
the audit trail. `lib/chrono.cyr` formats ISO 8601 timestamps.

Future M6 may add a kavach capability-check dep once kavach
exposes the surface.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Examples shipped

- `docs/examples/dotfiles-zsh/` — 3-file package used by the M1
  acceptance test, the `inspect` guide, and the M2 acceptance
  test (link + re-link idempotency).

## Next

See [`roadmap.md`](roadmap.md) for the M3 → v1.0 plan. Next ship
is M3 (`unlink` + `rollback` — audit-trail replay), targeting
v0.4.0.
