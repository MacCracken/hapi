# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.2.0** — M1 (manifest format spec + parser) shipped 2026-05-20.
M0 scaffold landed 2026-05-19.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Argv dispatcher with one real verb today
(`inspect`); `--version`, `--help` / `-v`, `-h` wired up so the
CLI surface matches a real tool from day one. M2 → M6 verbs
(`link`, `unlink`, `adopt`, `list`, `sync`, `status`,
`rollback`) plug into the same dispatch table.

### Current command surface

| verb              | exit codes              | status     |
|-------------------|-------------------------|------------|
| `hapi inspect`    | 0 ok / 1 parse / 2 args | M1         |
| `hapi --version`  | 0                       | M1         |
| `hapi --help`     | 0                       | M1         |
| `hapi link`       | —                       | M2 pending |
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
- `src/cmd/inspect.cyr` — `hapi inspect` handler

M2 onward fills:

- `src/cmd/link.cyr` / `unlink.cyr` / `adopt.cyr` / `list.cyr` /
  `sync.cyr` / `status.cyr` / `rollback.cyr`
- `src/audit.cyr` — audit-trail writer / reader (lands at M3)

## Tests

- `tests/hapi.tcyr` — primary suite. 36 assertions across 7 test
  groups covering happy path, validation errors, path-traversal,
  comments/blanks, on-disk parse, and missing-file error.
- `tests/hapi.bcyr` — benchmark stub
- `tests/hapi.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, slice, syscalls,
  assert, bench, args, fs, result, toml, cyml

`lib/cyml.cyr` provides the file-level CYML split (TOML header +
markdown body); `src/manifest.cyr` hand-rolls the section-aware
TOML parsing because `lib/toml.cyr` only recognizes `[[section]]`
headers, and the ADR locks `[package]` / `[[link]]` as the
user-facing shape.

Future M6 may add a kavach capability-check dep once kavach
exposes the surface.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Examples shipped

- `docs/examples/dotfiles-zsh/` — 3-file package used by the M1
  acceptance test and the `inspect` guide walkthrough.

## Next

See [`roadmap.md`](roadmap.md) for the M2 → v1.0 plan. Next ship
is M2 (`hapi link`), targeting v0.3.0.
