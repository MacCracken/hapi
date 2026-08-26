# hapi — Roadmap

> Forward-looking plan **post-v1.0**. The v1.0 contract is
> locked at [`release-notes/1.0.0.md`](release-notes/1.0.0.md);
> this file is the v1.x maintenance bucket plus the
> v2.0 Breaking-candidate bucket. v1.0 is the third leg of the
> AGNOS terminal-aesthetics set alongside `commandress`,
> `darshini`, `BannerManor`, and `iam`.

## Status

- **v1.0.0** shipped 2026-05-23 ✅
  ([release notes](release-notes/1.0.0.md))
- **v1.x** — additive growth, internal swaps, doc commitments;
  no caller-visible breaking change.
- **v2.0** — candidates that *must* earn a major bump because
  they break a frozen surface. None scheduled.

⚠ **The 1.0.x hardening arc is open** (below, ahead of the v1.x
bucket). The 2026-08-25 P(-1) sweep fixed six HIGH defects in 1.0.5 and
left **twenty findings live in the shipped tree** — three of them Tier 1,
where the failure is silent data loss or a wrong destructive action.
Additive v1.x work is on hold behind that arc's exit criteria: growth
does not resume while `rollback` can still reverse the wrong window.

The M0 → M8 milestone arc is closed. Future work is sized in
terms of *what bucket it belongs to*, not which sprint it
runs in.

## v1.0.x — hardening arc (open from the 2026-08-25 P(-1) sweep)

