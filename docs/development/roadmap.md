# hapi — Roadmap

> **Forward-looking only.** Every item on this page is work that has
> not shipped. Shipped work lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md); the frozen v1.0 contract
> lives in [`release-notes/1.0.0.md`](release-notes/1.0.0.md); live
> state lives in [`state.md`](state.md). When an item ships it is
> **deleted** from here, not struck through.

## Status

- **Current line: 1.0.x** (patch). The v1.0 contract — command surface,
  ADR 0001 manifest schema, ADR 0002 audit-trail format — stays frozen.
- **v1.x** — additive growth, internal swaps, doc commitments; no
  caller-visible breaking change. Nothing blocks it.
- **v2.0** — candidates that *must* earn a major bump because they
  break a frozen surface. None scheduled.

Future work is sized in terms of *what bucket it belongs to*, not which
sprint it runs in.

## Owed now

- **A P(-1) re-walk over the repaired write paths.** Thirteen fixes
  landed across 1.0.9 and 1.0.10, and between them they touched a path
  argument, a syscall and the audit-trail write path — all three of
  CLAUDE.md's re-run triggers. The newest pass on file,
  [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md),
  scanned 1.0.5; the re-walk files as `../audit/YYYY-MM-DD-audit.md`.
  Two accepted boundaries from that pass are still unwritten and belong
  to its Step 6: `hapi checkpoint` is not idempotent (three runs append
  three markers, undocumented in
  [`../guides/checkpoint.md`](../guides/checkpoint.md)), and 1.0.9's
  writer-side torn-tail refusal is absent from ADR 0002's *Crash
  semantics*.

## v1.x — maintenance & additive growth

Each item is additive (no caller-visible contract change). Roll
into v1.1, v1.2, … as work lands. None block each other;
ordering is driven by upstream readiness + dogfood pressure.

### Additive surface

- **Manifest discovery for no-arg `hapi sync`** — recover
  pkg_dir from a live audit entry so `hapi sync` without
  args can sync every tracked package. Needs either an
  additive trail field (`manifest_path`) or a tree-walk
  heuristic. The signature stays unchanged — no arg becomes
  legal. **Dogfood pressure (2026-05-24):** a drive-move
  recovery had to loop over packages by hand, and the wiped
  trail proved trail-recovery fails closed at bootstrap
  (zero packages found exactly when recovery matters most) —
  prefer the tree-walk / root-scan as the *primary* mechanism,
  trail-recovery only as augmentation. See
  [`issues/2026-05-24-no-arg-sync-bootstrap-recovery.md`](issues/2026-05-24-no-arg-sync-bootstrap-recovery.md).
- **`created_dirs` on `op:link` entries** — record the parent
  directories `link_create` had to make, so `unlink` / `rollback` can
  remove exactly those and nothing else. Today they are deliberately
  left behind (1.0.9, F-029): the trail records the symlink, not the
  directories, so any unlink-time prune is an *inference* — and `rmdir`
  can still take out a directory the user made on purpose, or drop a
  mode the user set. On `~/.ssh` that is a security regression hapi
  would have caused while claiming to reverse itself. hapi removes only
  what it created, *with proof*; this field is the proof. Additive per
  ADR 0002's growth contract, so v1.x.

### New flags (additive)

- **`hapi status --quiet`** — return 0 unless there's an
  actual error (manifest parse failure, IO error), flipping
  the exit-code semantic for scripted `&&` chains. The v1.0
  workaround is `link --dry-run` per
  [`guides/status.md`](../guides/status.md) *Exit-1 is an
  assertion, not a predicate*; the flag is a post-v1.0
  ergonomic addition if the pattern keeps recurring.
- **`hapi rollback --to <marker>` / `--steps N`** — refine
  the v1.0 no-arg form (walks to most recent marker). Both
  additive; the no-arg form remains the default.
- **`hapi sync --prune` (opt-in)** — emit `op:unlink` for
  trail rows no longer in the manifest. Conservative
  defaults: refuse if the prune count exceeds a threshold
  without `--force`. Tracked at
  [`issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`](issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md).
- **`--absolute` global flag** — opt individual runs into
  absolute symlink targets (vs the v1.0 relative default).
  ADR 0003 reserved.

### New verbs (additive)

- **`hapi merge <pkg>`** — speculative 3-way merge driver
  for drifting-upstream templates (hyprland-class). Needs
  a stock-template-version data model before earning its
  place; Tier-3 in
  [`issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md`](issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md).
- **`hapi fmt`** — manifest canonicalizer / formatter. Ships
  v1.x **if** its output equals `hapi_mf_canonicalize`'s
  bytes (no audit-trail hash change). If a richer canonical
  form is needed, it crosses into the v2 bucket below.

### Documentation commitments

- **`docs/architecture/001-upstream-drift-pattern.md`** —
  formalize the audit + merge workflow when a second
  drifting-upstream consumer hits the pattern (likely sway /
  fish / kitty when an upstream stock-template rewrite drops).
  Tier-2 from the archived issue.
- **`docs/benchmarks.md` trend rows** — append a row on every
  release that touches `src/cmd/link.cyr` / `src/audit.cyr` /
  `src/fs_link.cyr` / the manifest parser. Regression gate per
  the file: > 2× cold-time jump or any non-zero warm audit
  growth. ⚠ **1.0.10 owes one** — it changed `src/fs_link.cyr`
  and `src/cmd/link.cyr`, and the table stops at 1.0.9.

