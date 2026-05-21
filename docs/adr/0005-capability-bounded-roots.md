# 0005 — Capability-bounded roots

**Status**: Accepted
**Date**: 2026-05-20

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
