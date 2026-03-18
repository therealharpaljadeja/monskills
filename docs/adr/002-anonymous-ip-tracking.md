# ADR-002: Anonymous IP Tracking with Daily Hash Rotation

## Status

Accepted

## Context

The maintainer needs to understand which skills are most downloaded and how many unique users access them. This requires some form of visitor deduplication.

Options considered:

1. **Raw IP storage** — Store full IP addresses in the database.
2. **Hashed IP with static salt** — SHA-256 hash the IP with a fixed salt.
3. **Hashed IP with daily rotating salt** — SHA-256 hash the IP with the current date as salt.
4. **No deduplication** — Count raw hits without any visitor identification.
5. **Cookie-based tracking** — Set a unique cookie per visitor.

## Decision

Use SHA-256 hashed IPs with a daily rotating salt: `SHA-256(ip + "YYYY-MM-DD")`.

## Consequences

### Positive
- **Privacy preserving** — Raw IPs never reach the database. The hash is irreversible.
- **Daily deduplication** — Same IP on the same day produces the same hash, enabling unique visitor counts per day.
- **Cross-day unlinkability** — Different days produce different hashes, so visitors cannot be tracked across days.
- **No cookies** — Works for programmatic clients (curl, agents) that don't support cookies.
- **No user consent required** — No PII is stored, no cookies are set.

### Negative
- **No cross-day unique counts** — Cannot answer "how many unique users in the last 30 days" because hashes change daily. Only "unique visitors per day" is possible.
- **Shared IP collisions** — Users behind the same NAT/VPN will be counted as one unique visitor per day. Acceptable for this use case.
- **Salt is predictable** — The date is public knowledge, so an attacker with access to the database could theoretically brute-force common IPs against known dates. Mitigated by the fact that this data has low sensitivity (it only reveals "someone downloaded a public skill").

### Neutral
- User-agent strings are not stored, further reducing any fingerprinting surface.
- The footer on the landing page discloses that anonymous tracking is in place.
