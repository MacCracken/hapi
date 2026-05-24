---
name: hapi Documentation Health
description: Living state of doc currency in the hapi repo — fresh / stale / archived / open-question, refreshed as docs are touched
type: state
---

# Documentation Health — hapi

> **Last refresh**: 2026-05-24 (**1.0.x-final arc.** Filed two issues (`no-arg-sync-bootstrap-recovery`, `audit-trail-lost-on-state-dir-wipe`). Added `docs/audit/README.md` (audit-arc convention + index) and `docs/audit/2026-05-24-audit.md` (1.0.x-final P(-1) re-walk; F-006 accepted boundary). Refreshed CHANGELOG Unreleased, state.md (242/66 tests, `HapiSysno` enum, F-006 recovery boundary), roadmap (no-arg-sync dogfood note). **Prior — 2026-05-23 post-v1.0 stale-sweep:** README.md rewritten from scaffold-era language to the v1.0 surface. Eleven guides scrubbed of milestone (`M2`/`M5`/`M6`) and version-bound (`v0.4.0`, `v0.7.0`) narrative — replaced with timeless behavior. CLAUDE.md P(-1) recast as a standing process. state.md command-surface table dropped the M-shipped column; "M7 onward fills" rewritten as the post-v1.0 implementation backlog. **roadmap.md fully rewritten** — M0–M8 milestone narrative replaced with a v1.x maintenance bucket + v2.0 Breaking-candidate bucket.) | **Refresh cadence**: when docs are touched, update the affected row. Opportunistic, not periodic.
> **Scope**: This repo only (`hapi`) — the entire `docs/` tree plus root-level files (README, CHANGELOG, CLAUDE.md, VERSION, LICENSE, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, cyrius.cyml). Per-stdlib-dep docs live in `cyrius/`; cross-repo state lives in [`development/state.md`](development/state.md), not here.
>
> **Convention adopted from agnosticos**: pattern mirrors [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md) (small-repo variant). Per `first-party-documentation.md § Development Docs`, the ledger lives at `docs/` root (not `docs/development/`) because its scope is the whole tree. Hapi's doc tree is ~34 markdown files (vs cyrius's ~105) so the tier structure here is leaner.

This is a **ledger**, not a one-time audit. Rewrite-in-place as docs change.

---

## At a glance — 2026-05-23 inventory (v1.0.0 shipped; contract frozen)

**44 markdown files** across the repo (root + docs tree) — the
2026-05-24 1.0.x-final arc adds two issues, `docs/audit/README.md`,
and `docs/audit/2026-05-24-audit.md` to the v1.0 inventory.

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh / touched in current cycle** | ~38 | state.md / roadmap.md / CHANGELOG / 5 ADRs / **15 guides** / 2 example files / architecture README / adr README / issues README / **audit/ tier: README + 2026-05-23 + 2026-05-24 passes** / **2 new issues (2026-05-24)** / benchmarks.md. |
| 🟡 **Stale — refresh in place** | 0 | None flagged. |
| 🟠 **Read-through outstanding** | 0 | None flagged. |
| 🔵 **Probably evergreen** | ~3 | LICENSE / SECURITY.md / CODE_OF_CONDUCT.md — load-bearing root files; re-read pass at v1.0, not per-release. |
| 📦 **Archive — frozen by design** | 3 | Three M7-resolved issues moved to `issues/archived/` (status-exit-1, upstream-drift, no-backup-to). |
| ❓ **Open strategic question** | 0 | None — four open issues (`sync-prune`, `cap-check-symlink-escape`, `no-arg-sync-bootstrap-recovery`, `audit-trail-lost-on-state-dir-wipe`) are all scoped + deferred (post-v1.0 / kavach / accepted-boundary). |

Numbers approximate; rolls up from the per-tier tables below.

**Why now**: doc-health convention adopted at v0.7.0 alongside the M7 dotfile dogfood + cyrius/agnosticos first-party-documentation alignment. The hapi doc tree has been actively maintained (CHANGELOG canonical per CLAUDE.md, state.md refreshes every release, per-command guide added every milestone) but the *aggregate* currency had no surface — this file is that surface.

---

## Tier 1 — Structural docs (root + `docs/` root)

