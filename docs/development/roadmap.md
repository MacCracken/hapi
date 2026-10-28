# hapi — Roadmap

> **Forward-looking only.** Every item on this page is work that has
> not shipped. Shipped work lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md); the frozen v1.0 contract
> lives in [`release-notes/1.0.0.md`](release-notes/1.0.0.md); live
> state lives in [`state.md`](state.md). When an item ships it is
> **deleted** from here, not struck through.

## Status

- **Current line: 1.0.x** (patch). The v1.0 contract — command surface,
  ADR 0001 manifest schema, ADR 0002 audit-trail format — stays frozen.
- **v1.x** — additive growth, internal swaps, doc commitments; no
  caller-visible breaking change. Nothing blocks it.
- **v2.0** — candidates that *must* earn a major bump because they
  break a frozen surface. None scheduled.

Future work is sized in terms of *what bucket it belongs to*, not which
sprint it runs in.

## Owed now

- **A P(-1) re-walk over the repaired write paths.** Thirteen fixes
  landed across 1.0.9 and 1.0.10, and between them they touched a path
  argument, a syscall and the audit-trail write path — all three of
  CLAUDE.md's re-run triggers. The newest pass on file,
  [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md),
  scanned 1.0.5; the re-walk files as `../audit/YYYY-MM-DD-audit.md`.
  Two accepted boundaries from that pass are still unwritten and belong
  to its Step 6: `hapi checkpoint` is not idempotent (three runs append
  three markers, undocumented in
  [`../guides/checkpoint.md`](../guides/checkpoint.md)), and 1.0.9's
  writer-side torn-tail refusal is absent from ADR 0002's *Crash
  semantics*.

## v1.x — maintenance & additive growth

Each item is additive (no caller-visible contract change). Roll
into v1.1, v1.2, … as work lands. None block each other;
ordering is driven by upstream readiness + dogfood pressure.

### Additive surface

- **Manifest discovery for no-arg `hapi sync`** — recover
  pkg_dir from a live audit entry so `hapi sync` without
  args can sync every tracked package. Needs either an
  additive trail field (`manifest_path`) or a tree-walk
  heuristic. The signature stays unchanged — no arg becomes
  legal. **Dogfood pressure (2026-05-24):** a drive-move
  recovery had to loop over packages by hand, and the wiped
  trail proved trail-recovery fails closed at bootstrap
  (zero packages found exactly when recovery matters most) —
  prefer the tree-walk / root-scan as the *primary* mechanism,
  trail-recovery only as augmentation. See
  [`issues/2026-05-24-no-arg-sync-bootstrap-recovery.md`](issues/2026-05-24-no-arg-sync-bootstrap-recovery.md).
- **`created_dirs` on `op:link` entries** — record the parent
  directories `link_create` had to make, so `unlink` / `rollback` can
  remove exactly those and nothing else. Today they are deliberately
  left behind (1.0.9, F-029): the trail records the symlink, not the
  directories, so any unlink-time prune is an *inference* — and `rmdir`
  can still take out a directory the user made on purpose, or drop a
  mode the user set. On `~/.ssh` that is a security regression hapi
  would have caused while claiming to reverse itself. hapi removes only
  what it created, *with proof*; this field is the proof. Additive per
  ADR 0002's growth contract, so v1.x.

### New flags (additive)

- **`hapi status --quiet`** — return 0 unless there's an
  actual error (manifest parse failure, IO error), flipping
  the exit-code semantic for scripted `&&` chains. The v1.0
  workaround is `link --dry-run` per
  [`guides/status.md`](../guides/status.md) *Exit-1 is an
  assertion, not a predicate*; the flag is a post-v1.0
  ergonomic addition if the pattern keeps recurring.
- **`hapi rollback --to <marker>` / `--steps N`** — refine
  the v1.0 no-arg form (walks to most recent marker). Both
  additive; the no-arg form remains the default.
- **`hapi sync --prune` (opt-in)** — emit `op:unlink` for
  trail rows no longer in the manifest. Conservative
  defaults: refuse if the prune count exceeds a threshold
  without `--force`. Tracked at
  [`issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`](issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md).
- **`--absolute` global flag** — opt individual runs into
  absolute symlink targets (vs the v1.0 relative default).
  ADR 0003 reserved.

### New verbs (additive)

- **`hapi merge <pkg>`** — speculative 3-way merge driver
  for drifting-upstream templates (hyprland-class). Needs
  a stock-template-version data model before earning its
  place; Tier-3 in
  [`issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md`](issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md).
