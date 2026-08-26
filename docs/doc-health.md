---
name: hapi Documentation Health
description: Living state of doc currency in the hapi repo — fresh / stale / archived / open-question, refreshed as docs are touched
type: state
---

# Documentation Health — hapi

> **Last refresh**: 2026-08-25 (**1.0.5 P(-1) hardening sweep.** Six HIGH findings fixed with mutation-proven tests (two heap overflows, two silent data-loss paths, one capability escape, one argv bug that made `rollback <pkg>` reverse the whole trail); twenty left open and listed. New `docs/audit/2026-08-25-audit.md` — the first pass in this arc to find anything, because it looked at the WRITERS rather than the validators. F-002 re-scoped: the kavach dependency gate is void. `cyrius lint` cleared tree-wide (6 deferrals + 2 long lines). Refreshed CHANGELOG (`[1.0.5]`), state.md (280/76, new Version paragraph), benchmarks.md (third trend row), audit/README.md (index + next-arc scope), CI (aarch64 + agnos compile steps). **Prior — 2026-08-25 1.0.4 toolchain refresh:** Cyrius pin `6.4.22` → `6.5.35`, `lib/` resynced (108 files), the agnos `readlink`#70 work folded out of Unreleased. Fixed two latent defects the pin bump surfaced (a seven-vs-eight-argument `audit_append_link_r` call in `rollback`, a warning until cyrius 6.5.1 made wrong arity an error; and a bare `SYS_OPEN` that kept `--aarch64` from compiling). Rewrote both `.github/workflows` toolchain-install steps onto the upstream installer (the flat `~/.cyrius/{bin,lib}` untar is the pre-6.5 layout and 6.5.x `cyrius deps` rejects it). Refreshed CHANGELOG (new `[1.0.4]` section), state.md (246/71 tests, pin, `src/agnos_compat.cyr` added to the Source list, the stale `66`-group figure corrected to the real count), benchmarks.md (first trend row since the 0.9.0 baseline), VERSION, cyrius.cyml. **Prior — 2026-05-24 1.0.x-final arc:** filed two issues (`no-arg-sync-bootstrap-recovery`, `audit-trail-lost-on-state-dir-wipe`); added `docs/audit/README.md` and `docs/audit/2026-05-24-audit.md`.) | **Refresh cadence**: when docs are touched, update the affected row. Opportunistic, not periodic.
>
> _Superseded refresh detail (2026-05-24 / 2026-05-23), kept for provenance_: (**1.0.x-final arc.** Filed two issues (`no-arg-sync-bootstrap-recovery`, `audit-trail-lost-on-state-dir-wipe`). Added `docs/audit/README.md` (audit-arc convention + index) and `docs/audit/2026-05-24-audit.md` (1.0.x-final P(-1) re-walk; F-006 accepted boundary). Refreshed CHANGELOG Unreleased, state.md (242/66 tests, `HapiSysno` enum, F-006 recovery boundary), roadmap (no-arg-sync dogfood note). **Prior — 2026-05-23 post-v1.0 stale-sweep:** README.md rewritten from scaffold-era language to the v1.0 surface. Eleven guides scrubbed of milestone (`M2`/`M5`/`M6`) and version-bound (`v0.4.0`, `v0.7.0`) narrative — replaced with timeless behavior. CLAUDE.md P(-1) recast as a standing process. state.md command-surface table dropped the M-shipped column; "M7 onward fills" rewritten as the post-v1.0 implementation backlog. **roadmap.md fully rewritten** — M0–M8 milestone narrative replaced with a v1.x maintenance bucket + v2.0 Breaking-candidate bucket.) | **Refresh cadence**: when docs are touched, update the affected row. Opportunistic, not periodic.
> **Scope**: This repo only (`hapi`) — the entire `docs/` tree plus root-level files (README, CHANGELOG, CLAUDE.md, VERSION, LICENSE, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, cyrius.cyml). Per-stdlib-dep docs live in `cyrius/`; cross-repo state lives in [`development/state.md`](development/state.md), not here.
>
> **Convention adopted from agnosticos**: pattern mirrors [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md) (small-repo variant). Per `first-party-documentation.md § Development Docs`, the ledger lives at `docs/` root (not `docs/development/`) because its scope is the whole tree. Hapi's doc tree is ~34 markdown files (vs cyrius's ~105) so the tier structure here is leaner.

