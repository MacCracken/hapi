# 0004 — `hapi adopt` semantics

**Status**: Accepted — **Frozen at v1.0.0 (2026-05-23)**
**Date**: 2026-05-20

> Frozen: two positional args, single atomic `op:adopt` audit
> entry, append-`[[link]]`-row-before-`---`-body, three-step
> conditional rollback. Post-v1.0 nested-layout adoption
> (`--source <path>`) is reserved per the roadmap's *Out of
> scope* list.

## Context

M4's `hapi adopt` is the inverse of starting a dotfile package
from scratch: the user has an existing file (`~/.zshrc`, say)
and wants hapi to start managing it. The roadmap pins three
properties:

> - `hapi adopt <path>` — move an existing file into a package,
>   create the symlink back
> - Refuses if the target is already a symlink (no automatic
>   re-adoption; user must `unlink` first explicitly)
> - Audit-trail entry captures the move + the new link

The verb sits at the intersection of three existing surfaces:
- The manifest schema (ADR 0001) — adopt has to *grow* the
  manifest, which no other verb does today.
- The audit trail format (ADR 0002) — adopt is a new op type;
  the format must accept it without a `Breaking` (additive
  growth is the explicit ADR guarantee).
- Rollback (M3) — reversing adopt has to be both safe (skip
  on user-mutated state, like link/unlink rollback) and
  *complete* (move the file back, take the manifest row out)
  so the trail's invariant — "rollback returns the world to
  the pre-trail state" — still holds.

Constraints in play:

- The manifest is user-authored. Hapi edits it as little as
  possible, in the most predictable way possible — no
  reformatting, no comment removal, no field reordering.
- An adopt has to be a *single atomic step* from the trail's
  point of view. Otherwise a crash mid-adopt leaves a half-
  state that the next `hapi link` or `rollback` can't reason
  about cleanly.
- The audit field set should stay the same across ops where
  reasonable, so future readers / canonicalizers don't have
  to switch on `op` for basic field extraction.

## Decision

### CLI surface

```
hapi adopt <file-in-scope-root> <package-dir>
```

Two positional args. No `--into` flag; the destination is
mandatory and positional, mirroring `mv(1)`. The first arg is
a path relative to the scope root (`$HOME` by default); the
second is the package directory.

### Source-path naming convention

The source path inside the package is `basename(target)` with
a single leading `.` stripped:

| target            | source-in-package |
|-------------------|-------------------|
| `.zshrc`          | `zshrc`           |
| `.config/zsh/x`   | `x`               |
| `bin/script`      | `script`          |

The leading-dot strip is conventional for dotfile packages:
`hapi inspect dotfiles-zsh` reads better with `zshrc` than
`.zshrc` on the source side.

For now, adopt always places the source at the package root.
Per-row directory-preservation (e.g. adopting `~/.config/zsh/x`
into `dotfiles-zsh/config/zsh/x`) is out of scope for M4 — the
user can adopt the directory at the higher level, or pre-create
the target directory layout and adopt into it via a future
`--source <path>` flag (post-v1.0).

### Atomic adopt entry

Adopt records as a **single** audit entry with `op:"adopt"`
and the same field set as `link` / `unlink`:

```
{"ts":"...","op":"adopt","pkg":"dotfiles-zsh","pkg_version":"1.0.0",
 "manifest_hash":"sha1:<post-edit-hash>","source":"zshrc",
 "target":".zshrc","abs_source":"/home/user/dotfiles/dotfiles-zsh/zshrc",
 "abs_target":"/home/user/.zshrc"}
```

The hash is the *post-edit* manifest hash (after the
`[[link]]` row is appended). That keeps the field's meaning
consistent — `manifest_hash` always describes the manifest
state as of the moment the op was recorded.

Splitting adopt into two entries (`op:move` + `op:link`) was
considered and rejected — it splits the rollback story across
two entries, opens a crash window between them, and complicates
the `unlink`-after-`adopt` semantics. One atomic entry is the
simpler contract.

### Manifest edit semantics

Adopt appends one `[[link]]` row to the package's `hapi.cyml`.
Insertion point:

- If the manifest has a `---` markdown-body separator, the new
  row is inserted **immediately before** the separator, with a
  blank line above it for readability.
- If the manifest has no body separator, the new row is
  appended at EOF with a leading blank line.

The rest of the file is preserved byte-for-byte. We don't
re-canonicalize, don't strip comments, don't reorder anything.
The user's manifest formatting stays intact.

Writes are atomic via the `write-tmp-then-rename` pattern:
write the new content to `hapi.cyml.tmp` in the same directory,
fsync the file, then `rename(2)` over the original. If hapi
crashes mid-write, the original is intact and the `.tmp` file
is the recovery breadcrumb (a future `hapi check` could surface
it).

