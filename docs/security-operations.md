# Security Operations Checklist — MONSKILLS

## Peer Code Review

All production changes should be reviewed PR by PR before merge.

Reviewers should verify:

- Skill-address changes are sourced and, where applicable, verified on the correct Monad network.
- Vercel route changes match `api/skill.js` allowlists and `docs/api.yaml`.
- Feedback changes preserve the no-IP-storage guarantee.
- Dependency changes receive Socket.dev feedback or equivalent dependency review.
- Documentation changes keep the Security Review Request packet current.

## Production Change Check

Complete this checklist before merging or deploying a materially security-relevant production change:

- [ ] Product owner confirms scope and expected production impact.
- [ ] Security Team has reviewed [architecture.md](architecture.md), [trust-boundaries.md](trust-boundaries.md), and [api.yaml](api.yaml).
- [ ] Security office hours completed for material system design changes.
- [ ] Vercel project settings reviewed with Security.
- [ ] Neon database settings reviewed with Security.
- [ ] `DATABASE_URL` exists only in approved environment-variable stores.
- [ ] Preview deployment smoke tests pass.
- [ ] Automated tests or accepted test-coverage exception are documented in [test-coverage.md](test-coverage.md).
- [ ] Static analysis, dependency scanning, and agent security review findings are resolved or documented.
- [ ] Monitoring responsibilities and alert destinations are confirmed with the owner and Security Team.

## Security Office Hours

Required Security Team touchpoints:

- During material system design changes.
- Before deploying material changes to production.
- For infrastructure settings review when Vercel, Neon, domain, analytics, or alerting configuration changes.

Record meeting dates, attendees, decisions, and follow-up items in the Security Review Request.

## Static Analysis and Related Scanners

Required for production changes:

- If this repository is in a Monad Foundation managed GitHub org, confirm Security Team scanner setup with `@security` in Slack.
- Confirm Socket.dev has scanned any PR that changes dependencies. If expected Socket feedback does not appear, contact `@security`.
- Run the agent-specific security review workflow used by the project. If using Claude Code, run `/security-review`; if using another agent, use the equivalent review process.
- Resolve findings before merge, or document false positives in the PR with rationale.

## Infra Settings Review

Security should review:

- Vercel project access, production branch, preview deployments, environment variables, domains, analytics, and deployment protection.
- Neon project access, database roles, connection string scope, backups, and retention.
- GitHub branch protection, required reviews, dependency scanning, and secret scanning.