> **This bucket is repairs, not growth.** The 1.0.5 sweep
> ([`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md))
> fixed six HIGH defects and left **twenty findings open in the shipped
> tree**. They are all contract-safe — none needs a major bump — so they
> belong to the 1.0.x patch line, ahead of anything in the additive
> v1.x bucket below. Ordering is by blast radius, not by effort.

### Tier 1 — silent data loss or a wrong destructive action

- **F-007 · the trail reader's 256 KB head cap** — `audit_read` reads
  the first 256 KB of the trail, so once it outgrows that, `rollback`
  cannot see the most recent checkpoint marker, falls back to
  `start=0`, and reverses the *oldest still-live* links — destroying
  settled dotfiles — while exiting 0. Roughly 590–900 entries on a
  realistic `$HOME`. Fix with a size-derived read; land **F-016** (an
  interior malformed line must refuse, not be silently skipped) and
  **F-017** (an unreadable trail is an error, not "empty") in the same
  function while it is open.
  → [`issues/2026-08-25-trail-reader-head-cap.md`](issues/2026-08-25-trail-reader-head-cap.md)
- **F-012 · the unlocked manifest read-modify-write** — concurrent
  `hapi adopt` commits the renames, the symlinks and the audit entries
  while silently dropping manifest rows, so hapi's declarative state
  stops describing the filesystem and `status` cannot see the orphans.
  Needs `flock` plus a pid-unique `O_EXCL` tmp name. **F-021** (no TOML
  escaping on the written row) and **F-028** (a SIGKILL mid-`adopt`
  leaves the file outside `$HOME` with nothing recording it) are the
  same write path.
  → [`issues/2026-08-25-manifest-write-integrity.md`](issues/2026-08-25-manifest-write-integrity.md)
- **F-015 / F-002 · per-component symlink resolution** — a symlinked
  *intermediate* component of an ordinary `$HOME` target escapes the
  scope on a plain `hapi link`, no flag involved, and `--force` then
  deletes the file outside `$HOME`. Now hapi-owned work: the kavach dep
  gate is void (see below), and `hapi_readlink` — the primitive it needs
  — is portable across all three targets as of 1.0.4. The constraint
  that makes this an arc rather than a patch: four verbs prove ownership
  by recomputing `fsl_compute_relative` and byte-comparing, so changing
  the resolver changes what all four compare.
  → [`issues/2026-05-23-cap-check-symlink-escape.md`](issues/2026-05-23-cap-check-symlink-escape.md)

### Tier 2 — hapi reports a world that is not there

- **F-022** — `link` creates dangling symlinks without probing the
  source, and `status` (the designated post-recovery source of truth)
  calls them OK. GNU stow probes; hapi does not.
- **F-023** — `hapi list` overcounts live links after a `--force`
  takeover, claiming two packages own one symlink.
- **F-024** — an unnormalized package-dir argument breaks idempotency:
  `hapi link .` writes a `./`-bearing symlink that every later canonical
  run calls a conflict, and `sync` — whose contract *is* idempotence —
  then refuses with exit 1.
- **F-026** — `hapi sync --backup-to` is a no-op the guides and `--help`
  both advertise; the snapshot branch cannot fire on `sync`.
- **F-025** — `package.ignore` is parsed, printed back by `inspect` and
  folded into the hash, but never applied. Honouring it is a **v2.0**
  change (it alters what a directory row materializes); 1.0.x ships the
  documentation and a strict-mode warning.
  → [`issues/2026-08-25-reporting-and-idempotency.md`](issues/2026-08-25-reporting-and-idempotency.md)

### Tier 3 — hardening, small and self-contained

- **F-018** — the audit entry is written *after* the mutation and never
  fsynced, so a failed append leaves an orphan symlink no recovery verb
  can see.
- **F-019** — `--root` / `--backup-to` swallow the next argv token even
  when it is a flag, so `--root --dry-run pkg` consumes the flag as the
  value.
- **F-020** — an unvalidated `[package].name` is interpolated into the
  `--backup-to` destination, so a hostile *package* — not the user —
  picks where the bytes land.
- **F-029** — created parent directories use a hardcoded 0700 that
  ignores umask, and are never removed on unlink/rollback.
- **F-032** — a manifest target ending in `/` fails the symlink but
  leaves the directory hapi created behind.
- **F-033** — `hapi inspect` parses no flags, so any flag on it exits 1
  rather than the 2 ADR 0005 specifies.

### Target-conditional — blocked on infrastructure

- **F-027** (`_fsl_getcwd` returns `"."` on agnos, so a relative
  package-dir argument yields a non-absolute `abs_source` in the trail)
  and **F-031** (`O_NOFOLLOW` is dropped by the agnos `file_open`
  bridge, so F-003's TOCTOU defence does not exist there) cannot be
  reproduced or regression-tested without an **agnos/mirshi CI runner**.
  Until one exists the audit trail must read *unverified on agnos*
  rather than *clean*. The runner is the blocking item, not the fixes.

### Arc exit criteria

The 1.0.x hardening arc closes when Tier 1 is empty, Tier 2 is either
fixed or documented as intended behaviour, and a P(-1) re-walk over the
repaired write paths finds nothing new. Only then does the additive
v1.x bucket below reopen.

## v1.x — maintenance & additive growth

Each item is additive (no caller-visible contract change). Roll
into v1.1, v1.2, … as work lands. None block each other;
ordering is driven by upstream readiness + dogfood pressure.

### Internal improvements (no API change)

- ~~**kavach migration** — swap the env-var allowlist inside
  `src/cap.cyr` for the kavach capability service when its stable API
  ships~~ **— withdrawn 2026-08-25; the dependency does not exist.**
  kavach is at 3.12.3, long past stable, and is a *sandbox execution*
  framework: ten backends, strength scoring, an externalization scanner
  pipeline, a credential proxy, an HMAC audit chain. Its entire public
  path-facing surface is `kavach_path_exists` — there is no
  `cap_check(scope, action)`, none is planned, and adopting a
  process-sandboxing framework would collide with CLAUDE.md's
  no-process-spawning rule. **F-002 is hapi-owned work** and has moved
  to the 1.0.x hardening arc above, re-scoped from *the `--root` value*
  to *every path hapi derives from the scope root*. See the addendum on
  [ADR 0005](../adr/0005-capability-bounded-roots.md).
- ~~**stdlib syscall wrappers** — replace the in-source magic-
  number `syscall(N, ...)` calls (`sys_rename` in
  `adopt` / `manifest_write`, `sys_fsync` / `sys_fdatasync` in
  `_hmw_write_atomic`) with named wrappers~~ **— shipped in
  1.0.2.** Wrappers landed in cyrius 6.2.x; the `HapiSysno`
  stand-in enum is gone. No behavior change on x86_64;
  arch-correct on aarch64 (raw `82`/`74` were x86_64-only).
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

- **`docs/architecture/NNN-upstream-drift-pattern.md`** —
  formalize the audit + merge workflow when a second
  drifting-upstream consumer hits the pattern (likely sway /
  fish / kitty when an upstream stock-template rewrite drops).
  Tier-2 from the archived issue.
- **`docs/benchmarks.md` trend rows** — append a row on every
  release that touches `cmd_link.cyr` / `audit.cyr` /
  `fs_link.cyr` / the manifest parser. Regression gate per
  the file: > 2× cold-time jump or any non-zero warm audit
  growth.

### Upstream pendings

Items hapi needs from siblings; QoL patches when they land,
not blockers.

- ~~**`sys_rename` / `sys_fsync` / `sys_fdatasync` stdlib wrappers**~~
  **— landed in cyrius 6.2.x, consumed as of hapi 1.0.2.** (Was
  proposed in
  [`cyrius/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-syscalls-at-family-stdlib.md)
  and
  [`cyrius/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md).)
- ~~**kavach capability API** — the stable surface for the
  internal `src/cap.cyr` swap.~~ **— removed 2026-08-25. Not pending:
  not coming.** kavach 3.12.3 is a sandbox *execution* framework, not a
  capability service; there is nothing upstream to wait for. The work
  moved to the 1.0.x hardening arc as hapi-owned. See the
  [ADR 0005 addendum](../adr/0005-capability-bounded-roots.md).
- **cyriusly starship-install non-clobbering fix** — filed at
  [`cyrius/docs/development/issues/2026-05-20-cyriusly-cmdtools-install-clobbers-existing-starship-config.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-20-cyriusly-cmdtools-install-clobbers-existing-starship-config.md).
  Once landed, the caveat-comment in `dotfiles/starship` and
  its `hapi.cyml` companion note can drop.

## v2.0 — Breaking-candidate bucket

Items that **must** wait for a major bump because they break a
v1.0-frozen surface. None scheduled. Each earns a place only
when real consumer pressure demands it; each carries the
rationale that justifies the major bump.

### Manifest-schema growth (ADR 0001 frozen)

- **Glob source in `[[link]]` rows** (`source = "*.zsh"`).
  Field-semantic change: was a path; becomes a glob expanded
  at link time. Interacts badly with audit-trail hashing —
  the manifest hash would change every time source-directory
  contents change, even when the manifest bytes don't. Needs
  an ADR amendment explaining the hash interaction before it
  can ship.
- **Recursive `**` globs and brace expansion in `ignore`**.
  `*` and `?` cover the patterns real dotfile packages need
  today; `**` opens cross-directory expansion questions that
  earn their parser complexity only with demonstrated demand.
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

## v1.0 sign-off (historical)

The v1.0 criteria checklist was fully ticked at the v1.0.0 cut.
See [`release-notes/1.0.0.md`](release-notes/1.0.0.md) for the
full sign-off (command surface, manifest schema, audit-trail
format frozen; test coverage 235 / 65; security audit pass
filed; benchmarks baseline filed; dotfiles dogfooded across
v0.7.0 → v0.9.0). M0 → M8 milestone arc closed 2026-05-23.

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
