# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_Nothing yet._

## [1.0.7] - 2026-08-25

> **1.0.x hardening arc — the rest of the manifest write path.** F-021
> and F-028, the two findings left on the path 1.0.6 locked. That closes
> `issues/2026-08-25-manifest-write-integrity.md` entirely. No
> caller-visible surface change; the v1.0 contract stays frozen. Suite
> **307 assertions / 81 groups**.

### Fixed
- **A quote in a filename silently rewrote the manifest row (F-021).**
  `manifest_append_link_row` wrote `source` / `target` raw, so adopting
  a file named `.ev"il` produced `source = "ev"il"` and `hapi inspect`
  read it back as `ev` — hapi's declared state describing a file that
  does not exist, at exit 0. A later `link` / `sync` would act on that
  row.

  ⚠ **Escaping is not the fix, and finding out why changed it.** The
  audit proposed mirroring the parser's escaping contract; the parser
  turns out not to have one. Its `\`-skips-the-next-byte rule stops a
  quote from *terminating* the value but never strips the backslash, so
  a written `ev\"il` parses back as the six characters `ev\"il` —
  still not the filename. There is no un-escape half to mirror, and
  adding one would change how every existing manifest parses: an ADR
  0001 frozen-surface change, so v2.0.

  hapi therefore **refuses to write a row it cannot faithfully
  represent** — `"`, `\`, and control bytes — rather than writing one
  that quietly means something else. `adopt` checks before the rename,
  so nothing is moved: the file stays where it is with a message naming
  the reason. Ordinary names are unaffected.
- **A crash mid-`adopt` left the file invisible to every verb (F-028,
  detection half).** `adopt` renames the file into the package before it
  writes the row, so a SIGKILL, an OOM kill or a closing lid in that
  window strands the user's dotfile in the package with **no row, no
  symlink and no trail entry** — and every other verb reports a clean
  world, because they all start from manifest rows. Only a directory
  walk can see it.

  `hapi check` now compares the manifest against the package directory
  in both directions: a row whose source is missing, and a file in the
  package that no row claims. Staging leftovers (`hapi.cyml.<pid>.tmp`)
  are correctly not orphans. Exit 1 on divergence, which is what a check
  verb is for; the exit-code contract is unchanged.

  This is detection, not prevention, and deliberately so — true
  crash-atomicity means writing an intent record before the rename,
  which is an **ADR 0004 revision**, not a patch. It stays on the
  roadmap.

### Changed
- **`fs` is no longer a dead dependency.** `check`'s directory walk uses
  `lib/fs.cyr`'s `dir_list`, which already handles both the Linux and
  agnos dirent layouts — so hapi does not hand-roll a per-target dirent
  parser, which is the exact class of divergence this arc keeps finding.
  The audit's "declared but unused" note on `fs` is closed; `slice`
  remains unused.

## [1.0.6] - 2026-08-25

> **1.0.x hardening arc — Tier 1, both open items.** The trail reader
> (F-007 / F-016 / F-017) and the manifest writer's concurrency
> (F-012). Every one of them ends the same way: a verb reporting
> success having done the wrong thing, or nothing at all. No
> caller-visible surface change; the v1.0 contract stays frozen. Suite
> **295 assertions / 79 groups**, plus a new shell harness for the
> defect `cyrius test` structurally cannot express.

### Fixed
- **`rollback` reversed the wrong window once the trail passed 256 KB
  (F-007).** `audit_read` read the *first* 256 KB of an append-only
  file, so past that point it could not see the most recent checkpoint
  marker, fell back to `start = 0`, and reversed the **oldest still-live
  links** — settled dotfiles the user had not touched in months — while
  leaving the recent work in place. Exit 0, reported as success. The
  user's mental model is "undo what I just did"; the action taken was
  the exact opposite.

  Measured on a real 800-entry / 328,800-byte trail: a checkpoint, one
  new package linked, then `hapi rollback` — **637 settled links
  destroyed, and the one link the user wanted undone left in place.**
  Post-fix the same fixture reverses `1 / 1 entries`, exactly the link
  past the marker. The read is now sized from the file (`xlseek`
  SEEK_END, the same shape 1.0.5 used to fix F-009), with one byte of
  headroom so a trail that grows mid-read is detected rather than
  silently truncated.
- **An interior malformed line was silently skipped (F-016).** A bad
  sector, a partially-flushed extent after a crash, or an accidental
  editor save damaged one entry, and every consumer stepped over it:
  `rollback` claimed complete success while the link that line recorded
  survived on disk, `unlink` missed it, `list` undercounted. hapi's rule
  is that conflicts surface explicitly, and a damaged trail is a
  conflict with the user's own history — it is now refused, naming the
  line number. A **trailing** partial line is still dropped silently:
  that is the writer's atomic-append contract, and it keeps its own
  standing test.
- **An unreadable trail was swallowed as "empty" (F-017).** A
  permissions change, a failing disk or fd exhaustion made `list`,
  `rollback` and `unlink` exit 0 having done nothing, so a script keying
  on exit status concluded the rollback had succeeded. `ENOENT` is still
  `Ok(empty)` — that is the legitimate first-run case — but every other
  open or read failure is now an error.

- **Concurrent `hapi adopt` committed every filesystem mutation and
  dropped the manifest rows recording them (F-012).** The
  read-modify-write on `hapi.cyml` was unsynchronized and staged through
  a fixed `hapi.cyml.tmp`, so two adopts against one package used the
  same staging file and the last rename won.

  Measured on a 3 MB manifest with 16 concurrent adopts: **16 files
  moved, 16 symlinks planted, 16 trail entries — and 1 manifest row.**
  hapi's declarative state stopped describing its own filesystem, and
  because `status` walks manifest rows it could not see the orphans.
  Two changes, and the order matters — the first alone made things
  *worse*: staging is now `hapi.cyml.<pid>.tmp` opened `O_EXCL` (before
  it, 14 of the 16 adopts failed outright and were at least visible;
  after it they all "succeeded" and 15 rows vanished silently), and the
  read-modify-write now holds `LOCK_EX` for its whole duration. The lock
  is taken on the **package directory**, not the manifest: the manifest
  is replaced by rename, so writers flocking it by path can hold two
  different inodes and exclude nobody — and locking the directory leaves
  no `.lock` artifact in the user's dotfiles repo. Post-fix: 16/16 on
  every axis across repeated runs.

### Added
- **`scripts/concurrency-test.sh`** — the regression harness for F-012.
  The defect needs two hapi *processes*, and `.tcyr` cannot fork while
  hapi is syscall-only by rule, so there was no honest way to express it
  inside `cyrius test`. It lives alongside, the way the benchmark
  harness does, and CI runs it. Mutation-proven: dropping the lock turns
  it RED with `manifest rows: got 1, expected 16`.

### Changed
- **`audit_read_r` / `audit_read_default_r`** return a `Result`, and
  `rollback` / `unlink` / `list` use them: on a trail that exists but
  cannot be read or parsed, each prints what is wrong (with the line
  number for a corrupt entry) and exits 1 rather than acting on a
  partial view. `audit_read` remains as a vec-returning wrapper for call
  sites that genuinely cannot act on an error.
- **`tests/hapi.tcyr`'s "drops malformed lines" group is now "refuses an
  interior malformed line".** That test asserted the behaviour F-016
  identifies as the defect — it was encoding the bug as the contract, so
  it changed with the fix. Each of the three repairs is mutation-proven:
  reverting them turns the new group RED with ten distinct failures,
  including F-007's `got 882, expected 1000` as the old cap truncates
  mid-trail.

## [1.0.5] - 2026-08-25

> P(-1) hardening sweep per CLAUDE.md, and the repairs out of it.
> **Six HIGH-severity defects fixed** — two heap overflows reachable from
> an ordinary manifest, two silent destructions of user bytes, one
> capability escape, and one argument-parsing bug that made
> `hapi rollback <pkg>` reverse the entire trail. Full record in
> [`docs/audit/2026-08-25-audit.md`](docs/audit/2026-08-25-audit.md),
> including the **twenty findings that remain open**. No caller-visible
> surface change; the v1.0 contract (command surface, ADR 0001 manifest
> schema, ADR 0002 audit-trail format) stays frozen and byte-identical.
> Suite **280 assertions / 76 groups**; `cyrius lint` clean tree-wide;
> x86_64, aarch64 and agnos all build.

### Fixed
- **`hapi_mf_canonicalize` ignored its `cap` argument — heap overflow,
  SIGSEGV, exit 139 (F-014).** A 3,000-row manifest (138 KB, well under
  the cyml read cap) killed `hapi link`, `hapi sync` **and
  `hapi link --dry-run`** with an exit code outside the published 0/1/2
  contract and no diagnostic. `--dry-run` is not spared because the
  manifest hash is computed before the dry-run branch. The overflow
  lands on the `sorted` vec the row loop is iterating, so the faulting
  pointer is built from manifest bytes. Writes are now bounded and
  `hapi_mf_canonical_size` sizes the caller's buffer, so that manifest
  **links successfully** rather than merely refusing. It refuses rather
  than truncates when a buffer really is too small: these bytes are the
  `sha1c:` `manifest_hash` preimage frozen by ADR 0002, so a short
  prefix would quietly hash a different document. Canonical output is
  unchanged for every manifest that already fit — asserted by an
  exact-size byte comparison, the four standing canonical-hash groups,
  and a benchmark trail that is byte-identical at 101,150 bytes.
- **Audit entry composers ignored `cap` — out-of-bounds heap write that
  destroyed the trail (F-008).** `_audit_emit_field` wrote unbounded
  into a fixed `alloc(4096)`, and both bounds are attacker-sized: the
  values come from the manifest and the JSON escaper expands a control
  byte 6:1. A legal 19×200-character target composed 8,027 bytes into
  4,096; the same target as `0x01` bytes composed 46,028 — a ~42 KB
  overflow of attacker-chosen content. The post-format
  `audit_ensure_dir()` then bump-allocated *on top of* the formatted
  bytes, so the line reaching disk carried spliced heap content and a
  raw NUL: `link` exited 0, the trail stopped parsing, and `unlink`
  reported `unlinked 1 / 1` while the symlink stayed on disk. Writes are
  now bounded and each buffer is sized from its own inputs; an entry
  that cannot fit refuses through the existing
  `hapi: audit-trail write failed` / exit 1 path. Never truncates — a
  short line has no `\n`, so the next entry concatenates onto it and the
  reader drops both.
- **`adopt` applied no capability bound to its `<file>` argument
  (F-011).** `hapi adopt /path/outside/$HOME/f pkg` with **no `--root`**
  exited 0, moved the file out of its directory and planted a symlink
  there — a direct violation of CLAUDE.md's *"do not write outside
  `$HOME` without an explicit `--root` flag"*. `adopt`'s `<file>` is a
  write target and is now checked like one, via a new
  `cap_within_scope(path, scope_root)` that lexically normalizes both
  sides before a component-boundary match. Absolute and `../` escapes
  refuse with exit 1 and leave the file untouched; a file inside `$HOME`
  still adopts; and a path outside `$HOME` **with** a `--root` grant
  still adopts, so the capability grant keeps working.
- **`hapi rollback <pkg>` reversed the entire trail (F-013).** Every
  verb silently discarded positional arguments it had no slot for, so a
  user scoping a rollback to one package destroyed every link in the
  visible trail at exit 0 — and `hapi link A B` reported complete
  success having linked only A. Every verb now rejects an extra
  positional with exit 2 and a named diagnostic. Legitimate forms are
  unaffected.
- **A manifest past 256 KB was truncated and the truncation committed
  (F-009).** `_hmw_slurp` read into a fixed `alloc(262144)` and stopped
  at the cap with no signal, and both callers hand the buffer straight
  to the atomic rewrite — so `hapi adopt` on a 300 KB manifest exited 0
  having permanently deleted the markdown body and everything after it.
  ADR 0001 sanctions an arbitrarily long body below the `---`
  separator, so the size is reachable without doing anything unusual.
  The buffer is now sized from the file, with one byte of headroom so a
  file that grew mid-read is refused rather than committed short.
- **`--backup-to` destroyed one snapshot when two rows shared a target
  basename (F-010).** The destination is `<ts>-<pkg>-<basename>`, so
  `a/config` and `b/config` composed the same path inside one second and
  the second copy overwrote the first — destroying exactly the bytes
  `--force` was about to delete — while both trail entries pointed
  `backup_path` at the survivor. The composer now suffixes `-2`, `-3`, …
  until the name is free, and the copy opens `O_EXCL` instead of
  `O_TRUNC` as the backstop. Two adjacent repairs rode along: a `w == 0`
  write result is an error rather than a silent spin, and the write-side
  `file_close` return is captured, since a deferred error on the last
  copy of the bytes must not read as success.

### Changed
- **CI compiles `--aarch64` and `--agnos`, not just x86_64.** Two
  compile-only steps in `ci.yml`. Cross-compilation is all a GitHub runner
  can do for these — there is no aarch64 runner and agnos needs mirshi — but
  compiling is the check that was missing: `--aarch64` silently stopped
  building at 1.0.2 over a bare `SYS_OPEN` and nothing noticed until 1.0.4,
  because CI built one target. That matters more now that cyrius 6.5.1 makes
  a wrong argument count a hard error rather than a warning, so an unbuilt
  target can break on drift the x86_64 build accepts.
- **`cyrius lint` is clean across `src/` AND `tests/`** — 0 deferrals,
  0 warnings, 0 notes. Six untracked deferrals cleared: two were the
  linter matching `XXX` inside the `\uXXXX` escape notation
  (`#skip-lint`), two were real deferrals that now carry their tracking
  cross-reference (`cap.cyr` → F-002, `cmd/sync.cyr` → the sync-prune
  issue), two were stale prose describing milestones that shipped long
  ago. Ten over-long lines and a stray blank-line run cleared: seven of
  them were manifest fixtures in `tests/hapi.tcyr` written as one long
  escaped string, now **real multi-line literals** — the fixture reads
  like the manifest it is, at a third the line length. The one fixture
  that stays escaped is the cosmetic-insensitivity case, whose whole job
  is to carry trailing whitespace and a two-blank-line run; it is
  `#skip-lint` with the reason written next to it.