- **`hapi fmt`** — manifest canonicalizer / formatter. Ships
  v1.x **if** its output equals `hapi_mf_canonicalize`'s
  bytes (no audit-trail hash change). If a richer canonical
  form is needed, it crosses into the v2 bucket below.

### Documentation commitments

- **`docs/architecture/001-upstream-drift-pattern.md`** —
  formalize the audit + merge workflow when a second
  drifting-upstream consumer hits the pattern (likely sway /
  fish / kitty when an upstream stock-template rewrite drops).
  Tier-2 from the archived issue.
- **`docs/benchmarks.md` trend rows** — append a row on every
  release that touches `src/cmd/link.cyr` / `src/audit.cyr` /
  `src/fs_link.cyr` / the manifest parser. Regression gate per
  the file: > 2× cold-time jump or any non-zero warm audit
  growth. ⚠ **1.0.10 owes one** — it changed `src/fs_link.cyr`
  and `src/cmd/link.cyr`, and the table stops at 1.0.9.

### Upstream pendings

Items hapi needs from siblings; QoL patches when they land,
not blockers.

- **A no-follow open flag on agnos.** agnos's `AO_*` set has no
  no-follow bit, so `hapi_open_nofollow` (`src/agnos_compat.cyr`)
  pre-checks with `readlink` there (1.0.10, F-031). Between the
  readlink and the open nothing proves the two saw the same inode;
  the residual race is an accepted boundary until the kernel grows the
  flag, at which point the agnos arm collapses to the atomic
  Linux/macOS shape. File against agnos, not hapi.
- **envp for mirshi's child process.** mirshi passes none, so `getenv`
  returns null under it and no scope-rooted verb is reachable — which
  bounds what `scripts/agnos-smoke.sh` can exercise. Real agnos stages
  `HOME=/ PWD=/` at exec, so this is a supervisor gap. File against
  mirshi, not hapi.

## v2.0 — Breaking-candidate bucket

Items that **must** wait for a major bump because they break a
v1.0-frozen surface. None scheduled. Each earns a place only
when real consumer pressure demands it; each carries the
rationale that justifies the major bump.

### Manifest-schema growth (ADR 0001 frozen)

- **Honour `package.ignore`.** It is parsed, validated, echoed by
  `hapi inspect` and folded into the `sha1c:` manifest hash — and no
  verb applies it (F-025). ADR 0001 marks it **RESERVED, NOT YET
  HONOURED** and points here. Honouring it changes what a directory row
  materializes and how many audit entries a row writes, both frozen at
  v1.0, so it earns the major bump. Intended semantics per ADR 0001:
  source side only, POSIX `fnmatch(3)` (`*`, `?`, `[abc]`), applied to
  `[[link]]` rows that target a directory.
- **Recursive `**` globs and brace expansion in `ignore`** — a
  follow-on to the above, not a substitute for it. The fnmatch subset
  ADR 0001 specifies is what ships first; `**` opens cross-directory
  expansion questions that earn their parser complexity only with
  demonstrated demand.
- **Glob source in `[[link]]` rows** (`source = "*.zsh"`).
  Field-semantic change: was a path; becomes a glob expanded
  at link time. Interacts badly with audit-trail hashing —
  the manifest hash would change every time source-directory
  contents change, even when the manifest bytes don't. Needs
  an ADR amendment explaining the hash interaction before it
  can ship.
- **Per-row link attributes** (e.g. `mode = "copy"` for the
  rare case where a copy beats a symlink). ADR 0001 left
  headroom; a v2 amendment specifies the per-attribute
  semantics and the audit-trail interaction.
- **Per-row `--source <path>` for `adopt`** — opt into
  nested layouts (`~/.config/zsh/x` → `pkg/config/zsh/x`).
  If purely a new CLI flag, it's v1.x; if it changes the
  derived source-name algorithm, it lands in v2 to keep
  ADR 0004's contract honest.

### Audit-trail format growth (ADR 0002 frozen)

- **`hapi trail compact`** — collapse a window of
  link / unlink / re-link entries to their net effect.
  Breaking because the trail's append-only contract is
  load-bearing for rollback correctness; needs its own ADR
  defining compaction markers + rollback semantics across the
  new boundary.

### Adopt crash-atomicity (ADR 0004 revision)

