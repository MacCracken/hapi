# Contributing to hapi

Contributions are welcome. All contributions must be licensed under
GPL-3.0-only.

## Development

Follow the conventions in [`CLAUDE.md`](CLAUDE.md) and the AGNOS
[first-party standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

Build and test before submitting:

```sh
cyrius deps
cyrius build src/main.cyr build/hapi
cyrius test
```

## Command additions

Every new subcommand needs:

1. A `src/cmd/<name>.cyr` module with the handler.
2. A `docs/guides/<name>.md` page describing semantics, flags, and exit codes.
3. Happy + conflict + capability-denied tests in `tests/hapi.tcyr`.
4. CHANGELOG entry under `Added`.
5. If the command involves a new capability scope or breaks an existing
   audit-trail invariant, an ADR in `docs/adr/`.

## Reporting Issues

Open an issue at https://github.com/MacCracken/hapi/issues.

For security-sensitive issues (path traversal, capability bypass,
audit-trail tampering), see [`SECURITY.md`](SECURITY.md) instead.
