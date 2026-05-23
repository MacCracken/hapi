# `hapi sync`

Re-apply a package's manifest idempotently. State that already
matches the manifest is a no-op (no audit writes); missing
links are created (one audit entry each); user-mutated state
is refused (same conflict semantics as `hapi link`).

## Synopsis

```sh
hapi sync <package-dir|hapi.cyml>
```

## What it does

Operationally, `hapi sync <pkg>` is `hapi link <pkg>` *without*
`--force`. The verbs differ in *intent*:

- `hapi link` — "create these now" (first apply, or new
  links added to a manifest)
- `hapi sync` — "make state match manifest" (idempotent
  reconciliation)

Both produce the same audit-trail and filesystem effects.
Extending sync to also prune trail rows no longer in the
manifest (`hapi sync --prune`) is a post-v1.0 candidate — see
[`issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`](../development/issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md)
for the design discussion and the full-rotation workaround.

## Example: idempotent re-run

```sh
$ hapi sync docs/examples/dotfiles-zsh
syncing docs/examples/dotfiles-zsh...
  + ~/.zshrc -> ../...
  + ~/.zshenv -> ../...
  + ~/.config/zsh -> ../...
linked 3 / 3 (0 already up-to-date)

$ hapi sync docs/examples/dotfiles-zsh
syncing docs/examples/dotfiles-zsh...
linked 0 / 3 (3 already up-to-date)
```

Second invocation produced zero audit entries. That's the
acceptance contract: `sync` over a clean tree is a no-op.

## Example: re-create a missing link

```sh
$ rm ~/.zshrc

$ hapi sync docs/examples/dotfiles-zsh
syncing docs/examples/dotfiles-zsh...
  + ~/.zshrc -> ../...
linked 1 / 3 (2 already up-to-date)
```

Exactly the one missing link is re-created. The other two
(matching the manifest already) stay quiet.

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | state matches manifest                                        |
| 1    | conflict (use `hapi link --force` to override), parse error, or IO failure |
| 2    | bad usage (no path argument)                                  |

## Preserving bytes during destructive overwrites

`hapi sync` inherits `--force` from `cmd_link`, and with it
`--backup-to <dir>`. When you sync a package whose links would
overwrite existing regular files, pair the run with
`--backup-to` to snapshot each file before the destructive step:

```sh
hapi sync --backup-to ~/.local/share/hapi/backups pkg
```

See [`backup-to.md`](backup-to.md) for filename layout and
audit-trail effects.

## See also

- [`link.md`](link.md) — sync's engine; the `--force` flag for
  override semantics.
- [`status.md`](status.md) — detect drift before syncing.
- [`backup-to.md`](backup-to.md) — opt-in pre-`--force` snapshots.
