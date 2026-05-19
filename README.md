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
  directory-as-package convention.
- **Capability-bounded execution** — touches `$HOME` only by default;
  requires explicit grant for other roots. Fits AGNOS auth posture.
- **Lightweight audit trail** — what got linked when, by which `hapi`
  invocation. Clean rollback.
- Possibly `hoosh`-assisted conflict resolution later (skip for v1).

## Status

Pre-1.0 scaffold (0.1.0). No commands implemented yet.

## Build

```sh
cyrius deps                            # resolve stdlib
cyrius build src/main.cyr build/hapi   # compile
./build/hapi                            # prints "hapi v0.1.0 — scaffold"
cyrius test                             # run tests/*.tcyr
```

## License

GPL-3.0-only
