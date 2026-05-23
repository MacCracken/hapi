# `hapi adopt`

Move an existing file into a package, create the symlink back,
and append the matching `[[link]]` row to the package manifest.
A single atomic step that closes the loop between an
already-existing dotfile and a fresh hapi package.

## Synopsis

```sh
hapi adopt <file-in-scope-root> <package-dir>
```

Both arguments are positional. Shape mirrors `mv(1)` (`mv src
dst`). The file argument resolves relative to the scope root
(`$HOME` by default); the package argument resolves relative to
cwd.

## What it does

1. Resolves `<file>` to an absolute path under the scope root.
2. Probes the target — refuses unless it's a regular file
   (not a symlink, not a directory, not absent).
3. Parses the package's `hapi.cyml` — refuses if there's
   already a `[[link]]` row claiming the same source or target.
4. Refuses if the derived in-package source path is already
   occupied by a non-manifest file.
5. Renames the file into the package directory (`mv`).
6. Creates a relative symlink at the original location
   pointing to the moved file.
7. Appends a `[[link]]` row to the manifest (atomic via
   `tmp+rename`).
8. Writes a single `op:adopt` entry to the audit trail.

Per [ADR 0004](../adr/0004-adopt-op-semantics.md), the source
name inside the package is the target's basename with one
leading `.` stripped — `~/.zshrc` lands at
`<package>/zshrc`, manifest gets `source = "zshrc", target = ".zshrc"`.

## Example

```sh
$ ls ~/                 # an existing dotfile
.zshrc

$ ls dotfiles-zsh/      # an empty package
hapi.cyml

$ hapi adopt .zshrc dotfiles-zsh
  ~ /home/user/.zshrc -> ../dotfiles/dotfiles-zsh/zshrc
adopted into /home/user/dotfiles/dotfiles-zsh/hapi.cyml

$ ls -la ~/.zshrc       # now a symlink
lrwxrwxrwx ... .zshrc -> ../dotfiles/dotfiles-zsh/zshrc

$ ls dotfiles-zsh/      # file landed in the package
hapi.cyml  zshrc

$ cat dotfiles-zsh/hapi.cyml
[package]
name = "dotfiles-zsh"
version = "0.1.0"

[[link]]
source = "zshrc"
target = ".zshrc"
```

A subsequent `hapi link dotfiles-zsh` on a fresh machine will
recreate the symlink from the manifest — the adopt closes the
loop.

## Refusal cases

| target state                       | result                                       |
|------------------------------------|----------------------------------------------|
| regular file                       | adopted                                      |
| symlink (any target)               | refused — `hapi unlink <pkg>` first if hapi created it |
| directory                          | refused — adopt is file-scoped at v1.0       |
| absent                             | refused                                      |
| source name occupied in package    | refused — would clobber                      |
| target already in manifest         | refused — duplicate row                      |
| source already in manifest         | refused — duplicate row                      |

Every refusal is non-destructive: the target file (or whatever
is at the target path) is untouched on refusal.

## Preserving the original bytes — `--backup-to`

Adopt's intrinsic safety net is that the original file becomes
the package source — the bytes are still there, just at a new
path. For belt-and-suspenders coverage (e.g. a snapshot outside
the package tree, immune to a subsequent manifest edit), pair
adopt with `--backup-to <dir>`:

```sh
hapi adopt --backup-to ~/.local/share/hapi/backups .zshrc dotfiles-zsh
```

The flag copies the file to a timestamped path under `<dir>`
*before* the rename and stamps the audit entry with a
`backup_path` field. See [`backup-to.md`](backup-to.md) for the
full semantics.

## Rollback

`hapi rollback` over an `op:adopt` entry is a three-step
conditional reversal:

1. Remove the symlink (only if it still points where adopt put it)
2. Move the file back to its original location
3. Remove the matching `[[link]]` row from the manifest

All three preconditions are checked up front; either all three
apply or the reversal is skipped. See
[`rollback.md`](rollback.md) for the full conditional-reversal
semantics.

## Exit codes

| code | meaning                                                          |
|------|------------------------------------------------------------------|
| 0    | adopted cleanly                                                  |
| 1    | refused (probe / duplicate / source-clobber) or IO error         |
| 2    | bad usage (missing argument)                                     |

## See also

- [ADR 0004 — Adopt op semantics](../adr/0004-adopt-op-semantics.md)
- [`link.md`](link.md), [`unlink.md`](unlink.md), [`rollback.md`](rollback.md)
