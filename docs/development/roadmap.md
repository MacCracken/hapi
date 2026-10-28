# hapi — Roadmap

> **Forward-looking only.** Every item on this page is work that has
> not shipped. Shipped work lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md); the frozen v1.0 contract
> lives in [`release-notes/1.0.0.md`](release-notes/1.0.0.md); live
> state lives in [`state.md`](state.md). When an item ships it is
> **deleted** from here, not struck through.

## Status

- **Shipped: 1.1.1** — the cyrius 6.7 line (1.1.0) and its P(-1) audit
  and repairs ([`../audit/2026-10-28-audit.md`](../audit/2026-10-28-audit.md)).
- **Next: 1.2.0 — adopting cmdit** (below).
- **1.3.0 → 1.7.0** — the rest of v1.x's additive work, one theme per
  minor. The command surface, ADR 0001's schema and ADR 0002's line
  shape stay frozen throughout; everything here is additive.
- **Gated** — work that waits on something outside hapi, scheduled when
  the gate opens.
- **v2.0** — candidates that *must* earn a major bump because they break
  a frozen surface. None scheduled.

## How the 1.x line is cut

- **One theme per minor.** A minor adds caller-visible surface (a verb
  form, a flag, an additive trail field). Its `.x` patches carry fixes
  only: a `1.N.x` adds nothing.
- **Order: dependency first, then dogfood pressure.** cmdit goes first
  because every later flag registers through it. After that, sync
  carries two open dogfood issues, so it goes next. The order of 1.4 –
  1.7 is a proposal and can be swapped when pressure changes.
- **Standing obligations, per release** (CLAUDE.md, not repeated in each
  section): a P(-1) re-run when the release touches a path argument, a
  syscall, the capability surface or the trail format (each section
  says whether it does). A [`../benchmarks.md`](../benchmarks.md) row
  when it touches `link` / `audit` / `fs_link` / the parser. Both
  suites run on x86_64, aarch64 and agnos.

---

## 1.2.0 — Adopting cmdit (CLI parsing)

Replace `src/main.cyr`'s hand-rolled argv handling with cmdit. The v1.0
command surface stays frozen: every delta below is identical or
additive, which is what makes this a minor. Checked against the 1.1.1
tree (`src/main.cyr` is unchanged since 1.0.9) and cmdit **1.5.0**.

**P(-1): yes.** Argument parsing is a path-argument surface. Re-walk
F-013 (extra positionals), F-019 (flag-shaped values), F-033 (`inspect`
flags exit 2) and F-051 (the `--root` grant runs after parse, unchanged).

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
  each `cmd_*`'s own usage line (e.g. `cmd_link`'s `usage: hapi link …`). Help: `hapi_print_usage`
  (`:58-87`, stdout).

### Site → cmdit

