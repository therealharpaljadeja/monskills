# Trust Boundaries — MONSKILLS

## Overview

This document defines the trust boundaries in the MONSKILLS system, identifying where data crosses from untrusted to trusted zones and what controls are in place.

## Boundary Diagram

```
 UNTRUSTED                    BOUNDARY                     TRUSTED
 ─────────                    ────────                     ───────

 ┌───────────┐                                       ┌───────────────┐
 │ Internet  │                                       │ Neon DB       │
 │           │                                       │               │
 │ AI agents │──── HTTPS ────┐                       │ Only accessed │
 │ Browsers  │               │                       │ via DATABASE_ │
 │ curl      │               ▼                       │ URL (TLS)     │
 └───────────┘       ┌───────────────┐               └───────┬───────┘
                     │ Vercel Edge   │                       │
                     │               │                       │
                     │ Routes config │                       │
                     │ (pattern      │                       │
                     │  matching)    │                       │
                     └───────┬───────┘                       │
                             │                               │
                             ▼                               │
                     ┌───────────────┐                       │
                     │ api/skill.js  │───── SQL/HTTPS ───────┘
                     │               │
                     │ - Validates   │
                     │   skill name  │
                     │ - Hashes IP   │
                     │ - Reads file  │
                     └───────────────┘
                            │
                     ┌───────────────┐
                     │ api/stats.js  │
                     │               │
                     │ - Validates   │
                     │   secret key  │
                     └───────────────┘
```

## Trust Boundaries

### Boundary 1: Internet → Vercel Routes

**What crosses:** Inbound HTTP requests from any source (agents, browsers, scripts).

**Controls:**
- Vercel routes config only matches specific URL patterns against an allowlist of skill names.
- Unmatched routes fall through to static file serving or 404.
- No authentication required (skills are public by design).

**Risks:**
- Denial-of-service via high request volume → Mitigated by Vercel platform rate limiting and CDN caching.

### Boundary 2: Vercel Function → Neon Database

**What crosses:** SQL INSERT statements with skill name and hashed IP.

**Controls:**
- `DATABASE_URL` is stored as a Vercel environment variable, never in code.
- Connection uses TLS (enforced by Neon's `?sslmode=require`).
- Skill name is validated against an allowlist before any DB operation.
- IP is hashed before storage — raw IP never reaches the database.
- The Neon serverless driver uses HTTPS, not a persistent connection.

**Risks:**
- SQL injection → Mitigated by using parameterized queries (tagged template literals in `@neondatabase/serverless`).
- Connection string leak → Mitigated by `.env` in `.gitignore`, Vercel env var encryption.

### Boundary 3: Internet → Stats API

**What crosses:** Request for analytics data, which includes aggregated download counts.

**Controls:**
- Protected by `STATS_SECRET` query parameter.
- Returns 401 if key is missing or incorrect.
- Response contains only aggregated data (skill names, counts, hashed IPs) — no PII.

**Risks:**
- Secret brute-force → Mitigated by using a high-entropy secret (`openssl rand -hex 16`).
- Secret in URL query string may appear in server logs → Acceptable risk for an internal admin endpoint. Consider migrating to `Authorization` header if needed.

## Data Classification

| Data | Classification | Storage | Notes |
|------|---------------|---------|-------|
| Skill markdown content | Public | Filesystem (git) | Intentionally open |
| IP addresses | Not stored | N/A | Hashed before any storage |
| IP hashes | Internal | Neon DB | SHA-256 with daily rotating salt |
| Skill download counts | Internal | Neon DB | Aggregated, no PII |
| `DATABASE_URL` | Secret | Vercel env vars | Never in code or logs |
| `STATS_SECRET` | Secret | Vercel env vars | Never in code or logs |

## Assumptions

1. Vercel's platform security (TLS termination, DDoS protection, isolation) is trusted.
2. Neon's serverless infrastructure and encryption at rest is trusted.
3. The daily hash salt rotation is sufficient to prevent IP reconstruction (no rainbow tables for daily salts).
4. Skill content is public and does not require access control.