| File | Last touched | Status | Action |
|---|---|---|---|
| `README.md` | 2026-05-23 | ✅ Fresh | Top-level project README. Rewritten in the post-v1.0 sweep — scaffold-era "Pre-1.0 (0.1.0). No commands implemented yet." replaced with the v1.0 surface (ten verbs, capability boundary, audit trail, dogfood status). Links the v1.0 release notes + the guide / ADR / audit / benchmarks docs. |
| `CHANGELOG.md` | 2026-05-23 | ✅ Fresh | **Source of truth per CLAUDE.md.** Through v0.7.0 (M6 close — `--root` + `--dry-run`); Unreleased section now carries the two M7 Tier-1 doc fixes (status guide clarification + upstream-drift guide). Refreshed every release. |
| `CLAUDE.md` | 2026-05-23 | ✅ Fresh | Process + procedures + project-identity. Post-v1.0 sweep: P(-1) Hardening section recast as a standing process (was "before v0.2.0 first feature cut, and before v1.0" — both events past). Quick-Start scaffold-output line softened. CHANGELOG-Format paragraph already updated at v1.0 cut. |
| `VERSION` | 2026-05-20 | ✅ Fresh | `0.7.0`. Single source of truth; bumped manually in the same commit as the CHANGELOG header. |
| `CONTRIBUTING.md` | (pre-M5) | ✅ Fresh | Scaffolded by `cyrius init`. |
| `SECURITY.md` | (pre-M5) | 🔵 Evergreen | Public reporting policy; re-read pass at v1.0. |
| `CODE_OF_CONDUCT.md` | (pre-M5) | 🔵 Evergreen | Standard text; re-read pass at v1.0. |
| `LICENSE` | (pre-M5) | 🔵 Evergreen | GPL-3.0-only; durable. |
| `cyrius.cyml` | 2026-05-19 | ✅ Fresh | Toolchain pin `6.0.1`. Project manifest. |
| `docs/doc-health.md` | 2026-05-23 | ✅ Fresh | **This file.** v0.9.0 refresh — M7 close. |
| `docs/benchmarks.md` | 2026-05-23 | ✅ Fresh | **New 2026-05-23.** M7 close commitment. First `sync` baseline over a 100-pkg / 350-link synthetic home (cold 72 ms, warm 54 ms with 0 audit growth); methodology + reproduction inlined. Future trend rows fill in when perf-relevant code lands. |

---

## Tier 2 — Architecture (`docs/architecture/`)

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | (pre-M5) | ✅ Fresh | Index + conventions. No architecture notes filed yet — earned when a non-obvious invariant deserves capture. Candidates surfacing from M7: upstream-stock-template drift pattern (per the issues filing 2026-05-20). |

## Tier 2.5 — Security audits (`docs/audit/`)

| File | Last touched | Status | Notes |
|---|---|---|---|
| `2026-05-23-audit.md` | 2026-05-23 | ✅ Fresh | **New 2026-05-23.** P(-1) hardening pass per CLAUDE.md. Files three findings: F-001 HIGH (`--root` `..` bypass — fixed in Unreleased), F-003 LOW (backup-copy TOCTOU symlink race — fixed), F-002 MEDIUM (`--root` symlink escape — deferred to kavach). Accepted boundaries F-004 (audit-trail trust model), F-005 (single-process TOCTOU). |

---

## Tier 2.7 — Release notes (`docs/development/release-notes/`)

| File | Last touched | Status | Notes |
|---|---|---|---|
| `1.0.0.md` | 2026-05-23 | ✅ Fresh | **New 2026-05-23.** First release-notes doc — landed at v1.0.0. Documents the three frozen surfaces, the v1.0-criteria checklist, the post-v1.0-deferred list, and the v0.9.0 → v1.0.0 upgrade contract. |

## Tier 3 — Operational / Development (`docs/development/`)

> **Important framing**: state.md + roadmap.md form the **canonical operational surface**. CLAUDE.md delegates volatile state to state.md; roadmap.md is the milestone-pinning artifact. Both rotate every release; everything else in this tier rotates per-need.

| File | Last touched | Status | Action |
|---|---|---|---|
| `state.md` | 2026-05-23 | ✅ Fresh | **Rotates every release.** v1.0.0 cut + post-v1.0 sweep applied: command-surface table dropped the M-shipped column (the ten verbs are frozen, the milestone heritage now lives in the CHANGELOG); "M7 onward fills" rewritten as the post-v1.0 implementation backlog (kavach migration / stdlib syscall wrappers / no-arg sync discovery). Tests anchored at 235 / 65. |
| `roadmap.md` | 2026-05-23 | ✅ Fresh | **Fully rewritten 2026-05-23 post-v1.0 sweep.** M0–M8 milestone narrative dropped; restructured as v1.x maintenance / additive-growth bucket + v2.0 Breaking-candidate bucket + permanent out-of-scope list + a brief v1.0-sign-off pointer at the release-notes doc. Each v2 candidate carries the rationale that earns it a major bump. |
| `issues/README.md` | 2026-05-20 | ✅ Fresh | Filing conventions for hapi-side dogfood papercuts; severity guide; triage + archival lifecycle; cross-repo upstream-issue pointer. |
| `issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md` | 2026-05-20 | 🟡 Open | Low severity; M7 dogfood papercut. Deferred to post-v1.0 per existing roadmap entry. |
| `issues/2026-05-23-cap-check-symlink-escape.md` | 2026-05-23 | 🟡 Open | **New 2026-05-23.** Medium severity; F-002 from the P(-1) audit. `--root` cap-check is lexical-only; symlinked path components escape. Deferred to the kavach migration per ADR 0005. |
| `issues/archived/2026-05-20-status-exit-1-short-circuits-script-chains.md` | 2026-05-23 | 📦 Archived | Resolved in Unreleased via Tier-1 guide-doc note (`docs/guides/status.md` *Exit-1 is an assertion, not a predicate* section). |
| `issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md` | 2026-05-23 | 📦 Archived | Resolved in Unreleased via Tier-1 new guide `docs/guides/upstream-drift.md`. Tier-2/3 remain post-v1.0 candidates. |
| `issues/archived/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md` | 2026-05-23 | 📦 Archived | Resolved in Unreleased via the `--backup-to <dir>` flag on link / sync / adopt + the new `docs/guides/backup-to.md` guide + ADR 0002 additive-field note for `backup_path`. |

