# `hapi rollback`

Reverse the audit trail to the most recent rollback marker (or
to the start of the trail, when no marker exists). Each reversal
is conditional — running rollback twice produces the same end
state as running it once. Since 1.5.0 it can reach further back:
to a labelled checkpoint, or a number of checkpoints back.

## Synopsis

```sh
hapi rollback [--dry-run]                 # to the most recent marker
hapi rollback --to <label> [--dry-run]    # to the checkpoint named <label>
hapi rollback --steps N [--dry-run]       # N checkpoint windows back
```

No positional argument. `--to` and `--steps` are additive (1.5.0); the
no-arg form is the v1.0 contract and behaves exactly as before.

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

## Directories

Reversing a link also removes the directories its creation made, when
they are empty, exactly as [`unlink`](unlink.md#directories-hapi-made)
does. Rollback goes newest first, so a directory one link made is
removed after any later link that reused it. Reversing an `unlink`
re-creates the link, making its directories again, and the replayed entry
records them.

## Link shape

Reversing an `unlink` re-creates the link in the shape it had: relative,
or absolute when the `op:unlink` entry says `"shape":"absolute"` (1.6.0).
Rollback takes no `--absolute`; the trail decides. Reversing a link
removes it in either shape, as [`unlink`](unlink.md) does.

## Going further back: `--to` and `--steps`

The no-arg form is one undo: back to the last marker, after which a
second run finds nothing. Two flags reach past that. They take the same
reversals and print the same lines, preceded by one naming where the run
goes.

### `--to <label>`

Name a checkpoint when you make it, and roll back to it by that name:

```sh
$ hapi checkpoint --label pre-deploy
checkpoint `pre-deploy` written

$ hapi link sway-pkg                # ... and anything else
$ hapi adopt ~/.config/foot foot-pkg

$ hapi rollback --to pre-deploy
rolling back to checkpoint `pre-deploy` on line 41 (2026-10-28T12:00:00Z)
  ~ /home/me/.config/foot  (was adopt; file restored)
  - /home/me/.config/sway  (was link)
rolled back 2 / 2 entries
```

Everything after the checkpoint is reversed, past any other checkpoints
in between. This is the form for scripts: a label is untouched by
whatever checkpoints anyone else adds.

- **The most recent marker with the label** is the one. A script that
  reuses `pre-deploy` on every run gets its own latest checkpoint.
- **A label is 1 to 64 characters** from `A-Z a-z 0-9 . _ -`, and does not
  start with `-`. Anything else is exit 2.
- **Unknown label:** exit 1, nothing changed.
- **Already there**, or the checkpoint is inside a range an earlier
  rollback already went past: `nothing to roll back`, exit 0.

### `--steps N`

Undo the N most recent checkpoint windows. A window runs from one
marker to the next, so `--steps 1` is the work since the last checkpoint,
and `--steps 2` the work since the one before:

```sh
$ hapi link zsh-pkg
$ hapi checkpoint
$ hapi link nvim-pkg
$ hapi checkpoint
$ hapi link sway-pkg

$ hapi rollback --steps 1          # sway-pkg
$ hapi rollback --steps 1          # then nvim-pkg: one more step back
$ hapi rollback --steps 1          # then zsh-pkg, back to the start of the trail
```

That repeat is the point: each run undoes one more step. It works because
rollback's closing marker records where its range began (see *Rollback
markers*), and a later `--steps` or `--to` steps over everything that run
already undid.

- **Only windows still in effect count.** Back-to-back checkpoints are
  one step, and a window an earlier rollback emptied is none.
- **More steps than the trail holds:** exit 1, nothing changed, and the
  message says how many there are.
- **Nothing left:** `nothing to roll back`, exit 0.

### How they differ from the no-arg form

The no-arg form stops at the most recent marker of either kind. That
includes the one a rollback wrote, so straight after a rollback it finds
nothing. `--steps 1` steps over that and undoes the window before. They
differ in two more cases:

- after back-to-back checkpoints, where the no-arg form finds an empty
  window;
- over a window where nothing needed reversing (the links were already
  gone). `--steps` and `--to` still close it with a marker, so the next
  step moves on. The no-arg form writes none.

`--steps` and `--to` cannot be combined (exit 2).

## Rollback markers

A `rollback-marker` entry is a no-op for the trail's link/unlink
state but acts as a stopping boundary for `rollback`:

```
{"ts":"...","op":"rollback-marker"}
{"ts":"...","op":"rollback-marker","label":"pre-deploy"}    # checkpoint --label
{"ts":"...","op":"rollback-marker","from":"12"}             # closing a rollback
```

Markers are appended by [`hapi checkpoint`](checkpoint.md), and —
since 1.1.1 — by `hapi rollback` itself, at the end of a run that
reversed at least one entry without an error. When present,
`hapi rollback` reverses only entries after the most recent marker,
leaving everything before it untouched.

Since 1.5.0, rollback's own marker records `from`: the line its range
began on. That is how `--steps` and `--to` tell a checkpoint from the end
of an undo, and step over the undo. A marker written by a rollback before
1.5.0 has no `from`, so they read it as a checkpoint. A walk past it
replays the range it undid: each link is shown re-created and removed
again, with no net change, and one step is used. Run one more step to go
on.

Don't run other hapi writes while a rollback runs. A link made at the
same moment can land inside the range the rollback closes, and later
`--steps` / `--to` step over it as undone. `hapi unlink <pkg>` still
finds and removes it (F-063, accepted).

The closing marker is what makes a second run a no-op. Without it the
next run's window included the entries this run had just appended,
so every run re-reversed the last one — the same end state, but 2, 4,
8 … reversals and a trail that doubled each time (F-056). A run that
hit an error writes no marker, so it can be re-run once the cause is
fixed.

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | rollback completed (any per-entry skips were silent), or there was nothing to roll back |
| 1    | at least one entry hit an IO error mid-reversal; an adopt was reverted but its manifest row could not be removed (the reason is printed); the closing marker could not be written; the trail is not writable (nothing was changed); the trail refused a reversal's entry (below); or, with `--to` / `--steps`, an unknown label or more steps than the trail holds (nothing was changed) |
| 2    | bad usage: a positional argument, `--steps` that is not a whole number from 1 to 999999999, a `--to` that is not a label, or `--steps` with `--to` |

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

- [ADR 0007](../adr/0007-rollback-steps-and-to.md) — why `--to` takes a
  label, why a step is a checkpoint window, and what was weighed instead.
- [`checkpoint.md`](checkpoint.md) — making the markers, and labelling
  them.
- [`link.md`](link.md) / [`unlink.md`](unlink.md) — the ops
  rollback reverses.
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md) — the
  rollback-marker entry shape and the v1.0 frozen guarantee.
