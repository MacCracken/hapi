# 0005 — Capability-bounded roots

**Status**: Accepted — **Frozen at v1.0.0 (2026-05-23)**
**Date**: 2026-05-20

> Frozen: `cap_check_root_r(path) -> Result` is the contract.
> The implementation may swap from the v0.x
> `HAPI_ALLOWED_ROOTS` env-var stopgap to the kavach capability
> service — that's internal and does not change callers. The
> v0.9.0 lexical-normalization repair (F-001) and the v1.0
> behavior are identical at the interface; the symlink-aware
> resolution that closes F-002 lands in kavach without breaking
> the API.

## Context

Through M5 every hapi verb that touches the filesystem is
implicitly `$HOME`-scoped. The scope is the load-bearing
guarantee in CLAUDE.md's Key Principles: *"Every filesystem
touch is bounded by an explicit capability. `$HOME` is the
default root; touching anything else requires an explicit
`--root` flag and a capability grant."*

M6 has to deliver on that promise. Two requirements:

1. A user can ask hapi to manage a non-`$HOME` root via
   `--root <path>` (e.g. `/etc/myproject` for a system-config
   package, `/srv/app` for a service-config package).
2. That request must pass through an explicit *capability
   check*. We do not want hapi inheriting whatever filesystem
   permissions the invoking user happens to hold from the
   kernel; the design posture is "authorization over
   authentication" — the user-id matters less than whether
   the workflow explicitly grants this scope.

The complicating constraint: **kavach** — the agnosticos
capability service that will eventually own this surface —
does not yet expose a stable API. The roadmap entry for M6
acknowledges this explicitly:

> **Dep gate**: when kavach exposes a stable capability API;
> until then, a CLI-level allowlist.

Ship the stopgap. Don't block M6 on a dependency we don't
control.

## Decision

### Default scope is `$HOME`, capability is implicit

A bare `hapi link <pkg>` continues to resolve targets against
`$HOME`. No capability check fires; `$HOME` is *always* in
scope. This matches every existing test, every shipped guide,
and every user's muscle memory.

### `--root <path>` opens a non-default root

```sh
hapi link  --root /etc/myproject etc-pkg
hapi sync  --root /srv/app       app-pkg
hapi adopt --root /etc/myproject /etc/myproject/conf myproject-pkg
hapi status --root /srv/app       app-pkg
hapi list  --root /etc/myproject
```

Resolution rule when `--root` is set:

- `--root <abs-path>` — used verbatim (canonicalized).
- `--root <relative-path>` — resolved against `cwd`.
- The flag value replaces `$HOME` for the duration of the
  invocation. Manifest `target` rows resolve against the new
  root, the audit-trail entries record `abs_target` against
  the new root, and `hapi unlink` / `rollback` find the same
  paths back via the trail.

Commands that don't depend on scope (`inspect`, `check`,
`rollback`, `unlink`, `checkpoint`) ignore `--root` — they
read paths back from the audit trail's `abs_target`
verbatim. Documenting the surface as "the flag is accepted
silently" is wrong; we reject `--root` on those verbs with
exit code 2 so users don't get a confusing no-op.

### Capability check via `HAPI_ALLOWED_ROOTS` (stopgap)

A v0.7.0 capability check is a path-prefix lookup against an
env-var allowlist:

```sh
HAPI_ALLOWED_ROOTS=/etc/myproject:/srv/app:/var/lib/myservice
```

Colon-separated, absolute paths only. The check passes if the
resolved `--root` is exactly one of the allowed prefixes, *or*
is a strict subdirectory of one. `$HOME` is **always
implicitly allowed**; it never has to appear in the allowlist.

Failure modes:

- `--root /etc/myproject` with empty / unset
  `HAPI_ALLOWED_ROOTS` → exit 1 with
  `hapi: --root path is not in HAPI_ALLOWED_ROOTS`.
- `--root /tmp/foo` with `HAPI_ALLOWED_ROOTS=/etc/myproject` →
  same exit 1.
- `--root /etc/myproject/subdir` with
  `HAPI_ALLOWED_ROOTS=/etc/myproject` → **succeeds** (subdir
  of an allowed prefix).
- `--root /etc/myprojectextra` with
  `HAPI_ALLOWED_ROOTS=/etc/myproject` → **fails** (prefix
  match has to break on `/`, not on byte boundary).

### kavach migration path

