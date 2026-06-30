# Security Review — MONSKILLS

## Summary

No high-confidence, practically exploitable vulnerabilities were found.

## Findings Analyzed and Filtered

| # | Category | File | Confidence | Verdict |
|---|----------|------|------------|---------|
| 1 | DOM-based XSS via `javascript:` URIs in markdown links | `index.html:420` | 3/10 | **Filtered** — Content source is trusted (allowlisted SKILL.md files committed to repo). Requires a malicious PR to be merged. |

## Confirmed Secure

- **SQL injection** (`api/skill.js`) — Neon tagged template literals use parameterized queries. Skill name is also validated against a hardcoded allowlist.
- **Path traversal** (`api/skill.js`) — Skill name checked against `VALID_SKILLS` before use in `join()`. No user-controlled path components.
- **No download tracking** (`api/skill.js`) — Skill fetches do not write download events or request metadata to application storage.
- **No IP-derived feedback storage** (`api/feedback.js`) — Feedback submissions do not store raw IPs, hashed IPs, or IP-derived identifiers.
- **CORS `*` headers** — Acceptable for a public, read-only, credential-free content API.
- **Reserve balance documentation** (`concepts/references/reserve-balance.md`) — Protocol guidance only; not executable code or obfuscated script content.
- **Third-party scripts** (`index.html`, `skill.html`) — Vercel Analytics is intentionally loaded on the landing page for website visits; remaining CDN scripts use SRI and `crossorigin`.
