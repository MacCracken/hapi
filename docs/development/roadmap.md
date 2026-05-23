# hapi — Roadmap

> Forward-facing milestone plan through v1.0. State lives in
> [`state.md`](state.md); shipped milestones live in
> [`../../CHANGELOG.md`](../../CHANGELOG.md). This file is the
> sequencing of what's still ahead — what ships, in what order,
> against what dependency gates.

## v1.0 criteria

The hapi v1.0 contract: full CRUD parity with GNU stow plus an
auditable rollback story, dogfooded on the maintainer's own dotfiles.
**All criteria below were ticked at the v1.0.0 cut (2026-05-23).**

- [x] **Command surface frozen** — `link` / `unlink` / `adopt` /
      `sync` / `list` / `status` / `checkpoint` / `check` /
      `inspect` / `rollback` signatures stable (plus global flags
      `--root` / `--dry-run` / `--backup-to` / `--force` /
      `--strict`). See [`release-notes/1.0.0.md`](release-notes/1.0.0.md)
      *The verb set frozen* table.
- [x] **`hapi.cyml` manifest schema documented and frozen** — ADR
      [`0001`](../adr/0001-hapi-cyml-manifest-schema.md) now carries
      *Frozen at v1.0.0* status.
- [x] **Audit-trail format documented and frozen** — ADR
      [`0002`](../adr/0002-audit-trail-format.md) frozen; canonical
      `sha1c:` hash and additive-growth contract locked. Pre-v1.0
      `sha1:` reader tolerance preserved.
- [x] **Test coverage** — 235 assertions across 65 groups; every
      verb has happy + conflict + capability-denied paths.
- [x] **Benchmarks captured** —
      [`benchmarks.md`](../benchmarks.md) ships the v0.9.0
      baseline (sync over 100-pkg / 350-link home: cold 72 ms /
      warm 54 ms / 0 audit growth).
- [x] **Maintainer's dotfiles dogfooded** — v0.7.0 → v0.8.0 →
      v0.9.0 cycle, multiple boots / reboots confirmed at session
      start.
- [x] **CHANGELOG complete from v0.1.0 onward** — every release
      from the M0 scaffold has a populated section.
- [x] **Security audit pass** —
      [`audit/2026-05-23-audit.md`](../audit/2026-05-23-audit.md)
      filed; F-001 HIGH + F-003 LOW landed in v0.9.0; F-002
      MEDIUM deferred to kavach with documented workaround.
- [x] **All filed issues resolved or explicitly deferred** —
      three archived (status-exit-1, upstream-drift,
      no-backup-to); two open with explicit post-v1.0 deferrals
      (sync-prune, cap-check-symlink-escape).

## Upcoming milestones

### M7 — Dogfood + harden (v0.9.0)

The dedicated "use it for real, fix what breaks, harden what holds"
milestone. Spans the v0.8.x patch series + the v0.9.0 cut.

**Issue repairs** (filed in [`issues/`](issues/) during early
M7 dogfooding; ship the fixes before the v1.0 freeze)

- ✅ **`docs/guides/status.md` clarification** — document that
  `status`'s exit-1-on-drift is for assertion / CI use, and that
  `link --dry-run` is the right pre-flight for `&&` chains.
  Resolved in Unreleased; issue archived at
  [`archived/2026-05-20-status-exit-1-short-circuits-script-chains.md`](issues/archived/2026-05-20-status-exit-1-short-circuits-script-chains.md).
- ✅ **New guide `docs/guides/upstream-drift.md`** — codify the
  audit + merge workflow for upstreams that rewrite their
  stock-config templates every few releases (hyprland-class).
  Resolved in Unreleased; issue archived at
  [`archived/2026-05-20-upstream-stock-template-drift-pattern.md`](issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md).
- ✅ **`--backup-to <dir>` flag** on `link` / `sync` / `adopt` —
  opt-in pre-`--force` snapshot to a user-chosen directory so
  the manual `.pre-hapi.bak` ritual goes away. Audit-trail
  carries the new `backup_path` field additively per ADR 0002's
  growth contract; print-line surfaces the destination.
  Resolved in Unreleased; issue archived at
  [`archived/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md`](issues/archived/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md).

**Hardening**
- ✅ P(-1) hardening pass complete — security audit doc filed
  at [`docs/audit/2026-05-23-audit.md`](../audit/2026-05-23-audit.md)
  covering path traversal, symlink-loop detection, TOCTOU, and
  capability-boundary validation. Repairs landed in Unreleased:
  F-001 (HIGH — `--root` `..` bypass, fixed via lexical
  normalization), F-003 (LOW — backup-copy TOCTOU symlink race,
  fixed via O_NOFOLLOW). F-002 (MEDIUM — `--root` symlink escape)
  deferred to the kavach migration; filed at
  [`issues/2026-05-23-cap-check-symlink-escape.md`](issues/2026-05-23-cap-check-symlink-escape.md).
