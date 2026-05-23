# 0002 — Audit-trail format

**Status**: Accepted
**Date**: 2026-05-20

## Context

Every filesystem mutation hapi performs must be auditable. CLAUDE.md
locks the principle and the v1.0 contract puts teeth on it:

> Audit-trail format documented and frozen (rollback compatibility)

and

> Audit-trail format changes are always `Breaking`

The trail is also the input to M3 `rollback`, which CLAUDE.md
specifies as "replay the audit trail in reverse." So the file has
two consumers from day one: humans (debug, review) and the
`unlink` / `rollback` commands (M3) — and a third consumer at v1.0
(`hapi sync` reconciling the trail against on-disk state).

Constraints in play:

- **Crash-safety**: a hapi process that dies mid-link must leave
  the trail in a recoverable state. The next invocation must be
  able to read the trail without confusion.
- **Append-only**: we never rewrite earlier entries. Rollback
  appends a new "reverse" entry; it does not erase the original.
  This means storage grows monotonically — fine, dotfile churn
  is low; we can document a `hapi trail compact` for later.
- **Human-readable**: `cat ~/.local/state/hapi/audit.jsonl | jq`
  must just work for review and debugging.
- **Replay-stable**: an entry written today must parse identically
  five years from now. No schema migrations baked into the format
  (additive only — new fields are tolerated by older code).
- **No tooling dep**: hapi cannot rely on the user having `jq`,
  Python, or any other parser installed. The format must be
  parseable with `lib/json.cyr` (already in stdlib).
- **Stable on truncation**: a torn write at EOF should drop the
  partial line, not corrupt the rest of the file.

## Decision

The audit trail is a single file, **JSON Lines** (one
JSON object per line, `\n`-terminated), append-only.

### Location

```
$XDG_STATE_HOME/hapi/audit.jsonl
```

with fallback `$HOME/.local/state/hapi/audit.jsonl` when
`XDG_STATE_HOME` is unset. Per the XDG Base Directory spec —
state data that should persist across runs but is not config
and not cached.

The parent directory is created on first write (`mkdir -p`
semantics). hapi never reads or writes anywhere else for its
own state; nothing in the trail is sensitive enough to warrant
non-default permissions.

### Per-entry shape

One JSON object per line, no nested objects, no arrays of objects.
Keys ordered for canonical serialization (so two writers producing
"the same entry" produce byte-identical lines):

```
{"ts":"2026-05-20T15:30:42Z","op":"link","pkg":"dotfiles-zsh","pkg_version":"1.0.0","manifest_hash":"sha1:c3f1...","source":"zshrc","target":".zshrc","abs_source":"/home/user/dotfiles/dotfiles-zsh/zshrc","abs_target":"/home/user/.zshrc"}
```

Required fields, in declaration order:

