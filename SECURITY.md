# Security Policy

## Threat surface

hapi manages symlinks in the user's home directory by default,
with explicit opt-in for other roots. The realistic threats:

- **Path traversal** — `../` escapes that write outside the scoped root
- **Symlink loops** — manifest references that produce infinite-link cycles
- **TOCTOU races** — target path checked, then replaced before the link is created
- **Capability bypass** — `--root` accepted without proper capability check
- **Audit-trail tampering** — modifying past entries to hide an operation; the audit trail is the rollback source of truth and must be append-only with integrity protection

Every path argument is validated for bounds and traversal before any
syscall. Every filesystem mutation writes an audit-trail entry. The
capability boundary (`$HOME` by default, `--root` requires grant) is
load-bearing.

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not
open public issues for security bugs.

We will acknowledge receipt within 48 hours and provide a timeline
for a fix.