When kavach exposes a stable `cap_check(scope, action)`
surface, the `cap_check_root` helper in `src/cap.cyr` gets
re-implemented to call kavach. The env-var allowlist becomes
the second-tier fallback (still useful for dev / CI
environments that don't run a kavach daemon).

Signature stability is the contract: anything outside
`src/cap.cyr` only calls `cap_check_root(path)` →
`Ok(()) | Err(CapDenied)`. The internal mechanism switches
freely.

## Consequences

**Positive**:

- The "explicit capability for non-`$HOME`" principle ships,
  in a form testable today.
- Tests for capability-denial don't depend on kavach.
- Migration to kavach is a strictly internal refactor of
  `src/cap.cyr` — no caller code changes, no manifest
  changes, no audit-format changes.
- The env-var is also a perfectly reasonable production
  surface for CI runners that don't run a daemon. We may
  keep it forever even after kavach lands.

**Negative**:

- An env-var allowlist is *advisory*, not enforced by the
  kernel. A user who can set `HAPI_ALLOWED_ROOTS` can
  trivially expand their own scope. This is exactly the
  weakness kavach is meant to close, and that closure is
  the v1.0 hardening item.
- Subdirectory-of-allowed-prefix is a deliberate carve-out
  (a single allowlist entry `/etc/myproject` should cover
  every package within), but the prefix-match logic has to
  be careful about `/etc/myproject` vs `/etc/myprojectextra`.
  ASCII-byte prefix matching is wrong; the matcher splits on
  `/` and compares whole path components.

**Neutral**:

- The `--root` value is recorded in the audit-trail via
  `abs_target` already — no new audit field needed. Reading
  the trail back, every `abs_target` is absolute, and
  `unlink` / `rollback` operate on those without needing to
  know what scope-root the original op was run under.
- Per-command guide docs need an `--root` and `--dry-run`
  section each. Documented in M6's docs task.

## Alternatives considered

- **No allowlist; trust the user** — rejected. The capability
  boundary is the *whole point* of `--root`. If we don't gate
  it, the flag is just a CLI sugar for changing `$HOME` for
  one command. The principle in CLAUDE.md is "explicit grant";
  silent acceptance violates it.
- **`hapi cap grant <path>` verb + persisted allowlist** —
  rejected. Persisted state is its own design surface (where
  does it live? whose ownership? how is it audited?). The
  env-var stopgap is *intentionally* minimal because it gets
  ripped out when kavach ships. Don't build infrastructure
  around code that's known-temporary.
- **Block M6 on kavach** — rejected. The roadmap's dep gate
  explicitly carves out the stopgap path. Blocking would
  stall hardening (M7) and v1.0; the capability shape can be
  exercised today against a stopgap and against kavach
  tomorrow without changing the user-facing contract.
- **Treat `--root` as a sudo-style elevation** (require root
  privilege) — rejected. AGNOS userland posture is
  capability-bounded, not privilege-bounded. A user-mode
  service with a kavach grant should be able to write its
  own `/srv/app` config without `sudo`.
- **Implicit allow if the user owns the path** — rejected.
  Filesystem ownership is the kernel's authentication
  signal; hapi cares about *authorization* (was this
  workflow granted this scope?). The two are different
  questions; conflating them weakens both.

---

## Addendum — 2026-08-25 (1.0.5 P(-1) sweep)

**The decision stands. Two factual claims supporting it do not.**
Recorded as an addendum rather than an edit: ADR 0005 is *Frozen at
v1.0.0* and the decision — `$HOME` by default, `--root` plus a
capability grant to widen, `cap_check_root_r(path) -> Result` as the
frozen interface — is unchanged. What follows corrects the rationale.

**1. The kavach migration path does not exist.** The *kavach migration
path* section above says the fix for F-002 lands "when kavach exposes a
stable `cap_check(scope, action)` surface". kavach is at **3.12.3** —
long past stable — and it is a **sandbox execution framework**: ten
backends, strength scoring, an externalization scanner pipeline, a
credential proxy, an HMAC-SHA256 audit chain. Its entire public
path-facing surface is `kavach_path_exists`. There is no capability or
path-resolution API, none is planned, and adopting a process-sandboxing
framework would collide with CLAUDE.md's hard *no process spawning from
command handlers* rule. **The dep gate is void.** Per-component
symlink-aware resolution is hapi's own work; the primitive it needs
(`hapi_readlink`, portable across Linux, aarch64 and agnos) landed in
1.0.4, and the pinned stdlib exposes no `openat2` / `RESOLVE_BENEATH`,
so the shape is a `readlink` / `O_NOFOLLOW` per-component walk.

**2. "The user typed an explicit escape flag" does not cover the
escape.** The deferral's rationale assumes the unresolved case always
involves `--root`. It does not: a symlinked *intermediate component* of
an ordinary `$HOME` target — `~/.config -> /mnt/other/etc`, an everyday
convenience symlink — escapes the scope on a plain `hapi link`, with no
flag at all (F-015). F-002 is therefore re-scoped from *the `--root`
value* to *every path hapi derives from the scope root*.

**3. `unlink` and `rollback` do not re-check the grant.** They act on
the trail-recorded `abs_target` without re-validating the capability
that authorised the original write. This is a defensible position — hapi
removes only what it created — but it is a *boundary*, not a
consequence of the design above, and it was undocumented. Recorded as
an accepted boundary in
[`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md).

**4. What 1.0.5 did add.** `cap_within_scope(path, scope_root)` — the
containment predicate for a path hapi is about to *write*, as distinct
from `cap_check_root_r`, which vets the `--root` value the user typed.
`adopt` needs it because its `<file>` argument is itself a write target
(F-011). Internal addition; `cap_check_root_r`'s signature is untouched.
