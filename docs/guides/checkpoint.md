# `hapi checkpoint`

Append a `rollback-marker` entry to the audit trail. The marker
becomes a stopping boundary for the next `hapi rollback`:
everything before is sealed, everything after is in-scope.

## Synopsis

```sh
hapi checkpoint [--label <label>] [--dry-run]
```

No positional argument.

## What it does

1. Appends a single JSON line to `$XDG_STATE_HOME/hapi/audit.jsonl`:
   ```
   {"ts":"...","op":"rollback-marker"}
   {"ts":"...","op":"rollback-marker","label":"pre-deploy"}    # with --label pre-deploy
   ```
2. Returns 0.

## Naming a checkpoint: `--label`

Since 1.5.0, `--label` names the marker, so that
[`hapi rollback --to <label>`](rollback.md#--to-label) can go back to it,
past any checkpoints made after it:

```sh
$ hapi checkpoint --label pre-deploy
checkpoint `pre-deploy` written
```

- **1 to 64 characters** from `A-Z a-z 0-9 . _ -`, not starting with `-`.
  Anything else is exit 2, with nothing written.
- **Labels need not be unique.** `rollback --to` takes the most recent
  marker with the label, so a script can reuse one on every run.
- A label is the one thing that tells your checkpoints apart. To list
  them: `grep '"label"' ~/.local/state/hapi/audit.jsonl`.

The marker writer (`audit_append_rollback_marker_r`) and the
walk-to-marker logic in `hapi rollback` use the same audit-trail
shape; `hapi checkpoint` is the user-facing entry point.

**It is not idempotent, by design.** Three consecutive checkpoints
append three markers — journal semantics: each call records that you
asked for a boundary, at that moment. Consecutive markers behave
exactly like one for `rollback`, and each costs one short line of
trail. Since 1.1.1 `hapi rollback` also appends a marker after a run
that changed something, so consecutive markers are normal.

## Example: bracketing a risky session

```sh
$ hapi link dotfiles-zsh
linked 3 / 3 (0 already up-to-date)

$ hapi checkpoint
checkpoint written

$ hapi link experimental-nvim     # exploratory; want to undo if it goes sideways
$ hapi adopt ~/.config/sway sway-pkg

# Decision: revert everything after the checkpoint.
$ hapi rollback
rolled back 4 / 4 entries
```

Without the checkpoint, `hapi rollback` would have walked all
the way back to the beginning of the trail, undoing the
dotfiles-zsh link too. The marker is the bookmark that says
"keep this; lose what comes after."

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | marker appended (`--dry-run`: the trail would take it)        |
| 1    | audit-trail write failed (mkdir or write error); since 1.7.1 `--dry-run` fails the same way when the trail would refuse the write (F-094) |
| 2    | bad usage: a positional argument, or a `--label` that is not a label |

## See also

- [`rollback.md`](rollback.md) — the consumer of the marker, and its
  `--to` / `--steps` forms.
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md) — the
  `op:rollback-marker` entry shape and v1.0 freeze guarantee.
