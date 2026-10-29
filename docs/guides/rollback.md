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

The "only act if state still matches" gate is what makes rollback
**safe**: it never touches state a user or another tool changed since
hapi wrote it. A second run sees a state that
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

Markers are appended by [`hapi checkpoint`](checkpoint.md), and —
since 1.1.1 — by `hapi rollback` itself, at the end of a run that
reversed at least one entry without an error. When present,
`hapi rollback` reverses only entries after the most recent marker,
leaving everything before it untouched.

The closing marker is what makes a second run a no-op. Without it the
next run's window included the entries this run had just appended,
so every run re-reversed the last one — the same end state, but 2, 4,
8 … reversals and a trail that doubled each time (F-056). A run that
hit an error writes no marker, so it can be re-run once the cause is
fixed.

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | rollback completed (any per-entry skips were silent)          |
| 1    | at least one entry hit an IO error mid-reversal; an adopt was reverted but its manifest row could not be removed (the reason is printed); the closing marker could not be written; the trail is not writable (nothing was changed); or the trail refused a reversal's entry (below) |

### When the trail refuses an entry

A write can fail after the pre-flight passed (a full disk, a file-size
limit). Since 1.3.0, a reversal whose entry could not be written is
**taken back** and the run stops there: a removed link is put back, and a
re-created one is removed again (F-061). Through 1.2.1 the change stayed
on disk, unrecorded, reported only as an IO error. The one exception is
an `adopt` reversal, which is three steps (the link, the file, the
manifest row) and is not taken back. Instead it is reported exactly: the
file is back and its row removed, but the trail still says adopted.

## See also

- [`link.md`](link.md) / [`unlink.md`](unlink.md) — the ops
  rollback reverses.
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md) — the
  rollback-marker entry shape and the v1.0 frozen guarantee.
