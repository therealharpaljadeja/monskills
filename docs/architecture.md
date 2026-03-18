# System Architecture — MONSKILLS

## Overview

MONSKILLS is a static website with a thin serverless tracking layer. Skills (markdown files) are served through Vercel serverless functions that log anonymous download events to a Neon PostgreSQL database.

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
└─────────────┘      text/html                │
                                              │ SQL over HTTPS
┌─────────────┐        HTTPS                  │
│  Maintainer │   ──────────────────>         │
│             │    GET /api/stats?key=...     │
│             │  <──────────────────          ▼
└─────────────┘    application/json    ┌──────────────────┐
                                       │  Neon PostgreSQL │
                                       │  (Serverless)    │
                                       └──────────────────┘
```

**Actors:**
- **AI Agent** — Fetches skill markdown files to gain Monad development knowledge.
- **Developer** — Browses the landing page and copies skill URLs.
- **Maintainer** — Queries the stats API to monitor skill usage.

**External Systems:**
- **Neon PostgreSQL** — Serverless database storing anonymous download events.

### Level 2 — Container Diagram

```
┌───────────────────────────────────────────────────────────┐
│                     MONSKILLS (Vercel)                    │
│                                                           │
│  ┌───────────────┐     ┌───────────────────────────────┐  │
│  │  Landing Page │     │   Vercel Serverless Functions │  │
│  │  (index.html) │     │                               │  │
│  │               │     │  ┌─────────────┐              │  │
│  │  Static HTML  │     │  │ /api/skill  │──┐           │  │
│  │  + Vanilla JS │     │  │             │  │           │  │
│  │               │     │  └─────────────┘  │           │  │
│  │  Renders MD   │     │                   │ SQL/HTTPS │  │
│  │  in modal     │     │  ┌─────────────┐  │           │  │
│  └───────────────┘     │  │ /api/stats  │──┤           │  │
│                        │  │  (protected)│  │           │  │
│  ┌──────────────┐      │  └─────────────┘  │           │  │
│  │ Skill Files  │      │                   │           │  │
│  │ (*.SKILL.md) │◄───  │  ┌─────────────┐  │           │  │
│  │              │      │  │ _lib/db.js  │  │           │  │
│  │ scaffold/    │      │  │ (hash + db) │  │           │  │
│  │ wallet/      │      │  └─────────────┘  │           │  │
│  │ addresses/   │      │                   │           │  │
│  │ ...          │      └───────────────────┤           │  │
│  └──────────────┘                         │            │  │
│                                           │            │  │
└───────────────────────────────────────────┼────────────┘  │
                                            │               │
                                            ▼               │
                                    ┌──────────────────┐    │
                                    │ Neon PostgreSQL  │    │
                                    │                  │    │
                                    │ skill_downloads  │    │
                                    │ ├─ id (serial)   │    │
                                    │ ├─ skill_name    │    │
                                    │ ├─ ip_hash       │    │
                                    │ └─ downloaded_at │    │
                                    └──────────────────┘    │
└───────────────────────────────────────────────────────────┘
```

### Level 3 — Component: Skill Serving Flow

```
   Request: GET /scaffold
          │
          ▼
  ┌────────────────┐
  │ Vercel Routes  │  vercel.json routes config
  │ (pattern match)│
  └───────┬────────┘
          │  matched → /api/skill?name=scaffold
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
  │ 3. Hash IP     │  SHA-256(ip + YYYY-MM-DD)
  │                │
  │ 4. INSERT into │──────────────► Neon PostgreSQL
  │    DB (await)  │
  │                │
  │ 5. Return      │
  │    markdown    │
  └────────────────┘
          │
          ▼
   Response: 200 text/markdown
```

## Data Model

### `skill_downloads` table

| Column | Type | Description |
|--------|------|-------------|
| `id` | `SERIAL PRIMARY KEY` | Auto-incrementing row ID |
| `skill_name` | `VARCHAR(100) NOT NULL` | Name of the skill downloaded |
| `ip_hash` | `VARCHAR(64)` | SHA-256 hash of IP + daily salt |
| `downloaded_at` | `TIMESTAMPTZ DEFAULT NOW()` | Timestamp of download |

**Indexes:**
- `idx_skill_downloads_skill` on `skill_name`
- `idx_skill_downloads_time` on `downloaded_at`
- `idx_skill_downloads_hash` on `ip_hash`

## Key Design Decisions

- **Static-first:** No build step, no framework. Skills are plain markdown files.
- **Tracking via routes:** Vercel `routes` config intercepts requests before static file serving, routing through the tracking function.
- **Privacy by design:** Only hashed IPs stored, salt rotates daily, no cookies or fingerprinting.
- **Fire-and-wait:** DB insert is awaited to ensure it completes before the serverless function shuts down.

See [ADRs](adr/) for detailed decision records.
