# 0007 — `rollback`: `--steps` and `--to`

**Status**: Accepted
**Date**: 2026-10-28

## Context

Through 1.4.0, `hapi rollback` had one form. It reversed every entry after
the most recent `rollback-marker`, newest first and conditionally, and since
1.1.1 it closed a run that changed something with a marker of its own
(F-056). That makes a second run find nothing past the marker. So rollback
was a single undo, back to the last boundary, and nothing could reach
further.

The v1.0 release notes reserved two refinements, `--steps N` and
`--to <marker>`, and the no-arg form had to stay exactly as it was. Three
things made this a real design question:

- **Markers had no names.** A marker carried only `ts` and `op`.
  `--to` needed a way to name one: by position, by timestamp, or by a
  label.
- **Two writers make the same entry.** `checkpoint` writes a marker on
  request, and rollback writes one after each run. They are byte-identical
  in shape, so a walk could not tell a boundary the user placed from the
  end of an earlier undo.
- **An undo is itself in the trail.** Rollback appends a reversing entry
  for everything it reverses. A walk that reaches back past an earlier
  rollback meets those entries first. Reversing them redoes what the user
  undid, and reversing the originals then undoes it again. The end state
  is correct, since each reversal is conditional, but every link is shown
  re-created and removed, and the trail gains twice the entries.

## Decision

**`--to <label>` reverses back to the most recent marker carrying that
label. `--steps N` reverses the N most recent checkpoint windows still in
effect. Both step over every range an earlier rollback already undid.**
The no-arg form is unchanged.

**Naming: a label, written by `checkpoint --label <label>`.**

- The marker gains `"label":"<label>"` (ADR 0002, 1.5.0 addendum).
- A label is 1 to 64 characters from `A-Z a-z 0-9 . _ -`, not starting
  with `-`.
- `--to` takes the most recent marker with that label. A script that
  reuses a label each run gets its own latest checkpoint.
- An unknown label is exit 1 with nothing changed. So is asking for more
  steps than the trail holds.

**A step is a checkpoint window, counted only when it holds a live
entry.** A window runs from one marker to the next.

- Back-to-back checkpoints make one step.
- A window an earlier rollback emptied makes none.
- So after any rollback, `--steps 1` reaches the window before it. That
  is a multi-level undo; the no-arg form would say nothing to roll back.

**Rollback's closing marker records where its range began:
`"from":"<line>"`.** This is how a walk tells the two writers apart, and
how it skips an undone range.

- `from` is the 1-based line of the first trail line the run covered.
- Every closing marker carries it, including the no-arg form's.
- A walk that meets one jumps to the line before `from`. The run's
  reversing entries and the entries they reversed are never touched
  again.
- `from` is trusted only when it is digits naming a line before the
  marker's own. Otherwise the marker counts as a checkpoint, which can
  only make a walk stop sooner.

**`--steps` and `--to` seal a range even when nothing in it needed
reversing.** Otherwise the next `--steps 1` would find the same window
again. The no-arg form keeps 1.1.1's rule of writing a marker only after
a run that changed something. In every form, an errored run writes no
marker, so that it can be re-run.

## Consequences

- **Positive** — rollback becomes a real undo stack, while the no-arg
  form, and every pre-1.5 reader of the trail, behave exactly as before.
  An old binary stops at a closing marker as it always has, whatever the
  marker's fields. A script can bracket its own work with
  `checkpoint --label` and `rollback --to`, untouched by anyone else's
  checkpoints.
- **Negative** — a rollback made before 1.5.0 left a marker without
  `from`. `--steps` counts it as a checkpoint and replays the range it
  undid: no net change, but one step used and the churn shown. And a hapi
  write that runs concurrently with a rollback can land inside the range
  the rollback seals; later `--steps` / `--to` step over it (F-063,
  accepted). `hapi unlink` still finds it.
- **Neutral** — `--steps 1` and the no-arg form differ in three cases:
  right after a rollback, after back-to-back checkpoints, and over a
  window where nothing needed reversing. The rollback guide says so.

## Alternatives considered

- **`--to` by position** (`--to 2`, the second most recent checkpoint) —
  rejected. The number moves every time anyone adds a checkpoint, so a
  script cannot hold on to it. It also overlaps `--steps`.
- **`--to` by timestamp** — rejected. `ts` resolves to the second, so two
  markers can share one, and checkpoint is not idempotent by design. It
  is also awkward to type.
- **A step as one trail entry** — rejected. An entry is one link, so
  `--steps 2` could undo two rows of a three-row package and leave it
  half linked. A checkpoint is the unit the user chose.
- **A step as one command** — not possible without recording command
  boundaries on every entry. That would change every line's bytes, for
  the one verb that reads them.
- **Replaying earlier rollbacks rather than stepping over them** —
  rejected as the rule, kept as the fallback for markers with no `from`.
  It needs no format change, but `--steps 1` after a rollback would redo
  that rollback's last reversal: the opposite of what "one more step
  back" means.
- **Marking every entry rollback writes**, rather than its closing
  marker — would make the skip immune to a concurrent writer (F-063).
  But it adds a field to entries that `unlink`, `list` and `sync` also
  read, for a case ADR 0002 does not expect to happen. The closing marker
  alone was enough.
- **Reversing what exists when `--steps N` asks for more** — rejected. A
  script that asked for three steps and got two would carry on believing
  it had three. A refusal changes nothing, and asking again is cheap.
