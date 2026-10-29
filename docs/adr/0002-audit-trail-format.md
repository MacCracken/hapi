# 0002 — Audit-trail format

**Status**: Accepted — **Frozen at v1.0.0 (2026-05-23)**
**Date**: 2026-05-20 (canonical-hash migration: 2026-05-23)

> Per CLAUDE.md's CHANGELOG Format rule, audit-trail format
> changes are always `Breaking` — rollback compatibility is
> part of the contract. v1.0.0 freezes the JSONL shape, the
> required field set, the `sha1c:` canonical-hash prefix, and
> the additive-field growth contract (readers MUST tolerate
> unknown fields). The pre-v1.0 `sha1:` raw-bytes prefix
> remains tolerated by readers for backward compatibility with
> trails written by v0.x writers.

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
| `created_dir` | string | 1.4.0 | absolute path of the **outermost directory this link's creation made**; every directory from it down to `abs_target`'s parent was made too. Present on `link` entries only, and only when the creation made a directory; written last. See the 1.4.0 addendum. |
| `label`       | string | 1.5.0 | on a `rollback-marker` that `hapi checkpoint --label` wrote: the name `hapi rollback --to` finds it by. 1 to 64 of `A-Z a-z 0-9 . _ -`. See the 1.5.0 addendum. |
| `from`        | string | 1.5.0 | on the `rollback-marker` that `hapi rollback` writes to close a run: the 1-based line of the first trail line the run covered, in decimal. See the 1.5.0 addendum. |
| `shape`       | string | 1.6.0 | `"absolute"` on a `link` or `adopt` entry that wrote an absolute link text (`--absolute`), and on an `unlink` or `unadopt` entry that removed one. Absent for the relative default. See the 1.6.0 addendum. |

### Hash

`manifest_hash` is `"<prefix>:" + lowercase-hex(sha1(input))`,
where the prefix tags how the input was prepared:

| prefix    | input to sha1                            | written by         |
|-----------|------------------------------------------|--------------------|
| `sha1:`   | raw bytes of `hapi.cyml` as read on disk | v0.x writers (pre-Unreleased) |
| `sha1c:`  | canonical re-serialization of the parsed manifest (see below) | Unreleased onward — writers emit only this |

Canonical re-serialization rules (matching `hapi_mf_canonicalize`
in `src/manifest.cyr`):

- `[package]` fields emitted in fixed order: `name`, `version`,
  `description` (only if present), `ignore` (only if non-empty).
- `[[link]]` rows sorted by `target` in lex byte order — row
  reordering in the source manifest does not change the hash.
- No comments; no blank-line variation (exactly one blank line
  between sections); final `\n` at EOF; no trailing whitespace.