- **`link_probe`'s directory discrimination moved onto `io.cyr`'s
  portable wrappers** — `file_open` / `xgetdents` / `file_close` instead
  of `sys_open` + two raw `syscall(...)` numbers. Clears the last two
  lint notes and, more to the point, retires the last instance of the
  exact pattern that kept `--aarch64` from building between 1.0.2 and
  1.0.4. Behaviour is unchanged on every target; the block still sits in
  the non-agnos `#else` arm.
- **The sweep's open findings are tracked as arc work, not an audit
  appendix.** `docs/development/roadmap.md` gained a **1.0.x hardening
  arc** ahead of the additive v1.x bucket, bucketing all twenty by blast
  radius (Tier 1 silent data loss / Tier 2 wrong reporting / Tier 3
  hardening / target-conditional) with explicit exit criteria: additive
  growth does not resume while a Tier 1 finding is open. Three new issue
  files carry the Tier 1 and Tier 2 clusters, and `state.md` points at
  them. The roadmap's kavach migration bullet — the dep gate the audit
  found void — is withdrawn in place with the reason.

### Known limitations
- **Twenty audit findings from this sweep remain open in the shipped
  1.0.5.** They are recorded in
  [`docs/audit/2026-08-25-audit.md`](docs/audit/2026-08-25-audit.md) and
  scheduled as the **1.0.x hardening arc** in
  [`docs/development/roadmap.md`](docs/development/roadmap.md). Tier 1,
  where the failure is silent data loss or a wrong destructive action:
  **F-007**, the trail reader's 256 KB head cap, which makes `rollback`
  reverse the *oldest still-live* links once the trail outgrows it;
  **F-012**, the unlocked manifest read-modify-write, under which
  concurrent `adopt` commits every filesystem mutation and drops the row
  recording it; and **F-015**, a symlinked intermediate component in a
  manifest target escaping `$HOME` with no `--root` at all.
