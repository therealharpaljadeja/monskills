# Product Requirements Document — MONSKILLS

## Overview

MONSKILLS is a website that provides AI agents with domain-specific skills for building applications on the Monad blockchain. Skills are standalone markdown files served over HTTP, designed to be fetched and consumed by LLMs.

## Problem

AI agents lack accurate, up-to-date knowledge about Monad-specific development — contract addresses, deployment patterns, wallet integration, and chain-specific configurations. Hallucinated addresses or outdated patterns lead to lost funds and broken applications.

## Solution

A set of curated, versioned markdown skill files hosted at stable URLs. Agents fetch the skill they need via HTTP and gain accurate Monad knowledge instantly. No SDK, no package install, no authentication required.

## Users

1. **AI agents** (primary) — Claude Code, Cursor, Codex, Copilot, and other coding agents that fetch URLs and read markdown.
2. **Developers** (secondary) — Humans who browse the landing page, read skills in the modal, or copy URLs into agent prompts.
3. **Project maintainer** (internal) — Reviews website visit analytics, GitHub traffic analytics, and consent-gated slash-command feedback.

## Functional Requirements

### Skill Serving
- Each skill is accessible at `/<skill-name>` and `/<skill-name>/SKILL.md`.
- The root skill is accessible at `/SKILL.md`.
- All skill endpoints return `text/markdown` with CORS `*` headers.
- Skill endpoints do not write download events or request metadata to the database.

### Feedback
- Feedback is submitted only through the `/feedback` slash command.
- Feedback submission requires explicit user confirmation before any network request.
- Feedback payloads must be sanitized before submission.
- The feedback endpoint stores submitted fields without raw IPs, hashed IPs, or IP-derived identifiers.

### Landing Page
- Static HTML page at `/` with:
  - List of all available skills.
  - Modal preview for each skill (renders markdown client-side).
  - Copy-to-clipboard for skill URLs.
  - Multiple usage methods (npx, agent prompt, Claude Code plugin, curl).
  - Vercel Analytics for website visit analytics.

## Non-Functional Requirements

- **Privacy:** No app-side skill download tracking. No raw IPs, hashed IPs, cookies, or IP-derived identifiers are stored by application code. Landing-page website visits are measured with Vercel Analytics.
- **Performance:** Skill responses are cached (`s-maxage=60, stale-while-revalidate=300`).
- **Availability:** Hosted on Vercel with global CDN.
- **Correctness:** Smart contract addresses must be verified on-chain. Wrong address = lost funds.
- **Simplicity:** No build step and no frontend framework; client-side dependencies are limited to the documented analytics/i18n scripts.
- **Security reviewability:** System design, trust boundaries, API behavior, test status, production change checks, and monitoring expectations must be documented before production changes are approved.

## Security Review Scope

In scope for security review:

- Static landing pages: `index.html`, `skill.html`, `changelog.html`, `shared.css`, and static assets.
- Skill markdown distribution through Vercel routes and `api/skill.js`.
- Consent-gated feedback submission through `commands/feedback.md` and `api/feedback.js`.
- Neon PostgreSQL feedback storage and the `DATABASE_URL` deployment secret.
- Vercel deployment configuration in `vercel.json`.
- Documentation and hooks that direct agents to external CLIs or onchain workflows.

## Out of Scope

- User authentication or accounts.
- Skill editing via the web UI.
- App-side download analytics; use GitHub analytics instead.
- Rate limiting beyond platform defaults and lightweight payload validation.
- The Monad blockchain protocol, RPC providers, explorers, wallets, and third-party services referenced by skills.
- End-user applications built by developers after reading MONSKILLS.
- Historical analytics data outside current application code paths.
- Vercel, Neon, GitHub, and browser platform internals except for MONSKILLS-specific configuration choices.
