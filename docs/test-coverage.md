# Test Coverage — MONSKILLS

## Current Status

MONSKILLS does not contain Solidity contracts, so the Solidity 100% coverage requirement is not applicable.

For the rest of the stack, the repository currently has lightweight validation guidance but does not yet have a complete automated test suite or coverage report. Security review should treat this as a documented gap until the team either adds tests or obtains explicit Security Team acceptance for the reduced risk profile of this static/serverless application.

## Existing Validation

Run syntax checks for the serverless functions:

```bash
node --check api/skill.js
node --check api/feedback.js
node --check api/_lib/db.js
```

Manual route validation:

```bash
curl -i https://skills.devnads.com/SKILL.md
curl -i https://skills.devnads.com/scaffold
curl -i https://skills.devnads.com/scaffold/SKILL.md
```

## Recommended Automated Tests For Production Change Approval

- Unit tests for `api/skill.js`:
  - Known skill names return markdown with `text/markdown`.
  - Unknown names return `404`.
  - `lang=zh` serves Chinese files where present and falls back to English where absent.
  - Skill names cannot traverse paths outside the allowlist.
- Unit tests for `api/feedback.js`:
  - Rejects non-POST methods except `OPTIONS`.
  - Rejects invalid JSON and missing/short messages.
  - Enforces source/category/severity enums.
  - Truncates long optional fields.
  - Does not write raw IPs, hashed IPs, or IP-derived identifiers.
  - Uses parameterized inserts through the Neon client.
- Integration smoke tests against a Vercel preview:
  - Public skill URLs work.
  - CORS headers are present for markdown endpoints.
  - Feedback endpoint handles valid and invalid payloads.
- Static HTML checks:
  - Markdown preview rendering escapes untrusted text.
  - External scripts use SRI where applicable.

## Coverage Target

Follow the intent of Google's code coverage guidance: coverage is a signal, not a goal by itself. For this repository, tests should focus on route validation, input validation, privacy guarantees, and deployment-critical behavior rather than chasing incidental line coverage.
