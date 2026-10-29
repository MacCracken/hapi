# 0008 — `hapi fmt`

**Status**: Accepted
**Date**: 2026-10-29

## Context

ADR 0001 left room for a formatter and set its terms: *"Any future
formatter (`hapi fmt`, if it exists) must produce byte-identical output for
the same logical manifest, or audit-trail hashes break."* The roadmap made
that the condition for shipping one in v1.x: its output must equal
`hapi_mf_canonicalize`'s bytes, the preimage of the `sha1c:` manifest hash
(ADR 0002), and it must keep the body below `---` byte for byte (ADR 0001,
1.1.1 addendum). A richer canonical form would cross into v2.0.

The canonical form is narrow. It holds the parsed manifest and nothing
else, and the parser is lenient. It skips comments, unknown sections and
keys, keys before any section, a key given twice (keeping the last), text
after a value, and values that are not double-quoted strings. So a
formatter that writes the canonical form deletes all of that. None of it
changes what hapi reads, which is why the hash ignores it, but all of it
is the user's.

Two further facts shaped the design:

- **The canonical form is not idempotent for a backslash.** The parser
  keeps `\` as written (`\"` reads as two bytes; ADR 0001 has no
  un-escape, F-021), and the canonicalizer escapes every `\` and `"`. A
  value holding a backslash grows on every pass, and its hash changes.
- **`fmt` rewrites the file `adopt` appends to.** An `adopt` landing
  between `fmt`'s read and its rename would lose its row: the F-012 shape.

## Decision

**`hapi fmt <package-dir|hapi.cyml>` rewrites the header as the canonical
bytes, and refuses whenever that would lose something or change the
hash.**

- **What it writes.** The header is the canonical bytes, with each line
  ended as the file's first line is: LF, or CR LF. That is the writer's
  rule since F-041. If there is a body, one blank line follows, then
  everything from the `---` line on, unchanged. The parser ignores the
  line ending and the blank line, so the hash is untouched.
- **What it refuses, unless `--force`.** The parser records everything it
  skips, with its line, while `fmt` is tracking. Recording never changes
  what a parse returns, and every other verb parses with nothing
  recorded. `fmt` lists the skips and exits 1 with nothing written.
  `--force` drops them and lists each as dropped. The parser is the only
  list of what it drops, so the list cannot fall out of step with it.
- **What it always refuses.**
  - A value holding a backslash, even with `--force`.
  - Output that does not parse back to the same canonical bytes: `fmt`
    proves this on the very bytes it would write before writing them.
  - A manifest that does not parse.
  - A symlinked `hapi.cyml`, which the rename would replace with a
    private copy (F-058).
- **How it writes.** Through `manifest_write.cyr`, holding the
  package-directory lock from the read to the rename, with the same
  staging file and atomic commit as `adopt`.
- **`--check`** writes nothing and exits 1 when the manifest is not
  formatted, for CI. **`--dry-run`** prints the header it would write and
  exits as the real run would.
- **No trail entry.** `fmt` moves no link and leaves the recorded hash
  correct, so nothing a trail reader consults changes.
- **The verb is registered last.** cmdit numbers verbs in registration
  order, so appending `fmt` keeps every existing verb's id.

## Consequences

- **Positive** — a formatted manifest hashes as it did, so the trail's
  `manifest_hash` stays meaningful across a reformat. Nothing the user
  wrote disappears without `--force`, and the list says exactly what
  would. `--check` gives CI a predicate. A race with `adopt` cannot lose
  a row; the concurrency harness holds that, and goes red without the
  lock.
- **Negative** — a commented manifest cannot be formatted without losing
  its comments. Notes have to live in the body. A value with a backslash
  cannot be formatted at all until the parser gains an un-escape, which
  is v2.0. On a real agnos kernel the rename cannot replace an existing
  file (F-059), so `fmt` there fails safe, as `adopt` does.
- **Neutral** — the blank line before `---` is `fmt`'s framing, not part
  of the canonical form, which the body never enters. The parser's
  recording costs nothing when off: each site checks one global before
  building any message.

## Alternatives considered

- **Keep comments, by attaching them to the rows they precede.** That is
  a richer canonical form than the hash's, which the roadmap reserves for
  v2.0. It would also need comment-aware sorting, and would stop "the
  header is the canonical bytes" from being true.
- **Drop silently, or drop and report.** These are the simplest. But a
  run would delete the user's comments with no confirmation, against
  hapi's rule that nothing of the user's is overwritten without
  `--force`.
- **Always refuse, with no `--force`.** Safe, but it makes the user
  delete each comment by hand before the one command that would.
  `--force` makes the loss explicit, as `link --force` does.
- **Detect drops outside the parser**, by a separate lexer or by
  comparing byte counts. A second scanner can disagree with the parser,
  and a disagreement is a silent loss. Recording at the parser's own skip
  sites cannot disagree.
- **An `op:fmt` trail entry.** It would be a record only: the old text is
  not kept, so `rollback` could not reverse it. And it would sit in a
  trail that otherwise records links.
- **Convert the header to LF always.** That leaves a CR LF manifest with
  mixed line endings, which `adopt` stopped doing at F-041.