- **F-002's dependency gate is void.** ADR 0005 parks the symlink-escape
  fix on kavach exposing a stable `cap_check(scope, action)` API.
  kavach is at 3.12.3 and is a *sandbox execution* framework — ten
  backends, strength scoring, credential proxy, HMAC audit chain — whose
  entire public path surface is `kavach_path_exists`. There is no such
  API and none is planned, and adopting it would collide with hapi's
  no-process-spawning rule. F-002 is hapi-owned work now, and the
  primitive it needs (`hapi_readlink`, portable across all three
  targets) landed in 1.0.4.
- **Six files still fail `cyrius fmt --check`** under 6.5.28's indent
  contract, unchanged from 1.0.4. Deliberately not reformatted inside a
  release cut, because 6.5.28 also made `cyrius fmt <file>` rewrite in
  place — the remedy the tool prints would silently rewrite the
  ADR-0002-frozen `src/audit.cyr` and the 280-assertion suite.

## [1.0.4] - 2026-08-25

> Toolchain + vendored-stdlib refresh (cyrius `6.4.22` → `6.5.35`),
> the agnos `readlink`#70 `link_probe` work that had been sitting in
> Unreleased, and one latent audit-trail defect the new toolchain's
> call-arity check surfaced. No caller-visible surface change; the
> v1.0 contract (command surface, ADR 0001 manifest schema, ADR 0002
> audit-trail format) stays frozen. Suite **246 assertions / 71
> groups**, all passing; `--agnos` build green; `cyrius lint` clean.

### Fixed
- **`rollback` emitted a junk `backup_path` when reversing an `unlink`.**
  `_hrb_reverse_unlink` (`src/cmd/rollback.cyr`) called the eight-argument
  `audit_append_link_r` with seven: the optional `backup_path` was never
  passed, so the callee read an uninitialized argument slot and the replay
  entry could carry the field with a meaningless value. The reversal only
  ever recreates a symlink into an **absent** target — nothing is
  destructively overwritten, so there is no snapshot to record — and the
  call now passes `0`, the documented "no backup" value (`src/audit.cyr`
  emits the additive field only when `backup_path != 0 && strlen(...) > 0`).
  ADR 0002's frozen **required**-field set is untouched; this only stops an
  *optional* field from appearing where it has no meaning. The mismatch dates
  to 0.8.0, when `--backup-to` gave `audit_append_link_r` its eighth
  parameter and this call site was not updated with it. It shipped in every
  release from 0.8.0 through 1.0.3 because a wrong argument count was a
  **warning** until cyrius 6.5.1 — the compiler emitted the binary anyway,
  so the only outward sign was one easily-missed line. 6.5.1 made it an
  error (`_CHECK_ARITY` sets `_had_error`, no binary produced), which is why
  adopting 6.5.35 is what surfaced it. Locked by a new regression group —
  mutation-proven: it goes RED when the argument is replaced with a non-zero
  path. Three call sites in `tests/hapi.tcyr` carried the same omission (plus
  one nine-argument `audit_format_link`) and are fixed with it.
- **`cyrius build --aarch64` did not compile.** `src/fs_link.cyr`'s
  `link_probe` opened the probe fd with a bare
  `syscall(SYS_OPEN, path, 0, 0)`, and there is no `SYS_OPEN` on aarch64
  Linux — it has `openat(2)` only, so `lib/syscalls_aarch64_linux.cyr`
  deliberately declines to define the constant (its own comment notes that
  56 there is `openat` while 56 on x86_64 is `io_setup`, so a bare number
  would be worse than an undefined one). The site now calls the named
  `sys_open(path, flags, mode)` wrapper, which every non-agnos table
  provides and which routes through `SYS_OPENAT` + `AT_FDCWD` on aarch64.
  It sits in the non-agnos `#else` arm, so agnos's differently-shaped
  `sys_open(name, namelen, flags)` is out of reach. Pre-existing and
  unrelated to the pin bump — CI has never built aarch64 — and it is the
  last un-swept site from the 1.0.2 named-wrapper migration that actually
  broke a target. x86_64 and agnos codegen are unaffected; the suite is
  unchanged at 246.

### Changed
- **Toolchain pin `6.4.22` → `6.5.35`** (`cyrius.cyml` `[package].cyrius`)
  and **vendored `lib/` resynced to the 6.5.35 snapshot**
  (`cyrius lib sync --full`): 108 files — 67 updated, 10 new
  (`async_macos.cyr`, `async_win.cyr`, `thread_macos.cyr`, and the seven
  files of the `lib/unicode/` package directory), none removed. hapi's
  declared `[deps] stdlib` set is unchanged, and nothing hapi calls was
  renamed, moved, or removed across the span — the three stdlib symbols
  retired between the pins (`_arena_alloc` / `_arena_reset` in `alloc`,
  `_macho_capture_args` in `args_macos`, `json_v_parse_str` in `bayan`)
  have no hapi call sites. The stale `lib/agnosys.cyr` bundle — vendored at
  scaffold, dropped from the upstream snapshot at 6.4.x, never `include`d by
  hapi — is pruned, so `lib/` again mirrors the pin exactly.

  ⚠ **The shipped binary roughly doubles: ~280 KB → 562,992 bytes.** That is
  the cost of the bigger 6.5.35 stdlib (`bayan` alone gained 439 functions
  between the pins), not of anything hapi added — hapi's own source barely
  moved this release. Note also that `CYRIUS_DCE=1`, which the release
  workflow sets, now produces a binary of **exactly the same size** as a
  plain build (byte-different, same length): this cyrius NOPs dead
  functions in place rather than removing them, so the flag no longer buys
  the size reduction `release.yml`'s comment still claims for it. Nothing
  is broken by that — the DCE smoke run passes — but the artifact is
  larger, and a future release that cares about download size should take
  that up with the toolchain rather than expect DCE to fix it.
