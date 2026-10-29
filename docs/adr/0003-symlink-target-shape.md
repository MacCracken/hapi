# 0003 — Symlink target shape (relative vs absolute)

**Status**: Accepted — **Frozen at v1.0.0 (2026-05-23)**
**Date**: 2026-05-20

> Frozen: `hapi link` writes relative symlinks from the link's
> parent directory to the source. A post-v1.0 `--absolute`
> opt-in is reserved per the roadmap's *Out of scope* list but
> the default shape is contractual. The opt-in shipped in 1.6.0;
> see the 1.6.0 addendum.

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

## Addendum — 2026-10-28 (1.1.1): "the link's parent directory" is where the link physically sits

**The decision stands: relative links, from the link's parent directory to
the source.** Step 2 of *The computation* above spelled the parent
lexically — `<abs(scope_root)>/<dirname(target)>` — and that is only the
link's parent when no component of it is a symlink. When one is, the kernel
resolves the link's text from the directory the link is actually in, and a
lexical text can name nothing: with `~/.config -> data/deep/config`, the row
`.config/rc` was written `../dotfiles/pkg/rc`, which dangles (F-046,
[`../audit/2026-10-28-audit.md`](../audit/2026-10-28-audit.md)). This ADR's
own claim — computed links are correct by construction — failed there.

From 1.1.1 step 2 resolves the parent through every symlink. The source in
step 1 stays as spelled, so a package reached through a symlink keeps
portable links, which is this ADR's rationale. For every target without a
symlinked parent the text is byte-identical to 1.1.0. `unlink` and
`rollback` also accept the lexical text, so links an older hapi planted
under a symlinked parent remain hapi's to remove.

## Addendum — 2026-10-28 (1.6.0): the `--absolute` opt-in

**The default stands: relative.** The opt-in this ADR reserved ships as a
flag on the verbs that create links, `link`, `adopt` and `sync`, as
*Alternatives considered* said it would: a CLI flag, not a manifest knob.

**The absolute text is the source's path as spelled**: the `abs_source`
the trail records, lexically normalized (`.` and empty segments dropped)
and never resolved. That is the same choice the relative text makes for
its source half (1.1.1 addendum), for the same reason: a package reached
through a symlink keeps the indirection. The absolute text is also the
one shape F-046 cannot reach, since it does not depend on the directory
the link sits in.

**Either shape is hapi's link, everywhere.** The shape is chosen when a
link is created and never enforced afterwards. A symlink naming the row's
source, by the relative text or the absolute one, is:

- up to date for `link` and `sync`, so the flag does not re-shape an
  existing link, and a plain `sync` leaves absolute links alone;
- `OK` for `status`, which therefore needs no flag and reads no trail
  (F-006 holds: `status` works with the trail gone);
- removable by `unlink`, `sync --prune` and `rollback`.

Only the exact bytes count: another file's path, or this one's spelled
differently, is not hapi's.

**What changed for existing links.** Before 1.6.0 an absolute symlink to a
row's source was drift to `status`, a conflict to `link`, and not hapi's to
`unlink`. If a user had swapped hapi's relative link for that absolute one,
it is now hapi's in every verb. It names the same file, and hapi cannot
tell it from one `link --absolute` wrote.

**The trail records the shape** as `"shape":"absolute"` (ADR 0002, 1.6.0
addendum). It goes on the entries that write an absolute link and on those
that remove one, so `rollback` re-creates a removed link in the shape it
had. Rollback takes no flag of its own.

**Older versions** know only the relative text. Before 1.6.0, on an
absolute link, `status` reports drift, `link` a conflict, and `unlink` and
`rollback` refuse with exit 1. That is safe, since nothing is removed, but
an absolute link can only be removed by 1.6.0 or later.

**Weighed and not taken:** making the shape part of the link, with
`status`, `link` and `sync` reading the trail to learn which shape to
expect. A plain `sync` would then keep a package absolute without the
flag. But `status` would depend on the trail, and after a trail loss it
would call every absolute link wrong.

## Addendum — 2026-10-29 (1.7.1): the physical parent, resolved correctly, and the text 1.1.1–1.7.0 wrote

The 1.1.1 addendum computes the text from the directory the link
physically sits in. The resolver behind it dropped the first byte of every
relative symlink text it followed (F-065): with `~/.config ->
dotfiles/config`, the parent of `.config/nvim/init.lua` resolved to
`~/otfiles/config/nvim`. The text 1.1.1–1.7.0 wrote there,
`../../../dotfiles/nvim/init.lua`, sometimes resolves by luck and
sometimes dangles. 1.7.1 resolves the parent correctly, so the text for
that row is now `../../nvim/init.lua`.

**Removal keeps accepting the old text**, as it has accepted 1.1.0's
lexical text since F-046. `fsl_link_text_matches` recognizes four texts
as hapi's: today's, the absolute text, the lexical-parent text, and the
text 1.7.0's resolver computes. 1.7.0's resolver is kept verbatim as
`_fsl_resolve_path_legacy`, used for that match and nothing else.
`unlink`, `sync --prune` and `rollback` therefore remove links an older
hapi made, and the trail and the filesystem do not part ways on upgrade.

**Creation and `status` accept only today's texts**, the relative one and
the absolute one. A link with the old text is `WRONG` in `status` and a
conflict to `link`, and `hapi link --force <pkg>` rewrites it. A no-arg
`sync` refuses such a package until then.

**Weighed and not taken:** treating the old text as hapi's own but stale,
and rewriting it without `--force`. That is new planner behaviour in a
patch release. The old text also proves only that an older hapi computed
it, not that the link still names the right file, so the user decides, as
with F-046.

**Correction (1.7.1, finding 175).** The 1.6.0 addendum says a hapi
before 1.6.0 makes `unlink` and `rollback` refuse an absolute link with
exit 1. `unlink` does. `rollback` skips it as already at its state, with
exit 0. Neither removes it. A `rollback --steps` or `--to` before 1.6.0
also seals the entry it skipped, so no later rollback reaches it, and an
absolute adopt can then never be reversed (finding 226). The shipped
versions cannot change; the guides say not to roll back absolute links
with them.
