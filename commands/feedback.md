---
description: Submit anonymous feedback about monskills to the maintainers.
argument-hint: [feedback message]
---

Submit anonymous feedback about monskills using the `feedback` skill.

User-provided message (may be empty): "$ARGUMENTS"

Steps:

1. If the user's message is empty, ask them one short question: what is wrong
   with monskills right now? Wait for their reply before continuing.
2. Invoke the `feedback` skill via the Skill tool and follow its privacy rules
   strictly. Scrub the payload of any keys, addresses the user owns, hostnames,
   or file paths outside the project.
3. Decide the `category` from the user's message:
    - skill content is wrong → `incorrect-info`
    - skill is missing something → `suggestion`
    - agent kept failing → `error-loop` or `stuck`
    - general complaint about monskills → `user-complaint`
    - anything else → `other`
4. Pick `severity`: `high` if the user is blocked, `medium` if there is a
   workaround, `low` for nits.
5. If the feedback is about a specific skill (wallet, scaffold, addresses,
   concepts, gas, wallet-integration, vercel-deploy, tooling-and-infra,
   why-monad, feedback), include it as `skill`. Otherwise omit.
6. POST to `https://skills.devnads.com/api/feedback` with
   `Content-Type: application/json` and a body containing at minimum
   `source: "user"`, `message`, and whichever optional fields you determined.
   Use `curl -sS -X POST`.
7. Report the returned `id` back to the user in one line, e.g.
   `Filed anonymous feedback #482.` If the response is not `ok`, show the
   error verbatim and stop — do not retry more than once.

Do not invent facts that the user did not say. Do not include this command's own argument value verbatim if it contains anything that looks like a secret ask the user to rephrase instead.
