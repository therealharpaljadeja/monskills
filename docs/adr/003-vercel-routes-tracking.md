# ADR-003: Vercel Routes for Download Tracking

## Status

Accepted

## Context

Skills are markdown files on disk. To track downloads, requests must pass through a serverless function before the content is returned. Vercel offers several routing mechanisms:

Options considered:

1. **`rewrites` in vercel.json** — Maps URL patterns to destinations. Evaluated *after* static file matching.
2. **`routes` in vercel.json** — Legacy routing config. Evaluated *before* static file matching.
3. **Edge Middleware** — Intercepts requests at the edge. Available for all frameworks but adds complexity.
4. **Client-side tracking** — Add a fetch call in the landing page JavaScript. Only tracks browser visits, not programmatic downloads.

## Decision

Use `routes` in `vercel.json` to intercept skill URLs and route them through `/api/skill.js` before Vercel checks for static files.

## Consequences

### Positive
- **Captures all downloads** — Browser visits, curl, agent fetches, and direct SKILL.md URLs all pass through the tracking function.
- **Transparent** — The URL doesn't change for the consumer. `/scaffold` still returns markdown.
- **Simple** — No middleware runtime, no edge function config. Just a routing rule and a serverless function.

### Negative
- **Added latency** — Every skill download now goes through a serverless function instead of being served directly from the CDN. Mitigated by `Cache-Control: s-maxage=60, stale-while-revalidate=300`.
- **Cold starts** — First request after idle may have ~200-500ms cold start for the serverless function.
- **`routes` is legacy config** — Vercel recommends `rewrites`/`redirects` for new projects. However, `rewrites` evaluate after static files, which defeats the purpose. The `routes` config is stable and still supported.
- **Skill allowlist maintenance** — New skills must be added to both the `routes` regex in `vercel.json` and the `VALID_SKILLS` array in `api/skill.js`.

### Neutral
- The `includeFiles` function config ensures SKILL.md files are bundled with the serverless function for `readFileSync` access.
- The function reads files synchronously, which is acceptable for small markdown files in a serverless context.
