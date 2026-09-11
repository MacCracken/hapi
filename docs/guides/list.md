# `hapi list`

List the packages tracked in the audit trail, with the count
of currently-live symlinks for each. Read-only: walks the
trail, no filesystem touches beyond reading it.

## Synopsis

```sh
hapi list
```

No arguments.

## What it does

1. Reads `$XDG_STATE_HOME/hapi/audit.jsonl`.
2. Builds the unique set of package names that ever appeared
   in the trail (first-seen order).
3. Builds **one global per-target owner map** over the whole
   trail: `link` / `adopt` claim a target for that entry's
   package, **displacing** whatever package held it before;
   `unlink` / `unadopt` release it, but only when the remover
   is the package that currently owns it.
4. Prints one row per package with the live count, plus a
   scope-root header line.

A package whose entries are all eventually `unlink`-ed shows
`0 live links` but still appears — the trail says hapi *did*
manage it at some point, which is real history.

The owner map is what makes a `--force` takeover add up. When package B
takes a target A owned, A's claim is retired, so the two packages'
counts sum to the number of symlinks actually on disk. Before 1.0.9
both packages claimed it and the total overcounted.

## Example

```sh
$ hapi link docs/examples/dotfiles-zsh
linked 3 / 3 (0 already up-to-date)

$ hapi list
scope: /home/macro
  dotfiles-zsh  3 live links
```

After unlinking:

```sh
$ hapi unlink dotfiles-zsh
$ hapi list
scope: /home/macro
  dotfiles-zsh  0 live links
```

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | trail walked (empty trail is not an error)                    |
| 1    | `$HOME` unset, or audit-read failure                          |

## See also

- [`status.md`](status.md) — per-package drift detail.
- [`link.md`](link.md) / [`adopt.md`](adopt.md) — the ops that
  populate the trail.
