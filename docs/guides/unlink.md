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

## What it does

1. Reads `$XDG_STATE_HOME/hapi/audit.jsonl`.
2. Builds the set of "live" links for the named package: every
   `op:link` entry that hasn't been superseded by a later
   `op:unlink` for the same target.
3. For each live entry, probes the on-disk target:
   - If it's a symlink pointing to the value `hapi link` would
     have written → `unlink(2)` it, append an `op:unlink`
     audit entry.
   - If the symlink points elsewhere, or there's a regular
     file / directory / nothing — **refuse for that entry,
     keep going with the rest**.
4. Removes the directories hapi made for the links it just removed,
   when they are now empty (below).
5. Returns exit code 0 if every live entry was either cleanly
   removed or already absent; 1 if any refusal happened.

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

One gap is accepted: if the row that made a directory is removed in one
run (by `sync --prune`, say) while another row still uses it, the
directory stays, and it stays when the second row is removed later,
because that row's entry never claimed it. Remove it by hand, or remove
the package as a whole.

## Example

```sh
$ hapi link docs/examples/dotfiles-zsh
  + ~/.zshrc -> ../Repos/hapi/docs/examples/dotfiles-zsh/zshrc
  + ~/.zshenv -> ../Repos/hapi/docs/examples/dotfiles-zsh/zshenv
  + ~/.config/zsh -> ../../Repos/hapi/docs/examples/dotfiles-zsh/config/zsh
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
| 1    | at least one entry refused (user-mutated) or IO error, or the trail refused an entry (below) |
| 2    | bad usage (missing package name)                                 |

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
