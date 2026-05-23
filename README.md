# hapi

GNU `stow`-equivalent dotfile / symlink farm manager for AGNOS — in
[Cyrius](https://github.com/MacCracken/cyrius).

**Dual-read name:**
- **Hawaiian हपी** — *happy*. First Pacific Islands word in the AGNOS
  naming surface; reads as a friendly verb at the prompt
  (`hapi link bash`, `hapi sync`, `hapi adopt ~/.zshrc`).
- **Backronym:** **H**ome **A**sset **P**rovisioning **I**nterface.

## Positioning

Third leg of the terminal-aesthetics set:

- [`commandress`](https://github.com/MacCracken/commandress) (`cmdrs`) — prompt rendering
- [`darshini`](https://github.com/MacCracken/darshini) — file listing display
- **`hapi`** — dotfile / symlink management
- [`BannerManor`](https://github.com/MacCracken/bannermanor) (`bnrmr`) — ASCII banner generation
- [`iam`](https://github.com/MacCracken/iam) — system info / login MOTD

## Shape vs GNU stow

- **CYML manifest** (`hapi.cyml` in each package) instead of stow's
  directory-as-package convention. The manifest spells every
  symlink explicitly — no surprises from hidden-file conventions.
- **Capability-bounded execution** — touches `$HOME` only by default;
  any other root requires an explicit `--root` flag + capability
  grant. Fits AGNOS auth posture (authorization over authentication).
- **Lightweight audit trail** — every `link` / `unlink` / `adopt` /
  `sync` writes a JSONL entry under `$XDG_STATE_HOME/hapi/`. Clean
  rollback is exactly *"replay the trail in reverse."*
- **Idempotent** — re-running `hapi sync` over a clean tree produces
  zero filesystem changes and zero audit growth.

## Status

**v1.0.0** — contract frozen 2026-05-23. Command surface (ten verbs
plus five global flags), `hapi.cyml` manifest schema (ADR 0001), and
audit-trail format (ADR 0002) are all contractual. See
[`docs/development/release-notes/1.0.0.md`](docs/development/release-notes/1.0.0.md)
for the v1.0 surface and what's deferred post-v1.0.

## Quick start

```sh
cyrius deps                            # resolve stdlib + sibling deps
cyrius build src/main.cyr build/hapi   # compile
./build/hapi --help                    # see the verb set
cyrius test                            # 235 assertions across 65 groups
```

A worked example lives at
[`docs/examples/dotfiles-zsh/`](docs/examples/dotfiles-zsh/) —
three links, used by the M1–M3 acceptance tests. Adopt your own
file with `hapi adopt ~/.somerc somepackage`.

## Documentation

- [`docs/guides/`](docs/guides/) — per-verb how-tos (link, sync,
  rollback, adopt, …) plus cross-cutting flags (`--root`,
  `--dry-run`, `--backup-to`) and the upstream-drift merge ritual.
- [`docs/adr/`](docs/adr/) — five Architecture Decision Records.
  All frozen at v1.0.
- [`docs/audit/2026-05-23-audit.md`](docs/audit/2026-05-23-audit.md)
  — P(-1) security audit pass.
- [`docs/benchmarks.md`](docs/benchmarks.md) — sync over a 100-pkg
  synthetic home.
- [`docs/development/state.md`](docs/development/state.md) — live
  state snapshot.
- [`docs/development/roadmap.md`](docs/development/roadmap.md) —
  post-v1.0 plan (v1.x patches + v2.0 candidates).

## License

GPL-3.0-only
