---
description: Prepare consent-gated anonymous feedback about monskills for the maintainers.
argument-hint: [feedback message]
---

Prepare anonymous feedback about monskills. Do not send anything until the user explicitly confirms the sanitized payload.

User-provided message (may be empty): "$ARGUMENTS"

Steps:

1. If the user's message is empty, ask them one short question: what is wrong
   with monskills right now? Wait for their reply before continuing.
2. Scrub the payload of any keys, wallet addresses, transaction hashes,
   hostnames, user or organization names, account/project/customer IDs, raw logs,
   absolute paths, paths outside the project, prompts, transcripts, screenshots,
   file contents, and URLs that are not the public page being reported.
3. Decide the `category` from the user's message:
    - skill content is wrong → `incorrect-info`
    - skill is missing something → `suggestion`
    - agent kept failing → `error-loop` or `stuck`
    - general complaint about monskills → `user-complaint`
    - anything else → `other`
4. Pick `severity`: `high` if the user is blocked, `medium` if there is a
   workaround, `low` for nits.
5. If the feedback is about a specific skill (wallet, scaffold, addresses,
   concepts, gas, wallet-integration, tooling-and-infra, why-monad,
   indexer), include it as `skill`. Otherwise omit.
6. Prepare a minimal JSON body containing at minimum `source: "user"` and
   `message`, plus whichever optional fields you determined. Prefer a short
   paraphrase over raw user text if the message contains identifiers.
7. Before any network request, show the user:
   - the endpoint: `https://skills.devnads.com/api/feedback`
   - the sanitized fields that will be sent
   - that the application stores the submitted fields but does not store raw IPs,
     hashed IPs, or other IP-derived identifiers
   Ask for explicit confirmation, such as: `Reply yes to send this feedback.`
8. Only after the user clearly confirms in the current conversation, POST to
   `https://skills.devnads.com/api/feedback` with
   `Content-Type: application/json` and a body containing at minimum
   `source: "user"`, `message`, and whichever optional fields you determined.
   Use `curl -sS -X POST`.
9. Report the returned `id` back to the user in one line, e.g.
   `Filed anonymous feedback #482.` If the response is not `ok`, show the
   error verbatim and stop — do not retry more than once.

If the user declines, is silent, changes the subject, or gives ambiguous approval, do not submit. Do not invent facts that the user did not say. Do not include this command's own argument value verbatim if it contains anything that looks like a secret; ask the user to rephrase instead.
