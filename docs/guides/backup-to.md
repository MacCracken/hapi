# `--backup-to`

Opt-in pre-`--force` snapshot. When set, hapi copies the existing
on-disk file to a timestamped path under the chosen directory
**before** the destructive step that would otherwise wipe its bytes.
The audit-trail entry gains an additive `backup_path` field naming
the snapshot.

## Where it's accepted

| verb              | --backup-to | what it snapshots                              |
|-------------------|-------------|------------------------------------------------|
| `hapi link`       | ✓           | regular files removed by `--force` (not symlinks) |
| `hapi sync` | — | nothing: `sync` never overwrites (`sync --force` only lifts `--prune`'s limit), so there is no destructive step to snapshot |
| `hapi adopt`      | ✓           | the file about to be moved into the package   |
| every other verb  | —           | exit 2 if passed                              |

Verbs that don't accept `--backup-to` reject it with exit 2. So does an
empty value (1.7.1, F-098): `hapi: --backup-to needs a directory, not an
empty value`. Through 1.7.0 `--backup-to ''` was taken as the
directory `/`.

A relative `<dir>` is made absolute when the flag is read (1.7.1,
F-098), so the printed `(backup -> …)` and the recorded `backup_path`
name the snapshot wherever you later run `rollback` from. Through 1.7.0
`--backup-to bk` was printed and recorded as `bk/…`.

## What it does

1. Compose the backup destination: `<dir>/<YYYYMMDD-HHMMSS>-<pkg>-<basename>`.
2. `mkdir -p` the directory, then byte-copy the original file there.
   Since 1.7.1 the copy keeps the original's permission bits, so a
   `0600` secret stays `0600`; through 1.7.0 every snapshot was `0644`.
   It is fsynced before the destructive step. A copy that fails is
   removed, not left under a name that looks whole, and so is a
   snapshot whose `adopt` then fails (F-084).
3. Proceed with the existing `--force` / `adopt` steps (unlink, symlink,
   audit).
4. Stamp the audit entry with `"backup_path":"<dest>"`.

Symlink conflicts are skipped: a symlink points at content elsewhere,
so there's nothing to preserve. Only regular-file conflicts trigger
the snapshot. A FIFO, socket or device has no bytes to keep. The copy
refuses it without waiting on it, and the run stops before replacing it
(1.7.1, F-091).

The directory itself is refused, before anything changes (1.7.1,
F-084), when it:

- is in the package, where a snapshot of a secret would land in the
  package's working tree;
- is, or is beneath, a target the run would link (`link`);
- cannot be resolved (a file where a directory should be, or a loop).

Under `--dry-run`, the would-be destination is printed but no
snapshot is written and the audit trail does not grow. Since 1.7.1 a
`link --dry-run --force` that would need a snapshot fails, as the real
run would, when hapi could not create one in the directory: `hapi: the
--backup-to directory is not writable: <dir>  (dry-run)` (F-094).

## Filename shape

`<YYYYMMDD-HHMMSS>-<pkg>-<basename>[-N]` — for example:

```
20260523-153042-hyprland-hyprland.conf
```

- `<YYYYMMDD-HHMMSS>` — UTC timestamp at snapshot time (the trail's `ts`
  clock; hapi has no time-zone database).
- `<pkg>` — `package.name` from the manifest. Disambiguates
  concurrent backups when multiple packages overwrite files
  in one session.
- `<basename>` — final path component of the original file.
  Keeps the snapshot recognizable when you `ls` the backup dir. Since
  1.7.1 a long one loses its start, so the whole name fits the 255-byte
  `NAME_MAX` with room for a `-N` suffix. Through 1.7.0 a long basename
  made `--backup-to` refuse a file that plain `link --force` or `adopt`
  handled (F-110).
- `-N` — added when the name is taken, from `-2` up. Under `--dry-run`
  nothing is written, so since 1.7.1 a name the dry run already printed
  counts as taken too, and two same-named files show the two names the
  real run gives them (F-114). Through 1.7.0 the dry run showed both at
  one path.

## Example: `link --force` with a snapshot

```sh
# Plant a conflicting file with real content.
echo "user content" > ~/.gitconfig

# Apply with a snapshot dir.
hapi link --force --backup-to ~/.local/share/hapi/backups ~/dotfiles/git
#   + ~/.gitconfig -> ../dotfiles/git/gitconfig  (backup -> ~/.local/share/hapi/backups/20260523-153042-git-.gitconfig)
# linked 1 / 1 (0 already up-to-date)

# The original bytes are preserved.
cat ~/.local/share/hapi/backups/20260523-153042-git-.gitconfig
# user content

# Audit entry carries the backup_path field.
tail -1 ~/.local/state/hapi/audit.jsonl | grep -o '"backup_path":"[^"]*"'
# "backup_path":"/home/user/.local/share/hapi/backups/20260523-153042-git-.gitconfig"
```

## Example: a session-wide default

`--backup-to` does not consult any env var. To make it the default
for a session, wrap a verb that takes it in a shell function:

```sh
hapi-link() { hapi link --backup-to="$HOME/.local/share/hapi/backups" "$@"; }
```

A plain `alias hapi='hapi --backup-to=…'` does **not** work, in any
version: hapi accepts nothing before the verb, so the flag is read as
the command (`hapi: unknown command: --backup-to=…`, exit 2), and the
verbs that don't take `--backup-to` refuse it anyway. The `=` spelling
is accepted from 1.2.0; before that, write `--backup-to <dir>`. A value
starting with `-` is refused in either spelling — write `./-name`.
Wrappers are session-local on purpose: making this implicit at the
binary level would hide that backups exist.

## When to use it

Reach for `--backup-to` when:

- **First-time package adoption** — the merge step that produces
  the repo-side file could miss a section of the user's authored
  content; the backup is your undo.
- **Upstream-drift cycles** — adopting a newer stock-config
  template (see [`upstream-drift.md`](upstream-drift.md)); the
  backup captures the on-disk fresh-install copy you're about to
  replace.

It's redundant when:

- The conflict is a symlink (no file bytes to preserve — skipped
  automatically).
- The original file is also tracked in version control (git already
  holds the bytes; hapi's snapshot is duplicative).

## Combining flags

`--backup-to` composes with `--root`, `--dry-run`, and `--force`:

```sh
hapi link --root /etc/myproject --backup-to /var/backups/hapi --force --dry-run pkg
```

The cap-check fires first; if denied, no backup is written. Under
`--dry-run` the destination is printed but neither the backup file
nor the audit entry is created.

## Audit-trail growth

Per [ADR 0002](../adr/0002-audit-trail-format.md), readers tolerate
unknown additional fields, so a `backup_path` field on a link or
adopt entry is fully forward- and backward-compatible. Pre-v0.8.0
readers (before `--backup-to` shipped) parse the entry cleanly and
ignore the new field.

## See also

- [`link.md`](link.md) — `--force` semantics that drive the snapshot.
- [`adopt.md`](adopt.md) — the other entry point for the snapshot.
- [`dry-run.md`](dry-run.md) — composes with `--backup-to`.
- [`upstream-drift.md`](upstream-drift.md) — the workflow that
  motivated this flag.
