# `status`, `list` and `sync` report a world that is not on disk

**Discovered:** 2026-08-25, P(-1) hardening sweep (F-022, F-023, F-024, F-026, F-025)
**Severity:** Medium — no data is destroyed, but the verbs whose entire job is to tell the user the truth do not
**Affects:** `src/cmd/link.cyr`, `src/cmd/list.cyr`, `src/cmd/sync.cyr`, `src/fs_link.cyr`, `src/manifest.cyr`; live in the shipped 1.0.5
**Arc:** 1.0.x hardening, Tier 2 ([`../roadmap.md`](../roadmap.md))

## Why these are one issue

Each is small on its own. Together they undermine the same thing: after a
recovery, a migration, or a bad manifest, the user reaches for `status`
and `list` to find out what is actually linked — and both answer
confidently and wrongly. F-006 already designates `status` as *the
post-recovery source of truth*, which is precisely the role F-022 breaks.

## F-022 — `link` creates dangling symlinks, and `status` calls them OK

`link` never probes the source before creating the symlink. A typo in a
manifest, a file deleted from the package, a `git checkout` of a branch
that lacks it, or a source moved after linking — all produce a link
pointing at nothing.

`status` then recomputes the expected relative target, byte-compares it
against what the link holds, finds a match, and reports the tree clean at
exit 0. The user's `~/.zshrc` is broken, zsh will not start, and **both**
hapi verbs that exist to tell them so say everything is fine.

GNU stow probes the source. hapi should too: refuse at `link` time, and
classify a dangling link as drift in `status`.

## F-023 — `hapi list` overcounts after a `--force` takeover

When package B takes over a target that package A owned, the trail
records B's `link` but nothing retires A's claim, so `list` reports both
packages owning the same single symlink. After a recovery or a package
migration — exactly when `list` is what the user is reading — the counts
describe links that do not exist.

Fix: retire the displaced owner's claim when a `--force` takeover is
recorded. (There is an adjacent `vec_set` cleanup at the same site.)

## F-024 — `hapi link .` breaks idempotency, and the remedy is dangerous

An unnormalized package-dir argument flows into the relative-target
computation, so `hapi link .` writes a `./`-bearing symlink body. Every
later canonical run recomputes the clean form, byte-compares, sees a
mismatch, and calls it a conflict — so `hapi sync`, whose contract *is*
idempotence ("running `hapi sync` twice produces the same result"),
refuses with exit 1.

The sharp edge is the refusal's own advice: *rerun with `--force`*. On a
package that also has a genuine file conflict, following that advice
destroys the file.

Fix: normalize the package-dir argument at the five resolver sites.
⚠ **Do not change `fsl_compute_relative` itself or its inputs at the four
ownership-proof sites** (`unlink.cyr:122`, `rollback.cyr:68` and `:101`,
`status.cyr:93`) — those verbs prove ownership by recomputing and
byte-comparing, so changing the computation changes what they compare.

## F-026 — `hapi sync --backup-to` is an advertised no-op

The guides and `--help` both present `--backup-to` as available on
`sync`, and the snapshot branch on that path cannot fire. A user
following the documentation believes their files are snapshotted before a
destructive overwrite. They are not, and
[`../../guides/backup-to.md`](../../guides/backup-to.md)'s claim that
"sync inherits `--force`" is flatly false.

1.0.x fix is **documentation, not surface**: remove `sync` from every
`--backup-to` claim in the guides, `state.md` and `--help`. Adding
`--force` to `sync` would be a v2.0 command-surface change.

## F-025 — `package.ignore` is parsed, echoed and hashed, but never applied

A user lists `.git` and `secrets.env` to keep them out of `$HOME`.
`hapi inspect` prints every pattern back, confirming the belief. None of
them is honoured, and because a directory row materializes as a single
symlink to the whole directory, every ignored file is live under it.

⚠ **Honouring `ignore` is a v2.0 change, not a 1.0.x one** — it alters
what a directory row materializes and how many audit entries a row
writes, both v1.0-frozen behaviours. What 1.0.x ships is honesty:
document `ignore` as *reserved, not yet honoured* in ADR 0001, drop it
from the shipped example manifest so the docs stop demonstrating a no-op,
and warn in strict mode when a manifest sets it.

## Exit criteria

F-022, F-023 and F-024 fixed with tests; F-026 and F-025 corrected in the
documentation with their v2.0 successors recorded on the roadmap.
