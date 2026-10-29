# `hapi fmt`

Rewrite a manifest's header in its canonical form: the same bytes hapi
hashes for the audit trail. Formatting never changes what the manifest
means, so it never changes its hash. Since 1.7.0.

## Synopsis

```sh
hapi fmt <package-dir|hapi.cyml>              # rewrite the header
hapi fmt <package-dir|hapi.cyml> --check      # exit 1 if it is not formatted
hapi fmt <package-dir|hapi.cyml> --dry-run    # print what it would write
hapi fmt <package-dir|hapi.cyml> --force      # drop what the form cannot hold
```

## What it writes

The header becomes exactly `hapi_mf_canonicalize`'s bytes, the preimage of
the trail's `sha1c:` manifest hash
([ADR 0002](../adr/0002-audit-trail-format.md)):

- `[package]` first, its fields in a fixed order: `name`, `version`, then
  `description` and `ignore` when present;
- one `[[link]]` row per target, **sorted by target**, `source` before
  `target`;
- `key = "value"` with single spaces, one blank line between sections, a
  final newline, and nothing else.

Everything from the `---` body delimiter on is kept **byte for byte**,
after one blank line. A manifest without a body becomes exactly the
canonical bytes. A CR LF manifest keeps CR LF.

```sh
$ cat dots/zsh/hapi.cyml
[package]
version="1.0.0"
name =   "zsh"

[[link]]
target=".zshrc"
source="zshrc"
[[link]]
source = "zshenv"
target = ".zshenv"

---
# zsh
Notes that fmt never touches.

$ hapi fmt dots/zsh
formatted /home/me/dots/zsh/hapi.cyml

$ cat dots/zsh/hapi.cyml
[package]
name = "zsh"
version = "1.0.0"

[[link]]
source = "zshenv"
target = ".zshenv"

[[link]]
source = "zshrc"
target = ".zshrc"

---
# zsh
Notes that fmt never touches.
```

A second run says `already formatted` and writes nothing.

## What it refuses to drop

The canonical form has no place for some things a header can hold. `fmt`
names each, with its line, and refuses; nothing is written:

```sh
$ cat dots/zsh/hapi.cyml
# my zsh
[package]
name = "zsh"
version = "1"

[[link]]
source = "a"
target = ".a"
mode = "copy"

$ hapi fmt dots/zsh
hapi: formatting /home/me/dots/zsh/hapi.cyml would drop what its canonical form has no place for:
  line 1: a comment
  line 9: unknown key `mode` in a [[link]] row
  (rerun with --force to drop them; nothing was changed)
```

The list comes from the parser itself, which records everything it skips:

- comments, on their own line or after a value;
- unknown sections and keys, and keys before any section;
- a key given twice, of which only the last counts;
- text after a value or a section header;
- a value that is not a double-quoted string;
- a non-string element in an array;
- since 1.7.1, a UTF-8 byte-order mark at the start of the file, which
  the parser now skips (F-107).

Since 1.7.1 [`check --strict`](check.md) fails on each of these but
comments, so CI can catch what `fmt` would drop.

None of these change what hapi reads from the manifest, which is why the
hash ignores them, but they are yours. `--force` drops them, listing each
as `(dropped)`. Keep notes in the body below `---`, which `fmt` never
touches.

**Refused even with `--force`:** a value holding a backslash. hapi's
parser keeps a `\` as written, and the canonical form escapes it again,
so formatting would change the value and its hash (ADR 0001 has no
un-escape; that is a v2.0 change). Also refused, as by every write: a
manifest that does not parse, and a `hapi.cyml` that is a symlink, which
the rewrite would replace with a private copy. Since 1.7.1 so is a
manifest with other hard links, which a rewrite would leave holding the
old text: `hapi.cyml has other hard links; a rewrite would leave them
with the old text` (F-105). The rewrite keeps the manifest's permission
bits (through 1.7.0 it came back `0644`) and fails if its fsync fails.

Before writing, `fmt` proves its result: the header it would write must
parse back to the same canonical bytes. A header that would not (for
example a value spanning lines in a CR LF file) is refused.

## `--check` and `--dry-run`

- `--check` writes nothing and answers in the exit code: 0 when the
  manifest is formatted, 1 when it is not. It is for CI and pre-commit
  hooks:

  ```sh
  for p in ~/Repos/dotfiles/*/; do hapi fmt --check "$p" || exit 1; done
  ```

- `--dry-run` prints the header it would write and
  `would format <path>  (dry-run)`, and exits as the real run would: 1
  where the real run would refuse.

## Concurrency

`fmt` holds the package-directory lock from its read to its rename, as
`adopt` does. An `adopt` that runs at the same moment waits, and its row
is never lost. `scripts/concurrency-test.sh` races sixteen adopts against
four `fmt` loops on one package to hold this.

## The audit trail

`fmt` writes no trail entry. It moves no link, and the manifest hash it
leaves is the one already recorded, so nothing a trail reader consults
changes.

## Exit codes

| code | meaning |
|---|---|
| 0 | formatted, or already formatted (`--check`: formatted) |
| 1 | `--check`: not formatted; or a refusal: content to drop without `--force`, a backslash, a manifest that does not parse, a symlinked or hard-linked manifest, an IO failure |
| 2 | bad usage: no package, an empty argument, an extra argument, an unknown flag |

## See also

- [ADR 0008](../adr/0008-hapi-fmt.md) — why fmt writes exactly the
  canonical bytes, what it refuses, and what was weighed instead.
- [ADR 0001](../adr/0001-hapi-cyml-manifest-schema.md) — the manifest
  schema, and the `---` rule.
- [`check.md`](check.md) — validate a manifest, `--strict` for unknown
  keys.