- **`link_probe` on agnos uses `readlink`#70, not stat-classification.**
  agnos grew a ring-3 `readlink#70` — the symlink-introspection peer of
  `symlink#63` — so `src/fs_link.cyr`'s agnos branch probes readlink FIRST:
  `n > 0` ⇒ it is a symlink and hapi already holds the target to byte-compare
  against the manifest (a DANGLING link included — #70 SEES it, where
  `stat#33` reported it absent); otherwise it falls back to `stat#33` to split
  file/dir/absent (stat follows, but the path is not a symlink there). This
  closes the agnos-only gap 1.0.3 documented under *Known limitations* — hapi
  could create links but could neither see an existing one nor read its target
  for `status` / reconcile. Linux/macOS `link_probe` and every other target
  path are byte-unchanged.
- **`hapi_readlink` now calls the native `sys_readlink` peer on agnos.** The
  6.5.35 snapshot ships `sys_readlink(path, pathlen, buf, buflen)` in
  `lib/syscalls_x86_64_agnos.cyr`, so the shim in `src/agnos_compat.cyr` drops
  its locally-declared `AGNOS_SYS_READLINK = 70` and the raw `syscall(...)`
  form — exactly the collapse the shim's own comment planned for, and the same
  path `hapi_symlink` took for #63 at the 6.4.x refresh. The agnos/Linux
  divergence is now only the arity.
- **`hapi --version` derives its number from `CYRIUS_PKG_VERSION`.**
  `hapi_print_version` (`src/main.cyr`) carried a hand-synced `"hapi 1.0.3"`
  literal that had to be bumped in lockstep with `VERSION` — an
  undocumented third sync point beside `VERSION` and the CHANGELOG header.
  cyrius 6.5.21 exposes the resolved `[package].version` (i.e.
  `${file:VERSION}`) as the compile-time constant `CYRIUS_PKG_VERSION`, and
  6.5.34 made it visible inside `include`d files as well, so the literal is
  retired and `VERSION` is the single source. Output shape is byte-identical
  (`hapi <X.Y.Z>`), which the release workflow's smoke step already asserts
  against the git tag.

- **CI installs the toolchain with the upstream installer, not a hand-rolled
  untar.** Both workflows read the `cyrius.cyml` pin and pipe it to
  `scripts/install.sh` from the cyrius repo, then assert
  `~/.cyrius/versions/<pin>/lib` exists before going further. The old block
  untarred the release asset into a flat `$HOME/.cyrius/{bin,lib}` — the
  pre-6.5 layout — which 6.5.x's `cyrius deps` rejects outright:
  `error: cyrius.cyml pins version 6.5.35 but it is not installed at
  ~/.cyrius/versions/6.5.35/lib`. That is what broke CI on this pin bump. The
  installer lays out `versions/<v>/{bin,lib}` and symlinks `bin/` and `lib/`
  at it, and additionally does SHA256 + Ed25519 signature verification the
  old block skipped — which also had `|| true` on every `cp`, so a
  half-copied toolchain reported success. Same pattern as darshana / patra /
  libro. Verified end to end against a from-scratch install into a scratch
  `CYRIUS_HOME`: the snapshot lands with 108 `.cyr` files, `cyrius deps`
  exits 0 and leaves the vendored `lib/` byte-identical, and build + suite +
  the release DCE smoke all pass.

### Known post-upgrade items
- **`cyrius fmt --check` now fails on six files** — five in `src/`
  (`agnos_compat`, `audit`, `fs_link`, `cmd/adopt`, `cmd/link`) plus
  `tests/hapi.tcyr`. 6.5.28 gave `fmt` a canonical continuation-indent
  contract (2 spaces per open paren, 4 accepted, deeper rejected) that
  hapi's existing style predates, so `cyrius audit`'s fmt step is red purely
  from the toolchain move. Not reformatted here on purpose: **6.5.28 also
  made `cyrius fmt <file>` rewrite in place** (stdout-only before; `--dry`
  is the old behaviour), and reflexively running the remedy the tool prints
  would silently reformat the ADR-0002-frozen `src/audit.cyr` and the
  246-assertion suite inside a release cut. `ci.yml` does not run `fmt`, so
  nothing is blocked. Review with `cyrius fmt <file> --dry` and reformat as
  its own commit after the tag.
- **Two `cyrius lint` line-length warnings** (`src/manifest.cyr:25`,
  `src/manifest_write.cyr:80`, both over 120 chars), and a new lint *note*
  on `src/fs_link.cyr:89` recommending `lib/io.cyr`'s `xgetdents` over the
  raw `SYS_GETDENTS64` for agnos-bound directory code. `cyrius lint
  src/main.cyr` is clean; these surface per-file.
- **`fs` and `slice` are declared but unused** in `cyrius.cyml`
  `[deps] stdlib` — zero `fs_*` and zero `slice_*` call sites. `lib/fs.cyr`
  now carries 6.5.24's `#host_only` annotation, which is a hard error under
  a kernel-mode build, so hapi is carrying its only `#host_only` module for
  no benefit. Dropping both is a post-tag cleanup, not a release change.
- **`src/manifest.cyr` reaches `bayan` through deprecation shims** —
  `cyml_parse_file_r` / `cyml_doc_header` / `cyml_doc_header_len` are
  one-line forwarders onto the real `bayan_cyml_*` entry points. Pure
  forwarders today, deletable upstream at any minor bump with no
  compile-time warning until they vanish. Three-line migration, post-tag.

### Removed
- **Known limitation "symlink introspection is unavailable on agnos"**
  (recorded at 1.0.3). agnos `readlink#70` plus the native cyrius peer close
  it: hapi can now see an existing link and read its target on agnos, so
  `status` / reconcile behave as they do on Linux. agnos still exposes no
  `lstat` and no `getcwd` — `link_probe` needs neither (readlink no-follows
  the final component), and `_fsl_getcwd` continues to return `"."` there.

## [1.0.3] - 2026-07-08

> agnos target support + toolchain/vendored-stdlib refresh
> (cyrius `6.2.24` → `6.4.22`). hapi now compiles `--agnos` and runs
> under mirshi (>= 1.10.2), unblocking it in the agnos-dev docker
> image. No caller-visible surface change; the v1.0 contract (command
> surface, ADR 0001 manifest schema, ADR 0002 audit-trail format)
> stays frozen. Suite still **242 assertions / 66 groups**, all passing.

