# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
