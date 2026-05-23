---
name: hapi Documentation Health
description: Living state of doc currency in the hapi repo — fresh / stale / archived / open-question, refreshed as docs are touched
type: state
---

# Documentation Health — hapi

> **Last refresh**: 2026-05-23 (Unreleased — M7 sweep: status.md exit-1 clarification, new upstream-drift.md guide, `--backup-to <dir>` flag with new backup-to.md guide + ADR 0002 additive-field note, **manifest-hash canonicalization `sha1:` → `sha1c:`** with ADR 0002 *Hash* section rewrite; three M7 issues archived.) | **Refresh cadence**: when docs are touched, update the affected row. Opportunistic, not periodic.
> **Scope**: This repo only (`hapi`) — the entire `docs/` tree plus root-level files (README, CHANGELOG, CLAUDE.md, VERSION, LICENSE, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, cyrius.cyml). Per-stdlib-dep docs live in `cyrius/`; cross-repo state lives in [`development/state.md`](development/state.md), not here.
>
> **Convention adopted from agnosticos**: pattern mirrors [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md) (small-repo variant). Per `first-party-documentation.md § Development Docs`, the ledger lives at `docs/` root (not `docs/development/`) because its scope is the whole tree. Hapi's doc tree is ~34 markdown files (vs cyrius's ~105) so the tier structure here is leaner.

This is a **ledger**, not a one-time audit. Rewrite-in-place as docs change.

---

## At a glance — 2026-05-23 inventory (M7 issue-repair sweep in Unreleased)

**36 markdown files** across the repo (root + docs tree) — gained
`docs/guides/upstream-drift.md` and `docs/guides/backup-to.md`.

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh / touched in current cycle** | ~31 | M5 / M6 / M7 touched; state.md / roadmap.md / CHANGELOG / 5 ADRs (ADR 0002 gained an additive-field note) / **15 guides** / 2 example files / architecture README / adr README / issues README. |
| 🟡 **Stale — refresh in place** | 0 | None flagged. |
| 🟠 **Read-through outstanding** | 0 | None flagged. |
| 🔵 **Probably evergreen** | ~3 | LICENSE / SECURITY.md / CODE_OF_CONDUCT.md — load-bearing root files; re-read pass at v1.0, not per-release. |
| 📦 **Archive — frozen by design** | 3 | Three M7-resolved issues moved to `issues/archived/` (status-exit-1, upstream-drift, no-backup-to). |
| ❓ **Open strategic question** | 0 | None — remaining M7 issue (`sync-prune`) is post-v1.0 deferred. |

Numbers approximate; rolls up from the per-tier tables below.

**Why now**: doc-health convention adopted at v0.7.0 alongside the M7 dotfile dogfood + cyrius/agnosticos first-party-documentation alignment. The hapi doc tree has been actively maintained (CHANGELOG canonical per CLAUDE.md, state.md refreshes every release, per-command guide added every milestone) but the *aggregate* currency had no surface — this file is that surface.

---

## Tier 1 — Structural docs (root + `docs/` root)

| File | Last touched | Status | Action |
|---|---|---|---|
| `README.md` | (pre-M5) | ✅ Fresh | Top-level project README. Spot-check at v1.0 cut. |
| `CHANGELOG.md` | 2026-05-23 | ✅ Fresh | **Source of truth per CLAUDE.md.** Through v0.7.0 (M6 close — `--root` + `--dry-run`); Unreleased section now carries the two M7 Tier-1 doc fixes (status guide clarification + upstream-drift guide). Refreshed every release. |
| `CLAUDE.md` | 2026-05-20 | ✅ Fresh | Process + procedures + project-identity. Volatile state delegated to state.md per the standards. Updated 2026-05-20 to add `docs/development/issues/` + `docs/doc-health.md` pointers. |
| `VERSION` | 2026-05-20 | ✅ Fresh | `0.7.0`. Single source of truth; bumped manually in the same commit as the CHANGELOG header. |
| `CONTRIBUTING.md` | (pre-M5) | ✅ Fresh | Scaffolded by `cyrius init`. |
| `SECURITY.md` | (pre-M5) | 🔵 Evergreen | Public reporting policy; re-read pass at v1.0. |
| `CODE_OF_CONDUCT.md` | (pre-M5) | 🔵 Evergreen | Standard text; re-read pass at v1.0. |
| `LICENSE` | (pre-M5) | 🔵 Evergreen | GPL-3.0-only; durable. |
| `cyrius.cyml` | 2026-05-19 | ✅ Fresh | Toolchain pin `6.0.1`. Project manifest. |
| `docs/doc-health.md` | 2026-05-20 | ✅ Fresh | **This file.** Initial scaffold. |

