# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately via [GitHub Security Advisories](https://github.com/qte77/gha-cross-repo-issue-sync/security/advisories/new).

Do not open a public issue for security vulnerabilities.

## Scope

This action handles GitHub PATs and issue data. Key security considerations:

- **Token scope**: use minimum required permissions (Issues read+write)
- **Loop prevention**: bot actor + comment prefix guards prevent infinite sync loops
- **Event input sanitization**: all `github.event.*` data is passed via `env:` blocks, not inline in `run:` commands
