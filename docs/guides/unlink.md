# `hapi unlink`

Remove the symlinks created by prior `link` operations for a
package. Trail-driven, not manifest-driven: hapi only removes
what the audit trail says hapi created.

## Synopsis

```sh
hapi unlink <package-name>
```

`<package-name>` is the `package.name` from the manifest, not
a filesystem path. (At v0.4.0 there's no per-package directory
registry beyond the audit trail itself; the name is the lookup
key.)

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
4. Returns exit code 0 if every live entry was either cleanly
   removed or already absent; 1 if any refusal happened.

The safety rule is non-negotiable per CLAUDE.md and the v1.0
contract: hapi never deletes a user file, and never deletes a
user-created symlink. The trail tells us exactly what we
created and what it pointed to; if the current state doesn't
match, the user (or some other tool) intervened, and that's
out of hapi's lane.

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
| 1    | at least one entry refused (user-mutated) or IO error            |
| 2    | bad usage (missing package name)                                 |

## See also

- [`link.md`](link.md) — the operation `unlink` reverses.
- [`rollback.md`](rollback.md) — same audit-trail consumer, but
  reverses every recent op (not scoped to one package).
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md)
