# `link --force` / adopt have no `--backup-to` flag; user must hand-roll `.pre-hapi.bak` snapshots

**Discovered:** 2026-05-20 during M7 dotfile dogfooding (every conflicting-file adoption)
**Severity:** Low — convenience feature absence; safety net is achievable manually
**Affects:** hapi 0.5.0 through 0.7.0 — every `link --force` over a regular file

## Summary

When `hapi link --force <pkg>` replaces an existing on-disk regular file with a symlink, the previous file content is `sys_unlink`-ed and gone. Per the v1.0 design contract, this is acceptable because:

1. The user invoked `--force` explicitly,
2. `hapi rollback` walks back to the pre-link state by recreating an `op:unlink` audit entry, and
3. The repo-side merged file (the new symlink target) is supposed to be the canonical replacement.

**But (1)** rollback recreates the *symlink*, not the original file content — the bytes that were at the path before `--force` ran are not preserved anywhere by hapi. The user's safety net is to take a backup BEFORE running `link --force`:

```sh
cp ~/.zshrc ~/.zshrc.pre-hapi.bak     # manual, every time, easy to forget
hapi link --force ~/dotfiles/zsh
```

During M7 dogfooding, every `--force` case landed alongside a manual `.pre-hapi.bak` snapshot (zsh, git, starship, hyprland — four packages, four hand-rolled backups). That's four chances to forget the safety step.

## Reproduction

```sh
# Plant a conflicting file
echo "user-authored content" > ~/.somerc

# link --force replaces it; the content is now only recoverable from
# the dotfile-repo merged version (assumes that merge actually
# preserved everything the original had, which is on the user)
hapi link --force ./somepackage

# The original ~/.somerc content is gone:
readlink ~/.somerc       # -> ../path/to/repo/file (no original)
[ -f ~/.somerc.pre-hapi.bak ] && echo present || echo absent
# > absent — the safety net only exists if the user remembered it
```

## Root cause

Design omission, not a bug. The `cmd_link` --force path in `src/cmd/link.cyr` calls `sys_unlink(abs_tgt)` before `link_create(...)` — there's no intermediate step that copies the file aside. The audit-trail entry records that hapi *did* the unlink, but does not record the file content (and shouldn't — the audit trail is metadata, not blob storage).

The omission is benign in the common case (user has the merged content already in the dotfile repo) but punishing in the worst case (user mid-adoption realizes the merge missed a section, and the original bytes are unrecoverable from hapi).

## Proposed fix

An opt-in `--backup-to <dir>` flag on `link` (and by extension `sync`, `adopt`):

```sh
hapi link --force --backup-to ~/.local/share/hapi/backups ~/dotfiles/zsh
# Behavior:
# 1. mkdir -p the backup dir
# 2. For each row where the apply phase would --force-remove a regular file:
#    cp $abs_target $backup_dir/$(date +%Y%m%d-%H%M%S)-$pkg-$(basename $abs_target)
#    (or use a hardlink for cheap snapshots if same filesystem)
# 3. Proceed with the existing --force unlink + create
```

Audit-trail addition (additive — fits ADR 0002's growth contract): a `backup_path` field on the link entry when `--backup-to` was used, so `hapi rollback` could optionally restore from the backup. Out of scope for the first cut; surface the path in the print line only.

Default: opt-in (no flag = today's behavior). The cost of `--force` is supposed to be visible.

Variant: a global config option `HAPI_BACKUP_DIR=...` env var that defaults the flag when set. Lets the user opt-in once per shell rather than per-invocation.

## Consumer-side workaround

The M7 dogfood ritual:

```sh
# Before any link --force that replaces a file:
cp <target-file> <target-file>.pre-hapi.bak

# After the session, audit and delete the backups:
ls ~/*.pre-hapi.bak ~/.config/*/*.pre-hapi.bak ~/.config/*/*/*.pre-hapi.bak
# delete once the fresh shell / re-login confirms the new files work
```

Mentioned in passing in every per-command guide that explains `link --force`. If `--backup-to` ever lands, those guide mentions get replaced with a one-line pointer to the flag.