### Reversal (rollback)

`hapi rollback` over an `op:adopt` entry reverses **three**
things, in order, each conditionally:

1. **Symlink check + remove**: probe `abs_target`. If it's a
   symlink pointing to the value `hapi adopt` would have
   written, `unlink(2)` it. If it's anything else, skip the
   whole reversal — user mutated something, don't touch.
2. **File move back**: probe `abs_source`. If it's a regular
   file (still in the package), `rename(2)` it back to
   `abs_target`. If it's absent or has been replaced, skip.
3. **Manifest row removal**: if the manifest still has a row
   with matching `source` and `target`, remove it. If the
   row has been edited (user changed source or target) or
   removed, skip the edit but log to stderr.

Each step's "skip" is silent in normal operation, surfaced via
the rollback summary line. The full safety contract: rollback
of adopt never destroys user state; if any step's precondition
fails, the rest of the reversal is abandoned and the trail
moves on to the next entry.

The rollback writes one audit entry per *successful* reversal
step, just like `op:link` rollback writes an `op:unlink` entry.
For adopt, the reverse-entry op is `unadopt` — a synthetic op
that records the inverse for forward replay. (We don't reuse
`op:unlink` here because `unlink` is package-scoped and would
confuse the `hapi unlink <pkg>` consumer.)

### `hapi unlink` and adopt entries

`hapi unlink <pkg>` stays scoped to `op:link` entries. It does
**not** reverse adopts. The user who wants to undo an adopt
either:

- Runs `hapi rollback` (which handles the full reversal), or
- Manually `mv`s the file back and edits the manifest.

Mixing adopt-reversal into `unlink` would surprise the user
(they expect `unlink` to be cheap and symmetrical with `link`)
and force `unlink` to grow filesystem-write semantics it
doesn't have today. The two-verb separation is cleaner.

## Consequences

**Positive**:

- One atomic audit entry per adopt — the rollback story stays
  intact: every entry is independently reversible.
- Manifest stays user-authored. Hapi edits exactly what it
  needs to and nothing else.
- `op:adopt` is additive; existing readers (M3's audit_reader,
  `hapi unlink`) ignore unknown ops, so 0.4.x trails written
  before this ship can be read by 0.5.0 without issue.
- The CLI is mv-shaped, which is the right muscle memory for
  the operation.

**Negative**:

- Manifest editing is new code we own forever. Bugs here can
  corrupt user-authored config. The append-only insertion +
  atomic rename pattern minimizes the blast radius but
  doesn't eliminate it. M7 hardening pass should re-audit the
  manifest writer specifically.
- The basename + strip-leading-dot convention assumes a flat
  layout inside the package. Users with nested adopt needs
  will want a `--source <path>` knob — punt to post-v1.0.
- Rollback of adopt is a three-step conditional reversal —
  more state to check, more ways the "current state matches"
  gate can let one step through and block another. Documented
  in the guide; tested with full-reverse and partial-mutation
  cases.

**Neutral**:

- The synthetic `op:unadopt` audit entry for rollback-reversal
  is the third op in the v1.0 audit format alongside `link` /
  `unlink` / `rollback-marker` / `adopt`. Documented additively
  in ADR 0002's "Replay semantics" section via a future patch
  during M7 closeout.

## Alternatives considered

- **`hapi adopt <file>` with package auto-detected** — rejected.
  How would hapi guess the package? By directory layout? By a
  default-package config? Either way, the user does less
  typing but the surprise budget gets eaten. Two explicit
  positionals win.
- **Split into `op:move` + `op:link` entries** — rejected for
  the atomicity reason above. A crash between the two would
  leave the trail half-written.
- **Don't edit the manifest** — rejected. Without the row, a
  subsequent `hapi link <pkg>` won't recreate the symlink, so
  the adopted file would silently fall out of management on
  re-link. Closes-the-loop matters.
- **Edit the manifest in place via `O_TRUNC` + write** —
  rejected. A crash mid-write leaves a corrupt manifest. The
  tmp-then-rename pattern is one extra inode but zero corrupt
  states.
- **Don't reverse adopt in rollback** — rejected. We'd ship a
  v0.5.0 where the trail has entries `rollback` doesn't know
  what to do with, and the "rollback returns to the pre-trail
  state" guarantee silently breaks for any user who adopts.
- **Always require absolute paths for adopt args** — rejected.
  `hapi adopt .zshrc dotfiles-zsh` reads naturally from the
  scope root. We resolve relatively per the standard CLI
  convention (cwd-relative for the package dir, scope-root-
  relative for the file).
