# `hapi adopt` cannot succeed on a real agnos kernel

**Discovered:** 2026-10-28, P(-1) pass for 1.1.1 ([F-059](../../audit/2026-10-28-audit.md)), running hapi's agnos build on an agnos 1.57.14 kernel booted in QEMU
**Severity:** Medium — the verb is unusable on agnos; it fails closed (nothing is lost)
**Affects:** every hapi agnos build. Invisible under mirshi, which differs from the kernel on all three calls below.

## Summary

`adopt` ends by rewriting `hapi.cyml` under a package-directory lock: open
the directory, `flock` it, write `hapi.cyml.<pid>.tmp`, rename it over the
manifest. On a real agnos kernel each of those steps that touches a
directory or an existing name fails:

1. **The lock's open.** `_hmw_lock` opens the package directory `O_RDONLY`.
   agnos open#7 refuses a directory without `AO_DIRECTORY` (-1).
2. **The lock itself.** With `O_DIRECTORY` the open succeeds, but agnos
   flock#59 accepts only ext2 *regular-file* fds — `flock(dirfd)` is -1.
3. **The commit.** agnos ext2 rename#31 refuses an existing destination
   ("rename-replace is a follow-on bite" in the kernel), so the staging
   file cannot replace the manifest atomically at all.

The user sees `hapi: manifest edit failed (...); filesystem restored`, exit
1, with the file back where it was. `rollback` of an adopt entry would fail
its manifest edit the same way; that path is reachable only from a trail
written on another target.

## Reproduction

Needs a real kernel — mirshi answers 0 / an fd / 0 / 0 to the four calls
the kernel refuses (see the audit's *Harness gap* table). With hapi's agnos
build staged in an agnos image and booted under QEMU:

```sh
hapi adopt /p/file /p/pkg      # scope /p
# hapi: manifest edit failed (could not write the manifest); filesystem restored
```

## Why it is not fixed in hapi

Steps 1 and 2 are hapi-side and cheap — open with `O_DIRECTORY`, and lock a
regular file instead of the directory. But a lock file the rename never
replaces is a new artifact in every dotfiles repo (the reason 1.0.6 locked
the directory), and step 3 would still refuse. Without an atomic rename-over,
the only ways to commit are unlink-then-rename (a crash in between leaves no
manifest) or an in-place rewrite (a crash leaves a torn one). Both trade a
clean refusal for a corruption window, which is the wrong direction.

## What closes it

- **agnos kernel**: rename#31 replacing an existing destination on ext2 —
  filed 2026-10-28 as agnos
  `docs/development/issues/2026-10-28-ext2-rename-cannot-replace-an-existing-file.md`.
- **hapi**, once that lands: open the lock with `O_DIRECTORY`, and decide
  how to lock on agnos — flock#59 on a directory, if the kernel adds it, or a
  regular lock file.
- **mirshi**: match the kernel on the four calls, so the CI run can see
  this class at all — filed 2026-10-28 in mirshi's
  `docs/development/roadmap.md`, § *Open defects — kernel fidelity*.

## Stopgap

Edit `hapi.cyml` by hand on agnos, then `hapi link`. On the real kernel,
`link` → re-link (a no-op) → `status` → `list` → `unlink` was verified with
an explicit scope (1.1.0 binary). The default `HOME=/` scope needs 1.1.1's
F-047 fix, which is verified under mirshi but not yet on the kernel.
