# 0006 — `sync`: package roots and `--prune`

**Status**: Accepted
**Date**: 2026-10-28

## Context

Through 1.2.x, `hapi sync <pkg>` was `hapi link <pkg>` without `--force`.
Two dogfood issues pressed on it.

- **Recovery is a shell loop.** A drive move left 11 packages to
  re-establish, one `hapi sync` each, from a hand-kept list. Miss one and
  it stays unlinked with no error, because hapi was never told it existed
  ([`../development/issues/archived/2026-05-24-no-arg-sync-bootstrap-recovery.md`](../development/issues/archived/2026-05-24-no-arg-sync-bootstrap-recovery.md)).
  The same move wiped the audit trail, so finding packages through the
  trail would have found **none**, exactly when recovery mattered.
- **A dropped row needs a full rotation.** Removing one `[[link]]` row
  meant `unlink` (every row), edit, `link` (every kept row): 11 trail
  entries for a 6-row package, and five wanted links briefly gone
  ([`../development/issues/archived/2026-05-20-sync-prune-deferred-row-removal-rotation.md`](../development/issues/archived/2026-05-20-sync-prune-deferred-row-removal-rotation.md)).

The v1.0 surface is frozen, so both answers had to be additive.
`sync`'s positional was already optional at the parser (1.2.0), so no
package could become legal. Any new flag had to be a flag `sync` did not
take.

Two hazards shaped the choices.

- **A directory scan does not know a package's scope.** A package meant
  for `--root /etc/x` sitting under the scanned directory would be linked
  into `$HOME` by a scan that assumed the default.
- **The trail keys links on the package name alone.** Two package
  directories that share a name are indistinguishable there.

## Decision

**A no-package `hapi sync` syncs every package under
`HAPI_PACKAGE_ROOTS`.** `--prune` also removes the package's own links
whose rows left its manifest.

**Discovery — the root scan is the only source of what to sync.**

- `HAPI_PACKAGE_ROOTS` is colon-separated, like `HAPI_ALLOWED_ROOTS`.
  Every entry must be an absolute path. Unset is exit 2, with a message
  naming the variable.
- Each root is scanned **one level deep**. `<root>/<name>` is a package
  when it is a directory, not a symlink to one, holding a regular-file
  `hapi.cyml`. Names starting with `.` are skipped.
- **The scan follows no symlink.** A symlinked directory or manifest that
  would have been a package is named in a note and skipped, so a root
  bounds exactly what the scan picks up.
- Packages sync in byte order of their names, each exactly as
  `hapi sync <dir>` would. A failing package does not stop the rest: the
  run exits 1 at the end, and a summary line counts what synced.
- **Two scanned packages with the same name are both refused**, since the
  trail could not tell their links apart.
- **The trail is used only to report.** Packages it holds live links for,
  whose directory no root holds, are named and not synced: their scope
  cannot be known safely.
- `HAPI_PACKAGE_ROOTS` grants nothing. It says where packages are read
  from; every target is still decided by the scope, `--root` and ADR
  0005, exactly as for a named package.

**Prune — only this package's links, only in this run's scope, only what
hapi made.**

- A link is a candidate when all of these hold:
  - it is a live `op:link` under the manifest's name (`adopt`'s links stay
    rollback's, ADR 0004);
  - its `abs_source` lies in **this package directory** and its
    `abs_target` in **this run's scope**;
  - no row still in the manifest plans its target.
- A candidate is removed only if the symlink on disk is still the text
  hapi wrote (`fsl_link_text_matches`). Anything else refuses the whole
  package, and `--force` does not override that.
- **The limit.** Without `--force`, prune refuses when it would remove more
  than half of the package's live links in this scope, so an emptied or
  truncated manifest is caught. Dropping 1 of 6 goes through, and exactly
  half goes through.
- **`--force` on `sync` lifts that limit and nothing else.** `sync` still
  never overwrites a conflict; that remains `link --force`. `sync --force`
  without `--prune` is exit 2.
- **Order.** The link half is planned and refused on its own terms first.
  Then the prune half is planned, and only then is anything written:
  F-055's trail preflight, the removals (one `op:unlink` each, the entry
  `hapi unlink` writes), then the creates. A package is refused as a
  whole.

## Consequences

- **Positive**
  - Recovery is `hapi sync`: one process, which over 100 packages is also
    ~40 % faster than the loop it replaces (`../benchmarks.md`, 1.3.0).
  - The dogfood row drop is one `op:unlink`, with the kept links never
    touched.
  - Neither form writes a new trail field. ADR 0002's line shape is
    unchanged, and rollback reverses a prune as it reverses an `unlink`.
- **Negative**
  - The packages under one root share one scope. A `--root` package
    belongs under a root of its own, synced with that `--root`.
  - A package synced through a different spelling of its directory (a
    symlinked path, say) does not recognise its old links as its own, so
    they are not pruned. That fails safe, as an under-prune, and the link
    stays removable by `unlink`.
  - A new row nested under a pruned row's target still refuses, because
    the link half is planned before the prune runs. `hapi unlink` first.
- **Neutral**
  - `HAPI_PACKAGE_ROOTS` is a second environment variable beside
    `HAPI_ALLOWED_ROOTS`, with a different meaning: one says where to
    read, the other where writes may go.

## Alternatives considered

- **Scan the current directory**, stow-style, with no configuration.
  Rejected: an unpacked tarball or a cloned repo becomes links in `$HOME`
  because the shell happened to be there.
- **A `--from <dir>` flag.** Rejected for now as more surface than the
  dogfood case needs. The variable covers recovery, and a flag can be
  added later without breaking it.
- **Trail-recovery as the source, or sync the trail's packages too.** It
  fails closed (zero packages) on a wiped trail, the case recovery exists
  for, and it cannot know a package's scope without re-deriving it from
  `abs_target` and re-granting it. Report-only keeps the information
  without the risk. An additive `manifest_path` trail field was weighed
  for this and dropped: it would only name what the report already names.
- **`--force` on `sync` meaning what it means on `link`** (overwrite, and
  lifting the prune limit). Rejected: one flag would then authorize two
  unrelated destructive acts, and `sync` would stop being the
  non-destructive verb.
- **Other limits.** A fixed count (more than 3) ignores package size, and
  "any prune needs `--force`" makes `--prune` alone a preview. More than
  half catches the accident the limit exists for and lets the common case
  through.
