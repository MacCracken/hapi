# hapi — Roadmap

> **Forward-looking only.** Every item on this page is work that has
> not shipped. Shipped work lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md); the frozen v1.0 contract
> lives in [`release-notes/1.0.0.md`](release-notes/1.0.0.md); live
> state lives in [`state.md`](state.md). When an item ships it is
> **deleted** from here, not struck through.

## Status

- **Current line: 1.1.x.** 1.1.0 is the cyrius 6.7 toolchain line; the
  v1.0 contract — command surface, ADR 0001 manifest schema, ADR 0002
  audit-trail format — stays frozen. **Next: 1.1.1, the P(-1) audit and
  repairs** (below).
- **v1.x** — additive growth, internal swaps, doc commitments; no
  caller-visible breaking change. Nothing blocks it.
- **v2.0** — candidates that *must* earn a major bump because they
  break a frozen surface. None scheduled.

Future work is sized in terms of *what bucket it belongs to*, not which
sprint it runs in.

## 1.1.1 — P(-1) audit and repairs

One release: the full CLAUDE.md P(-1) checklist, filed as
`../audit/YYYY-MM-DD-audit.md`, plus the repairs it lands. The findings
ship together in 1.1.1, not as one patch release each. New findings
continue from **F-035**.

**Why it is owed.** Thirteen fixes landed across 1.0.9 and 1.0.10, and
between them they touched a path argument, a syscall and the audit-trail
write path — all three of CLAUDE.md's re-run triggers. 1.0.12 touched a
syscall again (`hapi_open_nofollow`). The newest pass on file,
[`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md), scanned
1.0.5.

**Scope — the walk itself.**

- [ ] The repaired write paths of 1.0.9 / 1.0.10 / 1.0.12, re-walked
  against the current tree (cyrius 6.7.18).
- [ ] **aarch64 as a first-class target in the walk.** 1.0.12 found that
  the x86_64 `O_NOFOLLOW` literal had silently disabled F-003's defence on
  arm64 since 0.9.0, and that the test harness was x86-only. That needs an
  F-id and an entry in the audit doc, which it never got. The re-walk
  should also sweep every remaining numeric constant in `src/` and
  `tests/` for per-arch meaning, not just the ones that have already
  bitten. CI now runs `cyrius test --aarch64` under qemu, so a new
  finding can get a test that runs there.
- [ ] Step 6, the two accepted boundaries from the 2026-08-25 pass that
  were never written down: `hapi checkpoint` is not idempotent (three
  runs append three markers, undocumented in
  [`../guides/checkpoint.md`](../guides/checkpoint.md)), and 1.0.9's
  writer-side torn-tail refusal is absent from ADR 0002's *Crash
  semantics*.
- [ ] **ADR 0001 never states the `---` delimiter rule.** It says only
  that an optional markdown body follows `---`. 1.1.0 found that the
  rule moved under hapi when bayan changed (CRLF and an unterminated
  final `---` became delimiters), and that the writer had its own,
  older copy. Write the rule into the ADR as a clarification, not a
  schema change: a whole `---` line, at the start of the file or after
  a `\n`, ending in `\n`, CR LF, or end of file. Then the tests in
  `tests/hapi.tcyr`'s `1.1.0` section pin a documented contract rather
  than an observed one.

**Known repair candidates going in** (found during the 1.0.12 / 1.1.0
toolchain work; each gets an F-id and a test if the walk confirms it):

- [ ] **F-031's residual race can now close on agnos.** cyrius 6.6.4's
  `file_open` bridges `O_NOFOLLOW` → `AO_NOFOLLOW`, which the agnos kernel
  has honoured since 1.56.53. `hapi_open_nofollow`'s agnos arm still uses
  only the readlink pre-check. Passing the flag as well makes the refusal
  atomic. It needs a decision on the minimum agnos kernel (behaviour on a
  kernel without the bit is unverified), and a mirshi ≥ 1.11.2 axis in
  `scripts/agnos-smoke.sh` that asserts a symlink is refused.
- [ ] **`hapi check` passes silently on an unreadable package
  directory.** `src/cmd/check.cyr` lists the package with `dir_list`,
  which returns an empty list for a directory it cannot read, so the
  F-028 orphan check finds nothing and reports clean. `dir_list_checked`
  (cyrius 6.6.10) reports the error, and `check` should exit 1 on it.
- [ ] **On agnos, `O_EXCL` now means exclusive.** Since cyrius 6.6.4
  `file_open` bridges it to `AO_EXCL` (agnos ≥ 1.56.56). Before that,
  `backup.cyr`'s and `manifest_write.cyr`'s exclusive creates opened an
  existing file and overwrote it in place. Check whether either path ever
  relied on the old behaviour (e.g. a retried backup in the same second),
  and add the `O_CREAT|O_EXCL`-on-existing case to the agnos smoke.
- [ ] **Nothing runs hapi's agnos code in CI.** The `agnos smoke` step
  always exits 2 (SKIP) on the runner, because there is no mirshi there,
  and cyrius 6.7.16 dropped its own run-under-mirshi gates. So the agnos
  arm — F-027, F-031, and the two candidates above — is exercised only
  when the smoke runs on a dev box. Either build mirshi in CI, or record
  the skip as an accepted boundary in the audit doc.
- [ ] **Appending to a CRLF manifest writes LF lines.** The writer's row
  template is LF-only, so `adopt` leaves a CRLF manifest with mixed line
  endings. The reader and `check --strict` accept it; an editor or a
  diff may not. Low — match the file's own ending when appending.
- [ ] **Supply chain: CI fetches the toolchain installer from `main`.**
  Both workflows `curl` `scripts/install.sh` from the cyrius repo's
  mutable `main` branch. Upstream's compiled `install` stopped doing that
  at 6.6.20 and fetches `…/cyrius/<version>/scripts/install.sh`. Fetch
  from the `cyrius.cyml` pin's tag the same way.

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
to drop, and no pin bump is needed (the dist compiled on 6.6.2; not yet re-checked on the current 6.6.20 pin):

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