- `argv(1)` chain → `cmdit_new("hapi")` + ten `cmdit_verb` + `cmdit_dispatch` on
  `cmdit_verb_matched`; `-v` → `cmdit_version_short(h, 118)`. Ids are registration order, so future
  verbs (`fmt` at 1.7.0) append at the end (stiva's `src/main.cyr:77` warning).
- Per-verb loops → one child handle per verb + `cmdit_parse_verb`, registering only that verb's
  subset. **Not** cmdit globals — those bind on every verb and would break the exit-2 rejections in
  `guides/dry-run.md:23`, `guides/backup-to.md:18` and `guides/capability.md:30-32`.
- Bools → `cmdit_bool`; `--root`/`--backup-to` → `cmdit_str` + `cmdit_metavar`, each with
  **`cmdit_reject_flag_value`** (cmdit 1.3.6, added for hapi), which keeps F-019's refusal: a
  flag-shaped separate value is `CMDIT_ERR_MISSING_VALUE`, not taken. The setters and
  `_hapi_apply_root` run after parse.
- Extra positional → `cmdit_require_positionals_max` (the token is `cmdit_positional(vh, N)`);
  missing value → `CMDIT_ERR_MISSING_VALUE` + `cmdit_err_flag`; unknown flag → **`cmdit_err_token`**
  (cmdit 1.3.3), so ``unexpected flag for `link`: --x`` survives verbatim. Every existing message
  is kept.
- Delete `args_init()` (`:182`): `cmdit_argv` calls it, and each Linux call allocates a fresh 2 MB
  buffer (`lib/args.cyr`).

### Decisions left (none block)

- [ ] **Help.** Keep `hapi_print_usage` hand-written, or render it with `cmdit_help_fd(h, 1)`
  (cmdit 1.3.5 — help on stdout, which `hapi --help` needs). The identity bar below decides: switch
  only if the output can match byte for byte. The default is to keep it hand-written; the verb set
  is frozen, so drift risk is low.
- [ ] **CHANGELOG as additive:** `--root=PATH`/`--backup-to=DIR`, `--` (an alternative to the
  `./-name` advice at `:129`), lone `-` as a positional, `hapi <verb> --help`/`--version` (exit 2
  today). Error precedence shifts on multi-error lines: unknown flags beat extra positionals, and
  parse errors (2) beat a cap denial (1).

### The manifest change

Append after `[deps]` (`cyrius.cyml`). `"args"` and `"io"` are already listed, there is no `"flags"`
to drop, and cmdit 1.5.0 is on the same cyrius pin as hapi (`6.7.18`), so no pin bump:

```
[deps.cmdit]
git = "https://github.com/MacCracken/cmdit.git"
tag = "1.5.0"
modules = ["dist/cmdit.cyr"]
```

### Tests and the output-identity bar

- [ ] **No argv-level test exists** — `tests/hapi.tcyr` drives `cmd_*` and cannot include
  `main.cyr`. Move the dispatcher into `src/cli.cyr` (already included, `tests/hapi.tcyr:20`) and
  drive the pure `cmdit_dispatch_argv` with synthetic argv. `tests/agnos.tcyr` needs nothing: it
  drives `cmd_*` too.
- [ ] No golden either: capture `(stdout, stderr, exit)` from the 1.1.1 binary for every verb ×
  {each accepted/rejected flag, extra positional, missing and flag-shaped value, `--help`/`-h`/
  `--version`/`-v`}, plus no args and an unknown verb. It must diff clean but for the deltas above.
- [ ] Must pass unmodified: `scripts/agnos-smoke.sh` checks 1 and 4 (`--version`; an unknown verb
  exits 2 on agnos), `scripts/concurrency-test.sh` (`adopt`), and `release.yml`'s `--version` gate
  (`hapi ${VERSION}`).
- [ ] **Benchmark row.** The sync harness starts 100 processes, so per-process parse cost is
  visible there. Dropping `args_init()` saves a 2 MB allocation per process. Record the DCE binary
  size too: cmdit adds code to a binary that is mostly bayan's Unicode data.

Pointers: cmdit's `README.md` (API reference) and `docs/adr/0002-verb-dispatch.md`; stiva's
`src/main.cyr` is the worked verb-tool migration, and sit (cmdit 1.4.0) a recent one.

## 1.2.x — cmdit fallout only

Fixes to 1.2.0's migration — a message that drifted, a flag that parses differently. No new
surface.

---

## 1.3.0 — sync: no argument, and `--prune`

The two open dogfood issues, both on `sync`. **P(-1): yes** — no-arg sync turns a tree walk into
write targets, and prune removes links.

- **No-arg `hapi sync`** — sync every package hapi can find, so a recovery is one command, not a
  loop. **Dogfood pressure (2026-05-24):** a drive-move recovery had to loop over packages by
  hand, and the wiped trail proved trail-recovery fails closed exactly when recovery matters
  most. So the **root scan is the primary mechanism**, and the trail only augments it (an additive
  `manifest_path` field on `op:link` would let it name packages the scan misses). The signature
  stays: no argument becomes legal, a positional-count change once cmdit owns the bounds. What the
  scan walks, how deep, and what it refuses to treat as a package are this release's design.
  [`issues/2026-05-24-no-arg-sync-bootstrap-recovery.md`](issues/2026-05-24-no-arg-sync-bootstrap-recovery.md).
- **`hapi sync --prune` (opt-in)** — emit `op:unlink` for trail rows no longer in the manifest.
  Conservative: refuse when the prune count exceeds a threshold, unless `--force` is given. Prune is
  a removal, so it runs F-055's trail preflight and the "we only remove what we created" text
  check (`fsl_link_text_matches`).
  [`issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`](issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md).

## 1.4.0 — `created_dirs` on `op:link`

**P(-1): yes** (trail format, plus a new removal path).

- Record the parent directories `link_create` had to make, so `unlink` / `rollback` can remove
  exactly those and nothing else. Today they are deliberately left behind (1.0.9, F-029): the
  trail records the symlink, not the directories, so any unlink-time prune is an *inference* — and
  `rmdir` can still take out a directory the user made on purpose, or drop a mode the user set. On
  `~/.ssh` that is a security regression hapi would have caused while claiming to reverse itself.
  hapi removes only what it created, *with proof*; this field is the proof. Additive per ADR 0002's
  growth contract.
- Needs an `rmdir` shim in `src/agnos_compat.cyr` (agnos `rmdir` takes a path length), and the
  reversal must remove deepest-first and stop at the first directory that is not empty.

## 1.5.0 — Script-facing flags

**P(-1): no** for `--quiet`. **Yes** for the rollback flags (they choose what is removed).

- **`hapi status --quiet`** — return 0 unless there's an actual error (manifest parse failure, IO
  error), flipping the exit-code semantic for scripted `&&` chains. The v1.0 workaround is `link
  --dry-run` per [`guides/status.md`](../guides/status.md) *Exit-1 is an assertion, not a
  predicate*.
