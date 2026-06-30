# ADR-004: Remove App-Side Download Tracking

## Status

Accepted

## Context

ADR-002 introduced daily-rotated IP hashes for download deduplication. Security scans later flagged that approach as IP-derived tracking. The maintainer also decided GitHub analytics is sufficient for traffic insight going forward, so MONSKILLS no longer needs to write new skill download events in application storage.

Options considered:

1. **Keep daily IP hashes** — Preserves approximate unique counts but remains IP-derived tracking.
2. **Store raw download rows only** — Keeps aggregate skill popularity but still tracks app-side downloads.
3. **Stop app-side download tracking for future requests** — Maximizes privacy for new requests, preserves historical rows, and relies on GitHub analytics for future traffic insight.

## Decision

Stop app-side skill download tracking for future skill fetches. `api/skill.js` does not write to the database.

Keep the existing `skill_downloads` table and historical data for now. Do not add new code paths that read or write it.

Feedback submissions are also stored without IP-derived identifiers. Spam control relies on payload validation, honeypot handling, and platform-level abuse controls rather than application-level IP rate limiting.

Existing databases must apply `docs/migrations/004-remove-app-side-download-tracking.sql` to remove the old `feedback.ip_hash` column. The migration intentionally preserves `skill_downloads`.

## Consequences

### Positive
- Stops new download tracking writes from application code.
- Removes IP-derived tracking concerns from future skill fetches.
- Simplifies `/api/skill` by making it a read-only markdown serving endpoint.
- Eliminates the protected in-app stats endpoint and its dedicated secret.
- Removes legacy stored IP hashes from the feedback table when the migration is applied.
- Preserves existing `skill_downloads` data for historical reference.

### Negative
- No new in-app download analytics.
- Less application-level spam throttling for feedback submissions.

### Neutral
- The app still receives HTTP requests through Vercel as any hosted service does; the decision is about what MONSKILLS application code stores.
- Website visit analytics comes from Vercel Analytics, and repository traffic insight comes from GitHub analytics outside MONSKILLS application storage.
