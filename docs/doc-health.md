---
name: hapi Documentation Health
description: Living state of doc currency in the hapi repo — fresh / stale / archived / open-question, refreshed as docs are touched
type: state
---

# Documentation Health — hapi

> **Last refresh**: 2026-05-20 (v0.7.0 — M6 close + M7 dotfile dogfooding session; bootstrapped `docs/development/issues/` with 4 papercut filings; created this ledger.) | **Refresh cadence**: when docs are touched, update the affected row. Opportunistic, not periodic.
> **Scope**: This repo only (`hapi`) — the entire `docs/` tree plus root-level files (README, CHANGELOG, CLAUDE.md, VERSION, LICENSE, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, cyrius.cyml). Per-stdlib-dep docs live in `cyrius/`; cross-repo state lives in [`development/state.md`](development/state.md), not here.
>
> **Convention adopted from agnosticos**: pattern mirrors [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md) (small-repo variant). Per `first-party-documentation.md § Development Docs`, the ledger lives at `docs/` root (not `docs/development/`) because its scope is the whole tree. Hapi's doc tree is ~34 markdown files (vs cyrius's ~105) so the tier structure here is leaner.

This is a **ledger**, not a one-time audit. Rewrite-in-place as docs change.

---

## At a glance — 2026-05-20 inventory (M6 close + M7 dogfood)

**34 markdown files** across the repo (root + docs tree).

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh / touched in current cycle** | ~28 | Touched within M5 (v0.6.0) and M6 (v0.7.0) ship arcs; state.md / roadmap.md / CHANGELOG / 5 ADRs / 13 guides / 2 example files / architecture README / adr README / issues README (NEW). |
| 🟡 **Stale — refresh in place** | 0 | None flagged. |
| 🟠 **Read-through outstanding** | 0 | None flagged. |
| 🔵 **Probably evergreen** | ~3 | LICENSE / SECURITY.md / CODE_OF_CONDUCT.md — load-bearing root files; re-read pass at v1.0, not per-release. |
| 📦 **Archive — frozen by design** | 0 | No archived issues / proposals / docs yet — repo is too young. |
| ❓ **Open strategic question** | 0 | None — M7 dogfood surfaced four papercuts but they're filed as durable issue prose, not open questions. |

Numbers approximate; rolls up from the per-tier tables below.

**Why now**: doc-health convention adopted at v0.7.0 alongside the M7 dotfile dogfood + cyrius/agnosticos first-party-documentation alignment. The hapi doc tree has been actively maintained (CHANGELOG canonical per CLAUDE.md, state.md refreshes every release, per-command guide added every milestone) but the *aggregate* currency had no surface — this file is that surface.

---

## Tier 1 — Structural docs (root + `docs/` root)

| File | Last touched | Status | Action |
|---|---|---|---|
| `README.md` | (pre-M5) | ✅ Fresh | Top-level project README. Spot-check at v1.0 cut. |
| `CHANGELOG.md` | 2026-05-20 | ✅ Fresh | **Source of truth per CLAUDE.md.** Through v0.7.0 (M6 close — `--root` + `--dry-run`). Refreshed every release. |
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
| `roadmap.md` | 2026-05-20 | ✅ Fresh | Through v1.0 plan; M6 retired, M7 (dogfood + harden) surfaced as Next at v0.9.0. Out-of-scope section updated with M5/M6 deferrals. |
| `issues/README.md` | 2026-05-20 | ✅ Fresh | **New 2026-05-20.** Filing conventions for hapi-side dogfood papercuts; severity guide; triage + archival lifecycle; cross-repo upstream-issue pointer. |
| `issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md` | 2026-05-20 | 🟡 Open | Low severity; M7 dogfood papercut. Deferred to post-v1.0 per existing roadmap entry. |
| `issues/2026-05-20-status-exit-1-short-circuits-script-chains.md` | 2026-05-20 | 🟡 Open | Low severity; M7 dogfood papercut. Tier-1 fix (guide-doc note) cheap; Tier-2 (`--quiet` flag) post-v1.0. |
| `issues/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md` | 2026-05-20 | 🟡 Open | Low severity; M7 dogfood papercut. Proposed `--backup-to <dir>` flag on link/sync/adopt. |
| `issues/2026-05-20-upstream-stock-template-drift-pattern.md` | 2026-05-20 | 🟡 Open | Low severity; M7 dogfood pattern report. Tier-1 fix (new guide `docs/guides/upstream-drift.md`); Tier-2 architecture note; Tier-3 speculative `hapi merge` verb. |

---

## Tier 4 — ADRs (`docs/adr/`)

5 ADRs. Re-read pass at v1.0; ADRs document decisions, not status.

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-05-20 | ✅ Fresh | Index updated for ADR 0005. |
| `template.md` | (pre-M5) | 🔵 Evergreen | Copy-as-starting-point. |
| `0001-hapi-cyml-manifest-schema.md` | (M1) | 🔵 Evergreen | Manifest schema; frozen at v1.0 per CLAUDE.md. |
| `0002-audit-trail-format.md` | (M2) | 🔵 Evergreen | Audit-trail format; frozen at v1.0. Reserves `sha1:` → `sha1c:` canonicalization swap for M7. |
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
| `link.md` | (M2) | ✅ Fresh | Symlink creation + `--force`. |
| `unlink.md` | (M3) | ✅ Fresh | Trail-driven removal + user-mutation refusal. |
| `rollback.md` | (M3) | ✅ Fresh | Reverse-replay + marker semantics. |
| `adopt.md` | (M4) | ✅ Fresh | File-into-package move + audit + manifest-edit + rollback. |
| `checkpoint.md` | (M5) | ✅ Fresh | Rollback-marker append. |
| `status.md` | (M5) | ✅ Fresh | Drift classifier; M7 dogfood surfaced exit-1-short-circuits pattern — guide-doc note pending per `issues/2026-05-20-status-exit-1-...`. |
| `list.md` | (M5) | ✅ Fresh | Trail walker; live-link count. |
| `check.md` | (M5) | ✅ Fresh | Strict-mode manifest validation. |
| `sync.md` | (M5) | ✅ Fresh | Idempotent re-apply. M7 dogfood surfaced prune-deferred gap — see `issues/2026-05-20-sync-prune-...`. |
| `capability.md` | (M6) | ✅ Fresh | `--root` flag + `HAPI_ALLOWED_ROOTS` env-var stopgap. |
| `dry-run.md` | (M6) | ✅ Fresh | `--dry-run` flag + composability. |

**Earned-but-not-yet-written**: `upstream-drift.md` (Tier-1 fix for the hyprland-class drift pattern per `issues/2026-05-20-upstream-stock-template-drift-pattern.md`). Author when the second drifting-upstream consumer hits the pattern (likely sway / fish / kitty when an upstream rewrite drops).

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
| 2 | **Manifest-hash canonicalization migration** — `sha1:` → `sha1c:` prefix swap per ADR 0002, deferred from M2 to M7. | M7 → M8 transition | ADR 0002, roadmap M7 entry | Audit-format `Breaking` lives on the prefix swap. Migration window: read both prefixes during M7 → M8, write only `sha1c:` from M8 forward. |
| 3 | **`upstream-drift.md` guide** — per `issues/2026-05-20-upstream-stock-template-drift-pattern.md` Tier-1 proposed fix. | When second drifting-upstream consumer hits the pattern | M7 issues filing | Codify the audit + merge workflow used for hyprland.conf during M7 dogfood. |

---

*Initial scaffold: 2026-05-20 (v0.7.0). Pattern mirrors [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md) small-repo variant. Refresh in place when docs are touched.*