---

## Tier 2 — Architecture (`docs/architecture/`)

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | (pre-M5) | ✅ Fresh | Index + conventions. No architecture notes filed yet — earned when a non-obvious invariant deserves capture. Candidates surfacing from M7: upstream-stock-template drift pattern (per the issues filing 2026-05-20). |

---

## Tier 3 — Operational / Development (`docs/development/`)

> **Important framing**: state.md + roadmap.md form the **canonical operational surface**. CLAUDE.md delegates volatile state to state.md; roadmap.md is the milestone-pinning artifact. Both rotate every release; everything else in this tier rotates per-need.

| File | Last touched | Status | Action |
|---|---|---|---|
| `state.md` | 2026-05-20 | ✅ Fresh | **Rotates every release.** Through v0.7.0 (M6 close). Test count 194 assertions / 52 groups. Source line count + command surface table all current. |
| `roadmap.md` | 2026-05-23 | ✅ Fresh | Through v1.0 plan; M6 retired, M7 (dogfood + harden) underway. M7 issue-repair list now shows ✅ for the three Unreleased fixes (status-exit-1, upstream-drift, `--backup-to`); deferred-section links re-pointed at `issues/archived/`. Three M7 issues archived. |
| `issues/README.md` | 2026-05-20 | ✅ Fresh | Filing conventions for hapi-side dogfood papercuts; severity guide; triage + archival lifecycle; cross-repo upstream-issue pointer. |
| `issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md` | 2026-05-20 | 🟡 Open | Low severity; M7 dogfood papercut. Deferred to post-v1.0 per existing roadmap entry. |
| `issues/archived/2026-05-20-status-exit-1-short-circuits-script-chains.md` | 2026-05-23 | 📦 Archived | Resolved in Unreleased via Tier-1 guide-doc note (`docs/guides/status.md` *Exit-1 is an assertion, not a predicate* section). |
| `issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md` | 2026-05-23 | 📦 Archived | Resolved in Unreleased via Tier-1 new guide `docs/guides/upstream-drift.md`. Tier-2/3 remain post-v1.0 candidates. |
| `issues/archived/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md` | 2026-05-23 | 📦 Archived | Resolved in Unreleased via the `--backup-to <dir>` flag on link / sync / adopt + the new `docs/guides/backup-to.md` guide + ADR 0002 additive-field note for `backup_path`. |

---

## Tier 4 — ADRs (`docs/adr/`)

5 ADRs. Re-read pass at v1.0; ADRs document decisions, not status.

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-05-20 | ✅ Fresh | Index updated for ADR 0005. |
| `template.md` | (pre-M5) | 🔵 Evergreen | Copy-as-starting-point. |
| `0001-hapi-cyml-manifest-schema.md` | (M1) | 🔵 Evergreen | Manifest schema; frozen at v1.0 per CLAUDE.md. |
| `0002-audit-trail-format.md` | 2026-05-23 | ✅ Fresh | Audit-trail format; frozen at v1.0. **Canonical-hash migration landed in Unreleased — `sha1:` → `sha1c:` prefix swap with the canonical re-serialization rules documented in the *Hash* table.** Also gained an *Additive fields shipped after the initial format* subsection registering the Unreleased `backup_path` field. |
| `0003-symlink-target-shape.md` | (M2) | 🔵 Evergreen | Relative-from-link-parent symlink shape. |
| `0004-adopt-op-semantics.md` | (M4) | 🔵 Evergreen | Adopt verb design; atomic single-entry audit + three-step conditional rollback. |
| `0005-capability-bounded-roots.md` | 2026-05-20 | ✅ Fresh | M6 ship; `--root` + `HAPI_ALLOWED_ROOTS` stopgap until kavach lands. |

