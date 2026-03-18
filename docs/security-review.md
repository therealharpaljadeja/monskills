# Security Review — MONSKILLS

## Summary

No high-confidence, practically exploitable vulnerabilities were found.

## Findings Analyzed and Filtered

| # | Category | File | Confidence | Verdict |
|---|----------|------|------------|---------|
| 1 | DOM-based XSS via `javascript:` URIs in markdown links | `index.html:420` | 3/10 | **Filtered** — Content source is trusted (allowlisted SKILL.md files committed to repo). Requires a malicious PR to be merged. |
| 2 | Timing side-channel on stats secret comparison | `api/stats.js:4` | 2/10 | **Filtered** — Nanosecond timing differences are unmeasurable over HTTP to Vercel serverless functions with 1-50ms network jitter. |

## Confirmed Secure

- **SQL injection** (`api/skill.js`) — Neon tagged template literals use parameterized queries. Skill name is also validated against a hardcoded allowlist.
- **Path traversal** (`api/skill.js`) — Skill name checked against `VALID_SKILLS` before use in `join()`. No user-controlled path components.
- **IP hashing** (`api/_lib/db.js`) — SHA-256 with daily rotating salt. Raw IPs never stored.
- **CORS `*` headers** — Acceptable for a public, read-only, credential-free content API.
