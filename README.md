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
- **Capability-bounded execution** — touches `$HOME` only by default.
  A different scope needs an explicit `--root` whose own path is inside
  `$HOME` or listed in `HAPI_ALLOWED_ROOTS`; authorizing one
  destination outside the scope is `HAPI_ALLOWED_ROOTS` alone.
  Containment is decided on where a target *physically resolves* —
  symlinks followed per component — so a symlinked parent directory
  cannot smuggle a link out of the scope, and `--force` does not
  override that refusal. Fits AGNOS auth posture (authorization over
  authentication).
- **Lightweight audit trail** — every `link` / `unlink` / `adopt` /
  `sync` writes a JSONL entry under `$XDG_STATE_HOME/hapi/`. Clean
  rollback is exactly *"replay the trail in reverse."* Name a point with
  `hapi checkpoint --label <name>` and return to it with
  `hapi rollback --to <name>`, or step back with `--steps N`.
- **Idempotent** — re-running `hapi sync` over a clean tree produces
  zero filesystem changes and zero audit growth.
- **One-command recovery** — with `HAPI_PACKAGE_ROOTS` naming the
  directories that hold your packages, a bare `hapi sync` re-links all of
  them. `hapi sync --prune` also removes links whose rows left a
  manifest, never more than half a package's without `--force`.

## Status

**v1.5.0** — the v1.0 contract, frozen 2026-05-23, still holds:
command surface (ten verbs plus five global flags), `hapi.cyml`
manifest schema (ADR 0001), and audit-trail format (ADR 0002) are all
contractual. 1.2.0 is the first release to add surface, all of it
additive: argument parsing moved to
[cmdit](https://github.com/MacCracken/cmdit), which brings
`--root=PATH`, `--` and `hapi <verb> --help`, with every 1.1.1 message
kept. 1.3.0 adds `hapi sync` with no package and `sync --prune`, the
two dogfood issues on `sync`, and 1.4.0 has `unlink` / `rollback` remove
the directories `link` made, recorded as proof in the trail. 1.5.0 adds
script-facing flags: `status --quiet`, `checkpoint --label`, and
`rollback --to <label>` / `--steps N`, a multi-level undo. The releases
before 1.2.0 added teeth: 1.0.5 → 1.0.10 closed all
twenty findings of the
[2026-08-25 P(-1) audit](docs/audit/2026-08-25-audit.md), and 1.1.1
repairs the [2026-10-28 pass](docs/audit/2026-10-28-audit.md), which
found the capability boundary still deciding some paths on their
spelling — see [`CHANGELOG.md`](CHANGELOG.md) for the per-release
record and
[`docs/development/release-notes/1.0.0.md`](docs/development/release-notes/1.0.0.md)
for the v1.0 surface.

## Quick start

```sh
cyrius deps                            # resolve stdlib + sibling deps
cyrius build src/main.cyr build/hapi   # compile
./build/hapi --help                    # see the verb set
cyrius test                            # 1340 + 77 assertions, two suites
```

A worked example lives at
[`docs/examples/dotfiles-zsh/`](docs/examples/dotfiles-zsh/) —
three links, used by the M1–M3 acceptance tests. Adopt your own
file with `hapi adopt ~/.somerc somepackage`.

## Documentation

- [`docs/guides/`](docs/guides/) — per-verb how-tos (link, sync,
  rollback, adopt, …) plus cross-cutting flags (`--root`,
  `--dry-run`, `--backup-to`) and the upstream-drift merge ritual.
- [`docs/adr/`](docs/adr/) — seven Architecture Decision Records: the
  five frozen at v1.0, 0006 (`sync`'s package roots and `--prune`) and
  0007 (`rollback --steps` / `--to`).
- [`docs/audit/`](docs/audit/) — the P(-1) security audit passes
  (index + four dated passes). The
  [2026-10-28 pass](docs/audit/2026-10-28-audit.md) is the current one;
  its findings F-035 – F-059 are repaired in 1.1.1, its 1.2.0
  addendum re-walks the argument surface under cmdit (F-060), and its
  1.3.0, 1.4.0 and 1.5.0 addenda cover `sync`'s scan and prune (F-061),
  the removal of directories `link` made (F-062), and the script-facing
  flags (F-063, accepted).
- [`docs/benchmarks.md`](docs/benchmarks.md) — sync over a 100-pkg
  synthetic home.
- [`docs/development/state.md`](docs/development/state.md) — live
  state snapshot.
- [`docs/development/roadmap.md`](docs/development/roadmap.md) —
  the plan: 1.5.0 through 1.7.0, upstream-gated work, and
  v2.0 candidates.

## License

GPL-3.0-only
