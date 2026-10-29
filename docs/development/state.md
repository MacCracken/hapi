# hapi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.7.1** (2026-10-29) — the P(-1) sweep after 1.7.0, on the cyrius 6.7
line (pin `6.7.18`). A 14-unit audit with paired verifiers
([2026-10-29 audit](../audit/2026-10-29-audit.md)) found the resolver
dropping the first byte of every relative symlink text (F-065), which had
left the capability boundary open for relative links since 1.1.1. 1.7.1
repairs all three of the audit's tiers, F-064 – F-116, and adds no verb
or flag. Tier 1 is containment and data loss:

- an unprobeable component ends the walk (F-066);
- rows are compared at their physical places (F-067);
- `--force` replaces in one rename (F-068);
- a source leading back to its target is refused (F-069), and so is
  another package's file (F-070);
- adopt is locked end to end and never replaces a name (F-071);
- the trail lives only under an absolute base (F-072);
- manifest reads are whole or refused (F-073), and an open value is an
  error (F-074);
- `link` hashes what it parsed (F-075);
- the suites clean up after themselves (F-064).

Tier 2 (F-076 – F-090) is correctness and error handling. A probe that
fails is never read as absent, a short trail write is taken back, a
closed output pipe no longer kills hapi, `rollback --to` honours only a
label's newest checkpoint, and an adopt's reversal finds its manifest.
Two behaviours changed by the maintainer's choice:

- `unlink` retires a link it finds already gone with an `op:unlink`
  carrying `"absent":"1"`, which rollback never re-creates (F-078);
- `link` records a link hapi wrote that the trail does not record for
  the package (F-079). A lost trail (F-006), a renamed package or a
  moved `$HOME` heals on the next `sync`.

Tier 3 (F-091 – F-116) covers robustness, messages, refactors, test gaps
and CI. It refuses FIFOs instead of waiting on them and rejects control
bytes in manifest values. A `--dry-run` fails where the real run's trail
write would. The trail's `\u` escapes are decoded, and a rewritten
manifest keeps its mode and refuses a hard link.

Removal still accepts the text 1.1.1–1.7.0 wrote under a relative
symlinked parent. Seven items are accepted, and the roadmap tracks them.
Both suites pass on x86_64 and on aarch64 under qemu, and
`tests/agnos.tcyr` also passes on agnos under mirshi. CI and release run
on `ubuntu-26.04`.

Before it, 1.7.0 added `hapi fmt` ([ADR 0008](../adr/0008-hapi-fmt.md)). Before it, 1.6.0 added `--absolute` (a link of either shape is hapi's; the
trail records `"shape":"absolute"`). 1.5.0 added `status --quiet`, `checkpoint --label` and
`rollback --to` / `--steps`, a multi-level undo
([ADR 0007](../adr/0007-rollback-steps-and-to.md); F-063 accepted).
1.4.0 recorded `created_dir` on `op:link`, so `unlink`,
`sync --prune` and `rollback` remove the directories `link` made (F-062
caught before release). 1.3.0 added `hapi sync` with no package (every package under
`HAPI_PACKAGE_ROOTS`) and `sync --prune` ([ADR
0006](../adr/0006-sync-package-roots-and-prune.md)), and fixed F-061 (a
removal whose trail entry failed after the pre-flight is now taken back).
1.2.0 / 1.2.1 moved argument parsing to cmdit 1.5.0
(`[deps.cmdit]`), keeping every 1.1.1 message (checked against an
819-line golden). They added the forms getopt brings (`<verb> --help` /
`--version`, `--root=PATH` / `--backup-to=DIR`, `--`, a lone `-`) and
fixed F-060. 1.1.1 repaired F-035 – F-059; F-059 (`adopt` on a real
agnos kernel) stays accepted.

Release-by-release detail lives in
[`../../CHANGELOG.md`](../../CHANGELOG.md), and the findings with their
resolutions in [`../audit/2026-10-28-audit.md`](../audit/2026-10-28-audit.md)
(and [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md) for
F-007 – F-034).
This file is the *snapshot*, not a second changelog — it says what is
true now, not how it got here.