This is a **ledger**, not a one-time audit. Rewrite-in-place as docs change.

---

## At a glance — 2026-08-25 inventory (1.0.4; v1.0 contract frozen)

**49 markdown files** across the repo (root + docs tree), counted
2026-08-25 (`find . -name '*.md' -not -path './.git/*' -not -path
'./lib/*'`) — the standing figure had read `44` and was one short.
The 2026-05-24 1.0.x-final arc added two issues,
`docs/audit/README.md` and `docs/audit/2026-05-24-audit.md` to the
v1.0 inventory; the 2026-08-25 1.0.4 pass adds no new doc files.

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh / touched in current cycle** | ~38 | state.md / roadmap.md / CHANGELOG / 5 ADRs / **15 guides** / 2 example files / architecture README / adr README / issues README / **audit/ tier: README + 2026-05-23 + 2026-05-24 passes** / **2 new issues (2026-05-24)** / benchmarks.md. |
| 🟡 **Stale — refresh in place** | 0 | None flagged. `roadmap.md`'s kavach bullet was the last known-false entry and was withdrawn 2026-08-25 (the dependency is a sandbox-execution framework with no capability API). |
| 🟠 **Read-through outstanding** | 0 | Cleared 2026-08-25: the twenty open findings were bubbled out of the audit doc into tracked arc work — a **1.0.x hardening arc** in `development/roadmap.md` bucketed by blast radius, three new issue files for the Tier 1 and Tier 2 clusters, and a pointer from `state.md`. They remain live in the shipped 1.0.5; they are no longer only recorded in an audit appendix. |
| 🔵 **Probably evergreen** | ~3 | LICENSE / SECURITY.md / CODE_OF_CONDUCT.md — load-bearing root files; re-read pass at v1.0, not per-release. |
| 📦 **Archive — frozen by design** | 3 | Three M7-resolved issues moved to `issues/archived/` (status-exit-1, upstream-drift, no-backup-to). |
| ❓ **Open strategic question** | 1 | **Does the additive v1.x bucket stay frozen until the 1.0.x hardening arc closes?** roadmap.md and state.md now both say yes — growth does not resume while a Tier 1 finding (silent data loss or a wrong destructive action) is open. That is a maintainer call worth revisiting if the arc runs long. |
| ❓ _(prior)_ | 0 | None — four open issues (`sync-prune`, `cap-check-symlink-escape`, `no-arg-sync-bootstrap-recovery`, `audit-trail-lost-on-state-dir-wipe`) are all scoped + deferred (post-v1.0 / kavach / accepted-boundary). |

Numbers approximate; rolls up from the per-tier tables below.

**Why now**: doc-health convention adopted at v0.7.0 alongside the M7 dotfile dogfood + cyrius/agnosticos first-party-documentation alignment. The hapi doc tree has been actively maintained (CHANGELOG canonical per CLAUDE.md, state.md refreshes every release, per-command guide added every milestone) but the *aggregate* currency had no surface — this file is that surface.

---

## Tier 1 — Structural docs (root + `docs/` root)

