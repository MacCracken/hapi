# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-19 via `cyrius init hapi`. No releases yet.

## Toolchain

- **Cyrius pin**: `6.0.0` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`hapi`). Single-binary CLI dispatcher; subcommands land at
M2 onward (`link`, `unlink`, `adopt`, `list`, `sync`, `status`,
`rollback`).

## Source

- `src/main.cyr` — entry point; currently prints scaffold version line and exits

M1 onward fills:

- Manifest parser
- Command dispatcher
- Audit trail writer / reader
- Subcommand handlers under `src/cmd/` (planned)

## Tests

- `tests/hapi.tcyr` — primary suite (currently empty per cyrius init defaults)
- `tests/hapi.bcyr` — benchmark stub
- `tests/hapi.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench

M1 adds `lib/cyml.cyr` for manifest parsing (already in stdlib path).
Future M6 may add a kavach capability-check dep once kavach exposes
the surface.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Next

See [`roadmap.md`](roadmap.md) for the M1 → v1.0 plan. Next ship is M1
(manifest format spec + parser), targeting v0.2.0.