Milestone index, for tracing an ADR or a guide back to its ship:
v1.0.0 = M8 / v1.0 freeze (2026-05-23), v0.9.0 = M7 close, v0.8.0 = M7
sweep, v0.7.0 = M6, v0.6.0 = M5, v0.5.0 = M4, v0.4.0 = M3, v0.3.0 = M2,
v0.2.0 = M1, M0 scaffold 2026-05-19.


## Toolchain

- **Cyrius pin**: `6.7.18` (in `cyrius.cyml [package].cyrius`)
- **Vendored `lib/`**: 114 files. 113 are the 6.7.18 full stdlib
  snapshot (106 top-level + 7 in `unicode/`, `cyrius lib sync --full`),
  mirroring the pin exactly — nothing hand-edited, nothing left over
  from an earlier snapshot. The 114th is `lib/cmdit.cyr`, cmdit 1.5.0's
  `dist/cmdit.cyr`, which `cyrius deps` writes from `[deps.cmdit]` and
  `cyrius.lock` pins to its commit (`7671a28`). Verify with
  `diff -rq lib ~/.cyrius/versions/6.7.18/lib` (the one difference is
  `Only in lib: cmdit.cyr`) and `cyrius deps --verify`.
- **Binary size**: the `CYRIUS_DCE=1` release binary is ~581 KB at
  1.2.0 (552 KB at 1.1.1; 543 KB at 1.1.0; 195 KB at 6.6.20). 1.2.0's
  +28 KB is code, cmdit's. The 6.7 line's earlier growth is
  **data**. 6.7.18's `bayan` unconditionally includes the Unicode
  casefold / category / normalization tables, and DCE drops dead code
  but not data. hapi reaches none of it, and `sync` timing is
  unchanged. Upstream's to fix — `lib/` is not edited here.
- **Refresh `lib/` with `cyrius lib sync --full`.** Through 6.7.11,
  `cyrius update` ignored the manifest pin and re-vendored from
  whatever `~/.cyrius/current` pointed at (it did exactly that during
  the 1.0.12 refresh). Fixed upstream at 6.7.12: `update` now runs the
  same sync from the pin's snapshot. Without `--full` it refreshes
  only the declared `[deps] stdlib` set, so `lib sync --full` (or
  `update --full`) is still what keeps hapi's full snapshot exact.
- **`cyrius.lock`**: written by `cyrius deps` / `lib sync` (sha256 per
  vendored file plus a `cyrius<TAB><pin>` trailer). Tracked in git
  since 1.0.12; `cyrius deps --verify` checks `lib/` against it.

## Shape

Binary (`hapi`). The command line is parsed by cmdit in `src/cli.cyr`:
the command is `argv[1]` alone (a verb, or `--version` / `--help` /
`-v` / `-h`), and each verb parses the rest on its own cmdit handle.
Ten real verbs frozen at v1.0.0, and since 1.7.0 an eleventh, `fmt`. Three "global" flags are per-verb
subsets, registered only on the verbs that take them:
`--root <path>` (link / adopt / sync / status / list),
`--dry-run` (link / unlink / adopt / sync / rollback /
checkpoint), and `--backup-to <dir>` (parsed on link / sync / adopt; effective
on `link --force` / `adopt` only — `sync` never overwrites, so it
is inert there) —
opt-in pre-`--force` snapshot. Since 1.3.0 `sync` also takes `--prune`,
and `--force` with it, which lifts prune's limit and nothing else. Since
1.5.0 `status` takes `--quiet`, `checkpoint` `--label <label>`, and
`rollback` `--steps N` or `--to <label>`. Since 1.6.0 `link`, `adopt` and
`sync` take `--absolute`. `fmt` (1.7.0) takes `--check`, `--dry-run` and
`--force`.

### Current command surface (frozen at v1.0)