| File | Last touched | Status | Action |
|---|---|---|---|
| `README.md` | 2026-08-25 | ✅ Fresh | Top-level project README. 1.0.4 pass: Status header moved to v1.0.4 (contract unchanged since the 2026-05-23 freeze) and the Quick-start test count corrected from a stale `235 / 65` to the measured `246 / 71`. Prior: Rewritten in the post-v1.0 sweep — scaffold-era "Pre-1.0 (0.1.0). No commands implemented yet." replaced with the v1.0 surface (ten verbs, capability boundary, audit trail, dogfood status). Links the v1.0 release notes + the guide / ADR / audit / benchmarks docs. |
| `CHANGELOG.md` | 2026-08-25 | ✅ Fresh | **Source of truth per CLAUDE.md.** Through `[1.0.4]` (toolchain refresh + the rollback `backup_path` fix + agnos `readlink`); `[Unreleased]` is empty. Historical note below is pre-v1.0: through v0.7.0 (M6 close — `--root` + `--dry-run`); Unreleased section now carries the two M7 Tier-1 doc fixes (status guide clarification + upstream-drift guide). Refreshed every release. |
| `CLAUDE.md` | 2026-05-23 | ✅ Fresh | Process + procedures + project-identity. Post-v1.0 sweep: P(-1) Hardening section recast as a standing process (was "before v0.2.0 first feature cut, and before v1.0" — both events past). Quick-Start scaffold-output line softened. CHANGELOG-Format paragraph already updated at v1.0 cut. |
| `VERSION` | 2026-08-25 | ✅ Fresh | `1.0.4`. Single source of truth, and as of 1.0.4 the *only* place the number lives — `src/main.cyr` reads the compile-time `CYRIUS_PKG_VERSION` constant instead of a hand-synced literal. Bumped in the same commit as the CHANGELOG header. |
| `CONTRIBUTING.md` | (pre-M5) | ✅ Fresh | Scaffolded by `cyrius init`. |
| `SECURITY.md` | (pre-M5) | 🔵 Evergreen | Public reporting policy; re-read pass at v1.0. |
| `CODE_OF_CONDUCT.md` | (pre-M5) | 🔵 Evergreen | Standard text; re-read pass at v1.0. |
| `LICENSE` | (pre-M5) | 🔵 Evergreen | GPL-3.0-only; durable. |
| `cyrius.cyml` | 2026-08-25 | ✅ Fresh | Toolchain pin `6.5.35`. Project manifest; `[deps] stdlib` set unchanged since the v6.1.25 `bayan` carve. |
| `docs/doc-health.md` | 2026-08-25 | ✅ Fresh | **This file.** 1.0.4 refresh — toolchain/stdlib pass. |
| `scripts/concurrency-test.sh` | 2026-08-25 | ✅ Fresh | **New 2026-08-25 (1.0.6).** The F-012 regression harness, and the first committed script in the repo. Exists because the defect needs two hapi *processes*: `.tcyr` cannot fork and hapi is syscall-only by rule, so `cyrius test` structurally cannot express it. CI runs it. Mutation-proven. |
| `docs/benchmarks.md` | 2026-08-25 | ✅ Fresh | Third trend row at 1.0.5 (cold 91 ms, warm 76 ms, 0 audit growth) — the P(-1) step-2 gate, passed, with the ~8%/~12% cost attributed to the F-014/F-008 sizing passes rather than left unexplained. Second trend row landed at 1.0.4 (cold 84 ms, warm 68 ms, 0 audit growth, best-of-four) — the first since the 0.9.0 baseline, triggered by `fs_link.cyr` changing. Carries an explicit non-attribution note: compiler, kernel and code all moved between the two rows, so the delta is a current reading, not a cost. |

---

## Tier 2 — Architecture (`docs/architecture/`)

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | (pre-M5) | ✅ Fresh | Index + conventions. No architecture notes filed yet — earned when a non-obvious invariant deserves capture. Candidates surfacing from M7: upstream-stock-template drift pattern (per the issues filing 2026-05-20). |

## Tier 2.5 — Security audits (`docs/audit/`)

