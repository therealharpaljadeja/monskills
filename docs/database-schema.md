# Database Schema — MONSKILLS

## Overview

MONSKILLS uses Neon PostgreSQL for consent-gated feedback submitted through the `/feedback` slash command and handled by `api/feedback.js`.

Current application code only writes to the `feedback` table. Skill fetches do not write download events or request metadata to application storage.

## `feedback`

Canonical schema expected by `api/feedback.js`:

```sql
CREATE TABLE IF NOT EXISTS feedback (
  id BIGSERIAL PRIMARY KEY,
  source VARCHAR(128)
    CHECK (source IS NULL OR source IN ('agent', 'user')),
  skill_name VARCHAR(128),
  category VARCHAR(128)
    CHECK (
      category IS NULL OR category IN (
        'stuck',
        'error-loop',
        'user-complaint',
        'bug',
        'incorrect-info',
        'suggestion',
        'other'
      )
    ),
  severity VARCHAR(128)
    CHECK (severity IS NULL OR severity IN ('low', 'medium', 'high')),
  message VARCHAR(5000) NOT NULL
    CHECK (char_length(message) >= 3),
  context VARCHAR(4000),
  agent_name VARCHAR(128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Field Notes

| Column | Required | Source | Notes |
|--------|----------|--------|-------|
| `id` | Yes | Database | Returned to the caller after insert. |
| `source` | No | Request body `source` | Must be `agent` or `user` when present. |
| `skill_name` | No | Request body `skill` or `skill_name` | Trimmed and capped at 128 chars by application code. |
| `category` | No | Request body `category` | Must match the slash-command category allowlist when present. |
| `severity` | No | Request body `severity` | Must be `low`, `medium`, or `high` when present. |
| `message` | Yes | Request body `message` | Trimmed, required, 3-5000 chars. |
| `context` | No | Request body `context` | Trimmed and capped at 4000 chars by application code. |
| `agent_name` | No | Request body `agent` or `agent_name` | Trimmed and capped at 128 chars by application code. |
| `created_at` | Yes | Database | Insert timestamp. |

## Privacy Notes

- The table does not include raw IP addresses.
- The table does not include hashed IP addresses or IP-derived identifiers.
- The table does not include user-agent strings.
- The feedback endpoint does not store skill download events.
- The honeypot field `website` is intentionally not stored.

## Legacy Cleanup

Existing databases created before app-side download tracking was removed should apply [004-remove-app-side-download-tracking.sql](migrations/004-remove-app-side-download-tracking.sql). That migration removes the old `feedback.ip_hash` column if it exists.
