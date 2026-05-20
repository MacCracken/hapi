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
2. Resolve the target: `$HOME/<target>` (the scoped root).
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

## Audit trail

Every link write appends one JSON-line entry to
`$XDG_STATE_HOME/hapi/audit.jsonl` (or
`$HOME/.local/state/hapi/audit.jsonl` when `XDG_STATE_HOME` is
unset). Format and field semantics are locked in
[ADR 0002](../adr/0002-audit-trail-format.md). The trail is the
input to `hapi unlink` (M3) and `hapi rollback` (M3).

The trail is append-only — `hapi link` never edits or truncates
existing entries. A re-run that does nothing writes no new
lines.

## Exit codes

| code | meaning                                                          |
|------|------------------------------------------------------------------|
| 0    | links applied (or already up-to-date)                            |
| 1    | manifest parse failure, conflict without `--force`, IO error,    |
|      | audit-trail write failure, or `--force` over a directory         |
| 2    | bad usage (missing argument)                                     |

## See also

- [`inspect.md`](inspect.md) — preview what `link` would do, no
  filesystem side effects.
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md)
- [ADR 0003 — Symlink target shape](../adr/0003-symlink-target-shape.md)