---

## Tier 5 — Guides (`docs/guides/`)

13 task-oriented how-tos. Each verb has its own guide; two cross-cutting guides cover the M6 global flags.

| File | Last touched | Status | Notes |
|---|---|---|---|
| `getting-started.md` | (pre-M5) | ✅ Fresh | Universal onboarding doc. |
| `inspect.md` | (M1) | ✅ Fresh | Manifest parse + display. |
| `link.md` | 2026-05-23 | ✅ Fresh | Symlink creation + `--force`. Gained a *Preserving the original bytes — `--backup-to`* section linking to `backup-to.md`. |
| `unlink.md` | (M3) | ✅ Fresh | Trail-driven removal + user-mutation refusal. |
| `rollback.md` | (M3) | ✅ Fresh | Reverse-replay + marker semantics. |
| `adopt.md` | 2026-05-23 | ✅ Fresh | File-into-package move + audit + manifest-edit + rollback. Gained a *Preserving the original bytes — `--backup-to`* section linking to `backup-to.md`. |
| `checkpoint.md` | (M5) | ✅ Fresh | Rollback-marker append. |
| `status.md` | 2026-05-23 | ✅ Fresh | Drift classifier; gained the *Exit-1 is an assertion, not a predicate* section (M7 Tier-1 fix; resolves `issues/archived/2026-05-20-status-exit-1-...`). |
| `list.md` | (M5) | ✅ Fresh | Trail walker; live-link count. |
| `check.md` | (M5) | ✅ Fresh | Strict-mode manifest validation. |
| `sync.md` | 2026-05-23 | ✅ Fresh | Idempotent re-apply. Gained a *Preserving bytes during destructive overwrites* section linking to `backup-to.md`. M7 dogfood surfaced prune-deferred gap — see `issues/2026-05-20-sync-prune-...`. |
| `capability.md` | (M6) | ✅ Fresh | `--root` flag + `HAPI_ALLOWED_ROOTS` env-var stopgap. |
| `dry-run.md` | 2026-05-23 | ✅ Fresh | `--dry-run` flag + composability. Cross-link to `backup-to.md` added in the *Combining flags* section. |
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
| 1 | **Security audit doc** — `docs/audit/YYYY-MM-DD-audit.md` filed before v1.0 cut per CLAUDE.md P(-1) Hardening step 5. | Before v1.0 release | [`CLAUDE.md`](../CLAUDE.md) Process P(-1) | Earned at M7; covers path-traversal, symlink-loop, TOCTOU, capability boundary per roadmap M7 entry. |
| 2 | **`docs/benchmarks.md` 3-point trend** — `sync` over a realistic 100-package home; baselines at v0.8.0, mid-cycle, v0.9.0 per roadmap M7. | v0.8.0 cut | roadmap M7 entry | Earned at M7; v1.0 criteria requires the benchmarks file present. |
| 3 | **`docs/architecture/NNN-upstream-drift-pattern.md`** — formalize the drift-audit pattern in the architecture tier once a second drifting-upstream consumer hits the pattern. | When sway / fish / kitty (or sibling) experiences a stock-template rewrite during dogfood | `issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md` Tier-2 | Tier-1 guide (`upstream-drift.md`) landed 2026-05-23; architecture note follows. |

---

*Initial scaffold: 2026-05-20 (v0.7.0). Pattern mirrors [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md) small-repo variant. Refresh in place when docs are touched.*