### Upstream pendings

Items hapi needs from siblings; QoL patches when they land,
not blockers.

- **A no-follow open flag on agnos.** agnos's `AO_*` set has no
  no-follow bit, so `hapi_open_nofollow` (`src/agnos_compat.cyr`)
  pre-checks with `readlink` there (1.0.10, F-031). Between the
  readlink and the open nothing proves the two saw the same inode;
  the residual race is an accepted boundary until the kernel grows the
  flag, at which point the agnos arm collapses to the atomic
  Linux/macOS shape. File against agnos, not hapi.
- **envp for mirshi's child process.** mirshi passes none, so `getenv`
  returns null under it and no scope-rooted verb is reachable — which
  bounds what `scripts/agnos-smoke.sh` can exercise. Real agnos stages
  `HOME=/ PWD=/` at exec, so this is a supervisor gap. File against
  mirshi, not hapi.

## v2.0 — Breaking-candidate bucket

Items that **must** wait for a major bump because they break a
v1.0-frozen surface. None scheduled. Each earns a place only
when real consumer pressure demands it; each carries the
rationale that justifies the major bump.

### Manifest-schema growth (ADR 0001 frozen)

- **Honour `package.ignore`.** It is parsed, validated, echoed by
  `hapi inspect` and folded into the `sha1c:` manifest hash — and no
  verb applies it (F-025). ADR 0001 marks it **RESERVED, NOT YET
  HONOURED** and points here. Honouring it changes what a directory row
  materializes and how many audit entries a row writes, both frozen at
  v1.0, so it earns the major bump. Intended semantics per ADR 0001:
  source side only, POSIX `fnmatch(3)` (`*`, `?`, `[abc]`), applied to
  `[[link]]` rows that target a directory.
- **Recursive `**` globs and brace expansion in `ignore`** — a
  follow-on to the above, not a substitute for it. The fnmatch subset
  ADR 0001 specifies is what ships first; `**` opens cross-directory
  expansion questions that earn their parser complexity only with
  demonstrated demand.
- **Glob source in `[[link]]` rows** (`source = "*.zsh"`).
  Field-semantic change: was a path; becomes a glob expanded
  at link time. Interacts badly with audit-trail hashing —
  the manifest hash would change every time source-directory
  contents change, even when the manifest bytes don't. Needs
  an ADR amendment explaining the hash interaction before it
  can ship.
- **Per-row link attributes** (e.g. `mode = "copy"` for the
  rare case where a copy beats a symlink). ADR 0001 left
  headroom; a v2 amendment specifies the per-attribute
  semantics and the audit-trail interaction.
- **Per-row `--source <path>` for `adopt`** — opt into
  nested layouts (`~/.config/zsh/x` → `pkg/config/zsh/x`).
  If purely a new CLI flag, it's v1.x; if it changes the
  derived source-name algorithm, it lands in v2 to keep
  ADR 0004's contract honest.

### Audit-trail format growth (ADR 0002 frozen)

- **`hapi trail compact`** — collapse a window of
  link / unlink / re-link entries to their net effect.
  Breaking because the trail's append-only contract is
  load-bearing for rollback correctness; needs its own ADR
  defining compaction markers + rollback semantics across the
  new boundary.

### Adopt crash-atomicity (ADR 0004 revision)

- **An intent record written before the rename.** `adopt` commits the
  filesystem move before the manifest row and the trail entry, so an
  interrupt in that window strands the user's dotfile in the package
  with nothing recording it (F-028). `hapi check` **detects** it — it
  walks the package directory and reports the orphan — but prevention
  needs `adopt` to become recoverable, which changes the operation's
  shape and therefore ADR 0004's *single atomic entry* decision. Earns
  the major bump.

### Default-behavior changes

- **`hapi sync --prune` as default-on**. If the v1.x opt-in
  flag earns universal adoption, flipping the default is a
  Breaking change — script callers may have relied on the v1.0
  no-prune behavior.
- **`--absolute` as the default**. Analogous; ADR 0003
  default flip.

## Out of scope (permanent)

Items that don't earn a place no matter the version.

- **hoosh-assisted conflict resolution** — possibly
  interesting later as a separate tool; out of hapi's lane.
- **GUI front-end** — never. CLI only.
- **Cross-machine dotfile sync** — different concern; hapi
  manages *placement*, not *content distribution*. Consume
  git / rsync / syncthing as the transport layer.
- **Network operations** — no fetch, no push, no remote
  anything.
- **Encrypted secrets management** — consume `sigil` in a
  future sibling tool if needed.
- **Per-host manifest variants** — a manifest is a manifest.
  Per-host needs go in per-host packages. No template engine,
  no conditionals.

## Cross-references

- [`state.md`](state.md) — live state (version, source layout,
  test count, audit-trail surface)
- [`release-notes/1.0.0.md`](release-notes/1.0.0.md) — the
  v1.0 contract
- [`issues/`](issues/) — open issues + `archived/` for closed ones
- [`../audit/`](../audit/) — security audit findings
- [`../adr/`](../adr/) — design records (all five frozen at v1.0)
- [`../benchmarks.md`](../benchmarks.md) — `sync` baseline + trend
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history