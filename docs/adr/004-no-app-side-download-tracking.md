# ADR-004: Remove App-Side Download Tracking

## Status

Accepted

## Context

ADR-002 introduced daily-rotated IP hashes for download deduplication. Security scans later flagged that approach as IP-derived tracking. The maintainer also decided GitHub analytics is sufficient for traffic insight, so MONSKILLS no longer needs to store skill download events in application storage.

Options considered:

1. **Keep daily IP hashes** — Preserves approximate unique counts but remains IP-derived tracking.
2. **Store raw download rows only** — Keeps aggregate skill popularity but still tracks app-side downloads.
3. **Remove app-side download tracking entirely** — Maximizes privacy and relies on GitHub analytics for traffic insight.

## Decision

Remove app-side skill download tracking entirely. Skill fetches do not write to the database.

Feedback submissions are also stored without IP-derived identifiers. Spam control relies on payload validation, honeypot handling, and platform-level abuse controls rather than application-level IP rate limiting.

Existing databases must apply `docs/migrations/004-remove-app-side-download-tracking.sql` to drop the legacy `skill_downloads` table and remove the old `feedback.ip_hash` column.

## Consequences

### Positive
- Removes download tracking from application storage.
- Removes IP-derived tracking concerns from skill fetches.
- Simplifies `/api/skill` by making it a read-only markdown serving endpoint.
- Eliminates the protected in-app stats endpoint and its dedicated secret.
- Removes legacy stored IP hashes from the feedback table when the migration is applied.

### Negative
- No in-app download analytics.
- Less application-level spam throttling for feedback submissions.

### Neutral
- The app still receives HTTP requests through Vercel as any hosted service does; the decision is about what MONSKILLS application code stores.
- Repository traffic insight comes from GitHub analytics outside MONSKILLS application storage.
