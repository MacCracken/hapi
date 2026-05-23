# `hapi status` exit 1 on drift short-circuits `status && link --force` chains — RESOLVED

**Discovered:** 2026-05-20 during M7 dotfile dogfooding (git package adoption)
**Severity:** Low — legitimate semantic; UX papercut for scripted chains
**Affects:** hapi 0.5.0 through 0.7.0 — applies wherever `hapi status` returns non-zero
**Resolution:** Tier-1 (Option A) guide-doc note landed in Unreleased; `docs/guides/status.md` now carries the *Exit-1 is an assertion, not a predicate* section pointing users at `link --dry-run` for `&&`-chain pre-flight. No code change. Tier-2 (`--quiet` flag) remains a post-v1.0 candidate per the roadmap.

## Summary

`hapi status <pkg>` returns exit code **1** when any row drifts from the manifest, per its design as an assertion-style verb (CI-friendly: any drift fails the check). This is correct *as a contract*. It bites the user when they reach for a natural pre-flight chain:

```sh
hapi status pkg && hapi link --force pkg
```

— because the `&&` short-circuits on the expected drift and the `link --force` never runs. The user adopting their first conflicting file (the dogfood `~/.gitconfig` case) hit this and had to re-run the link separately.

## Reproduction

```sh
# Plant a conflicting file at the target
cp some-config ~/.gitconfig

# Try a "check then apply" chain
hapi status /path/to/git-pkg && hapi link --force /path/to/git-pkg
# > status 0 / 1 OK (1 drift)
# > (exit 1; the && short-circuits)
# > link --force NEVER RAN
```

Verified during the M7 dogfood:

```
$ /home/macro/Repos/hapi/build/hapi check --strict ... && status ... && link --force ...
links (1): .gitconfig  -> .gitconfig
ok (strict)

  FILE     /home/macro/.gitconfig
status 0 / 1 OK (1 drift)
[exit 1; the link --force command in the chain never executed]
```

## Root cause

By design. `cmd_status` returns 1 when `drift > 0` (see `src/cmd/status.cyr`):

```
if (drift > 0) { return 1; }
return 0;
```

The exit code is the *result* of the assertion — it tells the caller "the state does NOT match the manifest". A CI workflow uses this as a fail-fast signal; that's the intended consumer. A script using `&&` is treating it as a *predicate* — "if state is clean, do X" — which is the inverse semantic. Both are valid views of the same verb; one of them is going to be surprising.

## Proposed fix

Two options, neither urgent:

### Option A — Guide-doc note (cheapest)

Add a paragraph to `docs/guides/status.md` clarifying that status's exit code is for **assertion** use (CI / lint), not for **pre-flight** use (`status && X`). Recommend `hapi link --dry-run` for the pre-flight pattern instead:

```sh
hapi link --dry-run pkg && hapi link --force pkg   # ← this composes
```

`--dry-run` returns the same exit codes as the real run (success / refusal-conflict / bad-usage) without writing anything, which is exactly what a pre-flight wants.

### Option B — `hapi status --quiet` flag

A flag that suppresses the exit-1-on-drift behavior, returning 0 unless there's an actual *error* (manifest parse failure, IO error). The user opts into the assertion semantics with the absence of `--quiet`, or into the predicate semantics with its presence.

Option A is the right v1.0 move (zero code change, documents the surface that already exists). Option B is a post-v1.0 enhancement if the dogfood pattern keeps recurring.

## Consumer-side workaround

Use `hapi link --dry-run pkg` as the pre-flight; chain to the real action via `&&`:

```sh
hapi link --dry-run /path/to/pkg && hapi link --force /path/to/pkg
```

`--dry-run` returns 0 when the would-be operation would succeed, 1 on a real conflict that even `--force` wouldn't resolve (directory at target), 2 on bad usage. That's the predicate semantic the user wants.

The M7 dogfood session adopted this pattern after the chain failure: every subsequent `link --force` was preceded by `link --dry-run` either standalone or in a chain.
