# hapi Issues — How to File

Active issue reports live here. Resolved items move to `archived/`
once closed — don't read archived/ looking for how to file, read
this.

## What belongs here

- **Real-world dogfood papercuts** — surfaces hapi has but the
  user keeps tripping on during actual dotfile work. M7 is the
  dedicated dogfood pass; most early issues land here.
- **Design-gap reports** — a behavior the user worked around in
  practice, where the fix belongs in hapi (not in consumer
  manifests). Include a clear stopgap if one exists.
- **Deferred-from-milestone items** that need durable in-repo
  prose because the roadmap entry alone isn't enough context
  (e.g. *why* a sync-prune feature was deferred, what its design
  considerations are, what consumer pressure would re-pin it).

## What doesn't belong here

- **Upstream bugs.** If the bug is in cyriusly, the kavach
  daemon, the kernel, or a third-party tool, file it in that
  repo. Hapi's `issues/` is for hapi-side bugs only.
- **Feature wishlists without a consumer stopgap.** Speculative
  surface ideas go in `docs/development/roadmap.md` under
  *Out of scope* or *post-v1.0 candidates*, not here. The bar
  for an issue is: *someone (the dogfood user) is working
  around this in real dotfile management right now.*
- **One-line questions.** If it fits in a chat message, don't
  file it.

## How to file

Create `docs/development/issues/YYYY-MM-DD-{short-slug}.md` —
kebab-case, ISO-date prefix. Slug should name the surface
(e.g. `sync-prune-deferred.md`, `status-exit-1-chains.md`).
Structure:

```markdown
# {title} — {short status}

**Discovered:** YYYY-MM-DD during {context — e.g. "M7 dotfile dogfooding"}
**Severity:** Low / Medium / High / Critical
**Affects:** hapi {version range}

## Summary

One paragraph. What surface bites, what the symptom looks like,
what the user's intent was when they hit it.

## Reproduction

Concrete steps. The audit-trail state, the manifest shape, the
command sequence. Include the actual `hapi list` / `hapi status`
output where it pins the issue.

## Root cause (if known)

File + line if hapi-side; "deferred from milestone X" if it's
a known design gap. Speculation OK — flag it.

## Proposed fix

Can be "none — just surfacing" if the fix needs design work.
Don't block on this; *surfacing* is the contribution.

## Consumer-side workaround (if any)

If the user shipped a workaround in their dotfiles (e.g. an
explicit unlink+edit+link rotation for a row removal), document
it here so the next consumer hitting the same surface can pick
it up while waiting for a hapi-side fix.
```

## Severity guide

- **Critical** — silent data loss in user dotfiles, audit-trail
  corruption, broken rollback contract, security (CVE-class).
- **High** — hard failure that blocks a real dotfile workflow,
  no workaround available.
- **Medium** — hard failure with a known workaround, or silent
  trail-state divergence (live count over/undercount, etc.).
- **Low** — ergonomic papercuts, misleading exit codes for
  scripted chains, missing convenience flags, doc-mismatches.

## Triage + lifecycle

The agent (or maintainer) reads new issues on-demand. Expect
one of:

1. **Accepted for release X.Y.Z** — scope locked, shows up in
   `docs/development/roadmap.md` and in the target release's
   CHANGELOG section.
2. **Accepted, modified** — the fix lands in a different shape
   than the proposal. Reason noted in the issue file.
3. **Declined** — with reason. Common decline shapes for hapi:
   "post-v1.0 candidate, doesn't earn its place in the v1.0
   surface" or "consumer-side concern, not hapi's surface".

When the fix lands, the issue file:
- Gets a `— RESOLVED` suffix in its top heading.
- Adds a status paragraph pointing at the fix version + the
  CHANGELOG section that closed it.
- Moves to `archived/`.
- Filename stays stable across the move so external links
  keep working.

## Cross-repo upstream issues

Bugs discovered during hapi dogfooding that turn out to be in
sibling tools (cyriusly, kavach, etc.) get filed *in that
repo's `docs/development/issues/`* — not here. Note the
hapi-side surfacing context in the upstream issue's "Discovered
during" line. Example: the 2026-05-20 cyriusly starship-install
clobbering bug surfaced during hapi M7 starship-package adoption
and is filed at
`cyrius/docs/development/issues/2026-05-20-cyriusly-cmdtools-install-clobbers-existing-starship-config.md`.

## Pointers

- `archived/` — resolved issues, kept for the audit trail.
- `../roadmap.md` — milestones and out-of-scope deferrals.
- `../state.md` — current live state.
- `../../../CHANGELOG.md` — source of truth for what each
  release actually shipped.
