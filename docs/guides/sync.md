# `hapi sync`

Re-apply manifests idempotently. State that already matches the manifest
is a no-op (no audit writes); missing links are created (one audit entry
each); user-mutated state is refused (same conflict semantics as
`hapi link`). Since 1.3.0, `sync` can also find every package itself, and
remove the links of rows that have left a manifest.

## Synopsis

```sh
hapi sync <package-dir|hapi.cyml> [--prune [--force]]
hapi sync [--prune [--force]]           # every package under HAPI_PACKAGE_ROOTS
```

`--dry-run`, `--root <path>` and `--backup-to <dir>` are accepted as
before (see *Overwriting existing files* for why `--backup-to` does
nothing here). Since 1.6.0 `--absolute` gives the links a sync creates
absolute targets, as [`link --absolute`](link.md#absolute-targets----absolute)
does; a link of either shape is up to date, so a plain `hapi sync` leaves
absolute links alone.

## What it does

For one package, `hapi sync <pkg>` is `hapi link <pkg>` *without*
`--force`. The verbs differ in *intent*:

- `hapi link` — "create these now" (first apply, or new
  links added to a manifest)
- `hapi sync` — "make state match manifest" (idempotent
  reconciliation)

Both produce the same audit-trail and filesystem effects. That includes
recording a link already in place that the trail does not record for
the package (1.7.1, F-079): `~ <target>  (already linked; now
recorded)`, once. See [`link.md`](link.md#links-the-trail-does-not-record).
On a conflict, sync's refusal points at `link` rather than at a flag it
does not take:

```
hapi: refusing to link `zsh` — 1 conflict (sync never overwrites; `hapi link --force` on the package does):
  /home/me/.zshrc  (existing regular file)
```

Through 1.7.0 it said `rerun with --force to override`, and
`hapi sync --force` is exit 2 (F-097).

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

## Every package: `hapi sync` with no package

Point `HAPI_PACKAGE_ROOTS` at the directories that hold your packages,
colon-separated and absolute, and `hapi sync` syncs each of them. This is
the recovery command: after a drive move, a wiped trail or a fresh
machine, one command re-establishes everything.

```sh
$ export HAPI_PACKAGE_ROOTS=$HOME/Repos/dotfiles
$ hapi sync
syncing /home/me/Repos/dotfiles/git...
  + /home/me/.gitconfig -> Repos/dotfiles/git/gitconfig
linked 1 / 1 (0 already up-to-date)
syncing /home/me/Repos/dotfiles/zsh...
hapi: refusing to link `zsh` — 1 conflict (sync never overwrites; `hapi link --force` on the package does):
  /home/me/.zshrc  (existing regular file)
synced 1 / 2 packages
```

What counts as a package:

- **One level deep.** `<root>/<name>` is a package when it is a directory
  holding a `hapi.cyml` that is a regular file. Directories without a
  manifest (`scripts/`, say) are ignored, and so are names starting with
  `.` (`.git`).
- **No symlinks are followed.** A symlinked package directory, or a
  symlinked `hapi.cyml`, is named in a note and skipped. Sync it by path
  if you meant it. This is what keeps a root an exact bound on what gets
  linked.
- **A package directory hapi cannot search** is synced anyway, and fails
  on its own terms, so the run exits 1. Through 1.7.0 it was skipped
  with a wrong reason, and the run reported success (F-097).
- **Names must be unique.** Two packages with the same `name` are both
  refused, because the audit trail keys links on the name and could not
  tell them apart.
- **A root given twice is one root**, in either spelling (`/r` and
  `/r/`, or a symlink to it). Through 1.7.0 every package in it was its
  own twin, and both were refused (1.7.1, F-110).

The run continues past a package that fails, and exits 1 at the end if
any did, with `synced N / M packages` saying how many made it. Packages
sync in root order, and by name within each root.

Afterwards, `sync` checks the trail. A package it holds live links for,
from a directory that no root holds, is named:

```
hapi: note: the trail has live links for `kitty` from /opt/kitty-cfg,
  which no package root holds; not synced
```

It is not synced, because hapi cannot tell which scope it was linked into.
Add its directory's parent to `HAPI_PACKAGE_ROOTS`, or sync it by path.
Since 1.7.1 the directories are compared where they resolve (F-113): a
package linked as `~/alias/kitty`, with `alias` a symlink to a root, is
held by that root and gets no note.

`HAPI_PACKAGE_ROOTS` says where packages are *read* from; it grants
nothing. Every target is still decided by the scope: `$HOME`, or
`--root`, with [ADR 0005](../adr/0005-capability-bounded-roots.md)'s
grant. So **one root holds packages for one scope.** Keep `--root`
packages under a root of their own, and sync that root with its `--root`.

| Situation | Result |
|---|---|
| `HAPI_PACKAGE_ROOTS` unset or empty | exit 2, naming the variable |
| an entry that is not an absolute path | exit 2 |
| a root that cannot be listed | that root is reported; exit 1 |
| no packages under any root | exit 1 |

## Dropping a row: `--prune`

`sync` only ever creates. When you delete a `[[link]]` row from a
manifest, the link it made stays. `--prune` removes it:

```sh
$ $EDITOR ~/Repos/dotfiles/zsh/hapi.cyml      # drop the figlet row

$ hapi sync ~/Repos/dotfiles/zsh --prune
syncing /home/me/Repos/dotfiles/zsh...
  - /home/me/.figlet/fonts/modular.flf
linked 0 / 5 (5 already up-to-date)
pruned 1 (no longer in the manifest)
```

That is one `op:unlink` in the trail, the entry `hapi unlink` writes, and
the five kept links are never touched. Since 1.4.0, a directory hapi made
for a pruned link goes with it when nothing else is left in it, as with
[`unlink`](unlink.md#directories-hapi-made). That happens before the creates,
so a row moved within a directory only it used re-makes the directory and
owns it. Before 1.3.0 the same change took
an `unlink` / edit / `link` rotation: 11 trail entries, and five wanted
links briefly gone. `rollback` reverses a prune exactly as it reverses an
`unlink`.

What `--prune` will remove — all of these must hold:

- **A live `op:link` of this package**, under its manifest's name. Links
  that `adopt` made are rollback's to reverse
  ([ADR 0004](../adr/0004-adopt-op-semantics.md)).
- **From this package directory**, so a second package directory that
  happens to share the name is left alone.
- **In this run's scope.** The entry's target must be this run's scope
  plus its row's target, so a run under `$HOME` does not prune what a
  `--root ~/sub` run made. Through 1.7.0 any target inside the scope
  counted, and such a prune removed rows still in the manifest (1.7.1,
  F-080).
- **Whose row is gone**, i.e. no row still in the manifest targets it.
  Rows are compared at their normalized and physical places, so
  re-spelling a kept row (`.a` as `./.a`) does not prune its link
  (1.7.1, F-080).
- **Still the link hapi wrote.** If the target is now a file, a directory
  or a symlink pointing elsewhere, the package is refused and nothing is
  removed. `--force` does not change that; hapi removes only what it
  created.

A dropped row whose link is already gone prints `= <target>  (already
absent)` and is retired, as [`unlink`](unlink.md) retires one (1.7.1,
F-078). It is not counted as pruned.

### The limit, and `--force`

An emptied or truncated manifest should not take a package's links with
it in one keystroke. So `--prune` refuses when it would remove **more than
half** of the package's live links. Since 1.7.1 only links still on disk
count: one already gone is not at stake, and counting it let a truncated
manifest past the limit (F-080).

```
hapi: refusing to prune `zsh` — 6 of its 6 live links left the manifest, more than half
  (rerun with --prune --force to remove them):
  /home/me/.zshrc
  ...
```

Dropping 1 of 6 goes through, and so does exactly half. To go past the
limit on purpose, add `--force`:

```sh
hapi sync ~/Repos/dotfiles/zsh --prune --force
```

**On `sync`, `--force` lifts that limit and nothing else.** `sync` still
never overwrites a conflict (that is `hapi link --force`), and
`hapi sync --force` without `--prune` is exit 2.

The whole package is planned before anything is written. A conflict, a
missing source, a refused prune or an unwritable trail stops the package
with nothing changed. Then the removals run, then the creates. Since
1.7.1 each create is checked again first, because a removal can change
where a row leads. A row whose place moved stops the run (F-080). If a
removal fails partway, the directories of the links already removed
still go (F-110). `--dry-run` shows both and writes nothing.

## Exit codes

| code | meaning |
|------|---------|
| 0    | state matches the manifest(s) |
| 1    | a conflict (use `hapi link --force` to override), a refused prune, a parse error, or an IO failure; with no package, any package that failed (one hapi cannot search included), a root that could not be listed, or no packages found |
| 2    | bad usage: `--force` without `--prune`, an empty argument, or no package with `HAPI_PACKAGE_ROOTS` unset or relative |

## Overwriting existing files

`sync` never overwrites. A row whose target is an existing regular file,
or a symlink pointing somewhere else, is a conflict and `sync` refuses
with exit 1.

Since `sync` never overwrites, there is no destructive step to snapshot,
and **`--backup-to` has nothing to do on this verb**. It is accepted (the
command surface is frozen) and inert. Prune removes only symlinks hapi
made, whose content lives in the package, so it has nothing to snapshot
either. Earlier versions of this guide claimed `sync` inherited `--force`
and with it `--backup-to`; that was never true, and the correction is
recorded as F-026 in
[`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md).

To overwrite deliberately, use `link`:

```sh
hapi link --force --backup-to ~/.local/share/hapi/backups pkg
```

See [`link.md`](link.md) and [`backup-to.md`](backup-to.md).

## See also

- [ADR 0006](../adr/0006-sync-package-roots-and-prune.md) — why the scan
  and prune work this way, and what was weighed instead.
- [`link.md`](link.md) — sync's engine; the `--force` flag for
  override semantics.
- [`unlink.md`](unlink.md) — removing a whole package's links.
- [`status.md`](status.md) — detect drift before syncing.
- [`backup-to.md`](backup-to.md) — opt-in pre-`--force` snapshots.