- **An intent record written before the rename.** `adopt` commits the
  filesystem move before the manifest row and the trail entry, so an
  interrupt in that window strands the user's dotfile in the package
  with nothing recording it (F-028). `hapi check` **detects** it — it
  walks the package directory and reports the orphan — but prevention
  needs `adopt` to become recoverable, which changes the operation's
  shape and therefore ADR 0004's *single atomic entry* decision. Earns
  the major bump.

### Default-behavior changes

- **`hapi sync --prune` as default-on**. If the v1.x opt-in
  flag earns universal adoption, flipping the default is a
  Breaking change — script callers may have relied on the v1.0
  no-prune behavior.
- **`--absolute` as the default**. Analogous; ADR 0003
  default flip.

## Out of scope (permanent)

Items that don't earn a place no matter the version.

- **hoosh-assisted conflict resolution** — possibly
  interesting later as a separate tool; out of hapi's lane.
- **GUI front-end** — never. CLI only.
- **Cross-machine dotfile sync** — different concern; hapi
  manages *placement*, not *content distribution*. Consume
  git / rsync / syncthing as the transport layer.
- **Network operations** — no fetch, no push, no remote
  anything.
- **Encrypted secrets management** — consume `sigil` in a
  future sibling tool if needed.
- **Per-host manifest variants** — a manifest is a manifest.
  Per-host needs go in per-host packages. No template engine,
  no conditionals.

## Cross-references

- [`state.md`](state.md) — live state (version, source layout,
  test count, audit-trail surface)
- [`release-notes/1.0.0.md`](release-notes/1.0.0.md) — the
  v1.0 contract
- [`issues/`](issues/) — open issues + `archived/` for closed ones
- [`../audit/`](../audit/) — security audit findings
- [`../adr/`](../adr/) — design records (all five frozen at v1.0)
- [`../benchmarks.md`](../benchmarks.md) — `sync` baseline + trend
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history

---

## Moving the cyrius pin to 6.6.6

**Current pin: `cyrius = "6.6.2"`** — four releases behind. Nothing must change first;
this is a pin bump and a rebuild.

### The O_APPEND question, answered first

hapi **does** use `O_APPEND`, in the one place where 6.6.6's Windows defect would have been
worst: `_audit_append_durable` (`src/audit.cyr:363`), the append-only audit trail. Before
6.6.6 a PE build's `O_APPEND` did not append — it overwrote from offset 0 — which for this
function would have meant each entry silently erasing the trail's head while
`file_lock` + `fsync` + the torn-tail guard all reported success.

**hapi is not exposed, and here is the check rather than the assumption.** hapi builds
exactly three targets, all of them in `.github/workflows/ci.yml`: x86_64 Linux, aarch64
Linux (compile-only), and agnos (compile-only, smoked under mirshi). There is no PE target,
no `CYRIUS_TARGET_WIN` / `_TARGET_PE` branch anywhere in `src/` — the only conditional in
the tree is `CYRIUS_TARGET_AGNOS`, at 11 sites — and no Windows runner in CI. The audit
comment's *"portable across all three targets"* means those three, not Windows.

So: not a live corruption, but **the reason to carry the fix anyway is that this repo is one
Windows target away from it**, and `src/audit.cyr:363` is the line that would go first.

### What else was checked

- **Other open sites, all safe by construction.** `src/backup.cyr:230` and
  `src/manifest_write.cyr:202` both open `O_WRONLY|O_CREAT|O_EXCL` — deliberately *not*
  `O_TRUNC` (backup.cyr:221–224 records why: with `O_TRUNC` a second copy in the same second
  silently overwrote the first). `O_EXCL` disposition behaviour is unchanged by 6.6.6.
- **No shape the new refusals catch.** Zero `struct` declarations in `src/`, so no
  struct/vector copy, no by-value struct parameter, no struct-valued return, no top-level
  struct call. **All 8 `: Result` fns were walked** (`hapi_mf_parse_header_r`,
  `hapi_mf_parse_file_r`, `audit_read_r`, `audit_read_default_r`, `cap_check_root_r`,
  `audit_preflight_r`, `_audit_append_bytes`, `audit_append_rollback_marker_r`) and every
  `return` in them is `Ok(…)`, `Err(…)` or a tail call to another `_r` — none returns a bare
  scalar, so the new "a pair-return fn must return a same-shaped pair" refusal is satisfied.
  No `async fn`, no `operator` fn, no SIMD-returning fn.
