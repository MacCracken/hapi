# `--dry-run`

The `--dry-run` flag turns any mutating hapi verb into a
faithful preview: planning runs, output renders, but no
syscall or audit-trail write happens. Exit codes match what
the real run would have returned.

## Where it's accepted

| verb              | --dry-run | --root  |
|-------------------|-----------|---------|
| `hapi link`       | ✓         | ✓       |
| `hapi unlink`     | ✓         | —       |
| `hapi adopt`      | ✓         | ✓       |
| `hapi sync`       | ✓         | ✓       |
| `hapi rollback`   | ✓         | —       |
| `hapi checkpoint` | ✓         | —       |
| `hapi fmt`        | ✓ (prints the header it would write) | — |
| `hapi status`     | — (already read-only) | ✓ |
| `hapi list`       | — (already read-only) | ✓ |
| `hapi inspect`    | — (already read-only) | — |
| `hapi check`      | — (already read-only) | — |

Verbs that don't accept `--dry-run` exit 2 if you pass it.

## What it does

Within each mutating verb the contract is identical:

1. The verb does its real planning phase (probe the
   filesystem, parse the manifest, classify each link).
2. The output prints what would happen, suffixed `(dry-run)`
   on each row.
3. Every `sys_unlink` / `sys_rename` / `link_create` /
   `audit_append_*` call is skipped.
4. The verb returns 0 (success) or 1 (refusal / conflict)
   exactly as the real run would have.

A `--dry-run` invocation produces zero audit-trail growth.
That's the testable invariant — `_test_file_size(audit_path)`
before and after a dry-run is unchanged.

Since 1.7.1 the exit code also counts the trail (F-094). A dry run that
would write checks that the trail could take that write, and refuses as
the real run would: `hapi: audit trail is not writable; refusing to
link`. An existing trail must open for writing and end on a whole line.
An absent one must have a directory it could be made in. Nothing is
created or written. Through 1.7.0 a dry run skipped the check and exited
0 where the real run refused. The same rule covers the rest:

- `link --dry-run --force --backup-to <dir>` fails when the snapshot
  the real run needs could not be written in `<dir>`.
- `adopt --dry-run` answers after every refusal the real run makes, not
  before them.
- `checkpoint --dry-run` checks the trail the same way.

## Example

```sh
$ hapi sync --dry-run dotfiles-zsh
syncing dotfiles-zsh...
  + ~/.zshrc -> ../...  (dry-run)
  + ~/.zshenv -> ../...  (dry-run)
  + ~/.config/zsh -> ../...  (dry-run)
linked 3 / 3 (0 already up-to-date)

$ hapi rollback --dry-run
  - ~/.zshrc  (was link; dry-run)
  - ~/.zshenv  (was link; dry-run)
  - ~/.config/zsh  (was link; dry-run)
rolled back 3 / 3 entries
```

In both runs no audit entry was written and no filesystem
state changed. The output is the *forecast*.

A `rollback` forecast probes each entry against the disk as it is now,
so it does not see what its own earlier reversals would change. Where
one reversal makes another possible, its counts can differ from the
real run's. This is accepted; the roadmap tracks it (finding 51 of the
2026-10-29 audit).

## Use cases

- Verifying a manifest change before applying it.
- Asking "what would `hapi rollback` do right now?" without
  actually rolling back.
- CI / lint workflows that want to validate manifests against
  an actual filesystem layout without leaving side effects.

## Combining flags

`--dry-run` composes freely with `--root`, `--backup-to`, and
verb-specific flags like `--force`:

```sh
hapi link --root /etc/myproject --backup-to /var/backups/hapi --dry-run --force pkg
```

The cap-check still fires under `--dry-run` — capability
denials short-circuit before planning starts. Under `--backup-to`
the would-be destination is printed but no snapshot file is
written.

## See also

- [`capability.md`](capability.md) — `--root` flag for non-`$HOME` scope.
- [`backup-to.md`](backup-to.md) — opt-in pre-`--force` snapshots.
