# hapi — Roadmap

> Forward-facing milestone plan through v1.0. State lives in
> [`state.md`](state.md); shipped milestones live in
> [`../../CHANGELOG.md`](../../CHANGELOG.md). This file is the
> sequencing of what's still ahead — what ships, in what order,
> against what dependency gates.

## v1.0 criteria

The hapi v1.0 contract: full CRUD parity with GNU stow plus an
auditable rollback story, dogfooded on the maintainer's own dotfiles.

- [ ] Command surface frozen — `link` / `unlink` / `adopt` / `sync` /
      `list` / `status` signatures stable
- [ ] `hapi.cyml` manifest schema documented and frozen
- [ ] Audit-trail format documented and frozen (rollback compatibility)
- [ ] Test coverage: every command's happy path + conflict path +
      capability-denied path; 100+ assertions
- [ ] Benchmarks captured in `docs/benchmarks.md` for `sync` on a
      realistic 100-package home
- [ ] Maintainer's dotfiles managed by hapi for at least one release
      cycle (real-world dogfood)
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`) — path
      validation, symlink loop, TOCTOU, capability boundary

## Upcoming milestones

### M5 — `list` + `sync` + trail management (v0.6.0)

- `hapi list` — show all packages with their link counts and
  capability scope
- `hapi sync` — re-apply every package's manifest (idempotent; no-op
  when state matches)
- `hapi status` — drift between manifest and actual symlink state
  (which links are missing, which point elsewhere)
- `hapi checkpoint` — append a `rollback-marker` entry to the
  audit trail (carried forward from M3 — the marker *machinery*
  shipped in M3 via `audit_append_rollback_marker_r` and
  `rollback`'s walk-to-marker logic, but the user-facing verb
  to drop one lives here alongside the other trail-management
  surface)
- `hapi check <pkg> --strict` — like `inspect`, but unknown
  manifest sections / keys become hard errors (carried forward
  from M1 — the lenient parser tolerates additive growth; the
  strict mode is the CI / lint surface)
- **Dep gate**: M3 (shipped).
- **Acceptance**: `sync` on a clean working tree produces no audit
  entries (idempotent).

### M6 — Capability gate + non-`$HOME` roots (v0.7.0)

- `--root <path>` flag opens a non-default root, gated by an
  explicit capability check (kavach integration when available;
  inline-check pattern until then)
- `--dry-run` flag — show what would change without writing
- ADR: capability model (`docs/adr/0005-capability-bounded-roots.md`)
- **Dep gate**: when kavach exposes a stable capability API; until
  then, a CLI-level allowlist.
- **Acceptance**: attempt to `link` outside `$HOME` without
  `--root` fails fast; with `--root /etc/myproject` succeeds when
  capability is granted.

### M7 — Dogfood + harden (v0.9.0)

- Maintainer's actual dotfiles migrate to hapi packages
- One release cycle passes with hapi as the dotfile mgr
- All real-world bugs / surprises filed in `docs/development/issues/`
  and resolved
- P(-1) hardening pass complete — security audit doc filed
- 3-point benchmark trend in `docs/benchmarks.md`
- **Manifest-hash canonicalization migration** (carried forward
  from M2 — ADR 0002 reserves the `sha1:` → `sha1c:` prefix
  swap for v1.0). The v0.x audit hash is over raw file bytes,
  so a cosmetic edit (trailing newline, comment change)
  produces a different hash. The canonical variant hashes the
  parsed-and-re-serialized manifest so semantically-identical
  manifests collide. Migration: read both prefixes during the
  M7 → M8 window; write only `sha1c:` from M8 forward; the
  `Breaking` lives on the prefix swap, not on the surrounding
  line format.

### M8 — v1.0.0

- API frozen, schema frozen, audit-trail format frozen
- CHANGELOG `Breaking` section for the freeze (no signature changes —
  the freeze is the contract change)
- v1.0.0 cut

## Out of scope (for v1.0)

The list keeps future contributors from adding to v1.0 by accident.
First half is original-design exclusions; second half is items
explicitly deferred by an ADR or implementation decision during
prior milestones, with the rationale that the v1.0 surface is
better without them.

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

Each entry cites the ADR or doc that documented the deferral so
the call can be revisited with full context post-v1.0.

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

Items hapi needs from sibling repos but doesn't block on (we
have working magic-number workarounds today; landed wrappers
become a quality-of-life patch).

- **`sys_rename` stdlib wrapper** — proposed in
  [`cyrius/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md).
  Hapi calls `syscall(82, ...)` directly in adopt + manifest_write.
- **`sys_fsync` / `sys_fdatasync` stdlib wrappers** — proposed in
  [`cyrius/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md).
  Hapi calls `syscall(74, fd)` in `_hmw_write_atomic`.
- **kavach capability API** — M6 gate. Until kavach exposes a
  stable surface, M6 ships with a CLI-level allowlist.

## Cross-references

- [`state.md`](state.md) — live status
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history,
  including the shipped M0 → M4 narrative
