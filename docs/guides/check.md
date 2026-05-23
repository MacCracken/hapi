# `hapi check`

Parse a package manifest and print the parsed interpretation,
the same way `hapi inspect` does — with an opt-in `--strict`
mode that rejects unknown `[section]` headers and unknown keys
within the known sections. The strict mode is the CI / lint
surface; the default parser is lenient on purpose (ADR 0001
leaves schema headroom for additive growth).

## Synopsis

```sh
hapi check <package-dir|hapi.cyml> [--strict]
```

## What it does

1. Resolves the package directory (or accepts a direct
   `*.cyml` path).
2. Parses the manifest.
   - **lenient** (default): unknown sections / keys are
     silently dropped. Forward-compatible with future schema
     growth.
   - **strict** (`--strict`): the first unknown section
     (anything other than `[package]` or `[[link]]`) or
     unknown key inside a known section (e.g. `[package].author`,
     `[[link]].mode`) becomes a hard error.
3. Prints the parsed manifest.
4. Appends `ok` (or `ok (strict)`).

## Example: lenient vs strict

Given a manifest with a typo:

```toml
[package]
name = "dotfiles-zsh"
version = "1.0.0"
authr = "me"        # typo for `author` — neither is known

[[link]]
source = "zshrc"
target = ".zshrc"
```

```sh
$ hapi check ./dotfiles-zsh
package:     dotfiles-zsh
version:     1.0.0
links (1):
  zshrc  -> .zshrc
ignore (0):
  (none)
ok

$ hapi check ./dotfiles-zsh --strict
hapi: manifest has an unknown key in a known section (strict mode) (./dotfiles-zsh/hapi.cyml)
```

The lenient run misses the typo. Strict mode catches it. Run
strict in CI; ship lenient at runtime so a future additive
manifest field (per ADR 0001's growth contract) doesn't break
an older hapi binary mid-deployment.

## What strict rejects

- Any `[section]` other than `[package]`.
- Any `[[section]]` other than `[[link]]`.
- Any key in `[package]` other than `name`, `version`,
  `description`, `ignore`.
- Any key in `[[link]]` other than `source`, `target`.

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | parsed cleanly                                                |
| 1    | parse error (including strict-mode rejection)                 |
| 2    | bad usage (no path argument)                                  |

## See also

- [`inspect.md`](inspect.md) — the lenient-only sibling.
- [ADR 0001 — Manifest schema](../adr/0001-hapi-cyml-manifest-schema.md) — what
  the v1.0 schema freezes and where additive growth is permitted.
