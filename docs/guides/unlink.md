# `hapi unlink`

Remove the symlinks created by prior `link` operations for a
package. Trail-driven, not manifest-driven: hapi only removes
what the audit trail says hapi created.

## Synopsis

```sh
hapi unlink <package-name>
```

`<package-name>` is the `package.name` from the manifest, not
a filesystem path. There's no per-package directory registry
beyond the audit trail itself; the name is the lookup key.

Given the path `link` and `sync` take, it says which name to use and
exits 1, removing nothing (1.7.1, F-106; through 1.7.0 it said `no live
links` and exited 0):

```
$ hapi unlink dots/zsh
hapi: unlink takes a package's name, not its path: `dots/zsh` holds package `zsh`
  run: hapi unlink zsh
```

## What it does

1. Reads `$XDG_STATE_HOME/hapi/audit.jsonl`.
2. Builds the set of "live" links for the named package: every
   `op:link` entry that hasn't been superseded by a later
   `op:unlink` for the same target. Since 1.7.1 another package's
   later `op:link` or `op:adopt` of the target also ends it
   (`link --force` of package B over A's link): through 1.7.0 A's
   entry stayed live, and A's `unlink` refused it as user-mutated on
   every run (F-079).
3. For each live entry, probes the on-disk target:
   - If it's a symlink pointing to the value `hapi link` would
     have written → `unlink(2)` it, append an `op:unlink`
     audit entry. Either shape counts (1.6.0): the relative text,
     or the source's absolute path, which `link --absolute` writes.
     Removing an absolute one records `"shape":"absolute"`, so
     `rollback` re-creates it absolute.
   - If nothing is there, print `= <target>  (already absent)` and
     retire the entry: an `op:unlink` carrying `"absent":"1"`, which
     `rollback` never reverses, so a link you deleted by hand stays
     deleted. Through 1.7.0 it printed a removal, wrote nothing, and
     the entry stayed live: every later `unlink` "removed" it again
     and `list` counted it forever (F-078).
   - If the symlink points elsewhere, or there's a regular
     file / directory — **refuse for that entry,
     keep going with the rest**.
4. Removes the directories hapi made for the links it just removed,
   when they are now empty (below).
5. Returns exit code 0 if every live entry was either cleanly
   removed or already absent; 1 if any refusal happened.

With no live links for the name it prints ``no live links for `<name>`
in the audit trail`` and exits 0. If some of the package's links came
from `hapi adopt`, it adds where they went (1.7.1): adopted links are
`rollback`'s to reverse ([ADR 0004](../adr/0004-adopt-op-semantics.md)),
though `list` counts them:

```
no live links for `zsh` in the audit trail
  (1 of its links came from `hapi adopt`; `hapi rollback` reverses an adopt)
```

The safety rule is non-negotiable per CLAUDE.md and the v1.0
contract: hapi never deletes a user file, and never deletes a
user-created symlink. The trail tells us exactly what we
created and what it pointed to; if the current state doesn't
match, the user (or some other tool) intervened, and that's
out of hapi's lane.

## Directories hapi made

Since 1.4.0 a link's trail entry records the outermost directory its
creation made (`created_dir`, see [`link.md`](link.md#directories-it-makes)).
When `unlink` removes that link, it also removes those directories:

```
$ hapi unlink nvim
  - /home/me/.config/nvim/lua/init.lua
  - /home/me/.config/nvim/lua/  (a directory hapi made)
  - /home/me/.config/nvim/  (a directory hapi made)
unlinked 1 / 1
```

- **Only what hapi made.** `~/.config` was there before, so it stays, empty
  or not. Nothing above `created_dir` is touched.
- **Only when empty.** It works deepest first and stops at the first
  directory that still holds something, such as a file you put there,
  which keeps that directory and everything above it.
- **Only with proof.** It acts only for a link this run removed itself. A
  link you already deleted, a `--dry-run`, or a link made before 1.4.0
  (no record) leaves its directories alone.
- **Never through a symlink.** If one of those directories has since been
  replaced by a symlink, none of them is removed (F-062).
- **Shared directories go when the run empties them.** A directory one row
  made and another row reused goes when the run removes both, in whatever
  order.
- **Each link's directories go right after it** (1.7.1, F-116), once its
  `op:unlink` is recorded, and a pass after the last link takes the shared
  ones. Through 1.7.0 they all went at the end, so a run stopped partway
  (Ctrl-C) left them, and no later verb removed them. `sync --prune` does
  the same.

One gap is accepted: if the row that made a directory is removed in one
run (by `sync --prune`, say) while another row still uses it, the
directory stays, and it stays when the second row is removed later,
because that row's entry never claimed it. Remove it by hand, or remove
the package as a whole.

## Example

```sh
$ hapi link docs/examples/dotfiles-zsh
  + ~/.zshrc -> Repos/hapi/docs/examples/dotfiles-zsh/zshrc
  + ~/.zshenv -> Repos/hapi/docs/examples/dotfiles-zsh/zshenv
  + ~/.config/zsh -> ../Repos/hapi/docs/examples/dotfiles-zsh/config/zsh
linked 3 / 3 (0 already up-to-date)

$ hapi unlink dotfiles-zsh
  - ~/.zshrc
  - ~/.zshenv
  - ~/.config/zsh
unlinked 3 / 3
```

The audit trail after both runs contains 6 entries (3 link +
3 unlink) — both ops are recorded, which is what makes
`hapi rollback` reversible later.

## Already-absent example

```sh
$ rm ~/.zshrc                          # the link deleted by hand
$ hapi unlink dotfiles-zsh
  = ~/.zshrc  (already absent)
  - ~/.zshenv
  - ~/.config/zsh
unlinked 2 / 3 (1 already absent)
```

Exit code 0. The trail now records all three as gone, `~/.zshrc`
with `"absent":"1"`, so a second `unlink` finds no live links and a
`rollback` re-creates only the two this run removed.

## Refusal example

```sh
$ ln -sf /tmp/elsewhere ~/.zshrc       # user mutates a hapi link
$ hapi unlink dotfiles-zsh
  - ~/.zshenv
  - ~/.config/zsh
  ! ~/.zshrc  (user-mutated; skipped)
unlinked 2 / 3 (1 refused)
```

Exit code 1. The `.zshrc` mutation is preserved untouched. The
other two links (untouched since `hapi link` wrote them) are
removed normally.

## Exit codes

| code | meaning                                                          |
|------|------------------------------------------------------------------|
| 0    | every live entry removed (or already absent)                     |
| 1    | at least one entry refused (user-mutated) or IO error, or the trail refused an entry (below), or a package path given for its name |
| 2    | bad usage (missing or empty package name)                        |

## When the trail refuses an entry

`unlink` proves the trail is writable before it removes anything (F-055),
but a write can still fail after that (a full disk, a file-size limit).
Since 1.3.0 the link whose entry could not be written is **put back**,
and the run stops there:

```
hapi: audit-trail write failed for /home/me/.zshenv
  it was taken back; this run left nothing unrecorded
  nothing after it was touched
```

Through 1.2.1 the link stayed removed while the trail still called it
live, and the run reported `unlinked 0 / N` over the links it had deleted
(F-061). Fix the trail's disk and re-run.

## See also

- [`link.md`](link.md) — the operation `unlink` reverses.
- [`rollback.md`](rollback.md) — same audit-trail consumer, but
  reverses every recent op (not scoped to one package).
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md)
