# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
