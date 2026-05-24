# hapi Audit Trail — the P(-1) hardening arc

> This directory holds the **completed** security/hardening
> passes. The process that produces them is CLAUDE.md
> **Process P(-1)** — a standing checklist, not a one-time gate.
> This README is the convention + index + the scope of the *next*
> pending arc.

## What this dir holds

- `YYYY-MM-DD-audit.md` — one file per completed P(-1) pass.
  Dated when the pass runs. Findings carry stable IDs (`F-NNN`)
  so issues and ADRs can cross-reference them durably.

A pass is **not** a feature changelog. It is the record of
walking the code with the four threat classes as lenses, the
findings (fixed / deferred / accepted), and the sign-off.

## When the arc runs

Per CLAUDE.md Process P(-1), re-run the checklist:

- on **any change** that touches a path argument, a syscall, the
  capability surface, or the audit-trail format;
- **always before a major-version cut**; and
- as the **wrap of a minor / patch line** before it's declared
  final and feature work resumes on the next line.

## The checklist (P(-1), six steps)

1. **Cleanliness** — `cyrius build`, `cyrius lint`, all tests pass.
2. **Benchmark baseline** — re-run the `sync` harness from
   [`../benchmarks.md`](../benchmarks.md); append a row if numbers
   shift > 2× or warm audit growth becomes non-zero.
3. **Internal review** — every path argument's validation; every
   syscall's return handling.
4. **External research** — GNU stow corner cases; audit-trail
   design references.
5. **Security audit** — the four threat classes (path traversal,
   symlink loops, TOCTOU, capability scope). File findings here.
6. **Documentation audit** — ADRs for new design choices;
   per-command guide pages for new surface; doc-health refresh.

## Index of passes

| Pass | Version at scan | Outcome |
|------|-----------------|---------|
| [`2026-05-23-audit.md`](2026-05-23-audit.md) | 0.8.0 → v1.0 hardening | F-001 (HIGH, `..` bypass) **fixed**; F-003 (LOW, backup-copy TOCTOU) **fixed**; F-002 (MEDIUM, symlink escape) **deferred** to kavach; F-004 / F-005 **accepted** boundaries. Closed P(-1) Step 5 for the v1.0 cut. |
| [`2026-05-24-audit.md`](2026-05-24-audit.md) | 1.0.0 (1.0.x-final) | Re-walk over the unchanged v1.0 surface. F-001/F-003 still fixed (test-asserted), F-002 still deferred (no kavach yet), F-004/F-005 still accepted. New F-006 (LOW, audit trail lost on state-dir wipe) **accepted** boundary. Reviewed the syscall-naming cleanup (behavior-neutral). |

---

## 1.0.x-final P(-1) pass — completed 2026-05-24

Ran 2026-05-24; outcomes in
[`2026-05-24-audit.md`](2026-05-24-audit.md) and the index above.
The scope below is the plan it executed.

**Trigger.** Wrap of the 1.0.x patch line, before v1.x feature
work (no-arg sync, `status --quiet`, `sync --prune`, …) opens.
The same "audit close to the line" cadence that produced the
v1.0 pass.

**Scope at scan time.** The v1.0 contract is frozen (command
surface, ADR 0001 manifest schema, ADR 0002 audit-trail format).
This arc is a *re-walk*, not a re-design — confirm the v1.0
findings still hold and weigh what's accumulated since
2026-05-23.

**Accumulated since the v1.0 pass:**

- **F-002 still open** — `cap_check_root_r` is lexical-only;
  symlink-component escape from `--root` is unfixed pending the
  kavach capability service. Re-confirm kavach has not shipped a
  stable API yet; if it has, the fix moves from this arc's
  "still-deferred" column into actual repair.
  ([`../development/issues/2026-05-23-cap-check-symlink-escape.md`](../development/issues/2026-05-23-cap-check-symlink-escape.md))
- **NEW — state-loss recovery boundary** — a 2026-05-24
  drive-move dogfood run surfaced that a wiped
  `$XDG_STATE_HOME/hapi/` leaves `hapi list` / `hapi rollback`
  undercounting reality (re-`sync` is idempotent and writes no
  trail entry, so it doesn't reconcile the trail). Decide in
  Step 5 whether this is an **accepted boundary** (document it,
  like F-004/F-005) or earns a **re-seed** affordance.
  ([`../development/issues/2026-05-24-audit-trail-lost-on-state-dir-wipe.md`](../development/issues/2026-05-24-audit-trail-lost-on-state-dir-wipe.md))
- **NEW — bootstrap ergonomics** — no-arg `hapi sync` is the
  turnkey recovery command hapi lacks; the same dogfood run shows
  trail-recovery is the wrong discovery mechanism (fails closed on
  an empty trail) and root-scan is right. Not a security finding —
  noted here so Step 3/6 weigh it alongside the recovery story.
  ([`../development/issues/2026-05-24-no-arg-sync-bootstrap-recovery.md`](../development/issues/2026-05-24-no-arg-sync-bootstrap-recovery.md))

**Per-step focus for this arc:**

1. **Cleanliness** — green as of 2026-05-24 (`build` OK,
   `235/235` tests + 1 example check). Re-run at scan time; a
   patch-line wrap should not regress this.
2. **Benchmark baseline** — no `cmd_link` / `audit` / `fs_link` /
   parser changes have landed since v0.9.0's baseline, so no new
   row is expected unless a 1.0.x patch touches the hot path.
   Re-run the harness to confirm warm audit growth is still zero.
3. **Internal review** — re-walk every path argument's validator
   and every syscall return; no new verbs since v1.0, so this is a
   confirmation pass, not net-new surface.
4. **External research** — re-check stow's hidden-file / `.keep`
   conventions and any audit-trail-format references that have
   moved since 2026-05-23.
5. **Security audit** — re-walk the four threat classes against
   the (unchanged) v1.0 surface; resolve the **state-loss
   recovery boundary** above (accept vs. re-seed) and re-confirm
   **F-002**'s deferral is still correct (kavach status). File a
   dated `YYYY-MM-DD-audit.md` with the outcome and an updated
   findings table.
6. **Documentation audit** — fold the disposition of the two
   2026-05-24 issues back into their files (`— RESOLVED` / accepted
   / archived as appropriate); refresh
   [`../doc-health.md`](../doc-health.md) for the docs this arc
   touches; ADR amendment only if Step 5 lands a behavior change
   (none expected — format/contract stay frozen).

**Sign-off bar.** Same as v1.0: the four threat classes
re-walked, each open finding either repaired-with-tests, deferred
with a tracked issue, or accepted with a documented boundary; the
dated audit file written and linked from the index above.

---

## Next arc — none scheduled

The next P(-1) arc fires on the standing rule — before a v2.0 cut,
or on the next change to a path argument, syscall, capability
surface, or audit-trail format. None scheduled; the v1.0 contract
is frozen and the open findings (F-002 kavach, F-006 boundary) are
tracked in [`../development/issues/`](../development/issues/).