- **`hapi rollback --steps N` / `--to <marker>`** — refine the no-arg form, which stays the
  default. **Open design question:** markers carry only `ts`, so `--to` needs a way to name one —
  by position (`--to 2`, the second most recent), by timestamp, or by a `label` field that
  `checkpoint --label` writes (additive under ADR 0002). Since 1.1.1, rollback writes its own
  closing marker (F-056). Whether `--steps` / `--to` should count those markers, or skip them, has
  to be decided too; an additive field that marks who wrote a marker would settle it.

## 1.6.0 — `--absolute`

**P(-1): yes** (link text). Opt a run into absolute symlink targets instead of ADR 0003's
relative default, which ADR 0003 reserved. Two helpers decide what hapi's own link looks like:
`fsl_link_text` (what `link`, `adopt` and `status` write and expect) and `fsl_link_text_matches`
(what `unlink` and `rollback` accept as theirs). Both must know about the absolute text. If only
the first does, an absolute link becomes un-removable. The flag also has to be recorded somewhere —
the trail, most likely — or a later `status` without it calls every absolute link wrong.

## 1.7.0 — `hapi fmt`

**P(-1): no** (it writes only the manifest, through the existing writer). A manifest
canonicalizer / formatter. Ships in v1.x **only if** its output equals `hapi_mf_canonicalize`'s
bytes, so the audit-trail manifest hash does not change. If a richer canonical form is needed, it
crosses into v2.0. It must keep the body below `---` byte for byte (ADR 0001, 1.1.1 addendum).

---

## Gated — scheduled when the gate opens

Each lands in whichever 1.x minor is next when its gate opens. None blocks the plan above.

- **`hapi adopt` on agnos** — *gate: agnos ext2 rename-over* (F-059, accepted —
  [`issues/2026-10-28-adopt-on-agnos-kernel.md`](issues/2026-10-28-adopt-on-agnos-kernel.md);
  filed 2026-10-28 in agnos as
  `docs/development/issues/2026-10-28-ext2-rename-cannot-replace-an-existing-file.md`). hapi's half:
  open the lock with `O_DIRECTORY`, and lock somewhere agnos flock#59 accepts. That is a directory
  if the kernel adds it, otherwise a regular lock file — which means deciding how `check` treats
  that file. Confirm on a QEMU-booted kernel; mirshi cannot see this class.
- **mirshi kernel fidelity** — *gate: mirshi matching agnos on four calls* (filed 2026-10-28 in
  mirshi's `docs/development/roadmap.md`, § *Open defects — kernel fidelity*, items 1–4). hapi's
  half: move `MIRSHI_REF` in `scripts/build-mirshi.sh`, then check that `tests/agnos.tcyr` still
  passes under the stricter mirshi. Its long-symlink case and the manifest round trip become
  meaningful there.
- **mirshi envp** — *gate: mirshi staging the kernel's `HOME=/ PWD=/`* (same section, item 5).
  hapi's half: widen `scripts/agnos-smoke.sh` check 2 from "the env gap is diagnosed" to running
  the shipped binary's verbs.
- **NFS homes** — *gate: someone running hapi on one.* Unconfirmed: flock on NFS is emulated with
  fcntl locks, an exclusive lock needs a writable fd, and the manifest lock is a directory fd. So
  `adopt` likely fails closed there (2026-10-28 audit, *Accepted boundaries*). If it does, the lock
  file from the agnos item above covers it too.
- **`hapi merge <pkg>`** — *gate: a stock-template-version data model.* A speculative 3-way merge
  driver for drifting-upstream templates (hyprland-class); Tier-3 in
  [`issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md`](issues/archived/2026-05-20-upstream-stock-template-drift-pattern.md).
  New verbs append to cmdit's registration order.
- **`docs/architecture/001-upstream-drift-pattern.md`** — *gate: a second drifting-upstream
  consumer* (likely sway / fish / kitty when an upstream stock-template rewrite drops). Formalizes
  the audit + merge workflow; Tier-2 from the same archived issue.

---

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

- **`hapi sync --prune` as default-on**. If the 1.3.0 opt-in
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