| field           | type   | meaning                                                       |
|-----------------|--------|---------------------------------------------------------------|
| `ts`            | string | ISO 8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`)               |
| `op`            | string | `"link"`, `"unlink"`, `"adopt"`, or `"rollback-marker"`       |
| `pkg`           | string | `package.name` from the manifest                              |
| `pkg_version`   | string | `package.version` from the manifest                           |
| `manifest_hash` | string | `"sha1:" + hex(sha1(manifest_bytes))` — see "Hash" below      |
| `source`        | string | the manifest's `source` value (relative to package dir)       |
| `target`        | string | the manifest's `target` value (relative to scoped root)       |
| `abs_source`    | string | absolute resolved source path on the writer's host            |
| `abs_target`    | string | absolute resolved target path on the writer's host            |

`abs_source` and `abs_target` are recorded even though they're
host-specific — they make the trail unambiguous on the machine
that wrote it (which is the only machine `rollback` will ever
run on; per the roadmap, cross-machine sync is explicitly out
of scope).

Unknown additional fields MUST be tolerated by readers. This is
the only way the format stays additive across the v0.x → v1.0
window without `Breaking` every minor.

#### Additive fields shipped after the initial format

| field         | type   | shipped in | meaning                                                |
|---------------|--------|------------|--------------------------------------------------------|
| `backup_path` | string | Unreleased | absolute path to a pre-`--force` snapshot of the prior file content. Present on `link` / `adopt` entries when the writer was invoked with `--backup-to <dir>`; omitted otherwise. Readers that don't know this field ignore it per the growth contract. |

### Hash

`manifest_hash` is `"sha1:" + lowercase-hex(sha1(manifest_bytes))`.
For M2, the input to sha1 is the *raw bytes of `hapi.cyml` as read
from disk*. Canonicalization (re-serialize the parsed AST to a
fixed byte form, then hash) is reserved for a later patch and
will land before v1.0 as a `Breaking` change in the hash prefix
(`sha1:` → `sha1c:` or similar). Recording the prefix in the
trail today means M3 / v1.0 readers can detect and reject
pre-canonical entries cleanly.

sha1 is fine here — this is an integrity / replay hash, not a
cryptographic identity. Collision resistance against an attacker
who can write to the user's manifest is not a meaningful threat
model (an attacker who can write the manifest can write anything).
sha1 is in stdlib (`lib/sha1.cyr`); no new dep.

### Crash semantics

Each line is written with a single `write(2)` syscall — POSIX
guarantees atomicity for writes up to PIPE_BUF (4096 bytes) on
regular files. Our entries are well under that (typical ~250
bytes, max ~1 KB even with long paths). A torn write at process
death therefore manifests as either:

1. Zero new bytes (process died before the write), or
2. The full new line (process died after the write).

We never see a partial line. The reader contract — "drop any
trailing bytes not ending in `\n`" — covers the unlikely case
where a future entry exceeds PIPE_BUF or the file lives on a
non-POSIX-conformant filesystem.

### Replay semantics (M3 preview)

`hapi unlink <pkg>` walks the trail forward, identifies every
`{"op":"link","pkg":"<pkg>"}` entry not yet superseded by an
`unlink` of the same `target`, and removes those symlinks (only
if the on-disk symlink still points where the trail says it
does — otherwise the user mutated it and we refuse).

`hapi rollback` walks backward to the most recent
`{"op":"rollback-marker"}` and reverses every entry between
there and EOF. The marker is written by future tooling
(`hapi checkpoint`, M3+); a trail with no markers rolls back
to its start.

Both operations *append* their reverse entries — they never
edit or truncate the file.

## Consequences

**Positive**:

- JSONL is the standard format for append-only logs. `jq`, `grep`,
  `tail -f`, every text editor work out of the box.
- Per-line JSON object is parseable with `lib/json.cyr` — no
  custom format, no parser to maintain.
- The required-field set is small and stable. Additive growth
  doesn't break the contract.
- Hash prefix (`sha1:`) leaves headroom for a v1.0 canonicalization
  switch without a `Breaking` of the surrounding line format.
- POSIX atomic writes give us crash-safety without explicit fsync
  or temp-file dances. Cheap and correct.

**Negative**:

- Monotonic growth. A heavy user could accumulate megabytes over
  years. We owe a `hapi trail compact` someday (out of scope
  for v1.0).
- `manifest_hash` over raw file bytes means a cosmetic edit
  (trailing newline, comment change) produces a different hash
  even when the manifest is semantically identical. M3's
  rollback compares hashes only for diagnostic context, not as
  a gate — link identity is `(pkg, target)`, not the hash.
  v1.0 canonicalization closes the loop.
- `abs_source` / `abs_target` make the trail non-portable across
  machines. That's intentional (cross-machine sync is out of
  scope), but worth flagging: copying `~/.local/state/hapi/`
  to a new host and running `rollback` on the absolute paths
  is undefined behavior.

**Neutral**:

- One file, no rotation. Simpler than per-package files (which
  would force the reader to merge for `rollback`) and simpler
  than dated rotation (which would force the reader to enumerate
  files for `unlink`).
- `op` is a string, not an enum-integer. Costs ~5 bytes per
  entry; gains: greppability, no integer-meaning drift across
  versions, future ops can be added without coordinating a
  shared enum.

## Alternatives considered

- **One file per package** (`audit/<pkg>.jsonl`) — rejected.
  `rollback` would have to scan and merge across files to
  preserve cross-package ordering; `unlink` is fine but
  `rollback` is the load-bearing reader.
- **SQLite** — rejected. Adds a dep (we'd need to ship a SQLite
  C library or write one in Cyrius); the access pattern is
  pure append + sequential read, which gains nothing from a
  query engine; and it loses `cat | jq` reviewability.
- **Custom binary format** — rejected. We'd own the parser
  forever, lose human-readability, and gain nothing the JSONL
  + POSIX-atomic-write combo doesn't already give us.
- **TOML/CYML entries** (one TOML table per entry, separated by
  blank lines) — rejected. Multi-line entries break the
  "atomic single-write line" crash-safety story; the format is
  also harder to grep.
- **Per-entry signature** (HMAC each line with a per-host key) —
  out of scope. The trail is local state; if an attacker can
  write to `~/.local/state/hapi/`, they can rewrite hapi's
  binary too. We're not in a threat model where this helps.
- **Append via `O_APPEND`** vs **seek-to-end + write** — chose
  `O_APPEND`. The kernel guarantees the offset/write pair is
  atomic across processes; seek-to-end + write races with any
  other writer. We don't expect concurrent hapi processes, but
  `O_APPEND` is the same code path and removes a class of
  bug.
