# `hapi link`

Create the symlinks declared in a package's `hapi.cyml` manifest.
Idempotent: re-running on an already-linked package produces no
changes (and no audit-trail growth).

## Synopsis

```sh
hapi link <package-dir> [--force]
hapi link <path-to-hapi.cyml> [--force]
```

## What it does

For each `[[link]]` row in the manifest:

1. Resolve the source: `<absolute-package-dir>/<source>`.
   If the source is **not present on disk the row is refused** — the
   symlink would dangle, and `--force` does not override that.
2. Resolve the target: `$HOME/<target>` (the scoped root), and refuse
   if its parent **resolves outside** that root once symlinks are
   followed per component. `--force` does not override that either;
   see [`capability.md`](capability.md).
3. Probe the target with `readlink(2)` to classify:
   - **absent** — create the symlink
   - **symlink to the correct relative path** — no-op
   - **symlink to a different path** — conflict
   - **regular file** — conflict
   - **directory** — conflict (never overrideable; see below)
4. If any conflict and `--force` is not set, refuse the run,
   list every conflict to stderr, exit 1, write nothing.
5. Otherwise, create each new symlink and append one
   audit-trail entry per write.

Symlinks are written as **relative paths** from the link's
parent directory to the source, per
[ADR 0003](../adr/0003-symlink-target-shape.md) — so the
dotfile repo stays portable across machines and clone paths.

## Example

```sh
$ hapi link docs/examples/dotfiles-zsh
  + /home/user/.zshrc -> ../Repos/hapi/docs/examples/dotfiles-zsh/zshrc
  + /home/user/.zshenv -> ../Repos/hapi/docs/examples/dotfiles-zsh/zshenv
  + /home/user/.config/zsh -> ../../Repos/hapi/docs/examples/dotfiles-zsh/config/zsh
linked 3 / 3 (0 already up-to-date)

$ hapi link docs/examples/dotfiles-zsh
linked 0 / 3 (3 already up-to-date)
```

The second invocation is a true no-op: no syscalls modify the
filesystem, no audit entries are written, exit 0.

## `--force`

`--force` makes the destructive replacements explicit:

| existing target            | without `--force` | with `--force`                |
|----------------------------|-------------------|-------------------------------|
| nothing                    | create            | create                        |
| symlink to right place     | no-op             | no-op                         |
| symlink to wrong place     | conflict          | unlink, recreate              |
| regular file               | conflict          | unlink, recreate (data lost)  |
| directory                  | conflict          | **still refuses**             |

Directories are never overridden by `--force`. They hold user
data; if you genuinely want to replace one, `rm -rf` with your
eyes on the screen and then re-run `hapi link`. The flag is a
small escape hatch, not a sledgehammer.

Four refusals are never overridden by `--force`, because following
the generic "rerun with --force" advice is exactly what made each one
destructive:

- **The target resolves outside the scope root** — see
  [capability](capability.md).
- **The row's source is missing** — the link would dangle.
- **The target resolves into the package itself** (1.1.1). With
  `~/.ssh -> dotfiles/pkg/ssh`, the row `ssh/config -> .ssh/config`
  names its own source as its target; through 1.1.0 `--force` deleted
  that file — the only copy — and linked it to itself.
- **The target lies beneath another row's target** (1.1.1). The outer
  row becomes a symlink, so the inner one would be written through it.

### Under a symlinked parent

The link text is computed from the directory the link physically sits
in (ADR 0003, 1.1.1 addendum). Through 1.1.0 it was computed from the
spelled parent, so under `~/.config -> data/deep/config` a row
`.config/rc` got a text that dangled — while `status` said OK. A link
1.1.0 wrote there still counts as hapi's for `unlink` and `rollback`;
`link` sees it as a conflict (`--force` replaces it) and `status`
reports it.

## Preserving the original bytes — `--backup-to`

`--force` over a regular file is irreversible by itself — the
file's bytes are gone. For a recoverable safety net, pair it
with `--backup-to <dir>`:

```sh
hapi link --force --backup-to ~/.local/share/hapi/backups pkg
```

The flag copies each `--force`-removed regular file to a
timestamped path under `<dir>` before the unlink, and records the
location as a `backup_path` field on the audit entry. Symlink
conflicts are skipped (no bytes to preserve). See
[`backup-to.md`](backup-to.md) for the full semantics.

## Audit trail

Every link write appends one JSON-line entry to
`$XDG_STATE_HOME/hapi/audit.jsonl` (or
`$HOME/.local/state/hapi/audit.jsonl` when `XDG_STATE_HOME` is
unset). Format and field semantics are locked in
[ADR 0002](../adr/0002-audit-trail-format.md). The trail is the
input to [`hapi unlink`](unlink.md) and [`hapi rollback`](rollback.md).

The trail is append-only — `hapi link` never edits or truncates
existing entries. A re-run that does nothing writes no new
lines.

### Directories it makes

A target whose parent does not exist gets its missing directories made
(`mkdir -p`, `0777` through your umask). Since 1.4.0 the entry records the
outermost one it made, as `created_dir`. With `~/.config` present and the
row `.config/nvim/lua/init.lua`, that is `~/.config/nvim`; `lua` below it
is implied. A row whose directory already existed records nothing, even
when another row made that directory a moment earlier. A directory that
was there before hapi is never claimed.

That record is what lets `unlink`, `sync --prune` and `rollback` remove
those directories again, and only those: see
[`unlink.md`](unlink.md#directories-hapi-made). If writing the entry fails,
the link is taken back, and since 1.4.0 so are the directories it made.

## Exit codes

| code | meaning                                                          |
|------|------------------------------------------------------------------|
| 0    | links applied (or already up-to-date)                            |
| 1    | manifest parse failure, conflict without `--force`, IO error,    |
|      | audit-trail write failure, or one of the three refusals          |
|      | `--force` does **not** override: an existing directory, a row    |
|      | whose **source is missing**, or a target that **resolves         |
|      | outside the scope root**                                         |
| 2    | bad usage — missing argument, an unknown flag, an extra          |
|      | positional, or a flag-shaped value after `--root`/`--backup-to`  |

## See also

- [`inspect.md`](inspect.md) — preview what `link` would do, no
  filesystem side effects.
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md)
- [ADR 0003 — Symlink target shape](../adr/0003-symlink-target-shape.md)
