# hapi — Roadmap

> **Forward-looking only.** Every item on this page is work that has
> not shipped. Shipped work lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md); the frozen v1.0 contract
> lives in [`release-notes/1.0.0.md`](release-notes/1.0.0.md); live
> state lives in [`state.md`](state.md). When an item ships it is
> **deleted** from here, not struck through.

## Status

- **Shipped: 1.6.0** — `--absolute` on `link`, `adopt` and `sync`:
  absolute link targets on opt-in, with either shape counted as hapi's
  link by every verb, and `"shape":"absolute"` in the trail (ADR 0003 and
  ADR 0002, 1.6.0 addenda). Its P(-1) is the *1.6.0 addendum* of
  [`../audit/2026-10-28-audit.md`](../audit/2026-10-28-audit.md). Before it,
  1.5.0 added the script-facing flags (`status --quiet`,
  `checkpoint --label`, `rollback --to` / `--steps`), 1.4.0 recorded and
  removed the directories `link` made, 1.3.0 added no-package `sync` and
  `--prune`, and 1.2.x moved argument parsing to cmdit.
- **Next: 1.7.0 — `hapi fmt`** (below), the last planned 1.x minor.
- **1.7.0** — the rest of v1.x's additive work. The command surface, ADR 0001's schema and ADR 0002's line
  shape stay frozen throughout; everything here is additive.
- **Gated** — work that waits on something outside hapi, scheduled when
  the gate opens.
- **v2.0** — candidates that *must* earn a major bump because they break
  a frozen surface. None scheduled.

## How the 1.x line is cut

- **One theme per minor.** A minor adds caller-visible surface (a verb
  form, a flag, an additive trail field). Its `.x` patches carry fixes
  only: a `1.N.x` adds nothing.
- **Order: dependency first, then dogfood pressure.** cmdit went first
  (1.2.0) because every later flag registers through it; sync's two
  dogfood issues went next (1.3.0), then `created_dir` (1.4.0), the
  script-facing flags (1.5.0) and `--absolute` (1.6.0).
- **Standing obligations, per release** (CLAUDE.md, not repeated in each
  section): a P(-1) re-run when the release touches a path argument, a
  syscall, the capability surface or the trail format (each section
  says whether it does). A [`../benchmarks.md`](../benchmarks.md) row
  when it touches `link` / `audit` / `fs_link` / the parser. Both
  suites run on x86_64, aarch64 and agnos.

---

## 1.7.0 — `hapi fmt`

**P(-1): no** (it writes only the manifest, through the existing writer). A manifest
canonicalizer / formatter. Ships in v1.x **only if** its output equals `hapi_mf_canonicalize`'s
bytes, so the audit-trail manifest hash does not change. If a richer canonical form is needed, it
crosses into v2.0. It must keep the body below `---` byte for byte (ADR 0001, 1.1.1 addendum).

---

## Gated — scheduled when the gate opens

Each lands in whichever 1.x minor is next when its gate opens. None blocks the plan above.

- **`hapi adopt` on agnos** — *gate: agnos ext2 rename-over* (F-059, accepted —
  [`issues/2026-10-28-adopt-on-agnos-kernel.md`](issues/2026-10-28-adopt-on-agnos-kernel.md);
  filed 2026-10-28 in agnos as
  `docs/development/issues/2026-10-28-ext2-rename-cannot-replace-an-existing-file.md`). hapi's half:
  open the lock with `O_DIRECTORY`, and lock somewhere agnos flock#59 accepts. That is a directory
  if the kernel adds it, otherwise a regular lock file — which means deciding how `check` treats
  that file. Confirm on a QEMU-booted kernel; mirshi cannot see this class.
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
