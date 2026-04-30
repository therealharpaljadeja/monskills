---
name: wallet-integration
description: How to add wallet connection and authentication to an existing Monad frontend using Para — embedded MPC wallets with email / phone / passkey / social login, plus external-wallet connect (MetaMask, Coinbase, WalletConnect, Rainbow, etc.). Driven by the `para` CLI (`@getpara/cli`). Fetch when the user wants to integrate Para into an existing Next.js or Vite frontend, or manage Para projects, API keys, and webhooks from the terminal. This is monskills' canonical wallet-integration skill — there is no separate skill for "social login" or "embedded wallets," it's all here.
---

# Wallet Integration (Para)

This skill covers adding wallet + authentication to the frontend of a Monad project using **Para** and the `para` CLI (`@getpara/cli`).

Para gives users embedded MPC wallets — they sign in with email, phone, passkey, or a social provider (Google, Apple, Twitter, Discord, Facebook, Farcaster) and instantly have a wallet, no browser extension required. It also supports connecting external wallets (MetaMask, Coinbase, WalletConnect, Rainbow, Zerion, Rabby) for users who already have one. The same `ParaProvider` handles both flows.

This skill assumes the frontend already exists (typically scaffolded by the `scaffold/` skill into `web/`). It does **not** scaffold a new app — Para's `para create` template is intentionally out of scope here, since the project scaffold is handled elsewhere.

## When to fetch this skill

- The user wants any wallet connect / sign-in flow on their frontend, on Monad mainnet or testnet.
- The user wants embedded wallets, social login, email/SMS login, or passkey login.
- The user has an existing frontend (Next.js or Vite) and wants to add Para to it (`para init` + `ParaProvider` + `para doctor`).
- The user wants to manage Para API keys, environments, webhooks, branding, or auth methods from the CLI.
- The user wants to debug a wallet integration that isn't working (`para doctor`).

## Monad on Para

Para's `--networks` flag supports `evm`. Monad mainnet and Monad testnet are EVM chains, so they fit the EVM template — but Para doesn't ship Monad as a built-in chain object. After `para init`, you wire Monad into the wagmi config that Para's provider consumes: import `monad` and `monadTestnet` from `wagmi/chains` and pass them in. See `references/para-monad-wiring.md` for the exact code edits.

## Prerequisites

Before any `para` command will work, the user must have all of these in place:

1. `@getpara/cli` installed globally: `npm install -g @getpara/cli` (or `pnpm add -g @getpara/cli`, or run via `npx @getpara/cli@latest`).
2. `para` logged in: `para login` (browser OAuth flow — only the user can complete it).
3. A Para organization and project selected as active context. After `para login`, the CLI auto-selects the first org and project; switch with `para orgs switch` / `para projects switch` if needed.

The monskills hook gates `para` commands on install + login. If a prereq is missing, the hook denies the tool call with the exact missing piece — surface that message to the user and wait.

### What NOT to do

- **Do not install the CLI for the user.** If `@getpara/cli` is missing, tell them the exact command and wait.
- **Do not run `para login` for the user.** It opens a browser tab and only the user can complete the OAuth flow. (`--no-browser` exists for headless setups, but monskills is for interactive use — let the user choose.)
- **Do not create a Para account or API key for the user via the web portal.** The CLI handles project + key creation — guide them through it.
- **Do not run `para create`.** Project scaffolding is handled by the `scaffold/` skill; this skill only integrates Para into a frontend that already exists.

## Integrate Para into the existing frontend

```bash
cd web   # or wherever the frontend lives
para init
```

`para init` writes `.pararc` (org + project + environment context), then you install the SDK packages, wrap the app in `ParaProvider`, and import Para's CSS. After wiring, run `para doctor` to verify nothing is missing.

See `references/para-workflows.md` → "Integrate Para into the existing frontend" for the exact code edits, package list, and `para doctor` debugging loop.

## Where to look next

Reference files — fetch on demand:

- [Workflow recipes](./references/para-workflows.md) — opinionated sequences for: integrating Para into the existing frontend, rotating an API key, configuring auth methods/branding/webhooks via `para keys config`, debugging with `para doctor`.
- [CLI reference](./references/para-cli.md) — every `para` command grouped by area (auth, config, orgs/projects, keys, diagnostics) with notes on flags and gotchas.
- [Monad wiring](./references/para-monad-wiring.md) — the exact post-`para init` edits to add Monad mainnet + testnet to the wagmi config that Para's provider consumes. Apply this after every Para integration.

Start with the workflow recipe that matches the user's goal. Drop into the CLI reference only when you need a flag or subcommand not covered there.

## Exit-code contract

Every `para` command follows the same convention — check exit codes, not just stdout:

| Exit code | Meaning | How to react |
|---|---|---|
| `0` | Success | Continue |
| `1` | User error (bad args, not logged in, unknown project, `para doctor` found errors with `--json`) | Read stderr, fix the input, retry |
| `2` | API/server error | Not the user's fault. Retry once; if it persists, tell the user and stop. |

`para doctor --json` exits 1 when it finds errors — that's expected behaviour, not a CLI bug. Use it as the signal that the integration has issues.

## Secrets hygiene

- `para keys get --show-secret` and `para keys get --copy-secret` print/copy the **secret** API key. Never echo the value back to the user in your response, and never paste it into a file you commit. The public key (no flag) is fine to include in `.env.local` under a `NEXT_PUBLIC_PARA_API_KEY` (or framework-equivalent) prefix.
- Always check the env-var prefix matches the framework before writing the key: `NEXT_PUBLIC_` for Next.js, `VITE_` for Vite. `para doctor` flags mismatches.
- `.pararc` is safe to commit (it only stores org/project IDs and environment, no secrets). `.env`/`.env.local` should be in `.gitignore`.

## Official docs

- CLI overview: https://docs.getpara.com/v2/cli/overview
- Installation: https://docs.getpara.com/v2/cli/installation
- Command reference: https://docs.getpara.com/v2/cli/commands
