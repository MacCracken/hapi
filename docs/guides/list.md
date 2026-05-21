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
3. For each package, walks the trail with a per-target
   last-write-wins reduction: `link` / `adopt` mark a target
   live, `unlink` / `unadopt` clear it.
4. Prints one row per package with the live count, plus a
   scope-root header line.

A package whose entries are all eventually `unlink`-ed shows
`0 live links` but still appears — the trail says hapi *did*
manage it at some point, which is real history.

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