- ✅ Benchmark baseline in
  [`docs/benchmarks.md`](../benchmarks.md) for `sync` over a
  100-package / 350-link synthetic home; first row landed
  v0.9.0 (cold 72 ms / warm 54 ms / 0 audit growth on a
  Ryzen 7 5800H tmpfs). Future trend rows fill in on
  perf-relevant code changes — `cmd_link.cyr`, `audit.cyr`,
  `fs_link.cyr`, or the manifest parser. Regression gate
  per the file's acceptance section: > 2× cold-time jump or
  any non-zero warm audit growth.

**Audit-format migration**
- ✅ Manifest-hash canonicalization migration `sha1:` → `sha1c:`
  per ADR 0002's reserved prefix swap. Landed in Unreleased.
  Writers emit only `sha1c:` going forward; readers tolerate
  both prefixes during the M7 → M8 window. Canonical form:
  `[package]` fields in fixed order, `[[link]]` rows sorted by
  `target`, no comments, single blank line between sections,
  only `"` and `\` escaped in strings. Cosmetic edits
  (whitespace, comments, row reordering) now produce the same
  hash; semantic edits still diverge. ADR 0002 *Hash* section
  rewritten with the prefix table and the canonical-form rules.

### M8 — v1.0.0 ✅ SHIPPED 2026-05-23

- ✅ Command surface, manifest schema, audit-trail format all
  frozen — ADRs 0001 / 0002 / 0003 / 0004 / 0005 each carry
  *Frozen at v1.0.0 (2026-05-23)* status.
- ✅ CHANGELOG `Breaking` section for the freeze — see the
  `[1.0.0]` entry. (No signature changes; the freeze IS the
  contract change.)
- ✅ Every *v1.0 criteria* checkbox ticked above.
- ✅ v1.0.0 tag cut + release notes published at
  [`release-notes/1.0.0.md`](release-notes/1.0.0.md).

The roadmap.md file from here forward is the **post-v1.0**
roadmap. Items previously sorted into *Deferred during prior
milestones (post-v1.0 candidates)* below are the v1.x backlog;
*Original-design exclusions* remain out of scope.

## Out of scope (for v1.0)

The list keeps future contributors from adding to v1.0 by accident.
First half is original-design exclusions; second half is items
explicitly deferred by an ADR, an issue filing, or an
implementation decision during prior milestones, with the
rationale that the v1.0 surface is better without them.

### Original-design exclusions

- **hoosh-assisted conflict resolution** — interesting later; out
  of scope for v1.0. (When two packages collide, the user resolves
  manually for v1.0.)
- **GUI front-end** — never. CLI only.
- **Cross-machine dotfile sync** — different concern; hapi manages
  *placement*, not *content distribution*. Consume git / rsync /
  syncthing as the transport layer.
- **Network operations** — no fetch, no push, no remote anything.
- **Encrypted secrets management** — out of scope; consume sigil
  in a future sibling tool if needed.
- **Per-host manifest variants** — a manifest is a manifest; if a
  user needs per-host variation, they write per-host packages.
  No template engine, no conditionals.

### Deferred during prior milestones (post-v1.0 candidates)

Each entry cites the ADR or issue file that documented the
deferral so the call can be revisited with full context post-v1.0.

- **Glob-source in `[[link]]` rows** (e.g. `source = "*.zsh"`) —
  deferred per [ADR 0001 § Alternatives](../adr/0001-hapi-cyml-manifest-schema.md).
  Glob expansion at link time interacts badly with audit-trail
  hashing (the manifest hash changes when the source directory
  contents change, even if the manifest didn't). The current
  `ignore` glob list stays glob; `[[link]]` rows stay explicit.
- **Recursive `**` globs and brace expansion in `ignore`** —
  deferred per ADR 0001. `*` and `?` cover the patterns real
  dotfile packages need; `**` opens cross-directory expansion
  questions that don't pay back the parser complexity at v1.0.
- **Per-row link attributes** (e.g. `mode = "copy"` for the rare
  case where a real copy beats a symlink) — ADR 0001 leaves
  schema headroom for additive growth; v1.0 ships with `source`
  and `target` only.
- **Per-row `--source <path>` for adopt** — ADR 0004 picks
  `basename(target)` with leading-`.` stripped as the only v1.0
  in-package source name. A future flag could opt into nested
  layouts (e.g. adopting `~/.config/zsh/x` into `pkg/config/zsh/x`).
- **`hapi fmt`** — a manifest canonicalizer / formatter. ADR 0001
  notes that any future formatter must produce byte-identical
  output for the same logical manifest, or audit-trail hashes
  break. Out of scope for v1.0; the M7 hash-canonicalization
  work is the prerequisite.
- **`hapi rollback --to <marker>` / `--steps N`** — flagged in
  [`docs/guides/rollback.md`](../guides/rollback.md) as the
  post-v1.0 surface refinement. v1.0 ships the no-arg form
  that walks to the most recent marker.
- **No-arg `hapi sync` (sync every tracked package)** —
  deferred from M5. The audit format doesn't carry a manifest
  path, so package-dir recovery would need either a tree-walk
  heuristic up from a live entry's `abs_source` until a
  `hapi.cyml` is found, or an additive `manifest_path` field
  in the trail. Per-package sync ships at v1.0; the no-arg
  form can layer on once one of those discovery paths is
  chosen.
- **`hapi sync --prune` (remove trail rows no longer in manifest)** —
  deferred per
  [`issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`](issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md).
  M7 dogfood papercut with a working full-rotation workaround
  (`unlink + edit manifest + link`); the `--prune` surface is
  a post-v1.0 candidate, possibly default-on at a major bump.
- **`hapi status --quiet` flag** — deferred per
  [`issues/archived/2026-05-20-status-exit-1-short-circuits-script-chains.md`](issues/archived/2026-05-20-status-exit-1-short-circuits-script-chains.md)
  Tier-2. The v1.0 fix is the guide-doc note (Tier-1, landed in
  Unreleased); a `--quiet` flag that flips the exit-code semantic
  is a post-v1.0 ergonomic addition if the pattern keeps recurring.
- **`docs/architecture/NNN-upstream-drift-pattern.md`** —
  architecture-note formalization of the drift-audit workflow
  per
  [`issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md`](issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md)
  Tier-2. Earned when the second drifting-upstream consumer
  hits the pattern (likely sway / fish / kitty when an upstream
  rewrite drops); guide-doc landed in Unreleased, architecture-note
  follows.
- **`hapi merge <pkg>` verb** — speculative 3-way merge driver
  for drifting upstreams per
  [`issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md`](issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md)
  Tier-3. Outside v1.0 scope; needs a data model for
  "stock-template version" before earning its place.
- **`hapi trail compact`** — ADR 0002 notes the trail grows
  monotonically; a compact verb is owed someday. Out of scope
  for v1.0 — the trail's append-only contract is load-bearing
  for rollback correctness, and compaction needs its own ADR.
- **Global `--absolute` link flag** — ADR 0003 chose relative
  symlinks as the v1.0 default. A future CLI flag could opt
  individual runs into absolute targets without baking the
  choice into every manifest. Post-v1.0 if user demand
  appears.

## Upstream dependencies (tracked)

Items hapi needs from sibling repos but doesn't block on — we
have working magic-number workarounds today; landed wrappers
become a quality-of-life patch.

- **`sys_rename` stdlib wrapper** — proposed in
  [`cyrius/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md).
  Hapi calls `syscall(82, ...)` directly in adopt + manifest_write.