---

## Tier 4 — ADRs (`docs/adr/`)

5 ADRs. **All five frozen at v1.0.0 (2026-05-23).**

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-05-20 | ✅ Fresh | Index covers all 5 ADRs. |
| `template.md` | (pre-M5) | 🔵 Evergreen | Copy-as-starting-point. |
| `0001-hapi-cyml-manifest-schema.md` | 2026-05-23 | ✅ Fresh | **Frozen at v1.0.0.** Manifest schema contract. |
| `0002-audit-trail-format.md` | 2026-05-23 | ✅ Fresh | **Frozen at v1.0.0.** Canonical-hash migration `sha1:` → `sha1c:` documented in the *Hash* table; additive-fields subsection registers `backup_path`. |
| `0003-symlink-target-shape.md` | 2026-05-23 | ✅ Fresh | **Frozen at v1.0.0.** Relative-from-link-parent default; `--absolute` opt-in reserved post-v1.0. |
| `0004-adopt-op-semantics.md` | 2026-05-23 | ✅ Fresh | **Frozen at v1.0.0.** Adopt verb design; atomic single-entry audit + three-step conditional rollback. |
| `0005-capability-bounded-roots.md` | 2026-05-23 | ✅ Fresh | **Frozen at v1.0.0.** `cap_check_root_r(path) -> Result` is the contract; kavach swap is internal. |

---

## Tier 5 — Guides (`docs/guides/`)

13 task-oriented how-tos. Each verb has its own guide; two cross-cutting guides cover the M6 global flags.

| File | Last touched | Status | Notes |
|---|---|---|---|
| `getting-started.md` | 2026-05-23 | ✅ Fresh | Universal onboarding doc. Post-v1.0 sweep: scaffold-era *subcommands land M2+* placeholder layout dropped; replaced with the current `src/cmd/*.cyr` + helper-module set. |
| `inspect.md` | 2026-05-23 | ✅ Fresh | Manifest parse + display. Post-v1.0 sweep: "(`link` does that, M2)" / "(M5)" / "(M6)" forward-references replaced with present-tense pointers to sibling guides. |
| `link.md` | 2026-05-23 | ✅ Fresh | Symlink creation + `--force`. *Preserving the original bytes — `--backup-to`* section + post-v1.0 milestone-ref scrub. |
| `unlink.md` | 2026-05-23 | ✅ Fresh | Trail-driven removal + user-mutation refusal. Post-v1.0 sweep: "(At v0.4.0 there's no per-package directory registry…)" parenthetical rewritten as timeless behavior. |
| `rollback.md` | 2026-05-23 | ✅ Fresh | Reverse-replay + marker semantics. Post-v1.0 sweep: "At v0.4.0..." / "A future hapi rollback --to..." references pointed at the roadmap; markers section now says checkpoint is the entry point (was: "reserved for a later patch"). |
| `adopt.md` | 2026-05-23 | ✅ Fresh | File-into-package move + audit + manifest-edit + rollback. *Preserving the original bytes — `--backup-to`* section + "file-scoped only at v0.5.0" → "file-scoped at v1.0". |
| `checkpoint.md` | 2026-05-23 | ✅ Fresh | Rollback-marker append. Post-v1.0 sweep: "shipped in M3 (v0.4.0); v0.6.0 wires the user-facing verb" → timeless "checkpoint is the user-facing entry point." |
| `status.md` | 2026-05-23 | ✅ Fresh | Drift classifier; *Exit-1 is an assertion, not a predicate* section landed v0.8.0; no other stale references. |
| `list.md` | (M5) | ✅ Fresh | Trail walker; live-link count. (Scanned in the sweep; no stale references found.) |
| `check.md` | 2026-05-23 | ✅ Fresh | Strict-mode manifest validation. Post-v1.0 sweep: "v0.7.x manifest field…v0.6.0 hapi binary" replaced with timeless additive-growth phrasing. |
| `sync.md` | 2026-05-23 | ✅ Fresh | Idempotent re-apply. *Preserving bytes during destructive overwrites* section + post-v1.0 sweep: "At v0.6.0 sync is operationally identical…deferred from this milestone" → timeless behavior + pointer to the open prune-issue. |
| `capability.md` | 2026-05-23 | ✅ Fresh | `--root` flag + `HAPI_ALLOWED_ROOTS` env-var stopgap. Post-v1.0 sweep: "v0.7.0 ships with…" → timeless; added a lexical-only caveat with a pointer to F-001 / F-002 in the audit doc. |
| `dry-run.md` | 2026-05-23 | ✅ Fresh | `--dry-run` flag + composability. Post-v1.0 sweep: "the other M6 global flag" → describes what `capability.md` does. |
| `backup-to.md` | 2026-05-23 | ✅ Fresh | Cross-cutting `--backup-to` guide. Post-v1.0 sweep: "v0.7.0" reader-tolerance note tightened to "pre-v0.8.0". |
| `upstream-drift.md` | 2026-05-23 | ✅ Fresh | hyprland-class merge ritual. No stale references — language was already version-agnostic. |
| `upstream-drift.md` | 2026-05-23 | ✅ Fresh | **New 2026-05-23.** Codifies the hyprland-class audit + merge ritual; lists syntax-shift markers; specifies tracking-note header convention (M7 Tier-1 fix; resolves `issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md`). |
| `backup-to.md` | 2026-05-23 | ✅ Fresh | **New 2026-05-23.** Cross-cutting guide for the `--backup-to <dir>` flag — semantics, filename layout, when to use it, composition with `--dry-run` / `--root`, audit-trail growth note (M7 fix; resolves `issues/archived/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md`). |

