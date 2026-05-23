# `hapi rollback`

Reverse the audit trail to the most recent rollback marker (or
to the start of the trail, when no marker exists). Each reversal
is conditional — running rollback twice produces the same end
state as running it once.

## Synopsis

```sh
hapi rollback
```

No arguments. `hapi rollback --to <marker>` and
`hapi rollback --steps N` are reserved as a post-v1.0 surface
refinement — see the
[roadmap](../development/roadmap.md) — but the v1.0 contract is
this no-arg form.

## What it does

1. Reads `$XDG_STATE_HOME/hapi/audit.jsonl`.
2. Walks **backward** from EOF, stopping at the most recent
   `op:rollback-marker` entry (or at index 0 if none).
3. For each entry in that window, in reverse-creation order:
   - **`op:link` entry**: if the symlink at `abs_target` still
     matches what hapi would have written, `unlink(2)` it and
     append an `op:unlink` audit entry.
   - **`op:unlink` entry**: if `abs_target` is currently
     absent, recreate the symlink and append an `op:link`
     entry.
   - Anything else (user-mutated state) → silently skipped.

The "only act if state still matches" gate is what makes
rollback safe and idempotent. A second run sees a state that
already matches the rollback's intent and does nothing.

## Example: clean rollback of a single link

```sh
$ hapi link docs/examples/dotfiles-zsh
linked 3 / 3 (0 already up-to-date)

$ hapi rollback
  - ~/.config/zsh  (was link)
  - ~/.zshenv  (was link)
  - ~/.zshrc  (was link)
rolled back 3 / 3 entries
```

Same end state as `hapi unlink dotfiles-zsh` in this trivial
case — the difference matters when the trail contains multiple
packages or interleaved ops:

## Example: rollback through link → unlink → link

```sh
$ hapi link  pkgA           # 3 link entries
$ hapi unlink pkgA           # 3 unlink entries
$ hapi link  pkgA           # 3 link entries
$ hapi rollback              # 9 reversals
rolled back 9 / 9 entries
```

Final state: clean. Rollback walks every entry, reversing each
conditionally — and the cumulative effect is "undo to the
beginning of the trail."

## Rollback markers

A `rollback-marker` entry is a no-op for the trail's link/unlink
state but acts as a stopping boundary for `rollback`:

```
{"ts":"...","op":"rollback-marker"}
```

Markers are appended by [`hapi checkpoint`](checkpoint.md).
When present, `hapi rollback` reverses only entries after the
most recent marker, leaving everything before it untouched.

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | rollback completed (any per-entry skips were silent)          |
| 1    | at least one entry hit an IO error mid-reversal               |

## See also

- [`link.md`](link.md) / [`unlink.md`](unlink.md) — the ops
  rollback reverses.
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md) — the
  rollback-marker entry shape and the v1.0 frozen guarantee.
