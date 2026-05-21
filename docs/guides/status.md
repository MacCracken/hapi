# `hapi status`

Show the drift between a package manifest and the on-disk
symlink state. Read-only: no audit writes, no filesystem
mutation.

## Synopsis

```sh
hapi status <package-dir|hapi.cyml>
```

## What it does

1. Resolves the package directory (or accepts a direct
   `*.cyml` path).
2. Parses the manifest.
3. For each `[[link]]` row: computes the expected absolute
   target and relative symlink value, then probes the
   filesystem state at the target and classifies it.

| classification | meaning                                                |
|----------------|--------------------------------------------------------|
| `OK`           | symlink points where `hapi link` would write           |
| `MISSING`      | no file at the target                                  |
| `WRONG`        | symlink points elsewhere                               |
| `FILE`         | a regular file lives at the target                     |
| `DIR`          | a directory lives at the target                        |
| `ERROR`        | probe failed (permission, etc.)                        |

## Example: clean state

```sh
$ hapi link docs/examples/dotfiles-zsh
linked 3 / 3 (0 already up-to-date)

$ hapi status docs/examples/dotfiles-zsh
  OK       ~/.zshrc
  OK       ~/.zshenv
  OK       ~/.config/zsh
status 3 / 3 OK
```

## Example: drift after user mutation

```sh
$ rm ~/.zshrc
$ ln -sf /tmp/elsewhere ~/.zshenv

$ hapi status docs/examples/dotfiles-zsh
  MISSING  ~/.zshrc
  WRONG    ~/.zshenv  (-> /tmp/elsewhere; expected -> ../...)
  OK       ~/.config/zsh
status 1 / 3 OK (2 drift)
```

Exit code 1 communicates drift; the next call should be
`hapi sync` (to re-create the missing) or manual investigation
(if the user-mutated symlink reflects intent).

## Exit codes

| code | meaning                                                       |
|------|---------------------------------------------------------------|
| 0    | every row classified `OK`                                     |
| 1    | one or more rows drifted, or manifest parse failed            |
| 2    | bad usage (no path argument)                                  |

## See also

- [`sync.md`](sync.md) — re-apply a manifest to restore drifted
  state.
- [`link.md`](link.md) — what `OK` actually means.
