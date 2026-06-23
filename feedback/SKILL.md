---
name: feedback
description: Prepare consent-gated anonymous feedback for monskills when the agent is stuck, hits the same error repeatedly, finds incorrect or missing information in a skill, or the user expresses frustration with monskills.
---

# Feedback

An anonymous feedback pipeline for agents using monskills. Submissions require explicit user consent before any outbound network request. The service stores submissions without personal data (only a daily-rotated hashed IP for spam control).

## When to propose feedback

Offer to prepare a feedback report when **any** of these is true:

1. **Agent is stuck.** You retried the same task 3+ times and are not converging on a solution. Use `category: "stuck"`.
2. **Repeated failures.** The same tool/command/error occurs 3+ times in a row while following a skill. Use `category: "error-loop"`.
3. **User is complaining about monskills.** The user says the skill is wrong, unclear, broken, outdated, or that the agent keeps failing at monskills instructions. Use `category: "user-complaint"`.
4. **Incorrect information.** You verified that a fact in a skill is wrong (e.g. a contract address returns empty `eth_getCode`, an API returns 404, a command flag no longer exists). Use `category: "incorrect-info"`.
5. **Missing information.** A skill claims to cover a topic but does not have the detail needed to finish the task. Use `category: "suggestion"`.

Do **not** propose feedback for:
- One-off transient errors (network blip, rate limit, user typo)
- User frustration unrelated to monskills content
- Tasks the user completed successfully

Submit **at most once per distinct issue per session**. If you already submitted for a given root cause, do not submit again for the same cause.

## Consent requirement

Never send feedback automatically. Before making a `POST` request:

1. Draft a minimal, sanitized payload locally.
2. Tell the user feedback would be sent to `https://skills.devnads.com/api/feedback`.
3. Show a short summary of the exact fields you plan to send, including `message` and any `context`.
4. State that the endpoint may receive the request IP for rate limiting, stored only as a daily-rotated hash.
5. Ask for explicit confirmation, such as "Reply yes to send this feedback."

Only submit after the user clearly agrees in the current conversation. If the user declines, is silent, changes the subject, or gives ambiguous approval, do not submit.

## How to submit

`POST https://skills.devnads.com/api/feedback` with a JSON body.

```bash
curl -X POST https://skills.devnads.com/api/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "source": "agent",
    "category": "error-loop",
    "severity": "medium",
    "skill": "wallet",
    "agent": "claude-code",
    "message": "propose.mjs fails with '\''nonce too low'\'' when proposing a second tx in the same block; retrying does not help.",
    "context": "Monad testnet, Safe v1.4.1, ran propose.mjs twice within ~300ms."
  }'
```

### Required fields

| Field | Type | Notes |
|-------|------|-------|
| `message` | string | What went wrong, in one or two sentences. Max 5000 chars. No PII, no secrets, no private keys, no raw addresses, no private repo names, and no host/user-identifying details. |

### Optional fields

| Field | Allowed values | Purpose |
|-------|----------------|---------|
| `source` | `"agent"` or `"user"` | Who is reporting. Defaults unset. |
| `category` | `stuck`, `error-loop`, `user-complaint`, `bug`, `incorrect-info`, `suggestion`, `other` | Triage bucket. |
| `severity` | `low`, `medium`, `high` | `high` = blocks the user, `medium` = workable workaround, `low` = nit/suggestion. |
| `skill` | a monskills slug (e.g. `wallet`, `scaffold`) | Which skill the feedback is about, if any. |
| `agent` | free-text ≤128 chars | Your agent name (e.g. `claude-code`, `cursor`, `codex`). |
| `context` | free-text ≤4000 chars | Short reproduction context: network, command, sanitized error output. Strip secrets and identifiers. |

The response is `{ "ok": true, "id": <number> }` on success, or `{ "ok": false, "error": "..." }` on rejection.

## Privacy rules (hard requirements)

Before sending, scrub the payload:

- **Never** include private keys, mnemonics, API keys, OAuth tokens, or session cookies.
- **Never** include names, emails, usernames, organization names, machine hostnames, local absolute paths, hidden directory paths, or `~` expanded to a real home directory.
- Use repo-relative file paths only when they are needed to understand the issue. Replace paths outside the repo with `<REDACTED_PATH>`.
- Replace wallet addresses, transaction hashes tied to the user, ENS names, account IDs, project IDs, database IDs, and ticket/customer IDs with placeholders such as `0xUSER_ADDRESS`, `<TX_HASH>`, or `<ACCOUNT_ID>`.
- Public contract addresses may be included only when they are necessary to identify incorrect skill content and are not user-controlled.
- Do not include raw command output, stack traces, environment dumps, full prompts, chat transcripts, screenshots, or file contents. Summarize the minimum reproduction details instead.
- Remove URLs unless the URL is the public documentation/API page that is the subject of the report.
- Error messages are OK to paraphrase if they contain no secrets or identifiers. If in doubt, paraphrase more aggressively.

If you cannot meet these rules for a specific field, omit that field.

## What is sent

With user consent, the request sends only the JSON fields you prepared (`source`, `category`, `severity`, `skill`, `agent`, `message`, and/or `context`). It does not send repository files, terminal history, chat transcripts, environment variables, or credentials unless you put that information in the JSON body, which the privacy rules forbid.

## Spam / rate limits

The endpoint applies these limits — design around them instead of retrying:

- Max 10 submissions per hour per hashed IP.
- Max message length 5000 chars; context 4000 chars.
- Payloads with >5 URLs or HTML script tags are dropped silently.
- The `website` field is a honeypot — never include it.

If you get `429`, stop submitting for the rest of the session.

## After submitting

Tell the user, in one line, that you filed anonymous feedback, with the returned `id`. Example:

> Filed anonymous feedback #482 about the wallet skill's propose.mjs nonce issue.

Then continue with the user's original task. Do **not** wait for a human response.