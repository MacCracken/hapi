# `--root` cap-check is lexical-only — a symlinked path component can escape $HOME

**Discovered:** 2026-05-23 during the P(-1) security audit pass
**Severity:** Medium — capability bypass, mediated by Unix DAC
**Affects:** hapi 0.8.0+ — the lexical fix from F-001 closes the
`..` case but `--root /home/user/trap` where `trap` is a symlink
to `/etc/secret` still passes the cap-check and writes through
the symlink at kernel time.

## Summary

`cap_check_root_r` resolves the user-supplied path via
`fsl_to_absolute` and `fsl_lexical_normalize`, then byte-prefix-
matches against `$HOME` and `HAPI_ALLOWED_ROOTS`. **Lexical
normalization does not follow symlinks.** A symlink under `$HOME`
that points outside `$HOME` survives the cap-check; the kernel
then resolves the symlink at write time, landing the write
outside the supposedly-bounded scope.

## Reproduction

```sh
# Attacker plants a symlink anywhere under $HOME.
ln -s /etc/secret ~/trap

# A subsequent --root invocation passes the cap-check…
hapi link --root ~/trap --dry-run pkg
#   + /home/user/trap/.zshrc -> ...  (dry-run)
# …but the actual on-disk write would land at /etc/secret/.zshrc.
```

The lexical fix from `2026-05-23-audit.md` F-001 catches `..`
escapes (`/home/user/../etc/secret`) but not this symlink case.

## Root cause

`fsl_lexical_normalize` is a pure path-string operation by
design — no filesystem calls, no symlink resolution. That's the
right semantics for the typo-class `..` bypass it defends, but
incomplete for the deliberate-attacker symlink case.

The full fix is per-component symlink resolution: open each
prefix with `O_PATH | O_NOFOLLOW` and check `S_ISLNK` via
`fstat` at each step, or hand-roll a `realpath` equivalent.
Either way, that's enough code to want its own design pass.

## Proposed fix (deferred)

ADR 0005 already names kavach as the permanent owner of
`cap_check_root_r`. The kavach capability service will do
per-component resolution properly — that's the natural place to
land the fix. Until kavach exposes the surface, v0.8.x ships the
lexical-only check with this issue as the documented boundary.

A pre-kavach in-repo fix is possible (the syscall sequence is
small) but earns its place only if a real consumer hits the
escape during dogfooding. The attacker model here is "someone
who can already plant a symlink under your `$HOME`" — bounded
by Unix DAC.

## Consumer-side workaround

`HAPI_ALLOWED_ROOTS` entries are matched after lex-normalization.
A defensive operator can enumerate the *real* paths their
deployment writes to (no symlinks) and set `HAPI_ALLOWED_ROOTS`
to those literal paths, then `realpath` the `--root` value before
passing it to hapi:

```sh
HAPI_ALLOWED_ROOTS=/srv/legit hapi link --root "$(realpath "$user_root")" pkg
```

That moves the symlink resolution to the shell, where the user
can see the result before hapi acts on it.

## Cross-references

- [`docs/audit/2026-05-23-audit.md`](../../audit/2026-05-23-audit.md) F-002 — origin entry.
- [ADR 0005](../../adr/0005-capability-bounded-roots.md) — kavach migration plan.
- [`state.md`](../state.md) — kavach swap noted under "M7 onward fills".
