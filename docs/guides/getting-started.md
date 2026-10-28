# Getting started with hapi

## Build

```sh
cyrius deps                            # resolve stdlib
cyrius build src/main.cyr build/hapi   # compile
./build/hapi --help                    # see the verb set
cyrius test                            # run tests/*.tcyr
```

## Layout

- `src/main.cyr` — entry point
- `src/cli.cyr` — the command line: verb dispatch and each verb's
  flags (cmdit), and the usage text. No command includes it.
- `src/dry_run.cyr` — the process-wide `--dry-run` flag the commands read
- `src/cmd/{link,unlink,adopt,list,sync,status,rollback,checkpoint,check,inspect}.cyr` —
  one module per verb
- `src/manifest.cyr` — `hapi.cyml` parser + canonical re-serializer
- `src/manifest_write.cyr` — atomic `[[link]]` row append / remove
- `src/audit.cyr` / `src/audit_reader.cyr` — JSONL trail writer + reader
- `src/fs_link.cyr` — symlink primitives + path resolution
- `src/cap.cyr` — `--root` capability check
- `src/backup.cyr` — `--backup-to` pre-`--force` snapshots
- `tests/hapi.{tcyr,bcyr,fcyr}` — tests / benchmarks / fuzz

## Adding a command

1. Add a new `src/cmd/<name>.cyr` module with the command handler.
2. Wire it into `src/cli.cyr`: append its id to the `HapiVerb` enum
   and its `cmdit_verb` call to `_hapi_cli_new` — at the **end** of
   both, because cmdit numbers verbs by registration order — then give
   it a flag set and a positional count, and call it from
   `_hapi_run_verb`. Add it to `hapi_print_usage` too.
3. Add a guide page at `docs/guides/<name>.md` describing the
   command's semantics, flags, and exit codes.
4. Add happy + conflict + capability-denied tests to `tests/hapi.tcyr`.
5. Update CHANGELOG.
6. If the design choice is non-trivial (e.g., a new flag with
   capability implications), file an ADR.

## Adding a feature to an existing command

1. Edit the relevant `src/cmd/<name>.cyr`.
2. Test additions per the existing matrix.
3. Update the command's guide page.
4. CHANGELOG entry + version bump.

## Conventions

- Every path argument is validated before any syscall (bounds,
  `../` traversal, symlink loop).
- Every filesystem mutation writes an audit-trail entry — no
  exceptions.
- Idempotent operations are the norm; non-idempotent operations
  (`adopt`, `--force`) are clearly flagged.
- No `exec_*`, no `sys_system()`. Syscall primitives only.

See [`../adr/template.md`](../adr/template.md) when a non-trivial
design choice deserves an ADR.