| File | Last touched | Status | Notes |
|---|---|---|---|
| `2026-08-25-audit.md` | 2026-08-25 | ✅ Fresh | **New 2026-08-25.** The 1.0.5 P(-1) sweep — nine HIGH findings where the two prior passes found none. Six fixed (F-008, F-009, F-010, F-011, F-013, F-014), twenty open and enumerated, F-002 re-scoped off its void kavach dep gate, and a refuted list so the next pass does not re-derive nine dead claims. Reads as an honest ledger, not a clean bill: it says outright that 1.0.5 is safer than 1.0.4 and not yet clean. |
| `README.md` | 2026-08-25 | ✅ Fresh | Index + convention. Gained the 1.0.5 row and a **next-arc scope** section naming F-007, F-012, F-015 and the missing agnos runner. |
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
| `state.md` | 2026-08-25 | ✅ Fresh | **Rotates every release.** 1.0.4 pass: new Version paragraph (pin `6.5.35`, 108-file `lib/`, the agnos `readlink` closure, the rollback fix, `CYRIUS_PKG_VERSION`); Toolchain section gained a vendored-`lib/` line; `src/agnos_compat.cyr` added to the Source list; Dependencies gained the agnos-syscall-peer arc. Tests anchored at **246 / 71** — the group figure had read a stale `66` since 1.0.1 while the per-tier breakdown summed to the real count; both now agree. Also corrected the 1.0.2 "arch-correct on aarch64" claim, which was not true until 1.0.4. |
| `roadmap.md` | 2026-08-25 | ✅ Fresh | Gained the **1.0.x hardening arc** (2026-08-25) ahead of the additive bucket: twenty open findings from the P(-1) sweep, bucketed Tier 1 / Tier 2 / Tier 3 / target-conditional, with exit criteria. The kavach migration bullet was withdrawn as factually void. Prior: | **Fully rewritten 2026-05-23 post-v1.0 sweep.** M0–M8 milestone narrative dropped; restructured as v1.x maintenance / additive-growth bucket + v2.0 Breaking-candidate bucket + permanent out-of-scope list + a brief v1.0-sign-off pointer at the release-notes doc. Each v2 candidate carries the rationale that earns it a major bump. |
| `issues/README.md` | 2026-05-20 | ✅ Fresh | Filing conventions for hapi-side dogfood papercuts; severity guide; triage + archival lifecycle; cross-repo upstream-issue pointer. |
| `issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md` | 2026-05-20 | 🟡 Open | Low severity; M7 dogfood papercut. Deferred to post-v1.0 per existing roadmap entry. |
| `issues/archived/2026-05-23-cap-check-symlink-escape.md` | 2026-08-25 | 📦 Archived | **New 2026-05-23.** Medium severity; F-002 from the P(-1) audit. `--root` cap-check is lexical-only; symlinked path components escape. Deferred to the kavach migration per ADR 0005. Note: 1.0.4 gives hapi a working cross-target `readlink` shim — the primitive a per-component resolver needs — but the sanctioned fix is still kavach. |
| `issues/2026-05-24-no-arg-sync-bootstrap-recovery.md` | 2026-05-24 | 🟡 Open | Low severity; dogfood papercut from a drive-move recovery. Needs manifest discovery; post-v1.0 additive work. |
| `issues/archived/2026-08-25-trail-reader-head-cap.md` | 2026-08-25 | 📦 Archived | F-007 + F-016 + F-017 — **resolved in 1.0.6**, the first Tier 1 item of the 1.0.x hardening arc. Carries a resolution banner with the before/after measurement (637 settled links destroyed → `1 / 1 entries`). |
| `issues/archived/2026-08-25-manifest-write-integrity.md` | 2026-08-25 | 📦 Archived | **New 2026-08-25.** High. F-012 + F-021 + F-028: the unlocked manifest read-modify-write commits every filesystem mutation and drops the row that records it. Needs a shell harness to regression-test (`.tcyr` cannot fork). Tier 1. |
| `issues/2026-08-25-reporting-and-idempotency.md` | 2026-08-25 | 🟡 Open | **New 2026-08-25.** Medium. F-022/F-023/F-024/F-026/F-025 — `status`, `list` and `sync` reporting a world that is not on disk, incl. the dangling-link blind spot in the verb F-006 designates as the post-recovery source of truth. Tier 2. |
| `issues/2026-05-24-audit-trail-lost-on-state-dir-wipe.md` | 2026-05-24 | 🟡 Open | Medium severity; F-006 accepted boundary. `status` is the post-recovery source of truth, not `list` / `rollback`. Not a bug awaiting a fix — a documented design edge. |
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
