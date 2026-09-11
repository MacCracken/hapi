# Capability-bounded roots

hapi's filesystem touch is bounded by an explicit capability.
`$HOME` is the default root; touching anything else requires
an explicit `--root` flag *and* a capability grant. See
[ADR 0005](../adr/0005-capability-bounded-roots.md) for the
rationale.

## Default: `$HOME` is implicitly allowed

```sh
hapi link dotfiles-zsh
hapi adopt .zshrc dotfiles-zsh
hapi sync dotfiles-zsh
```

These all resolve targets against `$HOME` and need no
capability dance.

## `--root <path>` opens a non-default scope

```sh
hapi link  --root /etc/myproject etc-pkg
hapi adopt --root /etc/myproject /etc/myproject/conf myproject-pkg
hapi sync  --root /etc/myproject etc-pkg
hapi status --root /etc/myproject etc-pkg
hapi list  --root /etc/myproject
```

`--root` is accepted on **link, adopt, sync, status, list**.
The other verbs (unlink, rollback, checkpoint, inspect, check)
reject the flag with exit 2 — they read absolute paths back
from the audit trail and don't need a scope.

## Granting a non-`$HOME` root

hapi ships with an **env-var allowlist**. Set
`HAPI_ALLOWED_ROOTS` to a colon-separated list of absolute
paths; hapi accepts `--root` for any path equal to, or a
strict subdirectory of, an allowlist entry.

```sh
export HAPI_ALLOWED_ROOTS=/etc/myproject:/srv/app
hapi link --root /etc/myproject etc-pkg            # OK
hapi link --root /etc/myproject/sub etc-pkg        # OK (subdir)
hapi link --root /srv/app/x/y app-pkg              # OK (subdir)
hapi link --root /tmp/random pkg                   # DENIED — exit 1
hapi link --root /etc/myprojectextra pkg           # DENIED (boundary on /)
```

The matcher splits on path components — a byte-prefix
collision like `/etc/myprojectextra` does **not** match
`/etc/myproject`.

## Resolved containment — the bound on every write

`--root` vets the scope root the *user typed*. A **separate** check vets
every path hapi is about to *write*, and it is the one that catches the
case no flag is involved in:

```sh
ln -s /mnt/other/etc ~/.config     # an ordinary convenience symlink
hapi link pkg                      # a row targeting .config/foo
```

Lexically `.config/foo` looks like it is inside `$HOME`. Physically it
is not. hapi resolves the target's parent **component by component**,
following a symlink at each one (hop-capped at 40, the kernel's own
ELOOP budget), and refuses when the resolved location falls outside the
scope:

```
hapi: refusing to link outside the scoped root:
  /home/user/.config/foo  (resolves outside the scoped root)
  --force does NOT override this. To authorize that location,
  add it to HAPI_ALLOWED_ROOTS (ADR 0005); `--root` re-roots
  every target and is a different operation.
```

Two things worth holding onto:

- **`--force` does not override an escape.** Before 1.0.8 the refusal
  came from the ordinary file-conflict path, which advises `--force` —
  and following that advice deleted a file outside `$HOME`.
- **`--root` is not the escape hatch.** It re-roots where *every*
  manifest target resolves. To authorize one symlinked destination,
  list it in `HAPI_ALLOWED_ROOTS`.

`adopt`'s `<file>` argument gets the same treatment: it is a write
target in its own right, since adopt renames the file away and plants a
symlink where it stood.

## Why an env var?

It was framed as a stopgap ahead of the agnosticos
[kavach](https://github.com/MacCracken/agnosticos) capability service.
**That dependency gate is void.** kavach is at 3.12.3 — long past
stable — and is a *sandbox execution* framework whose entire public
path-facing surface is `kavach_path_exists`. There is no
`cap_check(scope, action)`, none is planned, and adopting a
process-sandboxing framework would collide with hapi's
no-process-spawning rule. See the
[2026-08-25 audit](../audit/2026-08-25-audit.md) and the addendum on
[ADR 0005](../adr/0005-capability-bounded-roots.md).

So the env var is not a stopgap any more — it is the mechanism. What
was owed alongside it, per-component symlink resolution, shipped in
1.0.8 as hapi's own work (above).

## Caveats

- An env-var allowlist is *advisory*, not kernel-enforced. A user who
  can set `HAPI_ALLOWED_ROOTS` can expand their own scope. Treat it as
  a sanity rail, not a security boundary — and note there is no kavach
  swap coming to change that.
- **`--root`'s own check is lexical**; `..` segments are collapsed
  before the prefix-match (the F-001 repair in the
  [v0.9.0 hardening pass](../audit/2026-05-23-audit.md)). Symlink
  resolution applies to **write targets**, not to the `--root` value
  itself — see *Resolved containment* above. F-002 and F-015 closed in
  1.0.8.
- `$HOME` is always implicitly allowed and does not need to
  appear in the allowlist.
- The allowlist accepts **absolute paths only**; relative
  entries are silently dropped.

## See also

- [ADR 0005 — Capability-bounded roots](../adr/0005-capability-bounded-roots.md)
- [`dry-run.md`](dry-run.md) — composable preview flag.
- [`backup-to.md`](backup-to.md) — opt-in pre-`--force` snapshots.
