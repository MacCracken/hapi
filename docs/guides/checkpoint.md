# `hapi checkpoint`

Append a `rollback-marker` entry to the audit trail. The marker
becomes a stopping boundary for the next `hapi rollback`:
everything before is sealed, everything after is in-scope.

## Synopsis

```sh
hapi checkpoint
```

No arguments.

## What it does

1. Appends a single JSON line to `$XDG_STATE_HOME/hapi/audit.jsonl`:
   ```
   {"ts":"...","op":"rollback-marker"}
   ```
2. Returns 0.

The marker writer (`audit_append_rollback_marker_r`) and the
walk-to-marker logic in `hapi rollback` shipped in M3 (v0.4.0);
v0.6.0 wires the user-facing verb.

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
| 0    | marker appended                                               |
| 1    | audit-trail write failed (mkdir or write error)               |

## See also

- [`rollback.md`](rollback.md) — the consumer of the marker.
- [ADR 0002 — Audit-trail format](../adr/0002-audit-trail-format.md) — the
  `op:rollback-marker` entry shape and v1.0 freeze guarantee.
