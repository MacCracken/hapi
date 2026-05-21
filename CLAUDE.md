# hapi — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported backends, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**hapi** — **H**ome **A**sset **P**rovisioning **I**nterface; Hawaiian हपी (*happy*) — GNU stow-equivalent dotfile / symlink farm manager for AGNOS.

- **Type**: Binary
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)
- **Shared crates registry**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/shared-crates.md)

## Goal

Own AGNOS userland's dotfile / configuration-provisioning surface. CYML-manifest-driven symlink farms scoped to `$HOME` by default, with capability-bounded escape and a lightweight audit trail. Third leg of the terminal-aesthetics set alongside `commandress`, `darshini`, `BannerManor`, and `iam`.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, command surface, in-flight work, consumers, dep
> gaps. Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init hapi`. **Do not manually create project structure** — use the tools. If the tools are missing something, fix the tools.

## Quick Start

```sh
cyrius deps                            # resolve stdlib + sibling deps
cyrius build src/main.cyr build/hapi   # compile
./build/hapi                            # prints "hapi v0.1.0 — scaffold"
cyrius test                             # run tests/*.tcyr
```

## Key Principles

- **Capability-bounded by default.** Every filesystem touch is bounded by an explicit capability. `$HOME` is the default root; touching anything else requires an explicit `--root` flag and a capability grant. Fits AGNOS auth posture (authorization over authentication).
- **Manifest-driven, not directory-driven.** Each package has a `hapi.cyml` manifest declaring source → target. We don't infer link shape from directory layout (that's stow's convention; it's brittle and silently does the wrong thing on hidden files).
- **Every operation is auditable.** Every `link` / `unlink` / `adopt` / `sync` writes an entry to the audit trail. Rollback is exactly "replay the audit trail in reverse." No magic, no inference.
- **Idempotent.** Running `hapi sync` twice produces the same result. Existing correct symlinks are no-ops, not errors.
- **No process spawning from inside command handlers.** Everything happens via syscall primitives. No `exec_*`, no shelling out. If a feature seems to want it, the design is wrong.
- **Conflicts surface explicitly.** When a target path exists and isn't already the right symlink, we refuse, list the conflict, and exit non-zero. The user resolves; we never overwrite without `--force`.

## Rules (Hard Constraints)

- **Read the genesis repo's CLAUDE.md first** — [agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
- **Do not commit or push** — the user handles all git operations
- **Never use `gh` CLI** — use `curl` to the GitHub API only
- Do not skip tests before claiming changes work
- Do not use `sys_system()` or `exec_*` from command handlers — hapi is syscall-only
- Do not trust external paths without validation — every path argument gets bounds, `../` traversal check, and symlink loop detection
- Do not modify `lib/` files (vendored stdlib / dep symlinks managed by `cyrius deps`)
- Do not silently overwrite an existing file — refuse and exit non-zero unless `--force` is explicit
- Do not write outside `$HOME` without an explicit `--root` flag — the capability boundary is load-bearing
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth

## Process

### P(-1): Hardening (before v0.2.0 first feature cut, and before v1.0)

1. **Cleanliness** — `cyrius build`, `cyrius lint`, all tests pass
2. **Benchmark baseline** — `cyrius bench` for link / sync hot paths once they exist
3. **Internal review** — every path argument's validation; every syscall's return handling
4. **External research** — GNU stow corner cases (hidden-file conventions, dotfile collisions, .keep markers); audit-trail design references
5. **Security audit** — path traversal, symlink loop, TOCTOU, capability scope. File findings in `docs/audit/YYYY-MM-DD-audit.md`
6. **Documentation audit** — ADRs for manifest format choices; per-command guide pages

### Work Loop (continuous)

1. **Work phase** — new command, bug fix, manifest extension
2. **Build check** — `cyrius build src/main.cyr build/hapi`
3. **Test additions** — happy + conflict + capability-denied paths per command
4. **Internal review** — path validation, syscall returns, audit-trail entry
5. **Documentation** — CHANGELOG, `docs/development/state.md`, guide if a new command landed
6. **Version sync** — `VERSION`, `cyrius.cyml`, CHANGELOG header in sync before tag

### Task Sizing

- **Low/Medium effort**: batch freely — multiple manifest fields per cycle
- **Large effort**: small bites only — break each command into parse + execute + audit + rollback paths
- **If unsure**: treat it as large

## Cyrius Conventions

- All struct fields are 8 bytes (`i64`), accessed via `load64`/`store64` with offset
- Heap allocation via `fl_alloc()`/`fl_free()` for individual-lifetime data
- Bump allocation via `alloc()` for long-lived data (vec, str internals)
- Enum values for constants — don't consume `gvar_toks` slots
- `break` in while loops with `var` declarations is unreliable — use flag + `continue`
- No negative literals — write `(0 - N)` not `-N`
- See [cyrius CLAUDE.md](https://github.com/MacCracken/cyrius/blob/main/CLAUDE.md) for the full convention set

## Docs

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious constraints (*what's true about the code?*)
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos
- [`docs/examples/`](docs/examples/) — Runnable example manifests
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — Milestones through v1.0
- [`docs/development/issues/`](docs/development/issues/) — Open dogfood papercuts + design-gap reports (one file per issue; archived on close)
- [`docs/doc-health.md`](docs/doc-health.md) — Whole-tree doc-currency ledger (fresh / stale / archive / open-question; refreshed in place when docs are touched)

Full doc-tree convention: [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Manifest format changes are `Breaking` until v1.0, after which the manifest schema is frozen. Audit-trail format changes are always `Breaking` — rollback compatibility is part of the contract.
