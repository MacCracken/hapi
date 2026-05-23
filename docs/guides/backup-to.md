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
| `hapi sync`       | ✓           | same (sync is a link wrapper)                  |
| `hapi adopt`      | ✓           | the file about to be moved into the package   |
| every other verb  | —           | exit 2 if passed                              |

Verbs that don't accept `--backup-to` reject it with exit 2.

## What it does

1. Compose the backup destination: `<dir>/<YYYYMMDD-HHMMSS>-<pkg>-<basename>`.
2. `mkdir -p` the directory, then byte-copy the original file there.
3. Proceed with the existing `--force` / `adopt` steps (unlink, symlink,
   audit).
4. Stamp the audit entry with `"backup_path":"<dest>"`.

Symlink conflicts are skipped: a symlink points at content elsewhere,
so there's nothing to preserve. Only regular-file conflicts trigger
the snapshot.

Under `--dry-run`, the would-be destination is printed but no
snapshot is written and the audit trail does not grow.

## Filename shape

`<YYYYMMDD-HHMMSS>-<pkg>-<basename>` — for example:

```
20260523-153042-hyprland-hyprland.conf
```

- `<YYYYMMDD-HHMMSS>` — local-clock timestamp at snapshot time.
- `<pkg>` — `package.name` from the manifest. Disambiguates
  concurrent backups when multiple packages overwrite files
  in one session.
- `<basename>` — final path component of the original file.
  Keeps the snapshot recognizable when you `ls` the backup dir.

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

## Example: shell-wide default via env var

`--backup-to` does not consult any env var directly. To make the
flag default-on for a session, set a shell alias:

```sh
alias hapi='hapi --backup-to=$HOME/.local/share/hapi/backups'
```

(Note: hapi's CLI parses `--backup-to <dir>` as two tokens, not
`=`-joined. The alias works because the shell expands the `=` form
into two tokens before invoking the binary. Aliases are session-local
on purpose — making this implicit at the binary level would hide
that backups exist.)

## When to use it

Reach for `--backup-to` when:

- **First-time package adoption** — the merge step that produces
  the repo-side file could miss a section of the user's authored
  content; the backup is your undo.
- **Upstream-drift cycles** — adopting a newer stock-config
  template (see [`upstream-drift.md`](upstream-drift.md)); the
  backup captures the on-disk fresh-install copy you're about to
  replace.
- **Bulk `sync` runs** — many `--force` overwrites at once; one
  flag covers all of them.

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
adopt entry is fully forward- and backward-compatible. Readers from
v0.7.0 (before `--backup-to` shipped) parse the entry cleanly and
ignore the new field.

## See also

- [`link.md`](link.md) — `--force` semantics that drive the snapshot.
- [`adopt.md`](adopt.md) — the other entry point for the snapshot.
- [`dry-run.md`](dry-run.md) — composes with `--backup-to`.
- [`upstream-drift.md`](upstream-drift.md) — the workflow that
  motivated this flag.