- Strings escape only `"` and `\` (matches the parser's coarse
  rule).

**Readers tolerate both prefixes.** v0.x audit trails written
under `sha1:` parse cleanly on Unreleased readers; new entries
on the same machine accumulate under `sha1c:`. The
`manifest_hash` field is diagnostic-only (rollback's identity
check is `(pkg, target)`, not the hash), so the migration is
transparent — no consumer code needs to special-case the prefix.

This is the **Breaking** change ADR 0002 reserved for v1.0: the
prefix swap. The surrounding line format is unchanged, so older
tooling (`jq`, `cat`, the audit reader from v0.7.0) continues
to work without modification.

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

## Addendum — 2026-10-28 (1.1.1): crash semantics, as built

**The line shape and the required-field set are unchanged.** Two things in
*Crash semantics* above are corrected here, per the 2026-08-25 pass's
accepted boundaries and
[`../audit/2026-10-28-audit.md`](../audit/2026-10-28-audit.md).

**1. PIPE_BUF is not the guarantee.** POSIX bounds atomic writes by
PIPE_BUF for *pipes*, not regular files (and agnos's PIPE_BUF is 512). What
holds is: on Linux, `O_APPEND` plus an exclusive `flock` across the write;
on agnos, whose kernel does not honour `AO_APPEND`, the `flock` plus an
explicit seek to end. Since 1.1.1 an append whose lock fails is refused, not
attempted. Entries are still one `write(2)` each.

**2. The writer refuses a torn tail (since 1.0.9).** A crash mid-write can
leave a final line with no `\n`. The reader drops it, as stated above. The
*writer* checks the last byte before appending, and if it is not `\n` it
refuses: appending would splice two entries into one line, and the reader
would then drop both. The verb fails before it mutates anything — since
1.1.1 for `unlink`, `rollback` and `adopt` as well as `link` (F-055) — and
the user repairs the tail.

**Replay, as built.** `hapi rollback` writes a `rollback-marker` after a
run that reversed something without error (F-056), so a second run finds
nothing past it. Before 1.1.1 a trail with no marker was re-reversed by
every run. `hapi checkpoint` writes the same entry on demand; markers are
not de-duplicated.

## Addendum — 2026-10-28 (1.4.0): `created_dir`

**Additive: the line shape and the required-field set are unchanged.** A
`link` entry may now end with `"created_dir":"<path>"`. Entries whose
creation made no directory are byte-identical to 1.3.0's. hapi 1.3.0 reads a
1.4.0 trail unchanged (it drops the field), and 1.4.0 reads an older trail as
one that recorded no directories. Both directions were checked against the
released binaries.

**Why one string.** Every value in this format is a JSON string, and the
1.0 – 1.3 reader treats any other value as a malformed line. It would then
refuse to act on the trail at all ("a partial view"), so an array of paths
would have broken every earlier hapi on the first entry. One path is
enough because `mkdir -p` makes a contiguous chain: once a component is
missing, everything below it is too. So the outermost directory made
implies the rest. The writer records it only for a run it made without a
break. A directory found already there (on Linux, a racing creator's
EEXIST) restarts the run below it, so hapi never claims a directory it did
not make.

**What reads it.** `unlink`, `sync --prune` and `rollback` remove the
recorded directories with their link, as follows:

- They act only after removing the symlink themselves. The link sitting in
  the directory is the proof that the directory was not deleted and made
  again by the user in between.
- Deepest first, stopping at the first directory that is not empty.
- Never above `created_dir`.
- Never through a symlink: every directory in the chain must still be a
  real directory before any is removed (F-062).
- `unlink` and `--prune` remove the chains of everything the run removed
  together, so a directory one row made and another reused goes when both
  do.
- `rollback` goes newest first, so per entry is enough.

A link already gone, a `--dry-run`, or a pre-1.4.0 entry removes no
directory.

**What is not recorded.** The directories a removal took out are not
written to its `op:unlink`. The removal was recorded already; the
directories are its clean-up. Reversing it (`rollback` of the unlink)
re-makes them as any link does, and that replayed `op:link` records them
again.

Design note and the trade-off accepted (a directory emptied across two
separate runs is left), with the P(-1) record:
[`../audit/2026-10-28-audit.md`](../audit/2026-10-28-audit.md), *1.4.0
addendum*.

## Addendum — 2026-10-28 (1.5.0): `label` and `from` on `rollback-marker`

**Additive: the line shape and the required-field set are unchanged.** A
`rollback-marker` may now carry one more field, and at most one:

```
{"ts":"...","op":"rollback-marker","label":"pre-deploy"}    # hapi checkpoint --label pre-deploy
{"ts":"...","op":"rollback-marker","from":"12"}             # the marker closing a rollback
```

A plain `hapi checkpoint` is byte-identical to 1.4.0's. Both values are
strings, as every value in this format must be (see the 1.4.0 addendum).

**Why.** `hapi rollback --to <label>` needs a marker it can name, and
`--steps` / `--to` need to tell the two writers of a marker apart: a
boundary the user placed, and the end of a range rollback already undid.
`from` says where that range began, so a later walk can step over all of
it, the reversing entries and what they reversed, instead of redoing the
undo. The design and what was weighed instead are
[ADR 0007](0007-rollback-steps-and-to.md).

**`from` is a line number** of the trail file, counted from 1, as
`audit_corrupt_line` counts. The trail is append-only, so a line's number
never changes. A `from` that is not digits naming a line before the
marker's own is ignored, and the marker is read as a checkpoint. That only
ever makes a walk stop sooner.

**Compatibility.** Readers since 1.0 drop an unknown string field, and
every hapi rollback before 1.5.0 stops at any `rollback-marker`, so an older
binary's rollback behaves as it always did on a 1.5.0 trail. That was
checked against the released 1.1.1, 1.2.1, 1.3.0 and 1.4.0 binaries. In the
other direction, a closing marker written before 1.5.0 has no `from`;
1.5.0 reads it as a checkpoint, and a walk past it replays the range it
undid, to the same end state.

**Not recorded.** Which entries a rollback wrote is not marked on those
entries; the closing marker's range stands for them. A hapi write that
runs concurrently with a rollback can land inside that range and be
stepped over by later walks (F-063, accepted). `unlink`, which reads no
markers, still finds it.

## Addendum — 2026-10-28 (1.6.0): `shape`

**Additive: the line shape and the required-field set are unchanged.** An
entry whose link text is absolute ends with `"shape":"absolute"`:

```
{"ts":"...","op":"link",...,"abs_target":"/home/u/.zshrc","shape":"absolute"}
```

It is written last, after `created_dir`. An entry with a relative text has
no `shape`, so every relative entry is byte-identical to 1.5.0's.

**Where it goes.** On `link` and `adopt` entries that wrote an absolute
link, including the link a rollback re-creates, and on `unlink` and
`unadopt` entries that removed one. The removal entries carry it so that
reversing them (`rollback` of an unlink) re-creates the same shape. The
design is ADR 0003's 1.6.0 addendum.

**Reading it.** Only `"absolute"` means absolute. A missing `shape`, or one
hapi does not know, is the relative default. Nothing but rollback's
re-creation reads the field: every verb recognises a link of either shape
by its text, not by the trail (ADR 0003, 1.6.0 addendum).

**Compatibility.** Readers since 1.0 drop the unknown string field, so
earlier versions read a 1.6.0 trail without error. They do not know the
absolute text, so they treat an absolute link as not hapi's and leave it
in place. That was checked against the released 1.1.1, 1.2.1, 1.3.0,
1.4.0 and 1.5.0 binaries.
