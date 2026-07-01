# System Architecture — MONSKILLS

## Overview

MONSKILLS is a static website with thin serverless functions for serving public skill markdown and accepting consent-gated slash-command feedback. The application does not store skill download events, raw IPs, hashed IPs, or IP-derived identifiers. Landing-page website visits are measured with Vercel Analytics, and repository traffic insight comes from GitHub analytics.

## C4 Model

### Level 1 — System Context

```
┌─────────────┐       HTTPS          ┌──────────────────┐
│  AI Agent   │ ──────────────────>  │    MONSKILLS     │
│  (Claude,   │  GET /scaffold       │  (Vercel)        │
│   Cursor,   │<──────────────────   │                  │
│   Codex)    │  text/markdown       │                  │
└─────────────┘                      └────────┬─────────┘
                                              │
┌─────────────┐        HTTPS                  │
│  Developer  │   ──────────────────>         │
│  (Browser)  │        GET /                  │
│             │  <──────────────────          │
└─────────────┘      text/html                │ SQL over HTTPS
                                              ▼
                                     ┌──────────────────┐
                                     │ Neon PostgreSQL  │
                                     │ feedback only    │
                                     └──────────────────┘
```

**Actors:**
- **AI Agent** — Fetches skill markdown files to gain Monad development knowledge.
- **Developer** — Browses the landing page and copies skill URLs.
- **Maintainer** — Reviews Vercel Analytics, GitHub analytics, and slash-command feedback.

**External Systems:**
- **Neon PostgreSQL** — Serverless database storing consent-gated feedback submissions.
- **Vercel Analytics** — Website visit analytics for the landing page.
- **GitHub Analytics** — Source of repository traffic/download insight outside MONSKILLS application storage.

### Level 2 — Containers

| Container | Technology | Responsibility | Security notes |
|-----------|------------|----------------|----------------|
| Static website | HTML, CSS, browser JavaScript | Presents the skill catalog, renders markdown previews, copies skill URLs, and loads Vercel Analytics on the landing page. | Public content only. Client-rendered markdown is sourced from repository-controlled skill files. |
| Skill API | Vercel serverless function, Node.js | Validates skill names against an allowlist and returns bundled `SKILL.md` content as `text/markdown`. | No database writes, no request metadata persistence, CORS `*` by design for public skills. |
| Feedback API | Vercel serverless function, Node.js | Accepts JSON feedback from the `/feedback` slash command and stores sanitized fields. | POST-only except CORS preflight, length limits, enum validation, honeypot handling, parameterized SQL. |
| Feedback database | Neon PostgreSQL | Stores consent-gated feedback rows. | `DATABASE_URL` is a Vercel secret. Application code does not store raw IPs, hashed IPs, or IP-derived identifiers. |
| Skill corpus | Markdown files in git | Provides versioned agent instructions and Monad development guidance. | Reviewed through PRs. Address-bearing docs require extra care because wrong addresses can cause loss of funds. |

### Skill Serving Flow

```
   Request: GET /scaffold
          │
          ▼
  ┌────────────────┐
  │ Vercel Routes  │  vercel.json routes config
  │ (pattern match)│
  └───────┬────────┘
          │  matched -> /api/skill?name=scaffold
          ▼
  ┌────────────────┐
  │ api/skill.js   │
  │                │
  │ 1. Validate    │  Check skill name against allowlist
  │    skill name  │
  │                │
  │ 2. Read file   │  readFileSync(scaffold/SKILL.md)
  │    from disk   │
  │                │
  │ 3. Return      │  markdown
  │    markdown    │
  └────────────────┘
          │
          ▼
   Response: 200 text/markdown
```

## Data Model

### `feedback` table

Stores sanitized feedback submitted through the `/feedback` slash command. Application code does not store raw IPs, hashed IPs, or IP-derived identifiers.

Historical deployments may still contain legacy download analytics tables or columns from older designs. New application code does not write skill download events.

## Key Design Decisions

- **Static-first:** No build step, no framework. Skills are plain markdown files.
- **Serverless skill serving:** Vercel `routes` config maps skill URLs to a serverless function that validates skill names and returns markdown.
- **No app-side skill download tracking:** Skill fetches do not write to the database. Use GitHub analytics for repository traffic insight and Vercel Analytics for landing-page visits.
- **Feedback via slash command:** Feedback is collected only through the `/feedback` slash command and stored without IP-derived identifiers.

See [ADRs](adr/) for detailed decision records.

## Security-Sensitive Implementation Details

- `api/skill.js` rejects unknown skill names before constructing a filesystem path.
- `api/feedback.js` validates request method, body shape, string lengths, source/category/severity enums, and spam indicators before writing to Neon.
- SQL writes use `@neondatabase/serverless` tagged template literals so untrusted values are parameterized.
- `vercel.json` routes only known skill names through the skill API and bundles only markdown/reference files needed at runtime.
- Skill content is intentionally public and unauthenticated; feedback data is internal and stored in Neon.