- **`sys_fsync` / `sys_fdatasync` stdlib wrappers** — proposed in
  [`cyrius/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md).
  Hapi calls `syscall(74, fd)` in `_hmw_write_atomic`.
- **kavach capability API** — the stable surface that replaces
  the v0.7.0 `HAPI_ALLOWED_ROOTS` env-var stopgap inside
  `src/cap.cyr`. Internal-only refactor when kavach ships
  (`cap_check_root_r(path)` signature unchanged); no caller
  changes, no manifest changes, no audit-format changes. Also
  closes [F-002](../audit/2026-05-23-audit.md) — kavach's
  per-component symlink resolution supersedes the v0.8.x
  lexical-only normalization. Tracked at
  [`issues/2026-05-23-cap-check-symlink-escape.md`](issues/2026-05-23-cap-check-symlink-escape.md).
- **cyriusly starship-install non-clobbering fix** — filed
  upstream at
  [`cyrius/docs/development/issues/2026-05-20-cyriusly-cmdtools-install-clobbers-existing-starship-config.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-20-cyriusly-cmdtools-install-clobbers-existing-starship-config.md).
  Once landed, the caveat-comment baked into
  `dotfiles/starship/.config/starship.toml` (and the matching
  note in `hapi.cyml`) can drop.

## Cross-references

- [`state.md`](state.md) — live status
- [`issues/`](issues/) — open dogfood papercuts + design-gap reports
- [`../doc-health.md`](../doc-health.md) — whole-tree doc-currency ledger
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history
