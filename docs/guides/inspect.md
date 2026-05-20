# `hapi inspect`

Parse a package manifest and print the canonical interpretation of
what hapi would link. Read-only — `inspect` never touches the
scoped root.

## Synopsis

```sh
hapi inspect <package-dir>
hapi inspect <path-to-hapi.cyml>
```

The argument may be either the directory that contains a
`hapi.cyml` (the common case) or the manifest file itself. If the
path ends in `.cyml`, hapi reads it directly; otherwise hapi
appends `/hapi.cyml` to the path.

## Example

```sh
$ hapi inspect docs/examples/dotfiles-zsh
package:     dotfiles-zsh
version:     1.0.0
description: zsh configuration files

links (3):
  zshrc       -> .zshrc
  zshenv      -> .zshenv
  config/zsh  -> .config/zsh

ignore (3):
  *.bak
  .DS_Store
  *.swp
```

## What `inspect` does and doesn't check

`inspect` validates the manifest itself — schema fields, duplicate
targets, `..` path traversal — but it does **not** touch the
scoped root. Specifically:

- Source paths are not checked to exist. (`link` does that, M2.)
- Targets are not checked against the on-disk state. (`status`
  does that, M5.)
- No capability check is performed. (M6.)

That separation is intentional. `inspect` runs on any well-formed
manifest, in any working directory, with no filesystem side
effects — useful for CI, manifest review, and distro packaging.

## Exit codes

| code | meaning                                            |
|------|----------------------------------------------------|
| 0    | manifest parsed and printed                        |
| 1    | manifest could not be read or failed validation    |
| 2    | bad usage (missing argument)                       |

Validation errors print a one-line diagnostic to stderr naming the
offending field (e.g. `[[link]].target is missing or empty`).

## See also

- [ADR 0001 — hapi.cyml manifest schema](../adr/0001-hapi-cyml-manifest-schema.md)
  for the schema this command parses against.
- [`../examples/dotfiles-zsh/`](../examples/dotfiles-zsh/) — the
  canonical example used in the walkthrough above.
