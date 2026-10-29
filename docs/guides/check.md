# `hapi check`

Parse a package manifest and print the parsed interpretation,
the same way `hapi inspect` does — with an opt-in `--strict`
mode that rejects unknown `[section]` headers, unknown keys
within the known sections, and since 1.7.1 anything else the
lenient parser skips other than a comment. The strict mode is the CI / lint
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
     `[[link]].mode`) becomes a hard error. Since 1.7.1 so does
     anything else the lenient parser skips, comments aside; every
     such line is listed (below, F-107).
3. Prints the parsed manifest.
4. **Walks the package directory** and reports where the manifest and
   the package have diverged, in both directions:
   - a `[[link]]` row whose `source` is missing from the package;
   - a file in the package that **no row claims** — the signature of an
     `adopt` interrupted between the rename and the manifest write.
   Staging leftovers (`hapi.cyml.<pid>.tmp`) are not orphans, but each
   one is named on a `note:` line: it refuses every later manifest write
   by a process that draws the same pid, so delete it once no hapi is
   running. Since 1.7.1 only that exact shape counts, the manifest's
   name, a dot, digits and `.tmp`. Through 1.7.0 any `*.tmp` did, so a
   package's own `notes.tmp` was hidden from the orphan check (F-095).
   A `*.cyml` file beside the manifest is not an orphan either, so
   checking a named manifest (`pkg/zsh.cyml`) no longer reports itself,
   and a row source spelled `./x` claims `x`. A row source that runs through a regular file (`f/sub`) is
   reported as missing, matching `link` (1.1.1). Any divergence exits 1,
   and so does a package directory that cannot be listed (1.1.1 —
   through 1.1.0 a mode-0311 directory checked clean with an orphan in
   it).
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

The lenient run misses the typo. Strict mode catches it.

Since 1.7.1, strict also fails on the lines the lenient parser skips
without a word, which `hapi fmt` would then drop, and lists each one.
For a manifest that sets `version` twice and has a word after `name`'s
closing quote:

```sh
$ hapi check ./dotfiles-zsh --strict
hapi: the manifest has what the parser skips (strict mode):
  line 4: the earlier `version`, set again here
  line 5: text after the value of `name`
```

Run
strict in CI; ship lenient at runtime so a future additive
manifest field (per ADR 0001's growth contract) doesn't break
an older hapi binary mid-deployment.

## What strict rejects

- Any `[section]` other than `[package]`.
- Any `[[section]]` other than `[[link]]`.
- Any key in `[package]` other than `name`, `version`,
  `description`, `ignore`.
- Any key in `[[link]]` other than `source`, `target`.
- Since 1.7.1 (F-107), each of these, listed by line: a UTF-8
  byte-order mark, a key before any section, a key set again, a line
  that is not `key = value`, text after a value, a value that is not a
  double-quoted string, and a non-string element in an array. A comment
  is not reported.

## Errors in either mode

Since 1.7.1 these fail the parse for every verb, not only `check`:

- **A value with no closing quote** — `a value has no closing quote`
  (F-074). It was read to the end of the header, so a manifest cut
  mid-row parsed with a truncated target.
- **A control character in a name, version, source, target or ignore
  pattern** — `a value holds a control character (a NUL, a newline, an
  escape)` (F-092). A `description` may still hold a tab, a newline or a
  carriage return.
- **A manifest that changed while it was read** — `the manifest changed
  while it was read; rerun` (F-073).

A UTF-8 byte-order mark at the start of the file is skipped (1.7.1,
F-107). Through 1.7.0 it was read as part of the first line, so a
manifest saved by an editor that writes one failed with
`[package].name is missing or empty`.

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | parsed cleanly **and** the manifest matches the package        |
| 1    | parse error (including strict-mode rejection), or a divergence between the manifest and the package |
| 2    | bad usage (no path argument, or an empty one)                 |

## See also

- [`inspect.md`](inspect.md) — the lenient-only sibling.
- [ADR 0001 — Manifest schema](../adr/0001-hapi-cyml-manifest-schema.md) — what
  the v1.0 schema freezes and where additive growth is permitted.
