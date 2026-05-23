# 0001 — hapi.cyml manifest schema

**Status**: Accepted — **Frozen at v1.0.0 (2026-05-23)**
**Date**: 2026-05-20

> Per CLAUDE.md's CHANGELOG Format rule, manifest format changes
> are `Breaking` until v1.0; after v1.0 the schema is frozen.
> v1.0.0 ships the schema described here as the contract. Future
> additive growth is reserved for the *Out of scope (for v1.0)*
> items in [`docs/development/roadmap.md`](../development/roadmap.md)
> — none of which are scheduled for v1.x.

## Context

Every hapi package needs a machine-readable declaration of the
symlinks it owns. GNU stow infers link shape from directory layout —
the package directory's tree is mirrored under the target root. That
convention is brittle: hidden files behave inconsistently across stow
versions, dotfiles with the same name in two packages silently collide,
and the user has no single place to look up *what this package will
do* without reasoning about stow's algorithm.

hapi inverts that. A package is a directory containing a `hapi.cyml`
manifest plus the files the manifest references. The manifest is the
authoritative source of truth for what gets linked where. If a file
exists in the package directory but isn't in the manifest, it's not
linked — `ignore` becomes the default rather than a corner-case escape
hatch.

Constraints in play:

- We already ship a `lib/cyml.cyr` (TOML header + optional markdown
  body) and `lib/toml.cyr`. Reusing them keeps the M1 dep gate at
  "stdlib only" per the roadmap.
- Other AGNOS first-party tools (cyrius itself, iam, commandress)
  use `cyrius.cyml` with a pure-TOML header — the muscle memory is
  already there.
- Manifest format changes are `Breaking` until v1.0; after v1.0
  the schema is frozen. So we want the v1.0 shape settled now, with
  room reserved for additive growth.
- Every operation in hapi is auditable. The manifest is the input
  to that audit trail; its hash is part of every audit entry per the
  v1.0 contract. The schema needs to be canonicalizable enough that
  "same logical manifest" hashes the same way across formattings —
  which is a *future* concern (M3 lands the audit trail), but not
  something we want to design ourselves into a corner on.

## Decision

The `hapi.cyml` manifest is a single-entry CYML file: TOML header,
optional markdown body. One `[package]` table for metadata, one
or more `[[link]]` rows for the symlinks themselves:

```toml
[package]
name = "dotfiles-zsh"
version = "1.0.0"
description = "zsh configuration files"   # optional
ignore = ["*.bak", ".DS_Store", "*.swp"]  # optional

[[link]]
source = "zshrc"
target = ".zshrc"

[[link]]
source = "zshenv"
target = ".zshenv"

[[link]]
source = "config/zsh"
target = ".config/zsh"

---

# Optional markdown body
Free-form package description, README-style. hapi does not parse the
body; it's preserved for human readers and for downstream tooling.
```

Field semantics:

- **`package.name`** — required. The package identifier used by every
  subcommand (`hapi link <name>`, etc.). Must match the directory
  name containing the manifest (validation deferred to M2).
- **`package.version`** — required. Free-form string; semver-ish
  recommended but not enforced. Used by the audit trail to track
  which version of a package produced a given link.
- **`package.description`** — optional. One-line human description.
- **`[[link]]` rows** — zero or more. Each row has:
  - `source` — path relative to the package directory. May refer to
    a file or a directory. Required.
  - `target` — path relative to the scoped root (`$HOME` by
    default). Required.
- **`package.ignore`** — optional array of glob patterns. Files
  matching any pattern are excluded from any `[[link]]` row that
  targets a directory. Globs apply to the *source* side only; we
  never filter by target name. Pattern syntax matches POSIX
  fnmatch(3) (`*`, `?`, `[abc]`) — no recursive `**`, no brace
  expansion. Kept deliberately small for v1.0. Lives inside
  `[package]` (not at the file-top) because TOML semantics
  attach every key after a section header to that section —
  a top-level `ignore = [...]` placed after the `[[link]]` rows
  would silently land in the last link, not the package.

Validation enforced at parse time:

- Both `package.name` and `package.version` are present and non-empty.
- Every `[[link]]` row has both `source` and `target` non-empty.
- No two rows share the same `target`. (Two rows sharing the same
  `source` is allowed — it's a fan-out, even if a strange one.)
- No `target` contains `..` segments. Capability-bounded means
  capability-bounded — we don't walk outside the scoped root via
  the manifest.
- No `source` contains `..` segments either, by the same logic
  applied to the package directory.

Validation *not* enforced at parse time (deferred to M2 `link`):

- Whether `source` paths actually exist on disk.
- Whether `target` paths conflict with files already on disk.
- Whether the scoped root grants permission for the target.

The parser produces a static description of the manifest; M2 layers
the filesystem checks on top. This separation lets `hapi inspect`
run on any well-formed manifest without touching the target root
at all — useful for CI, for distro packagers, and for read-only
manifest review.

### Scope — what's in, what's out

In for v1.0:

- The five fields above (`name`, `version`, `description`,
  `link` rows, `ignore` list).
- One manifest per package directory. No multi-package files, no
  workspace manifests.
- POSIX fnmatch globs in `ignore`.

Out for v1.0 (track for v2.0 or later):

- **Conditional links** — no `if` predicates, no per-host variants,
  no template engine. A manifest is what it claims; users who need
  per-host variation write per-host packages.
- **Permissions / mode bits on the link** — symlinks ignore the
  link's own mode; the dereferenced target's mode is what counts.
  No reason to model it in the manifest.
- **Adopted-file metadata** — `adopt` (M4) writes audit-trail
  entries, not manifest entries. The manifest stays user-authored.
- **Dependencies between packages** — out of scope. hapi manages
  one package at a time; orchestration is the user's job (a shell
  loop, a Makefile, a higher-level meta-package tool).
- **Recursive `**` globs and brace expansion in `ignore`** — `*`
  and `?` cover the cases real dotfile packages actually need;
  `**` opens questions about cross-directory expansion that don't
  pay back the parser complexity at v1.0.

## Consequences

**Positive**:

- One file fully describes a package. No directory-layout reasoning,
  no hidden-file conventions, no surprises.
- Reuses `lib/toml.cyr` + `lib/cyml.cyr` — zero new dep surface
  for M1.
- `[[link]]` rows leave room to grow per-row attributes later
  (e.g., a future `mode = "copy"` for the rare case where a real
  copy beats a symlink) without a schema break, because TOML
  arrays-of-tables degrade gracefully when new optional keys land.
- The markdown body is a natural place for per-package documentation
  that travels with the package itself.
- Canonicalization is straightforward: the parsed manifest is a
  small, stable structure (name, version, sorted link rows by
  target, sorted ignore list); the audit-trail hash in M3 can
  hash the canonical form rather than the raw file bytes.

**Negative**:

- `[[link]]` rows are verbose for small packages. A
  `[link]` table with `source = "target"` would be one line per
  link, but it forces every `source` to be a valid TOML bare key
  (no slashes without quoting) and leaves no room for per-row
  attributes. We pay the verbosity for the structural headroom.
- We now own the canonicalization rules forever. Any future
  formatter (`hapi fmt`, if it exists) must produce byte-identical
  output for the same logical manifest, or audit-trail hashes
  break.

**Neutral**:

- Markdown body is free-form and unenforced at v1.0. Future
  tooling (`hapi readme <pkg>` or similar) could parse it; we
  reserve the body slot but don't commit to a structure.
- `description` is a nice-to-have, not load-bearing. If a future
  command surface wants richer metadata (license, maintainer URL,
  upstream link), it lands as additional `[package]` keys —
  additive, not breaking.

## Alternatives considered

- **Pure directory mirroring (the GNU stow model)** — rejected.
  The brittleness around hidden files and silent collisions is
  the *reason* hapi exists. Mirroring would make hapi a stow
  reimplementation in cyrius with no behavioral improvement.
- **`[link]` table with `source = "target"` rows** — rejected
  for the reason above: forces all sources through TOML bare-key
  rules (so `config/zsh` becomes `"config/zsh"` everywhere) and
  blocks per-row attributes without a schema break.
- **JSON manifest** — rejected. We already have TOML/CYML parsers
  in stdlib; JSON is human-hostile for hand-authored config; CYML's
  optional markdown body has no JSON equivalent.
- **YAML manifest** — rejected harder. Significant whitespace +
  the YAML 1.1 vs 1.2 mess is exactly the kind of foot-gun the
  audit-trail story can't tolerate.
- **Embedded shell-script manifest (a `manifest.sh` that emits a
  parseable line per link)** — rejected. Spawning processes from
  hapi violates the "no `exec_*` from command handlers" principle
  in CLAUDE.md.
- **Globs as a first-class link mechanism (`source = "*.zsh"`)** —
  deferred. Glob expansion at link time interacts badly with
  audit-trail hashing (the hash changes when the source directory
  contents change, even if the manifest didn't). `ignore` is glob;
  `link` is explicit. We may revisit for v2.0.
