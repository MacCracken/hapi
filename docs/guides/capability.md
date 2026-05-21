# Capability-bounded roots

hapi's filesystem touch is bounded by an explicit capability.
`$HOME` is the default root; touching anything else requires
an explicit `--root` flag *and* a capability grant. This guide
covers the v0.7.0 surface — see
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

v0.7.0 ships with an **env-var allowlist**. Set
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

## Why an env var?

It's the explicit stopgap. The agnosticos
[kavach](https://github.com/MacCracken/agnosticos) capability
service will eventually own this surface; until kavach exposes
a stable API, the env var is the simplest contract that
delivers the "explicit capability for non-`$HOME`" principle
in a way that's testable today. ADR 0005 walks through the
alternatives that lost.

The migration is *internal-only*: callers continue to use
`--root <path>` against the unchanged exit codes. Only
`src/cap.cyr` swaps env-var lookups for kavach calls.

## Caveats

- An env-var allowlist is *advisory*, not kernel-enforced. A
  user who can set `HAPI_ALLOWED_ROOTS` can expand their own
  scope. The kavach swap closes this gap; until then, treat
  the allowlist as a sanity rail, not a security boundary.
- `$HOME` is always implicitly allowed and does not need to
  appear in the allowlist.
- The allowlist accepts **absolute paths only**; relative
  entries are silently dropped.

## See also

- [ADR 0005 — Capability-bounded roots](../adr/0005-capability-bounded-roots.md)
- [`dry-run.md`](dry-run.md) — the other M6 global flag.
