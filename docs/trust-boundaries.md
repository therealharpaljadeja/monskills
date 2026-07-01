# Trust Boundaries — MONSKILLS

## Overview

This document defines the trust boundaries in the MONSKILLS system, identifying where data crosses from untrusted to trusted zones and what controls are in place.

## Boundary Diagram

```
 UNTRUSTED                    BOUNDARY                     TRUSTED
 ─────────                    ────────                     ───────

 ┌───────────┐
 │ Internet  │
 │           │
 │ AI agents │──── HTTPS ────┐
 │ Browsers  │               │
 │ curl      │               ▼
 └───────────┘       ┌───────────────┐
                     │ Vercel Edge   │
                     │ Routes config │
                     └───────┬───────┘
                             │
                             ▼
                     ┌───────────────┐
                     │ api/skill.js  │
                     │               │
                     │ - Validates   │
                     │   skill name  │
                     │ - Reads file  │
                     │ - Returns MD  │
                     └───────────────┘
                             │
                             ▼
                     ┌───────────────┐               ┌───────────────┐
                     │ api/feedback  │ SQL/HTTPS     │ Neon DB       │
                     │               │──────────────►│ feedback only │
                     │ - Validates   │               │               │
                     │   payload     │               │               │
                     │ - Stores      │               │               │
                     │   sanitized   │               │               │
                     │   feedback    │               │               │
                     └───────────────┘               └───────────────┘
```

## Trust Boundaries

### Boundary 1: Internet → Vercel Routes

**What crosses:** Inbound HTTP requests from any source (agents, browsers, scripts).

**Controls:**
- Vercel routes config only matches specific URL patterns against an allowlist of skill names.
- Unmatched routes fall through to static file serving or 404.
- No authentication required for skills because they are public by design.
- Skill fetches do not write download events or request metadata to application storage.
- The landing page loads Vercel Analytics for website visit analytics.

**Risks:**
- Denial-of-service via high request volume → Mitigated by Vercel platform rate limiting and CDN caching.
- Public CORS exposure → Accepted for skill-serving endpoints because returned skill content is public and credential-free.

### Boundary 2: Vercel Function → Neon Database

**What crosses:** SQL INSERT statements for consent-gated feedback submissions.

**Controls:**
- `DATABASE_URL` is stored as a Vercel environment variable, never in code.
- Connection uses TLS (enforced by Neon's `?sslmode=require`).
- Feedback fields are length-limited and enum-validated where applicable.
- No raw IPs, hashed IPs, download events, or IP-derived identifiers are written by application code.

**Risks:**
- SQL injection → Mitigated by using parameterized queries (tagged template literals in `@neondatabase/serverless`).
- Connection string leak → Mitigated by `.env` in `.gitignore`, Vercel env var encryption.

### Boundary 3: Browser → Third-Party Client Resources

**What crosses:** Browser requests to analytics or CDN-hosted client libraries used by public pages.

**Controls:**
- Vercel Analytics is used only for landing-page website visits.
- CDN script tags should use Subresource Integrity and `crossorigin` when a third-party script is required.
- Skill-serving API responses do not depend on client-side third-party scripts.

**Risks:**
- Third-party script compromise → Mitigated by minimizing dependencies and using SRI where possible.

### Boundary 4: Maintainer → Production Configuration

**What crosses:** Deployment settings, environment variables, domain settings, and database connection strings managed in Vercel and Neon.

**Controls:**
- `DATABASE_URL` is configured as a Vercel environment variable, not committed to git.
- Production changes should go through peer-reviewed PRs and Vercel preview validation.
- Security should review Vercel/Neon settings when material production settings change.

**Risks:**
- Misconfigured environment variables or overly broad production access → Mitigated by least-privilege maintainer access and production change checks.

## Data Classification

| Data | Classification | Storage | Notes |
|------|---------------|---------|-------|
| Skill markdown content | Public | Filesystem (git) | Intentionally open |
| Skill download events | Not stored | N/A | Use GitHub analytics outside app storage |
| Landing-page visit analytics | External telemetry | Vercel Analytics | Browser page visits only, not skill-fetch database rows |
| IP addresses | Not stored | N/A | Application code does not persist raw IPs |
| IP hashes | Not stored | N/A | Application code does not persist IP-derived identifiers |
| Feedback submissions | Internal | Neon DB | Consent-gated slash-command feedback; must be sanitized by the command |
| `DATABASE_URL` | Secret | Vercel env vars | Never in code or logs |

## Assumptions

1. Vercel's platform security (TLS termination, DDoS protection, isolation) is trusted.
2. Neon's serverless infrastructure and encryption at rest is trusted.
3. Skill content is public and does not require access control.
4. The Security Team will review production Vercel and Neon settings when material production settings change.
