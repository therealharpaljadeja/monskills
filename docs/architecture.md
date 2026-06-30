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