### Added
- **agnos target support** (`cyrius build --agnos src/main.cyr`).
  New `src/agnos_compat.cyr` centralizes the syscall-ABI divergences
  behind thin wrappers
  (`hapi_unlink`/`hapi_rename`/`hapi_fsync`/`hapi_symlink`/`hapi_mkdir`)
  that forward verbatim on Linux/macOS. `link_probe` classifies via
  `stat` (#33) on agnos; `hapi_symlink` uses the native agnos
  `sys_symlink` (#63); `hapi_fsync` maps to `sync` (#12); `hapi_mkdir`
  bridges the `(path, mode)` → `(path, pathlen)` ABI and treats an
  existing directory as success.

### Changed
- **Toolchain pin `6.2.24` → `6.4.22`** (`cyrius.cyml`
  `[package].cyrius`) and **vendored `lib/` resynced to the 6.4.22
  snapshot** (`cyrius lib sync --full`, 98 files). The refresh brings
  the agnos peer's native `sys_symlink` — so `hapi_symlink` calls it
  directly rather than a locally-defined syscall number — and an
  agnos-aware `file_append_locked` (LOCK_EX hold + explicit `SEEK_END`,
  since the agnos kernel does not honor `AO_APPEND` yet), so hapi no
  longer ships its own agnos append shim.
- **`src/fs_link.cyr` — per-target syscall paths.** `link_probe` uses
  `stat` (#33) mode-nibble classification on agnos (agnos has no
  `readlink`); the Linux `readlink` + `getdents64` path is unchanged
  behind `#else`. `_fsl_getcwd` returns `"."` on agnos (no `getcwd`
  syscall). `SYS_GETDENTS64` / `SYS_GETCWD` references are now
  Linux-gated so the agnos build resolves.

### Known limitations (agnos)
- **Symlink introspection is unavailable on agnos.** agnos exposes no
  `lstat` and no `readlink` to ring-3, and its `stat` follows the final
  symlink component (kernel `ext2_path_lookup`). So on agnos hapi cannot
  yet SEE an existing symlink or read its target: a symlink to an
  existing target classifies as that target's type, and its target
  cannot be compared in `status`/reconcile. Symlink *creation* (#63)
  works. Lifting this needs an agnos-side `lstat`/`readlink` surface.

## [1.0.2] - 2026-06-19

> Toolchain + vendored-stdlib refresh. No caller-visible surface
> change; the v1.0 contract (command surface, ADR 0001 manifest
> schema, ADR 0002 audit-trail format) stays frozen. Suite still
> **242 assertions / 66 groups**, all passing.

### Changed
- **Toolchain pin `6.0.1` → `6.2.24`** (`cyrius.cyml`
  `[package].cyrius`). The wrapper had already drifted to 6.2.24;
  this aligns the manifest pin with it.
- **Vendored `lib/` resynced to the 6.2.24 snapshot**
  (`cyrius lib sync`). Tracks the upstream stdlib carves: the
  former standalone `base64` / `csv` / `u128` / `bigint` / `toml` /
  `cyml` / `json` modules are now folded into the bundled **`bayan`**
  data-format module, and `matrix` / `linalg` / `math_advanced`
  into **`ganita`** (v6.1.25 carve). The nine now-folded standalone
  `lib/*.cyr` files were removed; `lib/bayan.cyr` + `lib/ganita.cyr`
  (and the new platform/tls split-outs) were added.
- **`src/manifest.cyr` include `lib/cyml.cyr` → `lib/bayan.cyr`.**
  The three `cyml_*` call sites (`cyml_parse_file_r`,
  `cyml_doc_header`, `cyml_doc_header_len`) are unchanged —
  `bayan`'s `_compat` section re-exports the old `cyml_*` names as
  thin shims over `bayan_cyml_*`, so the parser is byte-for-byte
  behaviourally identical. Release builds (`CYRIUS_DCE=1`) strip
  the unused `bayan` format bundles.
- **`cyrius.cyml` `[deps].stdlib`** — dropped `toml` + `cyml`
  (no longer stdlib modules), added `bayan`.

### Removed
- **`HapiSysno` enum + raw `syscall(N, …)` rename/fsync calls.**
  The stdlib `sys_rename` / `sys_fsync` / `sys_fdatasync` wrappers
  landed in cyrius 6.2.x (the coordinated removal flagged in
  [1.0.1]), so `src/manifest_write.cyr`, `src/cmd/adopt.cyr`, and
  `src/cmd/rollback.cyr` now call the named wrappers instead of
  the hand-rolled `HAPI_SYS_RENAME` (82) / `HAPI_SYS_FSYNC` (74)
  constants. Behaviour is unchanged on x86_64 (identical numbers)
  and now **arch-correct on aarch64** — the raw `82`/`74` literals
  were x86_64-only, whereas the wrappers route through the
  per-arch `renameat` / `fsync` syscalls. No caller-visible change.

## [1.0.1] - 2026-05-24

> 1.0.x-final hardening patch — closes the 1.0.x patch line. No
> caller-visible surface change; the v1.0 contract (command
> surface, ADR 0001 manifest schema, ADR 0002 audit-trail format)
> stays frozen. Internal syscall naming, one regression test, and
> the 1.0.x-final P(-1) audit pass.

### Changed
- **Syscall sites named (internal; no behavior change).** The bare
  `syscall(2/3, …)` probe calls in `src/fs_link.cyr` now use the
  stdlib `SYS_OPEN` / `SYS_CLOSE` constants, matching the existing
  `SYS_GETDENTS64` / `SYS_GETCWD` usage in the same file. The
  scattered `syscall(82, …)` rename calls (`manifest_write` /
  `adopt` / `rollback`) and the `syscall(74, …)` fsync call now
  resolve through one `HapiSysno` enum (`HAPI_SYS_RENAME` /
  `HAPI_SYS_FSYNC`) in `src/manifest_write.cyr`, marked for
  coordinated removal when the stdlib `sys_rename` / `sys_fsync`
  wrappers land (cyrius proposals 2026-05-17 / 2026-05-20).
  Codegen-identical — the constants resolve to the same numbers.

### Added
- Test: `sync: recovers after the audit trail is lost (drive-move
  scenario)` — locks the recovery semantics surfaced 2026-05-24
  (relative links survive a wiped `$XDG_STATE_HOME`, re-sync is a
  clean no-op, and the no-op sync does not rebuild the trail).
  Suite now **242 assertions / 66 groups**.
- `docs/audit/2026-05-24-audit.md` — the 1.0.x-final P(-1) re-walk
  pass; `docs/audit/README.md` establishes the audit-arc convention
  + index. New finding F-006 (audit trail lost on state-dir wipe)
  accepted as a boundary.
- Issues filed: `2026-05-24-no-arg-sync-bootstrap-recovery.md`
  (dogfood pressure on no-arg `sync` + the root-scan-over-trail
  design correction) and `2026-05-24-audit-trail-lost-on-state-dir-wipe.md`.

## [1.0.0]

### Breaking
- **Contract freeze.** The v1.0.0 release locks the contract
  for three surfaces. No signature changed in this release —
  the freeze IS the contract change.
  - **Command surface** — ten verbs (`link` / `unlink` /
    `adopt` / `sync` / `list` / `status` / `checkpoint` /
    `check` / `inspect` / `rollback`) plus four global flags
    (`--root`, `--dry-run`, `--backup-to`, `--force`,
    `--strict`). Arg shapes, exit codes, stdout / stderr line
    layouts are now contractual.
  - **`hapi.cyml` manifest schema** per ADR 0001 — frozen.
    `[package]` + `[[link]]` rows + the `ignore` glob list,
    with the validation rules in `src/manifest.cyr`.
  - **Audit-trail format** per ADR 0002 — frozen. JSONL with
    the required-field set, `sha1c:` canonical-hash prefix,
    additive-growth contract (readers MUST tolerate unknown
    fields). Pre-v1.0 `sha1:` raw-bytes hashes continue to be
    tolerated by readers.

  All five ADRs (0001 / 0002 / 0003 / 0004 / 0005) carry
  **Status: Frozen at v1.0.0 (2026-05-23)** as of this release.
  Post-v1.0 surface growth lives in the roadmap's *Deferred*
  section and any v1.x patch / minor must respect the freeze.

### Added
- `docs/development/release-notes/1.0.0.md` — the v1.0 release
  notes. Explains what "v1.0" means concretely (three frozen
  surfaces), walks the v1.0-criteria checklist, lists the
  post-v1.0-deferred items with rationale, and gives the
  v0.9.0 → v1.0.0 upgrade contract (no code changes required;
  v1.0 readers parse every v0.x trail).
- All five ADR Status lines updated to *Accepted — Frozen at
  v1.0.0 (2026-05-23)*; each ADR gains a one-paragraph
  freeze-contract note immediately under the Status header.

### Changed
- Roadmap *v1.0 criteria* checklist — every box ticked with
  the artifact that satisfies it.
- Roadmap M8 section — marked SHIPPED with the date.
- CLAUDE.md *CHANGELOG Format* paragraph clarified: manifest
  format and audit-trail format are now post-v1.0 frozen
  rather than "Breaking until v1.0."

### Filed
- Two open issues, both explicitly deferred post-v1.0 with
  rationale captured in the roadmap:
  - `issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`
    — row removal via full rotation works today; `--prune`
    surface is post-v1.0 if user demand earns it.
  - `issues/2026-05-23-cap-check-symlink-escape.md` — F-002
    MEDIUM from the audit pass. Lexical-only normalization at
    the cap-check; symlink-aware resolution lands with the
    kavach migration without breaking the `cap_check_root_r`
    API.

## [0.9.0]

### Security
- **F-001 [HIGH] — `--root` `..` bypass**, fixed.
  `cap_check_root_r` now lexically normalizes the resolved
  path (and `$HOME`, and each `HAPI_ALLOWED_ROOTS` entry)
  before the byte-prefix match. The pre-fix bypass —
  `--root /home/user/../etc/secret` passing as "within
  $HOME" while denoting `/home/etc/secret` — is rejected.
  New helper `fsl_lexical_normalize(path)` in
  `src/fs_link.cyr` collapses `.` and `..` segments without
  filesystem calls. Symbol-only fix; no caller signature
  changes.
- **F-003 [LOW] — backup-copy TOCTOU symlink race**, fixed.
  `hapi_backup_copy` now opens the source with
  `O_NOFOLLOW` (0x20000), so a `mv symlink → src` race
  between probe and copy fails with `ELOOP` instead of
  copying through the symlink. Defends the documented
  "snapshot of the original file's bytes" contract.
- **F-002 [MEDIUM] — `--root` symlink escape**, deferred.
  Lexical normalize does not resolve symlinks; the kavach
  migration owns the proper per-component resolution.
  Filed at `issues/2026-05-23-cap-check-symlink-escape.md`
  with reproduction + workaround.

### Added
- `docs/audit/2026-05-23-audit.md` — P(-1) hardening pass
  per CLAUDE.md Process step. Covers path traversal,
  symlink loops, TOCTOU, and capability boundary. Files
  three repairs (F-001 HIGH, F-003 LOW landed; F-002 MEDIUM
  deferred to kavach) and two accepted boundaries (F-004,
  F-005 per ADRs 0002 / 0004).
- `fsl_lexical_normalize(path)` in `src/fs_link.cyr` —
  pure-string `.` / `..` collapser. Used by
  `cap_check_root_r` and the `HAPI_ALLOWED_ROOTS` walker.
- Test suite grew 218 → 235 assertions (61 → 65 groups).
  New groups: lexical normalize, cap-check dotdot reject,
  allowlist normalization, backup-copy O_NOFOLLOW defense.
- `docs/benchmarks.md` — first M7 baseline. `sync` over a
  100-package / 350-link synthetic home: cold 72 ms (205 µs
  per link), warm 54 ms (154 µs per probe; 0 audit growth
  per the idempotency contract). Per-entry audit size 289
  bytes average — comfortably under the PIPE_BUF atomicity
  ceiling per ADR 0002. Reproduction harness inlined.

### Filed
- One open issue from the audit pass:
  `issues/2026-05-23-cap-check-symlink-escape.md` (F-002
  MEDIUM) — `--root` symlinked-component escape. Deferred
  to the kavach migration per ADR 0005.

## [0.8.0]

### Breaking
- Audit-trail `manifest_hash` prefix swap: `sha1:` →
  `sha1c:`. Writers emit only the canonical variant going
  forward; readers tolerate both prefixes during the
  M7 → M8 transition. Per ADR 0002, this is the prefix-swap
  Breaking the spec reserved at the format's introduction —
  the surrounding line format is unchanged. The
  `manifest_hash` field is diagnostic-only (rollback's
  identity check is `(pkg, target)`), so no consumer code
  needs to special-case the prefix; v0.x trails continue
  to read cleanly. Canonical form: `[package]` fields in
  fixed order (`name`, `version`, `description?`, `ignore?`),
  `[[link]]` rows sorted by `target` lex byte order, no
  comments, single blank line between sections, only `"` and
  `\` escaped in strings. Cosmetic edits (whitespace,
  comments, row reordering) now produce the same hash.

### Added
- `--backup-to <dir>` global flag — opt-in pre-`--force`
  snapshot. Accepted on **link, sync, adopt**; rejected with
  exit 2 on other verbs. Snapshots regular-file conflicts (not
  symlinks — symlinks point at content elsewhere). Filename
  shape: `<YYYYMMDD-HHMMSS>-<pkg>-<basename>`. Composes with
  `--dry-run` (destination printed; no snapshot written) and
  `--root`. Resolves
  `issues/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md`.
- `src/backup.cyr` — new module owning the process-wide
  `_hapi_backup_dir` flag (setter / getter mirror
  `cli.cyr::hapi_set_dry_run`), the `<ts>-<pkg>-<basename>`
  filename composer, and the byte-copy primitive
  (`hapi_backup_copy`).
- ADR 0002 additive field: `backup_path` (string, optional)
  on `link` and `adopt` entries. Per the ADR's growth
  contract, readers from v0.7.0 and earlier tolerate the new
  field without surfacing it. Audit reader (`hae_backup_path`)
  exposes the field on `HapiAuditEntry` for forward consumers.
- `docs/guides/backup-to.md` — cross-cutting guide for the
  new flag (semantics, filename layout, when to use it,
  composition with `--dry-run` / `--root`, audit-trail
  growth note).
- `hapi_mf_canonicalize(m, out, cap)` in `src/manifest.cyr`
  — re-serializes a parsed manifest to a fixed byte
  representation: `[package]` fields in fixed order,
  `[[link]]` rows sorted by `target`, no comments, single
  blank line between sections, only `"` and `\` escaped.
  Internal contract; bytes never surface to users.
- `audit_manifest_hash_raw(path)` in `src/audit.cyr` —
  legacy `sha1:` over raw file bytes, kept for trail-format
  diagnostics on pre-Unreleased entries. New entries use
  the canonical form by default.
- `docs/guides/status.md` — *Exit-1 is an assertion, not a
  predicate* section. Documents that `status`'s exit-1-on-drift
  is for CI / assertion use; points users at `link --dry-run`
  for the `&&`-chain pre-flight pattern. Resolves
  `issues/2026-05-20-status-exit-1-short-circuits-script-chains.md`
  (Tier-1). Zero code change — the surface already exists; the
  guide makes the contract legible.
- `docs/guides/upstream-drift.md` — new guide for the
  hyprland-class workflow where upstream rewrites its stock-
  config template every few releases. Codifies the 10-step
  audit + merge ritual, lists syntax-shift markers
  (wiki URLs, `autogenerated = 1` header, block-syntax
  migrations, new defaults), and specifies the dated
  tracking-note header that makes the next drift cycle
  cheaper. Resolves
  `issues/2026-05-20-upstream-stock-template-drift-pattern.md`
  (Tier-1). Tier-2 architecture note and Tier-3 speculative
  `hapi merge` verb remain post-v1.0 candidates.

### Changed
- `audit_manifest_hash(path)` now parses the manifest,
  canonicalizes it via `hapi_mf_canonicalize`, and hashes
  the canonical bytes. Returns `sha1c:` + 40 hex chars
  (was `sha1:` over raw file bytes at v0.7.0).
- ADR 0002 — gained a *Hash* table documenting both
  `sha1:` and `sha1c:` prefixes, the canonical re-serialization
  rules, and the reader-tolerates-both contract.
- `audit_format_link` / `audit_append_link_r` /
  `audit_format_adopt` / `audit_append_adopt_r` grew an
  optional last parameter `backup_path` (cstring, 0 when
  unset). Internal `_audit_format_link_op` emits the field
  only when the value is non-empty. `audit_format_unlink` /
  `audit_format_unadopt` signatures unchanged — those ops
  never carry a backup.
- Test suite: 194 → 218 assertions (52 → 61 groups). Five
  new groups cover the compose-path filename layout, the
  link --force snapshot end-to-end (audit + on-disk read-back),
  symlink-conflict skip, dry-run no-write invariant, and the
  adopt-before-rename snapshot. Four new canonicalization
  groups cover the `sha1c:` prefix, comment/whitespace
  collisions, row-reorder collisions, and value-change
  divergence. The existing `test_audit_format_link` gained
  two assertions for the optional-field presence/absence
  semantics.
- `link.md`, `adopt.md`, `sync.md`, `dry-run.md` each gained
  a `--backup-to` section pointing at the new guide.

### Filed
- Three M7 dogfood-papercut issues archived to
  `docs/development/issues/archived/`: status-exit-1
  (Tier-1 doc note), upstream-drift (Tier-1 new guide),
  no-backup-to (full `--backup-to <dir>` flag).

## [0.7.0]

### Added
- ADR 0005: capability-bounded roots. `$HOME` is the
  implicit default; `--root <path>` opens a non-default
  scope gated by `cap_check_root_r`. The check is an env-var
  allowlist (`HAPI_ALLOWED_ROOTS`, colon-separated, absolute
  paths only) as the explicit stopgap until kavach lands;
  the API contract `cap_check_root_r(path) -> Result`
  survives the kavach migration unchanged. Path-within
  matcher splits on `/` components so `/etc/myproject`
  never matches `/etc/myprojectextra`.
- `src/cap.cyr` — owns `cap_check_root_r`, the path-within
  matcher, and test hooks `cap_set_home` / `cap_set_allowlist`.
- `src/cli.cyr` — owns the process-wide `_hapi_dry_run`
  flag with setter / getter. Every mutating cmd checks the
  flag before its first syscall + audit write.
- `--root <path>` accepted on **link, adopt, sync, status,
  list**. Cap-check fires before dispatch; on denial, the
  binary exits 1 with `hapi: --root path is not in
  HAPI_ALLOWED_ROOTS (and is not within $HOME)`.
- `--dry-run` accepted on **link, unlink, adopt, sync,
  rollback, checkpoint**. Each verb runs its planning
  phase, prints the would-do lines suffixed `(dry-run)`,
  and skips every syscall + audit write. Exit codes match
  the real run.
- Per-verb arg parsing now rejects unrecognized `--flag`
  args with exit 2 + `hapi: unexpected flag for `<verb>`:
  <flag>`. Previously an unknown flag was silently
  swallowed as a positional arg.
- `docs/guides/capability.md` — user-facing guide for
  `--root` + the env-var allowlist.
- `docs/guides/dry-run.md` — user-facing guide for the
  composable preview flag.

### Changed
- `hapi --version` reports 0.7.0; help text grew a
  **global flags** section listing `--root` and `--dry-run`
  with their verb scopes.
- Test suite grew from 163 → 194 assertions (41 → 52
  groups) — cap × 4, dry-run × 6 (one per mutating verb),
  plus the M6 unit coverage of the path-within matcher.
- `HapiMfError` enum gained `HapiMfUnknownSection` and
  `HapiMfUnknownKey` (used by `check --strict`, shipped in
  v0.6.0 — listed here for completeness; the variants
  belong to the M5 work but the M6 dispatcher rewrite
  surfaced them in shared error-message tables).
- State.md and roadmap.md updated: M6 retired, M7
  (dogfood + harden) surfaced as Next.

## [0.6.0]

### Added
- `hapi checkpoint` — appends an `op:rollback-marker` entry
  to the audit trail. User-facing surface for the marker
  machinery that shipped in M3 (audit-writer + rollback's
  walk-to-marker logic). `src/cmd/checkpoint.cyr`.
- `hapi status <pkg>` — read-only drift classifier. Walks
  the manifest's [[link]] rows, probes each target, prints
  one of `OK` / `MISSING` / `WRONG` / `FILE` / `DIR` /
  `ERROR`. No audit writes; no filesystem mutation. Exit 0
  when clean, 1 on any drift. `src/cmd/status.cyr`.
- `hapi list` — walks the audit trail, prints unique
  packages in first-seen order with their live-link count.
  Reduction treats `link`/`adopt` as creators and
  `unlink`/`unadopt` as removers (generalizes the unlink
  command's per-target last-write-wins logic). Empty trail
  is not an error. `src/cmd/list.cyr`.
- `hapi check <pkg> [--strict]` — sibling of `inspect` with
  an opt-in `--strict` mode. Strict rejects any `[section]`
  other than `[package]` / `[[link]]`, and any unknown key
  inside the known sections. The default parser stays
  lenient per ADR 0001's additive-growth headroom; the
  strict mode is the CI / lint surface. New
  `HapiMfUnknownSection` and `HapiMfUnknownKey` error
  variants in `src/manifest.cyr`, plus a module-level
  `_hapi_mf_strict` flag that `cmd_check` sets/clears
  around the parse call. `src/cmd/check.cyr`.
- `hapi sync <pkg>` — re-apply a package's manifest
  idempotently. At v0.6.0 this is `cmd_link` without
  `--force`; the verb is the user-facing intent. Acceptance
  test passes: `sync` on a clean tree produces zero new
  audit entries. `src/cmd/sync.cyr`.
- Per-command guides: `docs/guides/checkpoint.md`,
  `status.md`, `list.md`, `check.md`, `sync.md`.

### Changed
- `hapi --version` reports 0.6.0; help text lists every
  new verb.
- Test suite grew from 127 → 163 assertions (29 → 41
  groups) — checkpoint × 1, status × 4, list × 3,
  strict-mode parser × 4, check × 1, sync × 2.
- Roadmap M5 line in [`state.md`](docs/development/state.md)
  retired; "Next" now points at M6 (`--root` capability
  gate, `--dry-run`).
- A no-arg `hapi sync` (sync every package in the trail) is
  deferred from M5 — the audit format doesn't carry a
  manifest path, so package-dir recovery would need either
  a tree-walk heuristic or an additive trail field. Filed
  as a post-M5 candidate in state.md's source section.

## [0.5.0]

### Added
- ADR 0004: `hapi adopt` op semantics. Two positional CLI
  args, atomic single-entry audit record (`op:adopt`), append
  `[[link]]` row before `---` body separator, three-step
  conditional rollback (remove symlink → move file back →
  remove manifest row).
- `src/manifest_write.cyr` — append + remove `[[link]]` rows
  in `hapi.cyml`. Atomic via `tmp+rename` (no corruption on
  crash). Append preserves comments, user formatting, and
  the markdown body. Remove strips matching block + leading
  blank lines.
- `src/cmd/adopt.cyr` — `hapi adopt <file> <pkg>`. Probes,
  parses, refuses on duplicate / wrong-type targets, renames
  file into package, creates relative symlink, appends
  manifest row, writes audit entry. Source name is target's
  basename with leading `.` stripped.
- `src/audit.cyr` — `audit_append_adopt_r` and
  `audit_append_unadopt_r` (the rollback-reverse op).
- `src/cmd/rollback.cyr` — handles `op:adopt` entries with
  the three-step conditional reversal. Ignores `op:unadopt`
  (forward-replay records, not re-reversible).
- `hapi adopt <file> <pkg>` wired into the dispatcher.
- `docs/guides/adopt.md`.
- Tests: M4 acceptance (adopt happy path), every refusal
  case (symlink target / directory target / absent target /
  duplicate manifest row), manifest_write append + remove,
  rollback-of-adopt three-step reversal. 127 assertions
  total (was 100 in v0.4.0).

### Changed
- `hapi --version` reports 0.5.0; help text lists `adopt`.
- Roadmap updated — deferred items from M1–M3 are now
  anchored to specific milestones (M5 picks up
  `hapi checkpoint` and `hapi check --strict`; M7 picks up
  the manifest-hash canonicalization migration) or
  explicitly listed under a new "Deferred during M1–M3"
  section in Out-of-scope with ADR citations.

### Filed upstream
- Proposal at
  `cyrius/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md`
  for `sys_fsync` / `sys_fdatasync` stdlib wrappers. Hapi
  currently calls `syscall(74, fd)` directly in
  `_hmw_write_atomic`; the magic number is the
  cross-arch-mismatch hazard the bare-name wrappers exist
  to prevent. Companion to the 2026-05-17 *at()-family
  proposal (`sys_rename` lives there). Targets the v6.x
  stdlib-syscall expansion arc.

## [0.4.0]

### Added
- `src/audit_reader.cyr` — JSONL reader. Hand-rolled scanner
  scoped to the ADR 0002 field set; unescapes `\"`, `\\`,
  `\n`, `\r`, `\t`, `\uXXXX` (writer only emits `\u00XX`).
  Drops malformed and torn-final lines silently per the
  ADR's crash-safety contract.
- `src/audit.cyr` — `audit_append_unlink_r` and
  `audit_append_rollback_marker_r`. `audit_format_link`
  and `audit_format_unlink` share a common formatter.
- `src/cmd/unlink.cyr` — `hapi unlink <pkg>`. Reads trail,
  identifies live links for the package (link entries not
  superseded by a later unlink), removes each only if the
  current symlink matches what hapi wrote. Refuses
  user-mutated entries (exit 1), keeps processing the rest.
- `src/cmd/rollback.cyr` — `hapi rollback`. Walks trail
  backward to the most recent `op:rollback-marker`,
  conditionally reverses every entry in between. Idempotent
  by construction — re-running produces the same end state.
- `hapi unlink <pkg>` and `hapi rollback` wired into the
  dispatcher.
- `docs/guides/unlink.md` and `docs/guides/rollback.md`.
- Tests: M3 acceptance (link → unlink → no residue, trail
  records both ops), user-mutation refusal, audit-reader
  round-trip, torn-line and malformed-line drops, rollback
  through link/unlink/link → clean slate, rollback
  idempotency, rollback stops at marker. 100 assertions
  total (was 69 in v0.3.0).

### Changed
- `hapi --version` reports 0.4.0; help text lists `unlink`
  and `rollback`.
- Refactored hand-counted `print(lit, N)` calls in
  `src/cmd/inspect.cyr` and `src/cmd/link.cyr` to use
  strlen-via-helpers (`_hi_puts` / `_hi_eputs` /
  `_hlnk_puts` / `_hlnk_eputs`). An off-by-one in the
  directory-blocked message at v0.3.0 leaked an adjacent
  rodata byte; the helpers eliminate the whole class of bug.

### Fixed
- Directory-blocked error message no longer prints a stray
  leading space character (was rendering with three leading
  spaces, now two — the byte count for the literal was off
  by one in v0.3.0).

## [0.3.0]

### Added
- ADR 0002: audit-trail format. JSONL at
  `$XDG_STATE_HOME/hapi/audit.jsonl`, append-only, one JSON
  object per line, fields ordered for canonical serialization.
  Format is **Breaking** for hash semantics (canonicalization
  switch reserved as `sha1:` → `sha1c:` for v1.0); everything
  else is additive.
- ADR 0003: symlink target shape. Relative-from-the-link's-
  parent-directory — keeps dotfile repos portable across
  machines and clone paths. Matches GNU stow convention.
- `src/audit.cyr` — audit-trail writer. JSON escaping for
  control bytes / `\` / `"`. `audit_append_link_r` does a
  single flock'd append per entry; entries are well under
  PIPE_BUF so POSIX atomicity holds.
- `src/fs_link.cyr` — symlink primitives. `link_probe` (one
  `readlink(2)` + a directory probe to split FILE / DIRECTORY),
  `fsl_compute_relative` (longest-common-prefix + `..` prepend),
  `link_create` (mkdir -p on parent + symlink).
- `src/cmd/link.cyr` — `hapi link <pkg> [--force]`. Pre-flights
  every target, refuses on any conflict without `--force`, then
  creates the new links and audits each write. `--force`
  replaces a symlink-to-elsewhere or a regular file; never a
  directory.
- `hapi link <package>` wired into the dispatcher.
- `docs/guides/link.md` — semantics, flags, exit codes, audit
  trail pointer.
- Tests: M2 acceptance (3-link package, re-run is no-op),
  conflict refusal, `--force` replace, `--force` refuses
  directory, audit JSON shape, JSON escaping, link_probe
  classification, relative-path computation. 69 assertions
  total (was 36 in v0.2.0).

### Changed
- `[deps].stdlib` gained `sha1` (manifest hashing) and
  `chrono` (ISO 8601 audit timestamps).
- `hapi --version` now reports 0.3.0; help text lists `link`.

## [0.2.0]

### Added
- ADR 0001: `hapi.cyml` manifest schema. `[package]` table for
  metadata (`name`, `version`, `description`, `ignore`); one or
  more `[[link]]` rows for the symlinks themselves. Single-entry
  CYML — TOML header above `---`, optional markdown body below.
  Schema is **Breaking** until v1.0; after v1.0 it freezes.
- `src/manifest.cyr` — manifest parser. Validates name/version
  presence, `[[link]]` source/target presence, duplicate-target
  rejection, and `..` path-segment rejection in both source and
  target. Filesystem checks (source exists, target writable,
  capability scope) deferred to M2.
- `hapi inspect <path>` — read a manifest and print the parsed
  interpretation. Read-only; never touches the scoped root.
  Accepts a package directory or a direct `*.cyml` path.
- `hapi --version` / `-v`, `hapi --help` / `-h` — surface the
  CLI dispatcher's basic shape from day one.
- `docs/examples/dotfiles-zsh/` — canonical 3-file example
  package; drives the M1 acceptance test.
- `docs/guides/inspect.md` — command guide.
- Test suite: 36 assertions across happy path, validation
  errors, path-traversal, comments/blanks, on-disk parse, and
  missing-file error.

### Changed
- `cyrius.cyml` toolchain pin bumped from 6.0.0 to 6.0.1.
- `[deps].stdlib` gained `args`, `fs`, `result`, `toml`, `cyml`,
  `slice` for the manifest parser and dispatcher.

## [0.1.0]

### Added
- Initial project scaffold
