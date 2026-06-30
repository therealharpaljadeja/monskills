# ADR-003: Vercel Routes for Skill Serving

## Status

Accepted

## Context

Skills are markdown files on disk. Requests need to return stable markdown URLs such as `/scaffold` and `/scaffold/SKILL.md`, while the server validates skill names and can serve language variants.

Options considered:

1. **`rewrites` in vercel.json** — Maps URL patterns to destinations. Evaluated after static file matching.
2. **`routes` in vercel.json** — Legacy routing config. Evaluated before static file matching.
3. **Edge Middleware** — Intercepts requests at the edge. Available for all frameworks but adds complexity.
4. **Static file serving only** — Simplest, but duplicates routing behavior and weakens allowlist validation.

## Decision

Use `routes` in `vercel.json` to route skill URLs through `/api/skill.js` before Vercel checks static files.

`api/skill.js` validates the skill name against an allowlist, reads the matching local markdown file, and returns `text/markdown`. It does not record download events.

## Consequences

### Positive
- Stable URLs for browser visits, curl, agents, and direct SKILL.md fetches.
- Central allowlist validation for public skill fetches.
- One place to handle language fallback.
- No app-side download tracking for skill fetches.

### Negative
- Added latency compared with direct CDN static file serving. Mitigated by `Cache-Control: s-maxage=60, stale-while-revalidate=300`.
- Cold starts for the serverless function after idle periods.
- `routes` is legacy config. It is retained because `rewrites` evaluate after static files.
- New skills must be added to both the `routes` regex in `vercel.json` and the `VALID_SKILLS` array in `api/skill.js`.

### Neutral
- The `includeFiles` function config ensures SKILL.md files are bundled with the serverless function for `readFileSync` access.
- The function reads files synchronously, which is acceptable for small markdown files in a serverless context.
