# ADR-001: Static Markdown Skill Distribution

## Status

Accepted

## Context

MONSKILLS distributes domain-specific knowledge (Monad development patterns, contract addresses, deployment guides) to AI agents as [Claude Code skills](https://code.claude.com/docs/en/skills).

The Claude Code skills specification requires skills to be markdown files (`SKILL.md`) served over HTTP. This is not an architectural choice — it is a requirement.

## Decision

Use static markdown files (`SKILL.md`) served over HTTP with CORS headers, following the Claude Code skills specification.

## Consequences

### Positive
- **Spec-compliant** — Works out of the box with Claude Code, Cursor, Codex, Copilot, and any agent that supports the skills spec.
- **Zero dependencies for consumers** — Any HTTP client (curl, fetch, agent) can read a skill. No SDK, no auth, no package install.
- **Version controlled** — Skills are plain files in git. Changes are reviewed via PRs with full diff history.
- **Cacheable** — Static files work naturally with CDN caching.
- **Simple hosting** — Any static host (Vercel, Netlify, GitHub Pages) works.

### Negative
- **No structured metadata API** — Consumers can't query "which skills exist?" programmatically without fetching the index.
- **No partial fetching** — Agents must fetch entire skill files, even if they only need a section.
- **Manual updates** — Adding a skill requires a code change and deploy, not a CMS update.

### Neutral
- Markdown rendering for the landing page modal is done client-side with a minimal custom parser (no external dependency).
