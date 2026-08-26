# The manifest read-modify-write has no lock, no escaping, and no crash breadcrumb

**Discovered:** 2026-08-25, P(-1) hardening sweep (F-012, with F-021 and F-028 on the same write path)
**Severity:** High — hapi's declarative state silently stops describing the filesystem
**Affects:** `src/manifest_write.cyr` and `src/cmd/adopt.cyr`; live in the shipped 1.0.5
**Arc:** 1.0.x hardening, Tier 1 ([`../roadmap.md`](../roadmap.md))

## Summary

`hapi adopt` performs a read-modify-write on `hapi.cyml`: slurp the file,
splice a `[[link]]` row, write it back via `tmp` + `rename`. Nothing
serialises that sequence, and nothing makes the tmp name unique.

Two concurrent adopts — two shells, a script adopting several files, an
editor plugin invoking hapi — interleave like this: each renames the
user's file into the package, plants the symlink, appends its audit
entry, and *then* has its manifest row overwritten by whichever writer
renames last.

The result is the worst shape available: **the filesystem mutations all
commit, and the declarative record of one of them vanishes.** The symlink
exists, the file has moved, the trail says it happened — and the manifest
does not list it. `hapi status` walks manifest rows, so it cannot see the
orphan; `hapi link` will not recreate it; the user's next `git commit` of
their dotfiles repo records a package that is missing a row.

## Reproduction shape

Two `hapi adopt` invocations against the same package, started close
enough together to overlap the slurp→rename window. Both exit 0. The
manifest ends up with one new row, not two; both symlinks exist.

Note this cannot be regression-tested from `tests/*.tcyr` — the harness
cannot fork, and hapi is syscall-only by rule. See *Test home* below.

## Two more defects on the same write path

- **F-021 — no TOML escaping on the written row.**
  `manifest_append_link_row` writes `source` and `target` into
  `hapi.cyml` raw. A filename containing a quote or a newline rewrites
  the row — or injects another one — while `adopt` reports success. A
  later `link` / `sync` then acts on a row the user never wrote, creating
  a symlink at a path they never named. The parser has an escaping
  contract; the *writer* does not implement its half.
- **F-028 — a SIGKILL mid-`adopt` leaves nothing behind.** The rename
  commits before the symlink and before the trail entry, so a Ctrl-C, an
  OOM kill or a closing lid at the wrong instant moves the user's dotfile
  out of `$HOME` with **no symlink, no manifest row and no trail entry**
  — and all four recovery verbs then report a clean world. A 400-trial
  SIGKILL sweep during the audit found the window is real.

## Proposed fix

Ordered by value per unit of risk:

1. **Pid-unique `O_EXCL` tmp name.** `<manifest>.tmp.<pid>` opened
   `O_CREAT|O_EXCL`. Removes the shared-tmp collision on its own and is
   the smallest self-contained half — ship it alone if the lock proves
   awkward.
2. **`flock` the manifest across the read-modify-write.** `xflock` is
   already the portable wrapper hapi uses elsewhere (`file_append_locked`
   holds `LOCK_EX` for exactly this reason on the trail).
3. **Escape on write** (F-021), mirroring the parser's contract.
4. **Detection, not prevention, for F-028.** True crash-atomicity —
   writing intent or a breadcrumb before the rename — is an **ADR 0004
   revision**, not a patch. What 1.0.x can ship is a `hapi check` that
   surfaces the orphan: a package source with no manifest row, or a
   manifest row whose source is missing.

## Test home

F-012's and F-028's regressions need process control the `.tcyr` harness
does not have. The honest home is a **shell harness alongside
`cyrius test`**, the way [`../../benchmarks.md`](../../benchmarks.md)'s
harness already lives. That harness is a prerequisite for closing this
issue, not an afterthought — without it the fix ships unverified.

## Related

F-005 in [`../../audit/2026-05-23-audit.md`](../../audit/2026-05-23-audit.md)
is recorded as an accepted single-process TOCTOU boundary. The 2026-08-25
sweep found that scoping wrong: the damage is in the **multi-process**
case, and it is not a TOCTOU — it is this unlocked read-modify-write.
Once this lands, the residual boundary is that hapi still assumes a
single writer for the *filesystem* mutations.
