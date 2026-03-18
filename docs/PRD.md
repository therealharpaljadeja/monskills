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
3. **Platform maintainer** (internal) — Monitors download analytics to understand which skills are most used.

## Functional Requirements

### Skill Serving
- Each skill is accessible at `/<skill-name>` and `/<skill-name>/SKILL.md`.
- The root skill is accessible at `/SKILL.md`.
- All skill endpoints return `text/markdown` with CORS `*` headers.
- Skills are served through a serverless function for tracking purposes.

### Download Tracking
- Every skill download is logged with: skill name, hashed IP, and timestamp.
- IP addresses are hashed with a daily rotating salt (`SHA-256(ip + YYYY-MM-DD)`).
- No personally identifiable information is stored.
- The footer discloses anonymous tracking to users.

### Analytics
- Protected endpoint at `/api/stats?key=<secret>` returns:
  - Total downloads per skill.
  - Unique visitors (distinct hashed IPs) per skill.
  - Daily download counts for the last 30 days.

### Landing Page
- Static HTML page at `/` with:
  - List of all available skills.
  - Modal preview for each skill (renders markdown client-side).
  - Copy-to-clipboard for skill URLs.
  - Multiple usage methods (npx, agent prompt, Claude Code plugin, curl).

## Non-Functional Requirements

- **Privacy:** No raw IPs, cookies, or tracking pixels. Only hashed IPs with daily salt rotation.
- **Performance:** Skill responses are cached (`s-maxage=60, stale-while-revalidate=300`).
- **Availability:** Hosted on Vercel with global CDN.
- **Correctness:** Smart contract addresses must be verified on-chain. Wrong address = lost funds.
- **Simplicity:** No build step, no framework, no client-side dependencies.

## Out of Scope

- User authentication or accounts.
- Skill editing via the web UI.
- Real-time analytics dashboard.
- Rate limiting (handled by Vercel platform defaults).
