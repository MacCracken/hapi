# 0003 — Symlink target shape (relative vs absolute)

**Status**: Accepted — **Frozen at v1.0.0 (2026-05-23)**
**Date**: 2026-05-20

> Frozen: `hapi link` writes relative symlinks from the link's
> parent directory to the source. A post-v1.0 `--absolute`
> opt-in is reserved per the roadmap's *Out of scope* list but
> the default shape is contractual.

## Context

When `hapi link <pkg>` creates a symlink, the value written into
the link itself can be either:

- **Relative** — `~/.zshrc` → `dotfiles/dotfiles-zsh/zshrc`
  (resolved from `~`'s parent at follow time)
- **Absolute** — `~/.zshrc` → `/home/user/dotfiles/dotfiles-zsh/zshrc`

Both produce a functioning symlink in the common case where the
user doesn't move anything. The choice surfaces when something
moves — the package directory, the user's home, or the user
themselves between machines.

Constraints:

- The manifest's `source` is always relative to the package
  directory (locked in ADR 0001). The link-shape decision is
  about the *on-disk symlink value*, not the manifest field.
- Hapi targets dotfile workflows. Dotfile repos commonly live
  in `~/dotfiles/`, `~/.dotfiles/`, `~/src/dotfiles/`, or under
  a per-machine path. Users clone the same repo at different
  paths on different machines.
- GNU stow uses relative links. Users coming from stow have
  a built-in expectation.
- The audit trail (ADR 0002) records both `target` (relative to
  scoped root) and `abs_target` (resolved absolute path) — so
  whatever the on-disk shape, the trail is unambiguous either
  way.

## Decision

hapi writes **relative symlinks**. The relative path is computed
as the shortest path from the link's parent directory to the
absolute source file.

For the canonical example with the package at
`/home/user/dotfiles/dotfiles-zsh/` and target `~/.zshrc`:

```
/home/user/.zshrc → dotfiles/dotfiles-zsh/zshrc
```

For a target nested deeper, e.g. `.config/zsh`:

```
/home/user/.config/zsh → ../dotfiles/dotfiles-zsh/config/zsh
```

The computation:

1. Resolve absolute source path: `<abs(pkg_dir)>/<source>`.
2. Resolve absolute target parent: `<abs(scope_root)>/<dirname(target)>`.
3. Compute the relative path from (2) to (1) by stripping the
   longest common prefix and prepending `..` segments for the
   remaining components in the parent.

The `..` segments produced *during link creation* are not the
`..` segments rejected at *manifest parse time* (ADR 0001).
The parse-time rejection guards user-supplied paths from
escaping the package or the scoped root. Computed relative
links are guaranteed to stay inside the user's filesystem by
construction — the source is already validated to be inside the
package, the target inside the scoped root.

## Consequences

**Positive**:

- The dotfile repo is **portable across machines and clone
  paths**. `git clone <repo> ~/work/dotfiles && hapi link
  dotfiles-zsh` works the same as `git clone <repo>
  ~/dotfiles && hapi link dotfiles-zsh` — the relative link
  resolves correctly from `~`'s parent in both cases.
- Matches the GNU stow convention, so the muscle memory
  transfers.
- The trail records both shapes (`target` = manifest-relative,
  `abs_target` = host-resolved), so rollback / status / audit
  review aren't affected by the on-disk choice.
- Smaller bytes-on-disk. Not load-bearing, but a 50-character
  abs path becomes a 30-character relative one on a typical
  dotfile setup.

**Negative**:

- The link breaks if the package directory itself moves
  *without* a corresponding move of the link's parent. That's
  a "user reorganized one half of the system without the
  other" scenario; `hapi status` (M5) will surface it. The
  alternative (absolute) breaks in the symmetric case
  (package moves, link still points to the old absolute
  location, equally broken).
- The relative-path computation adds parser complexity. Bounded
  — it's path-component split + common-prefix strip + `..`
  prepend — but it's code we own that absolute didn't require.
- Cross-filesystem links (`~` and the package on different
  mounts that happen to share a prefix) work either way, but
  the relative path can be long if the common prefix is high
  up the tree.

**Neutral**:

- The relative shape forces hapi to track the package
  directory's absolute path at link time anyway (we need it to
  compute the relative path). So absolute would have been
  *less* work, but only marginally — the rest of the M2
  pipeline needs absolutes for the audit trail's `abs_source`
  / `abs_target` regardless.

## Alternatives considered

- **Absolute symlinks** — rejected. Loses dotfile-repo
  portability across machines and clone paths, which is the
  most common hapi use case. Doesn't gain audit unambiguity
  (the trail records absolutes alongside relatives either way).
  Marginally simpler to compute but the simplification doesn't
  pay back the portability loss.
- **User-selected per-manifest** (a `link_style = "absolute"`
  knob in `hapi.cyml`) — rejected. Adds a v1.0 schema knob
  whose payoff is "the rare user who wants absolutes." The
  rare user can be served by a global `--absolute` flag at the
  CLI later (post-v1.0), without baking the choice into every
  manifest.
- **Hybrid** (relative when the package lives under `$HOME`,
  absolute otherwise) — rejected. The rule is hard to predict
  from the user's perspective; the audit trail becomes
  shape-mixed. Both bad properties.
- **Use the manifest's `source` value verbatim as the link
  target** — rejected. The manifest's source is relative to the
  *package directory*, not the *link's parent directory*. They
  match only when the link's parent is the package directory,
  which it almost never is.