---

## Tier 6 — Examples (`docs/examples/`)

Runnable example manifests. One-package set today; grows when new manifest features earn an example.

| Path | Files | Status | Notes |
|---|---|---|---|
| `dotfiles-zsh/` | 4 (hapi.cyml + 3 source files) | ✅ Fresh | Canonical 3-link example. Drives M1–M3 acceptance tests. |

---

## Refresh procedure

When docs are touched:

1. Find the affected row in the relevant tier table.
2. Update **Last touched** to the new date.
3. Update **Status** if the bucket changed.
4. Update **Action** / **Notes** if the next step changed.
5. If a doc moved or was archived, update its row.
6. Re-anchor "Last refresh" date in the header.

When the bucket counts at the top drift by more than ~3 in any cell, refresh the at-a-glance table.

This file's refresh cadence is **opportunistic** (touched when other docs are touched), not periodic.

---

## What this file is NOT

- Not a substitute for [`development/state.md`](development/state.md) (which holds version / test-count / source-line / consumer state).
- Not a CHANGELOG (which records what shipped, not what's stale).
- Not a TODO list (open work lives in [`development/roadmap.md`](development/roadmap.md) and [`development/issues/`](development/issues/)).
- Not a per-doc review log (this is the ledger of where each doc stands, not the per-doc reasoning).

---

## Forward doc-policy commitments

Items that are *scheduled* doc decisions, not stale state. Surfaced here so they aren't forgotten when the trigger date arrives.

| # | Commitment | Trigger | Source | Notes |
|---|---|---|---|---|
| 1 | **`docs/architecture/NNN-upstream-drift-pattern.md`** — formalize the drift-audit pattern in the architecture tier once a second drifting-upstream consumer hits the pattern. | When sway / fish / kitty (or sibling) experiences a stock-template rewrite during dogfood | `issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md` Tier-2 | Tier-1 guide (`upstream-drift.md`) landed 2026-05-23; architecture note follows. |
| 2 | **Re-run P(-1) audit** for v1.0 / on any new code touching paths, syscalls, or the capability surface. | Pre-v1.0 freeze + on touch | [`audit/2026-05-23-audit.md`](audit/2026-05-23-audit.md) sign-off | Standing commitment per CLAUDE.md Process P(-1). |
| 3 | **`docs/benchmarks.md` trend rows** — append a new row each release that touches `cmd_link.cyr` / `audit.cyr` / `fs_link.cyr` / the manifest parser. | On perf-relevant code change | [`benchmarks.md`](benchmarks.md) acceptance gates | First baseline filed 2026-05-23 (v0.9.0); regression gate is "> 2× cold-time jump OR any non-zero warm audit growth." |

---

*Initial scaffold: 2026-05-20 (v0.7.0). Pattern mirrors [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md) small-repo variant. Refresh in place when docs are touched.*
