# MONSKILLS -- Security Architecture & Implementation Review

> **Purpose:** This document describes the MONSKILLS system architecture, data flows, trust boundaries, and security posture for Security Team review. It is intended for reviewers evaluating the live service and materially security-relevant production changes.
>
> **Last updated:** 2026-07-01

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Context](#2-product-context)
3. [System Architecture](#3-system-architecture)
4. [Trust Boundaries](#4-trust-boundaries)
5. [Authentication and Session Management](#5-authentication-and-session-management)
6. [Authorization Model](#6-authorization-model)
7. [Data Classification and Storage](#7-data-classification-and-storage)
8. [API Security](#8-api-security)
9. [Input Validation and Output Encoding](#9-input-validation-and-output-encoding)
10. [Infrastructure and Deployment](#10-infrastructure-and-deployment)
11. [Third-Party Dependencies](#11-third-party-dependencies)
12. [Test Coverage and Review Process](#12-test-coverage-and-review-process)
13. [Monitoring and Operations](#13-monitoring-and-operations)
14. [Known Risks and Mitigations](#14-known-risks-and-mitigations)
15. [Threat Model Summary](#15-threat-model-summary)
16. [Recommendations and Owner Action Items](#16-recommendations-and-owner-action-items)

---

## 1. Executive Summary

MONSKILLS is a public documentation and skill-distribution site for AI agents building on Monad. It serves repository-controlled markdown files over stable HTTP routes and accepts consent-gated feedback through a serverless API.

The project does **not** handle payments, user accounts, wallet private keys, OAuth tokens, cryptocurrency transactions, or Solidity contract execution. The primary security concerns are content integrity, prevention of path traversal in markdown serving, feedback endpoint abuse, supply-chain hygiene, and production configuration of Vercel/Neon.

**Attack surface summary:**

- Public static pages: `/`, `/skill.html`, `/changelog.html`
- Public markdown skill routes: `/SKILL.md`, `/<skill>`, `/<skill>/SKILL.md`, `/<skill>/SKILL.zh.md`
- Public serverless API: `GET /api/skill`
- Public feedback API: `POST /api/feedback`
- Third-party client scripts for Vercel Analytics and i18n
- Neon PostgreSQL feedback storage
- GitHub PR workflow and dependency changes

**Review packet links:**

| Requirement | Artifact |
|-------------|----------|
| Repo README with build and test instructions | [../README.md](../README.md) |
| Product requirements | [PRD.md](PRD.md) |
| System overview and C4 architecture | [architecture.md](architecture.md) |
| Trust boundaries | [trust-boundaries.md](trust-boundaries.md) |
| API documentation | [api.yaml](api.yaml) |
| ADRs | [adr/](adr/) |
| Test coverage status | [test-coverage.md](test-coverage.md) |
| Current self-review notes | [security-review.md](security-review.md) |

---

## 2. Product Context

### Problem Statement

AI agents often have stale or incomplete Monad development knowledge. Outdated contract addresses, chain-specific behavior, deployment patterns, gas guidance, wallet tooling, or indexing instructions can lead to broken applications or loss of funds.

### Objectives

1. Provide stable, public, agent-readable Monad development skills.
2. Keep high-risk information, especially contract addresses and deployment guidance, versioned and reviewable in git.
3. Let developers and agents submit explicit feedback without storing raw IPs, hashed IPs, or skill download events in application storage.

### Users and Stakeholders

| Actor | Role |
|-------|------|
| AI agents | Fetch skill markdown files and use them as task context. |
| Developers | Browse the landing page, inspect skills, copy URLs, and submit feedback through slash commands. |
| Maintainer | Reviews PRs, Vercel Analytics, GitHub analytics, feedback submissions, and production configuration. |
| Security Team | Reviews architecture, trust boundaries, scanner coverage, monitoring, and production-change readiness. |

### Features

| Priority | Feature |
|----------|---------|
| Must-have | Serve root and per-topic `SKILL.md` files over stable public URLs. |
| Must-have | Validate skill names against an allowlist before filesystem access. |
| Must-have | Serve `text/markdown` with CORS headers for agent consumption. |
| Must-have | Accept consent-gated `/feedback` slash-command submissions. |
| Must-have | Avoid app-side download tracking and IP-derived identifiers. |
| Should-have | Support Chinese skill variants where available. |
| Should-have | Provide OpenAPI, architecture, trust-boundary, ADR, and review docs. |

### Constraints

- Static-first architecture; no frontend framework or compile step.
- Public skill access by design; no authentication requirement for reading skills.
- Vercel serverless functions and Neon PostgreSQL for feedback storage.
- Security review must distinguish implemented controls from owner actions that still need scheduling or confirmation.

---

## 3. System Architecture

### High-Level Topology

```
┌─────────────────┐       HTTPS        ┌────────────────────────────┐
│ AI agents       │ ─────────────────► │ MONSKILLS on Vercel        │
│ Browsers        │                    │                            │
│ curl/scripts    │ ◄───────────────── │ - Static HTML/CSS/JS       │
└─────────────────┘   markdown/html    │ - Serverless functions     │
                                       │ - Vercel routes config     │
                                       └─────────────┬──────────────┘
                                                     │ SQL over HTTPS/TLS
                                                     ▼
                                       ┌────────────────────────────┐
                                       │ Neon PostgreSQL            │
                                       │ feedback submissions only  │
                                       └────────────────────────────┘

External services:
  - Vercel Analytics for landing-page visit analytics
  - GitHub analytics for repository traffic insight
  - GitHub/Security tooling for PR review, secret scanning, dependency scanning
```

### Repository Structure

| Path | Purpose |
|------|---------|
| `SKILL.md` | Root monskill router used by agents to select topic skills. |
| `<skill>/SKILL.md` | Public skill markdown files. |
| `<skill>/references/*.md` | Supporting markdown references for skills. |
| `api/skill.js` | Serverless markdown-serving endpoint. |
| `api/feedback.js` | Serverless feedback submission endpoint. |
| `api/_lib/db.js` | Neon client factory. |
| `commands/feedback.md` | Slash-command feedback workflow. |
| `docs/` | Architecture, API, ADRs, trust boundaries, security review packet. |
| `vercel.json` | Route mapping, headers, and serverless function file includes. |

### Technology Stack

| Component | Technology |
|-----------|------------|
| Hosting | Vercel |
| Runtime | Node.js serverless functions |
| Database | Neon PostgreSQL |
| Database client | `@neondatabase/serverless` |
| Frontend | Static HTML, CSS, and browser JavaScript |
| API docs | OpenAPI 3.0.3 in [api.yaml](api.yaml) |
| Diagrams/specs | Markdown C4 overview |

### Key Design Decisions

- Skills are static markdown files served over public HTTP. See [ADR-001](adr/001-static-markdown-distribution.md).
- Skill URLs are routed through `api/skill.js` for allowlist validation. See [ADR-003](adr/003-vercel-routes-tracking.md).
- App-side skill download tracking was removed. See [ADR-004](adr/004-no-app-side-download-tracking.md).
- Historical IP-hash tracking design is superseded for current code paths. See [ADR-002](adr/002-anonymous-ip-tracking.md) and [ADR-004](adr/004-no-app-side-download-tracking.md).

---

## 4. Trust Boundaries

```
┌───────────────────────────────────────────────────────────────┐
│ UNTRUSTED: Internet clients                                   │
│                                                               │
│ - AI agents                                                   │
│ - Browsers                                                    │
│ - curl/scripts                                                │
│ - Feedback request bodies                                     │
│                                                               │
├─────────────── TRUST BOUNDARY 1: HTTPS/Vercel ────────────────┤
│                                                               │
│ SEMI-TRUSTED: Vercel routes and static assets                 │
│                                                               │
│ - Public pages and markdown routes                            │
│ - Route regexes in vercel.json                                │
│ - Vercel Analytics client script                              │
│                                                               │
├─────────────── TRUST BOUNDARY 2: Serverless API ──────────────┤
│                                                               │
│ TRUSTED APPLICATION CODE                                      │
│                                                               │
│ - api/skill.js validates skill allowlist before file reads    │
│ - api/feedback.js validates and stores sanitized feedback      │
│ - No skill fetch metadata stored by application code           │
│                                                               │
├─────────────── TRUST BOUNDARY 3: Database ────────────────────┤
│                                                               │
│ TRUSTED DATA STORE: Neon PostgreSQL                           │
│                                                               │
│ - Feedback submissions                                        │
│ - DATABASE_URL configured outside git                         │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### Key Trust Boundary Observations

1. **Skill content is public by design.** No authentication or authorization is required to read skill markdown.
2. **Feedback content is untrusted.** The feedback endpoint validates method, JSON shape, field lengths, enums, and spam indicators before writing to Neon.
3. **Skill names are the main filesystem boundary.** `api/skill.js` rejects unknown skill names before constructing a path.
4. **Third-party browser scripts are not needed for markdown API correctness.** Skill-serving works independently of client-side analytics/i18n scripts.
5. **Production configuration is a separate trust boundary.** Vercel, Neon, GitHub branch protection, and scanner settings need Security review when material production settings change.

See [trust-boundaries.md](trust-boundaries.md) for the detailed trust-boundary document.

---

## 5. Authentication and Session Management

MONSKILLS does not implement user accounts, login, OAuth, password authentication, wallet authentication, or application sessions.

| Surface | Auth Required | Notes |
|---------|---------------|-------|
| Static pages | No | Public documentation and landing pages. |
| Skill markdown routes | No | Public by design for agent consumption. |
| `GET /api/skill` | No | Public read-only markdown endpoint. |
| `POST /api/feedback` | No app session | Submission is gated by the slash-command consent flow, not by server-side login. |

Because there are no application sessions:

- No session cookies are issued by MONSKILLS application code.
- No JWTs or OAuth provider tokens are stored.
- No wallet private keys are handled.
- CSRF risk is limited to unauthenticated feedback submission abuse rather than account-bound state changes.

---

## 6. Authorization Model

There is no role-based access control and no authenticated user model in the application.

### Route-Level Authorization

| Endpoint/Route | Access | Authorization Check |
|----------------|--------|---------------------|
| `/` | Public | None |
| `/changelog` | Public | None |
| `/SKILL.md` | Public | Routes to root skill. |
| `/<skill>` | Public | Vercel route regex plus `VALID_SKILLS` allowlist. |
| `/<skill>/SKILL.md` | Public | Vercel route regex plus `VALID_SKILLS` allowlist. |
| `/<skill>/SKILL.zh.md` | Public | Vercel route regex plus `VALID_SKILLS` allowlist and English fallback. |
| `GET /api/skill?name=<skill>` | Public | `VALID_SKILLS.includes(skill)`. |
| `POST /api/feedback` | Public write | Payload validation, length limits, enum allowlists, honeypot, spam checks. |

### Authorization Pattern

The main authorization control is allowlist-based routing for public markdown files:

```js
if (!skill || !VALID_SKILLS.includes(skill)) {
  return res.status(404).send("Skill not found");
}
```

This prevents arbitrary filesystem paths from being used as skill names.

---

## 7. Data Classification and Storage

### Data Categories

| Category | Data | Sensitivity | Storage |
|----------|------|-------------|---------|
| Skill content | Markdown skills and references | Public | Git repository and Vercel deployment bundle |
| Static assets | HTML, CSS, JS, images, logos | Public | Git repository and Vercel CDN |
| Feedback submissions | Source, skill name, category, severity, message, context, agent name | Internal | Neon PostgreSQL `feedback` table |
| Database credentials | `DATABASE_URL` | Secret | Vercel environment variables |
| Landing-page analytics | Page visit telemetry | External telemetry | Vercel Analytics |
| Repository traffic | GitHub traffic analytics | External telemetry | GitHub |
| Skill download events | Not stored by current app code | N/A | N/A |
| Raw IPs / IP hashes | Not stored by current app code | N/A | N/A |

### Data Retention

- Skill content is retained through git history.
- Feedback retention policy is not yet documented and should be confirmed with the owner and Security Team.
- Historical deployments may contain legacy analytics tables; current application code does not write skill download events.

### Encryption

- **In transit:** HTTPS for public requests; Neon connection should use TLS via `?sslmode=require`.
- **At rest:** Provided by Vercel/Neon platform controls.
- **Application-level encryption:** Not currently implemented. Feedback should not contain secrets or sensitive personal data.

---

## 8. API Security

### `GET /api/skill`

Security properties:

- Rejects missing or unknown skill names with `404`.
- Uses a hardcoded `VALID_SKILLS` allowlist before path construction.
- Reads only bundled skill markdown files.
- Serves `text/markdown; charset=utf-8`.
- Sets `Access-Control-Allow-Origin: *` intentionally because skills are public and credential-free.
- Sets CDN caching: `public, s-maxage=60, stale-while-revalidate=300`.
- Does not write request metadata, download events, IPs, or IP-derived identifiers to application storage.

### `POST /api/feedback`

Security properties:

- Allows `OPTIONS` for CORS preflight and rejects non-POST methods with `405`.
- Requires `DATABASE_URL`; returns `500` if database is not configured.
- Parses JSON bodies and rejects malformed input.
- Uses a honeypot field (`website`) to silently accept obvious bot submissions without writing.
- Requires a non-empty message with minimum length.
- Applies maximum lengths:
  - `message`: 5000 chars
  - `context`: 4000 chars
  - short metadata fields: 128 chars
- Validates enums:
  - `source`: `agent`, `user`
  - `severity`: `low`, `medium`, `high`
  - `category`: `stuck`, `error-loop`, `user-complaint`, `bug`, `incorrect-info`, `suggestion`, `other`
- Rejects simple spam indicators such as more than five URLs or `<script` patterns.
- Writes through `@neondatabase/serverless` tagged template literals, which parameterize values.

### CORS

| Endpoint | CORS |
|----------|------|
| Skill markdown routes | `Access-Control-Allow-Origin: *` |
| `GET /api/skill` | `Access-Control-Allow-Origin: *` |
| `POST /api/feedback` | `Access-Control-Allow-Origin: *`, methods `POST, OPTIONS`, header `Content-Type` |

This is acceptable for public, credential-free endpoints, but Security should confirm the posture.

### Defensive Response Headers

Current headers are documented in [vercel.json](../vercel.json). Markdown and shell files receive explicit content-type and CORS headers.

Potential hardening to review:

- Add broader defensive headers for static HTML pages, such as `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, and a Content Security Policy.
- Review Vercel Analytics and CDN script allowlists if CSP is introduced.

---

## 9. Input Validation and Output Encoding

### Input Surfaces

| Input | Surface | Validation |
|-------|---------|------------|
| Skill name | `GET /api/skill?name=` and Vercel routes | Vercel route regex plus `VALID_SKILLS` allowlist. |
| Language | `GET /api/skill?lang=zh` | Only `zh` is accepted; anything else falls back to English behavior. |
| Feedback JSON | `POST /api/feedback` | JSON parsing, required message, length limits, enum allowlists, honeypot, spam checks. |
| Feedback `skill_name` / `agent_name` | `POST /api/feedback` | Trimmed and capped at 128 chars. |
| Feedback `context` | `POST /api/feedback` | Trimmed and capped at 4000 chars. |

### SQL Injection

Mitigated by `@neondatabase/serverless` tagged template literals in `api/feedback.js`. Untrusted values are passed as parameters, not interpolated into raw SQL strings.

### Path Traversal

Mitigated by the `VALID_SKILLS` allowlist in `api/skill.js`. The filesystem path is constructed only after the requested skill name is confirmed to be one of the known values.

### XSS

- Static pages render repository-controlled content, not arbitrary user-submitted HTML.
- Skill preview markdown is sourced from allowlisted repository files.
- Existing self-review notes track a low-confidence markdown-link XSS scenario in [security-review.md](security-review.md). The risk depends on a malicious PR modifying trusted skill content.
- Feedback messages are stored server-side and should be escaped by any future admin UI that displays them.

---

## 10. Infrastructure and Deployment

### Deployment Topology

| Service | Platform | Access |
|---------|----------|--------|
| Static website | Vercel | Public |
| Serverless functions | Vercel | Public |
| Feedback database | Neon PostgreSQL | Application-only via `DATABASE_URL` |
| Source repository | GitHub | Maintainer/Security controlled |

### Environment Variables

| Variable | Classification | Required | Notes |
|----------|----------------|----------|-------|
| `DATABASE_URL` | Secret | Yes for feedback | Neon PostgreSQL connection string. Should include TLS settings. |

`.env.example` documents only the active required secret.

### Database Setup and Migrations

- Current active table: `feedback`.
- Schema is provisioned through one-time maintainer-only setup endpoints that are removed after use.
- Existing databases created before app-side download tracking was removed should apply [004-remove-app-side-download-tracking.sql](migrations/004-remove-app-side-download-tracking.sql).

### CI/CD

Current deployment model:

- Vercel deploys from the repository.
- Pushes to `main` trigger production deployment.
- Preview deployment behavior should be confirmed with the owner.

Open items for Security/owner confirmation:

- GitHub branch protection and required review rules.
- Required status checks before merge.
- Scanner installation status for the production GitHub org.
- Vercel production branch and deployment protection.
- Neon access control, backups, and retention.

---

## 11. Third-Party Dependencies

### Runtime Dependencies

| Dependency | Purpose | Trust Level | Notes |
|------------|---------|-------------|-------|
| `@neondatabase/serverless` | PostgreSQL access | High | Used by `api/_lib/db.js` and `api/feedback.js`. |
| Vercel Analytics script | Landing-page analytics | Medium | Loaded on `index.html`. |
| jsDelivr i18next scripts | Client-side i18n | Medium | Uses SRI and `crossorigin`. |
| Neon PostgreSQL | Feedback database | High | Stores internal feedback submissions. |
| Vercel | Hosting/runtime/CDN | High | Serves static assets and functions. |
| GitHub | Source control/review | High | PR review and scanner integration. |

### Supply Chain Considerations

- Dependency changes should receive Socket.dev feedback or equivalent dependency review.
- If this repository is in a Monad Foundation managed GitHub org, Security Team scanner setup should be confirmed with `@security`.
- If Socket.dev feedback is expected but does not appear on a dependency-changing PR, developers should contact `@security`.

---

## 12. Test Coverage and Review Process

### Current Status

MONSKILLS does not contain Solidity contracts, so the Solidity 100% coverage requirement is not applicable.

The repository does not yet have a complete automated non-Solidity test suite or coverage report. This is documented in [test-coverage.md](test-coverage.md) and should be resolved either by adding tests or by obtaining explicit Security Team acceptance for the reduced risk profile.

### Existing Validation

Recommended syntax checks:

```bash
node --check api/skill.js
node --check api/feedback.js
node --check api/_lib/db.js
```

Recommended route smoke checks:

```bash
curl -i https://skills.devnads.com/SKILL.md
curl -i https://skills.devnads.com/scaffold
curl -i https://skills.devnads.com/scaffold/SKILL.md
```

### Peer Review

All production changes should be reviewed PR by PR before merge.

Reviewers should verify:

- Skill-address changes are sourced and, where applicable, verified on the correct Monad network.
- Vercel route changes match `api/skill.js` allowlists and [api.yaml](api.yaml).
- Feedback changes preserve the no-IP-storage guarantee.
- Dependency changes receive Socket.dev feedback or equivalent dependency review.
- Security review documentation remains current when architecture, trust boundaries, API behavior, or production configuration changes.

### Static Analysis and Agent Review

Required for production changes:

- Confirm Security Team scanner setup if using a Monad Foundation managed GitHub org.
- Confirm Socket.dev scans dependency-changing PRs.
- Run the project-approved agent security review workflow. If using Claude Code, run `/security-review`; if using another agent, use the equivalent process.
- Resolve findings or document false positives in the PR.

---

## 13. Monitoring and Operations

### Current Signals

- Vercel deployment status and function logs.
- Vercel Analytics for landing-page visits.
- GitHub repository traffic analytics.
- Neon database logs/metrics for feedback storage health.
- Slash-command feedback submissions reviewed by maintainers.

### Recommended Site Integrity Checks

- Production homepage returns `200`.
- `/SKILL.md` returns `200` and `text/markdown`.
- Each public skill shorthand route returns `200`.
- Unknown skill routes return `404`.
- Feedback endpoint rejects invalid payloads and accepts valid test payloads in a non-production environment.

### Ownership To Confirm

- Primary maintainer/on-call for production alerts.
- Slack channel or email destination for Vercel and Neon alerts.
- Security Team contact for site integrity monitoring.
- Frequency for reviewing feedback submissions and analytics.

---

## 14. Known Risks and Mitigations

### High Priority

| Risk | Description | Current Status | Recommended Mitigation |
|------|-------------|----------------|------------------------|
| Incomplete automated test coverage | Non-Solidity stack does not yet have full automated tests/coverage. | Active | Add focused tests for skill routing, feedback validation, no-IP-storage guarantees, and static rendering; or obtain Security exception. |
| Production infra settings need periodic review | Vercel, Neon, GitHub branch protection, scanner installation, and alert destinations should be confirmed for material production changes. | Active | Schedule Security infra review for material infra changes and record decisions in this document or PR. |

### Medium Priority

| Risk | Description | Current Status | Recommended Mitigation |
|------|-------------|----------------|------------------------|
| Public feedback endpoint abuse | Unauthenticated endpoint may receive spam or high-volume submissions. | Partially mitigated | Honeypot, validation, length limits, and simple spam checks exist. Consider platform rate limiting, CAPTCHA-free abuse controls, or Security-approved monitoring thresholds. |
| Static HTML defensive headers are minimal | Markdown/shell file headers are configured, but broader static HTML headers/CSP are not fully documented as enforced. | Active | Add and test security headers for static pages after reviewing script allowlists. |
| Malicious content PR | Skill markdown is trusted by the renderer and agents. A malicious PR could add harmful links/instructions. | Partially mitigated | Require peer review for skill changes, especially address-bearing or executable-command guidance. Consider content linting for dangerous links/patterns. |
| Legacy historical analytics tables | Older databases may retain historical `skill_downloads` rows. | Known | Current code does not write new download rows. Confirm retention/deletion policy with owner and Security. |

### Low Priority

| Risk | Description | Current Status | Recommended Mitigation |
|------|-------------|----------------|------------------------|
| Public CORS on skill endpoints | Any origin can fetch public skill markdown. | By design | Security should confirm that this is acceptable for public, credential-free content. |
| Feedback may contain secrets accidentally pasted by users | Feedback text is free-form. | Active | Keep feedback internal, avoid logging full messages unnecessarily, add reviewer guidance to redact/delete accidental secrets. |
| CDN script dependency risk | i18n scripts are loaded from jsDelivr. | Partially mitigated | SRI and `crossorigin` are present. Consider vendoring scripts or enforcing CSP. |

---

## 15. Threat Model Summary

### Threat Actors

| Actor | Motivation | Capability |
|-------|------------|------------|
| Spam bot | Pollute feedback database or consume function/database resources | Automated HTTP requests |
| Malicious contributor | Insert harmful skill content, wrong addresses, or unsafe commands | PR access or compromised maintainer review path |
| Scraper | Mirror public skill content | Automated HTTP requests |
| Dependency attacker | Compromise package/CDN dependency | Supply-chain attack |
| Misconfigured operator | Accidentally expose secrets or weaken deployment controls | Vercel/Neon/GitHub access |

### Attack Scenarios

| Scenario | Likelihood | Impact | Mitigation Status |
|----------|------------|--------|-------------------|
| Path traversal through skill name | Low | High | Mitigated by Vercel route regex and `VALID_SKILLS` allowlist. |
| SQL injection through feedback body | Low | High | Mitigated by Neon tagged template parameterization. |
| Feedback spam / database growth | Medium | Medium | Partially mitigated by honeypot, validation, and spam checks; monitoring/rate limits should be reviewed. |
| XSS through malicious markdown link | Low | Medium | Partially mitigated by trusted repo content and PR review; renderer behavior should remain under review. |
| Wrong smart contract address added to skill | Medium | High | Mitigated by address verification instructions and PR review; wrong address can cause loss of funds. |
| Secret committed to repository | Low | High | Mitigated by `.env.example` and expected GitHub secret scanning; scanner setup needs confirmation. |
| Supply-chain compromise of CDN script | Low | Medium | Partially mitigated by SRI for i18n scripts; CSP/vendoring can further reduce risk. |
| Unauthorized access to feedback database | Low | Medium | Mitigated by Vercel env secret storage and Neon platform controls; access policy requires review. |

---

## 16. Recommendations and Owner Action Items

### Production Review Critical

- [ ] Confirm whether this is a documentation-only review or tied to a material production change.
- [ ] Provide the production GitHub org/repo where Security scanners should run.
- [ ] Confirm whether the repo is in a Monad Foundation managed GitHub org.
- [ ] Schedule Security office hours for system design.
- [ ] Schedule Security office hours for production infra settings review if settings are changing.
- [ ] Confirm the Vercel project, Neon project, production domain, and alert destinations.
- [ ] Add automated tests or obtain Security acceptance for the documented coverage gap.
- [ ] Run the project-approved agent security review workflow and document false positives in the PR.

### Recommended Hardening

- [ ] Add focused automated tests for `api/skill.js` and `api/feedback.js`.
- [ ] Add security headers/CSP for static HTML pages after reviewing required script sources.
- [ ] Confirm feedback retention and accidental-secret handling policy.
- [ ] Confirm GitHub branch protection, required reviews, dependency scanning, and secret scanning.
- [ ] Confirm Vercel deployment protection and production environment-variable access.
- [ ] Confirm Neon backups, access controls, connection-string scope, and retention.

### Key Questions for Security Review

- Is public wildcard CORS acceptable for unauthenticated markdown skill endpoints?
- Is the current no-IP-storage feedback design acceptable without app-level IP rate limiting?
- What minimum automated test coverage or exception is required before approval?
- Should site integrity monitoring be owned by Security, the maintainer, or both?
- Should static HTML security headers/CSP be required for the next material production change?
