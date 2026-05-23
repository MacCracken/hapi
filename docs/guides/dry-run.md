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
