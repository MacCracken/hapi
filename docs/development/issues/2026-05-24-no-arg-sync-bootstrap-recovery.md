# No-arg `hapi sync` — bootstrap/recovery needs one command, not a loop

**Discovered:** 2026-05-24 during a drive-move / system-restart dotfile recovery
**Severity:** Low — ergonomic; a known post-v1.0 roadmap item, now with dogfood pressure
**Affects:** hapi 1.0.0 — `hapi sync` requires a `<package-dir|hapi.cyml>` argument; there is no no-arg form that syncs every tracked package.

## Summary

Recovering a full dotfile set after a drive move is the canonical
"sync everything" moment, and it's exactly the moment hapi makes
the user write a shell loop. `hapi sync` is per-package by design
at v1.0; re-establishing 11 packages meant
`for p in ...; do hapi sync ~/Repos/dotfiles/$p; done`. It worked
(9 no-ops, git created `.gitconfig`, zsh refused `.zshrc` until a
`--force`), but the ergonomics invert the principle: the
disaster-recovery path should be the *most* turnkey, and it's the
one that requires hand-assembling the package list.

## Reproduction

```sh
# What recovery actually looked like:
for p in git hypridle hyprland hyprlock hyprmocha hyprpaper \
         kitty starship waybar wofi zsh; do
  hapi sync ~/Repos/dotfiles/$p
done
# The package list is hand-maintained. Miss one and that package
# silently stays unlinked — no error, because hapi was never told
# it existed.

# What it should have been:
hapi sync            # discovers every tracked package, syncs all
```

## Root cause

Deferred from v1.0 by design — `cmd_sync` is a thin wrapper over
`cmd_link` and the no-arg dispatch was left as post-v1.0 additive
work (`src/cmd/sync.cyr`; see roadmap *Manifest discovery for
no-arg `hapi sync`*). The open design question is **how to
enumerate "every tracked package"** with no argument.

The roadmap names two mechanisms: (a) recover `pkg_dir` from a
live audit entry, or (b) a tree-walk heuristic. **Today's event
is direct evidence that (a) is the wrong primary mechanism.** The
drive move wiped the audit trail (see
[`2026-05-24-audit-trail-lost-on-state-dir-wipe.md`](2026-05-24-audit-trail-lost-on-state-dir-wipe.md)),
so a trail-driven `hapi sync` would have discovered **zero**
packages in precisely the scenario where no-arg sync is most
valuable — the empty-trail bootstrap. The mechanism that actually
worked was a root scan: `find ~/Repos/dotfiles -name hapi.cyml`.

## Proposed fix (deferred — post-v1.0 additive)

When no-arg sync is picked up, **prefer the root-scan mechanism
over trail-recovery**, or use trail-recovery only as an
augmentation with root-scan as the fallback when the trail is
empty:

- Resolve a packages-root (e.g. a `HAPI_PACKAGES_ROOT` env var,
  or a `--from <dir>` arg, defaulting to a configured dotfiles
  dir), scan one level for `*/hapi.cyml`, sync each.
- Trail-recovery may *supplement* this for packages outside the
  root, but must not be the sole source — it fails closed (zero
  packages) exactly at bootstrap, which is the opposite of what a
  recovery command should do.

Signature stays unchanged — no arg becomes legal — so this is
v1.x additive, not a contract change.

## Consumer-side workaround

The shell loop above is the stopgap; keep the package list in a
recovery script. A drop-in:

```sh
# re-establish all hapi-managed dotfile packages
for m in ~/Repos/dotfiles/*/hapi.cyml; do
  hapi sync "$(dirname "$m")"
done
# then resolve any conflicts the no-force sync refused, e.g. a
# freshly-regenerated ~/.zshrc stub:
#   hapi link --force --backup-to ~/.cache/hapi-relink-backup ~/Repos/dotfiles/zsh
```

The `*/hapi.cyml` glob *is* the root-scan the no-arg form should
internalize — it discovers packages from the repo layout, not
from a trail that a drive move can erase.

## Cross-references

- [`2026-05-24-audit-trail-lost-on-state-dir-wipe.md`](2026-05-24-audit-trail-lost-on-state-dir-wipe.md)
  — same recovery event; why trail-recovery is the wrong discovery
  mechanism for this command.
- [`../roadmap.md`](../roadmap.md) — *Manifest discovery for no-arg
  `hapi sync`* (this issue is the dogfood-pressure record + the
  root-scan design correction).
- [`../state.md`](../state.md) — `cmd_sync` shape + the post-v1.0
  per-package-discovery note.