| verb                  | exit codes               |
|-----------------------|--------------------------|
| `hapi inspect`        | 0 ok / 1 parse / 2 args  |
| `hapi link`           | 0 ok / 1 fail / 2 args   |
| `hapi unlink`         | 0 ok / 1 refused / 2 args|
| `hapi rollback`       | 0 ok / 1 IO error / 2 args |
| `hapi adopt`          | 0 ok / 1 refused / 2 args|
| `hapi list`           | 0 ok / 1 env error       |
| `hapi sync`           | 0 ok / 1 fail / 2 args   |
| `hapi status`         | 0 ok / 1 drift / 2 args  |
| `hapi checkpoint`     | 0 ok / 1 IO error / 2 args |
| `hapi check --strict` | 0 ok / 1 parse / 2 args  |
| `hapi fmt` (1.7.0)    | 0 ok / 1 refused or `--check`: not formatted / 2 args |
| `hapi --version`      | 0                        |
| `hapi --help`         | 0                        |

Additive since 1.2.0: `hapi <verb> --help` / `-h` and `--version` /
`-v` (exit 0), `--root=PATH` and `--backup-to=DIR`, `--` to end a
verb's flags, and a lone `-` as a positional. Since 1.3.0: `hapi sync`
with no package (every package under `HAPI_PACKAGE_ROOTS`; exit 2 when it
is unset), and `sync --prune [--force]`. Since 1.5.0: `status --quiet`
(drift exits 0; 1 only on an error), `checkpoint --label <label>`, and
`rollback --steps N` / `--to <label>` (exit 1, nothing changed, for an
unknown label or more steps than the trail holds). Since 1.6.0:
`--absolute` on `link` / `adopt` / `sync`. Since 1.7.0: the `fmt` verb,
registered after `sync` so no verb id moved. Nothing is accepted
before the verb, and a leading `--help` / `--version` answers whatever
follows it.

ADR 0005's usage contract, tightened in 1.0.9: **every** verb rejects an
extra positional with exit 2 (`hapi rollback <pkg>` used to ignore the
argument and reverse the entire trail); a verb that takes no flags still
owes 2 for one rather than 1 (F-033, `inspect`); and a flag-shaped value
for `--root` / `--backup-to` is refused rather than consumed (F-019 —
`link --root --dry-run pkg` used to create a directory named
`--dry-run`; since 1.2.0 a value starting with `-` is refused in every
spelling). On a line with more than one error, a flag error is named
before an extra positional, and a usage error (2) before a `--root`
denial (1). `status` exits 1 on drift, which is an assertion, not a
predicate; `status --quiet` (1.5.0) is the predicate.

Two accepted keys do nothing, and a state snapshot is the right place to
say so: `--backup-to` is **inert on `sync`** (sync never overwrites: its
`--force` only lifts `--prune`'s limit, so no destructive step to snapshot
— F-026), and `package.ignore` is parsed,
echoed by `inspect` and folded into the manifest hash but honoured by no
verb (**reserved until v2.0** — F-025, ADR 0001).

## Source

- `src/main.cyr` — entry point: `alloc_init()`, then
  `hapi_cli_main()`.
