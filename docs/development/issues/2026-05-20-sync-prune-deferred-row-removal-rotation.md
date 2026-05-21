# `hapi sync` cannot prune trail rows that left the manifest — row removal needs full rotation

**Discovered:** 2026-05-20 during M7 dotfile dogfooding (zsh package figlet-row removal)
**Severity:** Low — ergonomic papercut with a working rotation
**Affects:** hapi 0.6.0 through 0.7.0 (and forward until a sync-prune surface lands)

## Summary

Dropping a single `[[link]]` row from a multi-row hapi package requires the user to:
1. `hapi unlink <pkg>` — removes ALL of the package's symlinks (writes one `op:unlink` audit entry per row).
2. Edit the manifest — remove the targeted row.
3. `hapi link <pkg>` — re-creates the remaining rows (writes one `op:link` per kept row).

For a 6-row package losing 1 row, this churns **11 audit-trail entries** (6 unlinks + 5 relinks) and briefly leaves 5 still-wanted symlinks absent on disk. The user's actual intent — *"forget about row N"* — can't be expressed in one command at v0.7.0. The deferral is explicit in the CHANGELOG [0.6.0] Out-of-scope section and the roadmap *Deferred during prior milestones* list, so this issue file is the durable surface so the post-M7 reconsideration has a triage anchor.

## Reproduction

The exact case from M7 dotfile work:

```sh
# zsh package starts with 6 rows including .figlet/fonts/modular.flf
hapi list
# > zsh  6 live links

# User decides figlet font no longer belongs in the package
# (BannerManor + iam replaced the third-party figlet greeter).

# Required workflow today:
hapi unlink zsh
# > 6 unlink lines printed; ~/.zshrc briefly absent

vim dotfiles/zsh/hapi.cyml   # remove the [[link]] block for the figlet row

hapi link zsh
# > 5 link lines printed; trail now has 6 link + 6 unlink + 5 link = 17 entries
#   for what should have been "1 unlink for the dropped row"
```

Live trail-state check:

```sh
hapi list
# > zsh  5 live links     ← correct
```

## Root cause

Design gap, not a bug. `hapi sync <pkg>` at v0.6.0 is a thin wrapper over `cmd_link` (per `src/cmd/sync.cyr`), which only knows how to *create* missing rows — it does not walk the trail looking for "live" entries whose manifest row no longer exists, and so can't emit per-row `op:unlink` entries for those. The roadmap explicitly defers this:

> **`hapi sync` reconciliation (prune trail rows no longer in manifest)** — deferred from M5. v0.6.0 sync is link-without-`--force`; it creates missing rows but doesn't remove links whose manifest row vanished. The full reconciliation surface is post-v1.0 if user demand appears.

— `docs/development/roadmap.md` (*Deferred during prior milestones* section).

The full-rotation workaround that the user reaches for instead has the right *end state* but the wrong *audit-trail shape* (11 entries instead of 1) and the wrong *runtime window* (5 unwanted unlinks + 5 unwanted relinks of files that should have stayed put).

## Proposed fix

`hapi sync <pkg> --prune` (post-v1.0 candidate, possibly default behavior on a major bump):

1. Parse the manifest, build the set of *manifest rows* (source/target pairs).
2. Build the set of *live trail entries* for the package via the existing `_hul_live_entries_for` reduction (in `src/cmd/unlink.cyr`).
3. **Live but not in manifest** → emit `op:unlink` for each, just like `hapi unlink`'s per-target probe + remove + audit.
4. **In manifest but not live** → emit `op:link` for each, just like today's `cmd_link` CREATE path.
5. **In both, state matches** → no-op (already the case today).
6. **In both, state diverges** → refuse per the existing conflict semantics, unless `--force`.

The audit-trail shape for the dogfood case becomes: `1 op:unlink` for the dropped figlet row, `5 op:NOOP` for the kept rows. The runtime window is zero — the 5 kept symlinks are never touched.

Risk surface: the prune step removes symlinks based on what's *no longer in the manifest*. A user who accidentally deletes a row from a manifest and then runs `sync --prune` loses the symlink with no warning. Mitigation: keep `--prune` opt-in, surface the count of would-be-unlinks in the planning phase, refuse if it exceeds some threshold without `--force`.

## Consumer-side workaround

The full rotation works today (`unlink + edit + link`). For multi-row packages where the rotation churn matters, the user can pre-stage the manifest edit and minimize the window by running the three commands back-to-back without intervening manual steps. The dogfood session used exactly this pattern for `dotfiles/zsh/hapi.cyml` and it landed clean.
