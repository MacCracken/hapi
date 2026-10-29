# hapi — Roadmap

> **Forward-looking only.** Every item on this page is work that has
> not shipped. Shipped work lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md); the frozen v1.0 contract
> lives in [`release-notes/1.0.0.md`](release-notes/1.0.0.md); live
> state lives in [`state.md`](state.md). When an item ships it is
> **deleted** from here, not struck through.

## Status

- **Shipped: 1.7.1** — the P(-1) sweep after 1.7.0
  ([2026-10-29 audit](../audit/2026-10-29-audit.md)). The resolver had
  dropped the first byte of every relative symlink text since 1.1.1
  (F-065), which left the capability boundary open for relative links.
  1.7.1 repairs every tier the audit found, F-064 – F-116, and closes F-006
  (`link` records links the trail lost). Before it, 1.7.0 added
  `hapi fmt`, 1.6.0 `--absolute`, 1.5.0 the script-facing flags, 1.4.0
  `created_dir`, 1.3.0 no-package `sync` and `--prune`, and 1.2.x moved
  argument parsing to cmdit.
- **Next: nothing scheduled.** What remains before v2.0 is the **gated**
  work, and the few things 1.7.1 **accepted** rather than fixed. Both are
  below. A 1.x minor is cut when a gate opens or dogfood pressure arrives.
- **v2.0** — candidates that *must* earn a major bump because they break
  a frozen surface. None scheduled.

## How the 1.x line is cut

- **One theme per minor.** A minor adds caller-visible surface (a verb
  form, a flag, an additive trail field). Its `.x` patches carry fixes
  only: a `1.N.x` adds nothing.
- **Order: dependency first, then dogfood pressure.** cmdit went first
  (1.2.0) because every later flag registers through it; sync's two
  dogfood issues went next (1.3.0), then `created_dir` (1.4.0), the
  script-facing flags (1.5.0), `--absolute` (1.6.0) and `hapi fmt`
  (1.7.0).
- **Standing obligations, per release** (CLAUDE.md, not repeated in each
  section): a P(-1) re-run when the release touches a path argument, a
  syscall, the capability surface or the trail format (each section
  says whether it does). A [`../benchmarks.md`](../benchmarks.md) row
  when it touches `link` / `audit` / `fs_link` / the parser. Both
  suites run on x86_64, aarch64 and agnos.

---

## Accepted in 1.7.1 — open to a later 1.x minor

The 2026-10-29 audit's few findings that need a design choice or new
surface, rather than a fix. They are recorded in the audit file's
*Accepted boundaries*.

- **`rollback --dry-run` does not model its own earlier reversals**
  (finding 51). Its counts can differ from the real run's when one
  reversal makes another possible. A faithful forecast needs a planner
  that applies reversals in memory.
- **An adopt reversal interrupted mid-way** (231). The rerun calls the half
  state "already at expected state". Prevention is ADR 0004's intent record
  (v2.0, below).
- **A trail path that is not valid UTF-8** (84). It is written as raw
  bytes, which a strict JSON reader rejects. Escaping it changes how hapi
  reads it back.
- **agnos: `fsync` is a global `sync`** (122). Its −1 reports a failure
  that may not concern the trail, and agnos needs a per-file fsync.
- **`$HOME` reached through a symlink** (20). Link texts climb out of
  `$HOME` and back in by the symlink's name. That is ADR 0003's
  physical-parent rule, working as designed.
- **`/proc` magic links** (9). They resolve by their text, as every link
  does; the kernel follows them to the object.
- **The directories of a link removed by a run that died before its
  `op:unlink`** (230). The rerun retires the entry, but an absent link's
  directories carry no proof they are still hapi's (the 1.4.0 rule).
  F-116 narrows the window to one row. Closing it needs the pending
  removal recorded before the `unlink(2)`.

---

## Gated — scheduled when the gate opens

Each lands in whichever 1.x minor is next when its gate opens.

- **`hapi adopt` and `hapi fmt` on agnos** — *gate: agnos ext2 rename-over* (F-059, accepted —
  [`issues/2026-10-28-adopt-on-agnos-kernel.md`](issues/2026-10-28-adopt-on-agnos-kernel.md);
  filed 2026-10-28 in agnos as
  `docs/development/issues/2026-10-28-ext2-rename-cannot-replace-an-existing-file.md`). hapi's half:
  open the lock with `O_DIRECTORY`, and lock somewhere agnos flock#59 accepts. That is a directory
  if the kernel adds it, otherwise a regular lock file — which means deciding how `check` treats
  that file. `fmt` (1.7.0) rewrites through the same lock and rename, so it fails safe there
  the same way and opens with the same fix. Confirm on a QEMU-booted kernel; mirshi cannot see
  this class.
- **mirshi kernel fidelity** — *gate: mirshi matching agnos on four calls* (filed 2026-10-28 in
  mirshi's `docs/development/roadmap.md`, § *Open defects — kernel fidelity*, items 1–4). hapi's
  half: move `MIRSHI_REF` in `scripts/build-mirshi.sh`, then check that `tests/agnos.tcyr` still
  passes under the stricter mirshi. Its long-symlink case and the manifest round trip become
  meaningful there.
- **mirshi envp** — *gate: mirshi staging the kernel's `HOME=/ PWD=/`* (same section, item 5).
  hapi's half: widen `scripts/agnos-smoke.sh` check 2 from "the env gap is diagnosed" to running
  the shipped binary's verbs.
- **NFS homes** — *gate: someone running hapi on one.* Unconfirmed: flock on NFS is emulated with
  fcntl locks, an exclusive lock needs a writable fd, and the manifest lock is a directory fd. So
  `adopt` likely fails closed there (2026-10-28 audit, *Accepted boundaries*). If it does, the lock
  file from the agnos item above covers it too.
- **`hapi merge <pkg>`** — *gate: a stock-template-version data model.* A speculative 3-way merge
  driver for drifting-upstream templates (hyprland-class); Tier-3 in
  [`issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md`](issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md).
  New verbs append to cmdit's registration order.
- **`docs/architecture/001-upstream-drift-pattern.md`** — *gate: a second drifting-upstream
  consumer* (likely sway / fish / kitty when an upstream stock-template rewrite drops). Formalizes
  the audit + merge workflow; Tier-2 from the same archived issue.

---

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
- **An un-escape in the manifest parser.** The parser keeps a `\` as
  written: `\"` reads as the two bytes `\"`, so no value can hold a bare
  quote, and the manifest writer refuses to write a quote or a backslash
  at all (F-021). The canonical form
  escapes every `\` again, so `hapi fmt` refuses a value with a backslash
  outright. An un-escape changes how existing manifests parse, which is a
  major bump. Once it lands, `fmt` can format those values too.
- **`hapi fmt` that keeps comments.** 1.7.0 writes exactly the canonical
  bytes, so comments in the header cannot survive and `fmt` refuses to
  drop them without `--force` (ADR 0008). Keeping them needs a richer
  canonical form than the hash's, attaching comments to the rows they
  precede, which the 1.7.0 roadmap reserved for v2.0.
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

- **`hapi sync --prune` as default-on**. If the 1.3.0 opt-in
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