- `src/agnos_compat.cyr` — target-portability shims for the agnos
  userland (`hapi_unlink` / `hapi_rename` / `hapi_fsync` /
  `hapi_symlink` / `hapi_readlink` / `hapi_mkdir`, and since 1.4.0
  `hapi_mkdir_made` — which says whether it made the directory, asking
  `stat` first on agnos, whose `mkdir` is idempotent — and `hapi_rmdir`).
  Each forwards
  verbatim on Linux/macOS; the agnos branch absorbs the
  syscall-ABI divergence (explicit path lengths, `sync` for
  `fsync`, `mkdir`'s length-not-mode second argument). Every
  wrapper now rides a native cyrius peer — the last locally
  declared syscall number, `AGNOS_SYS_READLINK`#70, went away in
  1.0.4 when the 6.5.35 snapshot shipped `sys_readlink`. Also
  `hapi_open_nofollow` (atomic on every target since 1.1.1 — the agnos
  arm passes `O_NOFOLLOW` and keeps a 4096-byte readlink pre-check for
  kernels before 1.56.53), and the two errno-free predicates agnos
  needs: `hapi_excl_exists` and `hapi_open_absent` (stat-based there,
  `-EEXIST` / `-ENOENT` on Linux).
- `src/manifest.cyr` — `hapi.cyml` parser + canonical
  re-serializer. `hapi_mf_canonicalize(m, out, cap)` emits
  the fixed byte form used by the v0.8.0 `sha1c:`
  manifest_hash variant: `[package]` fields in fixed order,
  `[[link]]` rows sorted by `target`, no comments, single
  blank line between sections. Since 1.7.0 the parser records what it
  skips (`_hapi_mf_drop`, at each skip site, only while `fmt` tracks:
  `hapi_mf_track_drops`), and `hapi_mf_format_r` builds `fmt`'s header —
  the canonical bytes in the file's line ending, the drops, a backslash
  check, and the proof that the result parses back to the same bytes.
- `src/manifest_write.cyr` — append + remove `[[link]]` rows
  atomically via `tmp+rename`. **Header-only, by the reader's rule**:
  `_hmw_delim_at` / `_hmw_find_separator` find the first `---` line
  exactly as bayan 1.11.1 does (a whole `---` line ending in `\n`, CR
  LF, or end of file), append inserts above it, and remove searches
  only above it. The bodies below it are markdown and never edited.
  The two sides are pinned against each other by the `1.1.0` section of
  `tests/hapi.tcyr`; a bayan bump that moves the rule fails there. Since
  1.7.0 it also exports the pieces `fmt` rewrites with — `manifest_lock`
  / `manifest_unlock`, `manifest_read`, `manifest_body_start`,
  `manifest_uses_crlf`, `manifest_commit` (which refuses a symlinked
  manifest, F-058).
  An appended row matches the file's line ending; a symlinked
  `hapi.cyml` is refused (an atomic rename would replace the link); a
  leftover `hapi.cyml.<pid>.tmp` is reported as such. Uses the stdlib `sys_rename` /
  `sys_fsync` wrappers (landed in cyrius 6.2.x) — shared by
  `adopt` / `rollback`. The 1.0.1-era `HapiSysno` enum
  (`HAPI_SYS_RENAME` / `HAPI_SYS_FSYNC`, x86_64-only literal
  numbers) was retired in 1.0.2; the wrappers are arch-correct.
  `fs_link.cyr`'s open/close already use the stdlib `SYS_OPEN` /
  `SYS_CLOSE`.
- `src/audit.cyr` — JSONL audit-trail writer (link / unlink /
  adopt / unadopt / rollback-marker entries; manifest hash via
  `hapi_mf_canonicalize` + sha1 with `sha1c:` prefix as of
  v0.8.0; XDG path resolution with test override hook).
  `audit_report_unwritten` is the F-061 report for a mutation whose
  entry the trail refused after the pre-flight passed, and the test hook
  `audit_test_fail_appends` opens exactly that window.
- `src/audit_reader.cyr` — JSONL reader; hand-rolled scanner
  over the ADR 0002 field set
- `src/fs_link.cyr` — symlink primitives (probe / compute
  relative / create with mkdir-parents) and the physical-path layer:
  `fsl_resolve_path` (every component followed, `..` popped against the
  resolved prefix), `fsl_link_text` (ADR 0003's text, from the parent
  the link physically sits in), since 1.6.0 `fsl_absolute_text` /
  `fsl_link_text_shaped` (the `--absolute` text) and
  `fsl_is_absolute_text` (either shape is hapi's: `link`, `status` and
  `fsl_link_text_matches` all accept it), and `fsl_lands_in` (does a target
  resolve into a given directory — the package guard). `link_probe`
  reads the link first, so a symlink is always SYMLINK, then splits
  file from directory. Since 1.4.0 `fsl_mkdir_parents_mode_r` /
  `link_create_r` report the outermost directory they made (an
  `op:link`'s `created_dir`), and `fsl_rmdir_created` (one link) /
  `fsl_rmdir_created_all` (a run's links together) remove such a chain,
  after `_fsl_made_ok` (the record is its link's own) and
  `_fsl_chain_is_real` (no directory in it is now a symlink, F-062).
- `src/cmd/inspect.cyr` — manifest dump
- `src/cmd/link.cyr` — `_hlnk_plan_run` parses the manifest, classifies
  every row and makes every refusal before any write; `_hlnk_execute`
  creates and audits. Split in 1.3.0 so `sync --prune` can plan both
  halves first. On a refused trail entry a new link is taken back (F-018).
- `src/cmd/unlink.cyr` — trail-driven removal
- `src/cmd/adopt.cyr` — file-into-package move + symlink +
  manifest edit + audit
- `src/cmd/rollback.cyr` — reverse-replay; handles
  link / unlink / adopt entries. Since 1.5.0 `_hrb_select` picks the
  range for `--steps` / `--to`, stepping over a closing marker's `from`
  range (`_hrb_from_line` decides whether to trust it), and the closing
  marker records `from`
- `src/cmd/checkpoint.cyr` — appends `op:rollback-marker`
  via `audit_append_marker_r`, with a `label` under `--label`
- `src/cmd/status.cyr` — read-only drift classifier over
  manifest [[link]] rows
- `src/cmd/list.cyr` — trail walker; per-package live-link
  counter (link/adopt = create, unlink/unadopt = clear)
- `src/cmd/check.cyr` — inspect with `--strict` (rejects
  unknown sections / keys via the `_hapi_mf_strict` flag
  added to `manifest.cyr`)
- `src/cmd/fmt.cyr` (1.7.0, ADR 0008) — `hapi fmt`: under the
  package-directory lock, read, format the header (`hapi_mf_format_r`),
  refuse what would be lost without `--force` and any backslash, then
  commit the canonical header, a blank line and the body unchanged.
  `--check` and `--dry-run` only read.
- `src/cmd/sync.cyr` — `link` without `--force` for one package, plus
  (1.3.0, ADR 0006) the no-package scan of `HAPI_PACKAGE_ROOTS`
  (`_hsy_all`: one level, no symlinks followed, twins refused, failures
  do not stop the run, the trail only reported from) and `--prune`
  (`_hsy_prune_one`: candidates must be this package directory's live
  `op:link`s in this scope whose row is gone and whose link is still
  hapi's; refused past half without `--force`; planned whole, then
  pre-flight, removals, creates). Test hook `sync_set_package_roots`.
- `src/cap.cyr` — the capability boundary. `cap_check_root_r(path)`
  vets `--root` on the PHYSICALLY resolved root (1.1.1, F-051): inside
  the resolved `$HOME`, or inside a resolved `HAPI_ALLOWED_ROOTS` entry
  (path-component boundary; `/` contains everything). The spelling it
  returns is lexically normalized, as before. `cap_target_allowed(path,
  scope)` is the per-write check — resolved target inside resolved
  scope, or allowlisted. Test hooks `cap_set_home` and
  `cap_set_allowlist`.
- `src/cli.cyr` — the command line (1.2.0). `hapi_cli_main()` reads
  argv through `cmdit_argv`; the pure `hapi_cli_run(argc, argv)` is
  what `tests/hapi.tcyr` drives. cmdit dispatches over `argv[1]` alone;
  each verb then parses `argv[1..]` on its own handle with only its
  flags (`--root` / `--backup-to` as `cmdit_repeat` +
  `cmdit_reject_flag_value`), its positional count is
  `cmdit_require_positionals_max`, and hapi renders every error in its
  1.1.1 words. Verb ids are registration order: a new verb appends to
  the `HapiVerb` enum and to `_hapi_cli_new`. Also the hand-written
  usage (`hapi_print_usage`), `hapi_print_version` — `hapi <X.Y.Z>`
  from the compile-time `CYRIUS_PKG_VERSION` (cyrius resolves it from
  `[package].version` = `${file:VERSION}`, so `VERSION` is the only
  place the number lives). Nothing under `src/cmd/` includes it: the
  dispatcher depends on the commands, not the reverse.
- `src/dry_run.cyr` — owns the process-wide `_hapi_dry_run` flag
  (`hapi_set_dry_run(0|1)` / `hapi_dry_run()`), which every mutating
  cmd checks before its first syscall / audit write. A leaf since
  1.2.1; 1.2.0 kept it in `src/cli.cyr`, so a command pulled in the
  whole command line.
- `src/backup.cyr` — owns the process-wide
  `_hapi_backup_dir` cstring (set by `--backup-to <dir>`),
  the `<YYYYMMDD-HHMMSS>-<pkg>-<basename>` filename
  composer, and the byte-copy primitive used by link's
  `--force` path and adopt's pre-rename step. Setter
  `hapi_set_backup_dir(cstr|0)` and getter
  `hapi_backup_dir()` mirror the dry-run pattern.

## Audit trail

- **Location**: `$XDG_STATE_HOME/hapi/audit.jsonl` (or
  `$HOME/.local/state/hapi/audit.jsonl` when unset)
- **Format**: JSONL, append-only, ADR 0002
- **Hash**: `sha1c:` + 40 hex — canonical variant: parse the
  manifest, re-serialize to fixed byte form, sha1 the result.
  Pre-v0.8.0 entries written under the legacy `sha1:` raw-bytes
  prefix continue to be tolerated by readers per the migration
  contract.
- **Entry ops**: `link`, `unlink`, `adopt`, `unadopt`,
  `rollback-marker`
- **Additive fields**: `backup_path` on `link` / `adopt` entries
  when `--backup-to <dir>` is set. Pre-v0.8.0 readers tolerate
  the field per ADR 0002's growth contract. `created_dir` (1.4.0) on
  `link` entries whose creation made a directory: the outermost one,
  the rest implied. One string, written last; pre-1.4.0 readers drop it.
  On `rollback-marker` (1.5.0): `label`, from `checkpoint --label`, and
  `from`, the line a rollback's range began on, on the marker closing it.
  The reader also records each entry's line (`hae_lineno`). `shape`
  (1.6.0): `"absolute"` on `link` / `adopt` entries that wrote an
  absolute link text and `unlink` / `unadopt` entries that removed one;
  absent for the relative default. `absent` (1.7.1): `"1"` on an
  `unlink` entry that retires a link already gone; rollback skips it.
- **Readers**: `unlink`, `rollback`, `list`, `status`, `sync`
  — every verb that consults the trail walks via
  `src/audit_reader.cyr`.
- **Recovery (F-006, closed by F-079 in 1.7.1)**: the trail is local
  state, and a wiped `$XDG_STATE_HOME` empties it even when the links
  survive. Since 1.7.1 the next `link` or `sync` records each link whose
  text is exactly what hapi writes for the row, so the trail is rebuilt
  ([issue, archived](issues/archived/2026-05-24-audit-trail-lost-on-state-dir-wipe.md)).
- **One environment, one trail**: the location is read per run, so a
  shell that sets `XDG_STATE_HOME` and a cron job that does not keep two
  trails, neither seeing the other's (ADR 0002 § Location).

## Tests

- `tests/hapi.tcyr` — primary suite. **2,052 assertions across 207 test
  groups.** Re-derive rather than recount by hand — these figures have
  rotted twice, and the per-tier breakdown below drifted 16 groups
  short before the 2026-08-26 sweep:

  ```sh
  cyrius test                                   # assertions
  grep -c 'test_group(' tests/hapi.tcyr         # groups
  cyrius test 2>&1 | grep '^=== ' | sed 's/^=== //;s/:.*//' \
    | sort | uniq -c | sort -rn                 # per-tier breakdown
  ```

  Groups by tier (first word of the group name), as measured at 1.7.1:
  link 26, rollback 16, manifest 14, cli 14, sync 13, manifest_write 9,
  check 9, cap 9, adopt 9, unlink 8, status 7, fs_link 7, backup 7,
  audit 7, dry-run 6, audit_reader 6, `--absolute` 6, fmt 5, canonical 5,
  created_dir 4, audit-repair 4, list 3, scratch 2, resolve 2,
  checkpoint 2, `--backup-to` 2, and one each of main, guards,
  agnos_compat, adopt's and `--dry-run`. The two `scratch` groups run
  last: they remove every directory the run made under /tmp and assert
  that nothing of it is left (F-064, `tests/scratch.cyr`). The `cli` tier (1.2.0) runs `hapi_cli_run` with a
  synthetic argv and its stdout / stderr captured through `dup2`, so the
  v1.0 messages are asserted byte for byte.
- `tests/agnos.tcyr` — **100 assertions across 16 groups**, all
  target-neutral: the agnos-conditional paths (no-follow open,
  exclusive create, absent trail, trail and manifest round trips,
  backup copy, the fs shims, `link` / `status` / `unlink` with the
  scope at `/`, since 1.3.0 a package-root scan and a prune, and since
  1.4.0 a made-directory round trip, since 1.5.0 `rollback --to` and
  `--steps`, since 1.6.0 an absolute link's round trip, since 1.7.0 an
  `fmt` round trip, since 1.7.1 the no-replace move and a cleanup of every
  scratch directory). `cyrius test` runs it on x86_64 and aarch64; the agnos
  smoke builds it with `--agnos` and runs it under mirshi. Absolute
  paths only, no chmod, no environment — what an agnos run allows.

### Harnesses

`cyrius test` cannot express two of hapi's regressions, so they live
beside it as shell harnesses. **CI runs both.**

The suite itself also runs on aarch64 — `cyrius test --aarch64` under
`qemu-aarch64` (2,052 / 2,052 and 100 / 100 at 1.7.1). **CI runs it** as of 1.0.12
(`Test (aarch64, under qemu)`, after installing `qemu-user`; a missing
qemu fails the step, it never skips). Before that the aarch64 step was
compile-only, which is how the `O_NOFOLLOW` literal went unseen from
0.9.0 to 1.0.11. `release.yml` gates on `ci.yml`, so a release runs it
too.

- `scripts/concurrency-test.sh` — F-012's regression. The defect needs
  two hapi *processes* racing on one manifest, and `.tcyr` cannot fork
  while hapi is syscall-only by rule. Measured before the fix: 16
  concurrent adopts → 16 files moved, 16 symlinks, 16 trail entries and
  **1** manifest row; 16/16 after. Since 1.7.0 it also races 16 adopts
  against four `fmt` loops on one package. One round missed a lockless
  `fmt` in 5 of 12 runs, so since 1.7.1 it runs five, and a lockless
  `fmt` fails 8 runs of 8. Since 1.7.1 it also races two adopts that
  derive one package-side name (F-071), `list` against appends (F-102),
  and a closed output pipe (F-085); each section fails on 1.7.0.
- `scripts/agnos-smoke.sh` — runs the `--agnos` build under mirshi.
  Five checks: the binary loads and the agnos arg reader delivers argv,
  the envp gap is asserted rather than assumed, a relative package
  argument is refused rather than silently mis-resolved (F-027), the
  exit-code contract holds, and `tests/agnos.tcyr`'s agnos build passes
  with zero failures. A missing prerequisite exits **2 = SKIP**, for dev
  boxes; **CI fails on it** (F-043 — through 1.1.0 the runner had no
  mirshi, so every run skipped).
- `scripts/build-mirshi.sh` — how CI gets a mirshi: clones the pinned
  tag (1.11.3) and builds it with hapi's own cyrius pin. ⚠ mirshi
  differs from the real agnos kernel on four calls (readlink of an
  over-long body, a directory open without `AO_DIRECTORY`, flock on a
  directory fd, rename onto an existing file — the 2026-10-28 audit's
  *Harness gap*), so a pass that touches the agnos arm should also run
  on a QEMU-booted kernel.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, slice, syscalls,
  assert, bench, args, fs, result, bayan, sha1, chrono
  (`bayan` supplies `cyml`; the standalone `toml` / `cyml`
  modules were folded into it in the v6.1.25 stdlib carve)
- **cmdit 1.5.0** (`[deps.cmdit]`, `modules = ["dist/cmdit.cyr"]`) —
  argument parsing, since 1.2.0. On the same cyrius pin as hapi.
  `args` and `io` above are what it needs.

Previously-pending stdlib syscall wrappers **landed in cyrius
6.2.x** and are now consumed directly (1.0.2): `sys_rename`
(proposal `2026-05-17-syscalls-at-family-stdlib.md`) and
`sys_fsync` / `sys_fdatasync`
(`2026-05-20-syscalls-fsync-stdlib.md`). The hand-rolled
`HapiSysno` enum that stood in for them is retired — though one
bare `syscall(SYS_OPEN, ...)` in `fs_link.cyr` survived that sweep
and was only caught at 1.0.4, when it turned out to be the single
constant the aarch64 table does not define. The remaining raw sites
(`SYS_GETDENTS64`, `SYS_CLOSE`, `SYS_GETCWD`, all in `fs_link.cyr`)
are defined on every target hapi builds for, so they compile;
`cyrius lint` recommends `lib/io.cyr`'s `xgetdents` for the first as
agnos-bound dir-code hygiene. Post-1.0.4 cleanup, tracked with the
other post-upgrade items in the CHANGELOG's 1.0.4 section (`cyrius
fmt --check`, the unused `fs` / `slice` deps, the `bayan` `cyml_*`
deprecation shims).

The agnos syscall peers followed the same arc: `sys_symlink`#63
landed in the 6.4.x stdlib (consumed at 1.0.3) and
`sys_readlink`#70 in 6.5.x (consumed at 1.0.4). hapi declares no
syscall numbers of its own on any target as of 1.0.4. Still
absent on agnos and not needed: `lstat` (readlink no-follows the
final component) and `getcwd` (`_fsl_getcwd` returns `"."`).

`HAPI_ALLOWED_ROOTS` is the grant for non-`$HOME` roots. It was to be
replaced by "the kavach capability service"; the 2026-08-25 audit
established there is no such service, and the symlink-aware resolution
it was meant to bring became hapi's own: per component from 1.0.8
(F-002 / F-015), and on the resolved root for `--root` itself from
1.1.1 (F-051). `cap_check_root_r(path) -> Result` is frozen.

## Consumers

_None yet._ hapi is end-user-facing; "consumers" in this context
means downstream packagers (zugot recipes) and user manifests.

## Examples shipped

- `docs/examples/dotfiles-zsh/` — 3-file package used across
  the M1 / M2 / M3 acceptance tests.

## Next

The 2026-10-28 P(-1) pass is **closed** in 1.1.1. Its 1.2.0 addendum
(the argument surface under cmdit) closed with F-060 fixed, its 1.3.0
addendum (`sync`'s scan and prune) with F-061 fixed, its 1.4.0
addendum (`created_dir`) with F-062 caught before release, its 1.5.0
addendum (the script-facing flags) with no defect and F-063 accepted, and
its 1.6.0 addendum (`--absolute`) and 1.7.0 addendum (`hapi fmt`), each
with no defect.
Every finding is fixed except two that are accepted: F-059, an agnos
kernel gap
([`issues/2026-10-28-adopt-on-agnos-kernel.md`](issues/2026-10-28-adopt-on-agnos-kernel.md)),
and F-063, a boundary of concurrent use.
Two upstream follow-ups came out of it, both filed upstream on
2026-10-28: mirshi's divergences from the kernel (its roadmap, § *Open
defects — kernel fidelity*) and agnos ext2's missing
rename-over-existing (an agnos issue file). [`roadmap.md`](roadmap.md)
§ *Upstream pendings* has the paths.

Forward-looking work is **not** listed here — it lives in
[`roadmap.md`](roadmap.md), which carries only work that has not
shipped. **Every planned 1.x minor has shipped**; what remains is
upstream-gated work, which lands in the next minor when its gate opens,
and the v2.0 bucket. Open dogfood papercuts are in [`issues/`](issues/) (2
open, 9 archived).