- **The 6.6.6 `file_append_locked` fix does not reach hapi's trail, and that is by design.**
  6.6.6 makes `lib/io.cyr`'s `file_append_locked` loop until the whole record lands — before
  it, one `write` could append a **prefix** and return that count as success, so a caller
  testing `< 0` logged a torn line and called it written. hapi does not use it (audit.cyr:343
  records why), and `_audit_append_durable`'s own write is `var w = file_write(fd, buf, n);`
  followed by `if (w != n) { return 0 - 5; }` — it does not loop, but it **detects** the short
  write and reports it rather than claiming success, so the torn-line class cannot occur.
  Worth knowing, because the stdlib's new looping behaviour is now the stronger of the two:
  if F-018's two missing properties ever land upstream, hapi's hand-rolled path can retire.
- **Also clean:** no `var` inside a top-level block (zero top-level `{` / `if (` / `while (`
  at column 0), no raw `SYS_STATFS`, no `lib/regression.cyr` consumer, no `vec_*` of hapi's
  own, no symlink in `lib/` (which matters here: 6.6.6 makes `cyrius deps` **fail** rather
  than skip when a `lib/*.cyr` cannot be hashed, and a stale dangling symlink must be removed
  rather than bypassed — hapi's `lib/` is 43 regular files, nothing to clear). The only
  duplicate top-level global is `var r = main();` in `src/main.cyr` and `src/test.cyr`, two
  entry files that are never co-linked.

### ⚠ One new stdlib primitive to look at deliberately, not adopt by reflex

6.6.6 adds **`file_replace_atomic`, which writes THROUGH a symlink**, and changes
`file_write_atomic` to **keep an existing file's mode** (it was `0644 & ~umask`). hapi
currently uses neither — `manifest_write.cyr` hand-rolls tmp-write-then-rename.

- The `file_write_atomic` mode-preservation change is the behaviour hapi wants: a dotfile
  manager that rewrites a user's file should not silently reset its mode to 0644.
- **`file_replace_atomic`'s write-through-symlink semantics are the opposite of what a
  symlink farm wants** in most paths. hapi's whole model is that `~/.zshrc` *is* a link into
  the package tree; writing through it edits the package source instead of the link. If a
  future slot reaches for it, that has to be a decision, not a default.

### What it gains

6.6.3's `#inline`-disarms-`#derive` fix; 6.6.4's ≥64 KB string-literal read-back fix (hapi's
longest literal is 3,668 B in `src/manifest.cyr`, so not reachable today, but the manifest
format is the part of hapi that grows); 6.6.5's aggregate-layout fix, silently wrong since
5.8.17, and three corrected ENTRY stack bases; and 6.6.6's nine new refusals.

### Verify after bumping

`cyrius deps` → `cyrius build` → `cyrius test` → `cyrius build --aarch64` and
`cyrius build --agnos` (both compile-only gates; the roadmap's own note that `--aarch64`
silently stopped building at 1.0.2 and nothing noticed until 1.0.4 is exactly why these must
be re-run, not assumed) → `scripts/concurrency-test.sh` (F-012, needs two racing processes)
→ the agnos smoke under mirshi (F-027, F-031). Then re-run the audit-trail append path
specifically and confirm the torn-tail guard still refuses a trail whose last byte is not
`\n` — that guard reads the file's tail, and it is the one hapi behaviour that a change in
open-flag handling would silently alter.

---

## Adopting cmdit (CLI parsing)

**Demand-gated, not a forced sweep.** hapi is a Tier-2 verb tool in the 2026-06-25 ecosystem
CLI review. Nothing here is owed; the v1.0 command surface stays frozen through it, so every
delta below is identical or additive. Checked against the tree, not assumed.

### What is hand-rolled, and where

All of it is `src/main.cyr` — `argc(`/`argv(`/`flags_`/`FLAG_ERR_` appear nowhere else in `src/`,
`tests/` or `scripts/`, and `cyrius.cyml` has no stdlib `"flags"`.

- **Verbs** — a `_hapi_argeq` chain over `argv(1)`, ten verbs (`:197-386`); `--version`/`-v`/
  `--help`/`-h` match only at `argv(1)` (`:192-195`). No args → usage, exit 2 (`:185-188`); unknown
  verb → stderr `hapi: unknown command: X` + usage on stdout, exit 2 (`:388-392`).
- **Per-verb flag loops** re-walk `argv(2..)` with each verb's subset of `--force`, `--strict`,
  `--dry-run`, `--root <path>`, `--backup-to <dir>`. The usage text calls the last three "global";
  they are per-verb subsets, and nothing is accepted before the verb.
- **Helpers** — `_hapi_flag_value` refuses a flag-shaped value (`:114-119`, F-019); three message
  helpers render the exit-2 errors (`:124-178`); `_hapi_apply_root` cap-checks mid-walk (`:137-154`).
- **Positionals** are capped at 1, 2 (adopt) or 0 (rollback/checkpoint/list); a *missing* one is
  each `cmd_*`'s own usage line (e.g. `src/cmd/link.cyr:205`). Help: `hapi_print_usage` (`:58-87`, stdout).

### Site → cmdit

- `argv(1)` chain → `cmdit_new("hapi")` + ten `cmdit_verb` + `cmdit_dispatch` on
  `cmdit_verb_matched`; `-v` → `cmdit_version_short(h, 118)`. Ids are registration order, so future
  verbs (`merge`, `fmt` above) append at the end (stiva's `src/main.cyr:77` warning).
- Per-verb loops → one child handle per verb + `cmdit_parse_verb`, registering only that verb's
  subset. **Not** cmdit globals — those bind on every verb and would break the exit-2 rejections in
  `guides/dry-run.md:23`, `guides/backup-to.md:18` and `guides/capability.md:30-32`.
- Bools → `cmdit_bool`; `--root`/`--backup-to` → `cmdit_str` + `cmdit_metavar`; the setters and
  `_hapi_apply_root` run after parse. Extra positional → `cmdit_require_positionals_max` (the token
  is `cmdit_positional(vh, N)`); missing value → `CMDIT_ERR_MISSING_VALUE` + `cmdit_err_flag`. Both
  existing messages survive verbatim.
- Delete `args_init()` (`:182`): `cmdit_argv` calls it, and each Linux call allocates a fresh 2 MB
  buffer (`lib/args.cyr:132-143`).

### Gaps (none block)

- [ ] **F-019 returns without a guard.** cmdit takes the next token as the value whatever it looks
  like, so `link --root --dry-run pkg` would again set root = `--dry-run`. Re-check
  `load8(v) == 45` after parse. One-consumer evidence for an opt-in "no flag-shaped value" modifier.
- [ ] **Unknown-flag text.** cmdit exposes no accessor for the offending token, so
  ``unexpected flag for `link`: --x`` becomes `<prog>: unknown flag` unless the caller re-walks
  `cmdit_verb_argv(h)`. Exit 2 either way; pick one and record it.
- [ ] **Help stays hand-written** — cmdit's renderers write stderr, `hapi --help` writes stdout,
  and the frozen verb set keeps the drift risk low.
- [ ] **CHANGELOG as additive:** `--root=PATH`/`--backup-to=DIR`, `--` (an alternative to the
  `./-name` advice at `:129`), lone `-` as a positional, `hapi <verb> --help`/`--version` (exit 2
  today). Error precedence shifts on multi-error lines: unknown flags beat extra positionals, and
  parse errors (2) beat a cap denial (1).

### The manifest change

Append after `[deps]` (`cyrius.cyml:14-21`). `"args"` and `"io"` are listed, there is no `"flags"`
to drop, and no pin bump is needed (the dist compiles on 6.6.2):

```
[deps.cmdit]
git = "https://github.com/MacCracken/cmdit.git"
tag = "1.3.0"
modules = ["dist/cmdit.cyr"]
```

### Tests and the output-identity bar

- [ ] **No argv-level test exists** — `tests/hapi.tcyr` drives `cmd_*` and cannot include
  `main.cyr`. Move the dispatcher into `src/cli.cyr` (already included, `tests/hapi.tcyr:20`) and
  drive the pure `cmdit_dispatch_argv` with synthetic argv.
- [ ] No golden either: capture `(stdout, stderr, exit)` from the current binary for every verb ×
  {each accepted/rejected flag, extra positional, missing and flag-shaped value, `--help`/`-h`/
  `--version`/`-v`}, plus no args and an unknown verb. It must diff clean but for the deltas above.
- [ ] Must pass unmodified: `scripts/agnos-smoke.sh:44-48,85-87` (`--version`; unknown verb exits 2
  on agnos), `scripts/concurrency-test.sh` (`adopt`), `release.yml:143-150` (`hapi ${VERSION}`).

Pointers: cmdit's `README.md` (API reference) and `docs/adr/0002-verb-dispatch.md`; stiva's
`src/main.cyr` is the worked verb-tool migration.
