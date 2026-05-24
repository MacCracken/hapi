# Audit trail lost on state-dir wipe — `list`/`rollback` undercount after a drive move

**Discovered:** 2026-05-24 during a drive-move / system-restart dotfile recovery
**Severity:** Medium — silent trail-state divergence (live count + rollback scope undercount reality)
**Affects:** hapi 1.0.0 — and structurally all versions: the trail lives in `$XDG_STATE_HOME/hapi/`, which is local-only state outside the version-controlled dotfiles repo.

## Summary

After a drive move, `$XDG_STATE_HOME/hapi/audit.jsonl` was gone
(the new system's `~/.local/state/` was fresh). The relative
symlinks themselves survived — `$HOME` and the dotfiles repo
moved together, so the `../../Repos/dotfiles/...` links still
resolved — and `hapi status` confirmed 0 drift across all 11
packages (24 links). But the trail that records *how those links
got there* was lost. Re-running `hapi sync` to recover did **not**
rebuild the trail: sync on an already-correct package is an
idempotent no-op and writes no audit entry. The result is a trail
that knows about 2 links (the two that actually needed
(re-)creation today) while 24 are live. `hapi list` undercounts
and `hapi rollback` can only reverse the 2 it can see — it is
blind to the 18 pre-existing links.

## Reproduction

```sh
# Trail wiped (drive move / fresh state dir):
ls ~/.local/state/hapi/audit.jsonl
#   No such file or directory

# Re-link everything from the manifests:
for p in git hypridle hyprland hyprlock hyprmocha hyprpaper \
         kitty starship waybar wofi zsh; do
  hapi sync ~/Repos/dotfiles/$p
done
# 9 packages: "linked 0 / N (N already up-to-date)" — no trail entry.
# git: created .gitconfig (1 entry). zsh: .zshrc force-linked (1 entry).

# Reality vs trail:
hapi status ~/Repos/dotfiles/<each>      # all OK — 24 links live, 0 drift
hapi list
#   scope: /home/macro
#     git  1 live link
#     zsh  1 live link
# ^ 2 of 24. The 18 surviving hyprland/kitty/waybar/... links are invisible.
```

## Root cause

Two facts compose into the divergence:

1. **The trail is ephemeral local state.** Per ADR 0002 it lives
   in `$XDG_STATE_HOME/hapi/audit.jsonl`, deliberately *not* in
   the dotfiles repo (cross-machine content distribution is
   permanent out-of-scope per the roadmap). A drive move that
   doesn't carry `~/.local/state/` forward loses it. That much is
   by design.
2. **Idempotent re-link is invisible to the trail.** A `sync` /
   `link` over an already-correct symlink is a no-op and emits no
   `op:link` entry (`src/cmd/link.cyr` short-circuits on the
   already-up-to-date probe before the audit write). So the
   obvious recovery move — re-run `sync` — confirms reality but
   does **not** reconcile the trail to it. `hapi list`
   (`src/cmd/list.cyr`, trail-walker) and `hapi rollback`
   (`src/cmd/rollback.cyr`, reverse-replay) both read only the
   trail, so both now undercount.

The declarative truth (`status` over the manifests) is intact;
the operational log (`list` / `rollback`) is not.

## Proposed fix

None committed — surfacing for the 1.0.x-final audit arc to weigh
(see [`docs/audit/README.md`](../../audit/README.md)). Candidate
directions, roughly ordered by invasiveness:

- **Document the boundary (no code).** Declare the trail an
  ephemeral operation log: `status` is the source of truth for
  "is everything linked"; rollback history resets when the state
  dir is lost. Recovery = re-run `sync`, accept the reset. This is
  consistent with ADR 0002's local-trust model and is arguably the
  honest semantic. Lowest cost; closes the issue as an accepted
  boundary the way F-004 / F-005 were.
- **Re-seed on confirm (additive).** A `hapi sync --reseed` (or a
  `link` that emits an `op:link` even for an already-correct link)
  would let the recovery `sync` rebuild the trail to match the
  live set. Additive flag; no contract change. Interacts with the
  no-arg-sync work — see
  [`2026-05-24-no-arg-sync-bootstrap-recovery.md`](2026-05-24-no-arg-sync-bootstrap-recovery.md).
- **Reconstruct from status (additive verb/flag).** A one-shot
  that walks the manifests, and for every `OK` row synthesizes the
  trail entry it *would* have written. Heavier; only worth it if
  the boundary keeps biting in dogfood.

Whichever lands, the audit-trail *format* (ADR 0002) stays frozen
— this is reader/writer behavior, not a line-shape change.

## Consumer-side workaround

Treat `hapi status <pkg>` as the post-recovery truth, not
`hapi list`. After a state-dir loss, `list` and `rollback` only
reflect operations performed since the loss; do not rely on
`rollback` to undo links that predate it. If a clean trail is
wanted, the heavy hammer is: `unlink` every package (while the
trail still has the entries — *before* the wipe, not after), or
accept that the post-move trail starts fresh. Today's recovery
took the "accept the reset" path: 24 links live and correct, trail
seeded with the 2 operations the recovery actually performed.

## Cross-references

- [`2026-05-24-no-arg-sync-bootstrap-recovery.md`](2026-05-24-no-arg-sync-bootstrap-recovery.md)
  — same recovery event; the no-arg-sync ergonomics half.
- [ADR 0002](../../adr/0002-audit-trail-format.md) — trail format
  + local-trust model (F-004 lineage).
- [`docs/audit/README.md`](../../audit/README.md) — 1.0.x-final
  audit arc; this issue is a scoped item for Step 5 (recovery /
  state-loss boundary).
- [`../state.md`](../state.md) — audit-trail location + reader set.
