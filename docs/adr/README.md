# Architecture Decision Records

Decisions about hapi — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

- [0001 — hapi.cyml manifest schema](0001-hapi-cyml-manifest-schema.md)
- [0002 — Audit-trail format](0002-audit-trail-format.md)
- [0003 — Symlink target shape](0003-symlink-target-shape.md)
- [0004 — `hapi adopt` semantics](0004-adopt-op-semantics.md)
- [0005 — Capability-bounded roots](0005-capability-bounded-roots.md)
