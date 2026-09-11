> ## ✅ RESOLVED in 1.0.6 (2026-08-25)
>
> All three landed together, as this issue proposed. `audit_read_r`
> sizes the read from the file (`xlseek` SEEK_END), distinguishes
> `ENOENT` from every other open failure, and refuses an interior
> malformed line while still dropping a trailing partial one.
> `rollback` / `unlink` / `list` consume the `Result` and exit 1 with a
> diagnostic — naming the line number for a corrupt entry — rather than
> acting on a partial view.
>
> Verified against the reproduction below: an 800-entry / 328,800-byte
> trail that previously destroyed **637 settled links** while keeping
> the one the user wanted undone now reverses **`1 / 1 entries`**.
> Mutation-proven: reverting the three repairs turns the new test group
> RED with ten distinct failures, including `got 882, expected 1000` as
> the old 256 KB cap truncates mid-trail.
>
> `hapi trail compact` remains open and orthogonal, as the *Not this
> fix* section below argued — a v2.0 verb, not a substitute.

# `audit_read` caps the trail at 256 KB from the head, so `rollback` reverses the wrong window

**Discovered:** 2026-08-25, P(-1) hardening sweep (F-007, with F-016 and F-017 in the same function)
**Severity:** High — a wrong *destructive* action, taken silently, at exit 0
**Affects:** every version with `src/audit_reader.cyr` in its current shape; live in the shipped 1.0.5
**Arc:** 1.0.x hardening, Tier 1 ([`../roadmap.md`](../../roadmap.md))

## Summary

`audit_read` reads the **first** 256 KB of the audit trail. The trail is
append-only, so past that point the reader sees a window that no longer
contains the end of the file — and `rollback`'s whole model is *find the
most recent marker, reverse everything after it*.

Once the trail outgrows the cap:

1. `_hrb_find_marker` cannot see the most recent `rollback-marker`.
2. `rollback` falls back to `start = 0`.
3. It reverses the **oldest still-live** links — settled dotfiles the
   user has not touched in months — and leaves the recent work in place.
4. Exit 0, reported as success.

The user's mental model is "undo what I just did". The action taken is
the exact opposite: keep what was just done, destroy the oldest links.

## Reach

Measured 445 bytes/entry on a deep `$HOME` during the sweep;
[`../../benchmarks.md`](../../../benchmarks.md) records 289 bytes/entry on
the synthetic harness. That puts the cliff at roughly **590–900 entries**
— reachable by an ordinary dotfiles user over a year, and much sooner
given `hapi checkpoint` is not idempotent (three consecutive checkpoints
append three markers; see the accepted boundaries in the audit).

## Two more defects in the same function

Fix these together — they touch the same read and the same failure
philosophy:

- **F-016 — an interior malformed line is silently dropped.** A bad
  sector, a partially-flushed extent after a crash, or an accidental
  editor save damages one entry, and every consumer skips it: `rollback`
  claims complete success while the recorded link survives on disk,
  `unlink` misses it, `list` undercounts. A *trailing* partial line is
  legitimately dropped (that is the torn-write contract, and it has a
  standing test); an *interior* one is corruption and must refuse.
- **F-017 — an unreadable trail is swallowed as "empty".** A permissions
  change, a failing disk, or fd exhaustion, and `list` / `rollback` /
  `unlink` all exit 0 having done nothing. A script keying on exit
  status concludes the rollback succeeded.

## Proposed fix

Introduce `audit_read_r` returning a `Result`, and land all three:

- size the read from the file (`xlseek` SEEK_END), the way `_hmw_slurp`
  was fixed for F-009 in 1.0.5 — that repair is the working precedent;
- distinguish ENOENT (a genuinely absent trail → empty, exit 0) from
  every other open/read error (→ `Err`, non-zero exit);
- treat a negative read as an error rather than EOF;
- refuse on an interior malformed line, keep dropping a trailing partial.

Keep `audit_read` as a thin wrapper during migration so the five
consumers can move one at a time.

## Not this fix

`hapi trail compact` — the ergonomic answer to monotonic growth that
`src/audit_reader.cyr`'s own comment already names — is **orthogonal**.
Compaction is convenience; reading the whole trail is correctness. And a
new verb is new surface, so compaction is a v2.0 item. Do not let it
substitute for this.

## Regression test

A trail built past the cap with a marker beyond it: `rollback` must
reverse only the post-marker entries. Mutation-prove it by restoring the
fixed-size read and confirming the test goes RED — the same discipline
the 1.0.5 repairs used.
