# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
