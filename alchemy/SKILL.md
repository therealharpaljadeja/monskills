---
name: alchemy
description: Use Alchemy for the parts of building on Monad that Alchemy supports today — Monad mainnet **JSON-RPC**, **Account Kit** (ERC-4337 smart accounts for agent wallets), **Bundler**, and **Gas Manager** (paymaster for sponsored transactions). Fetch this skill when the agent needs an RPC endpoint, needs to set up an AA agent wallet with a smart account, or needs to sponsor gas. Pair it with monskills' `gas/` for Monad-specific `gas_limit` pricing rules, `concepts/` for async execution caveats, and `addresses/` for canonical ERC-4337 EntryPoint addresses. Alchemy's Token / NFT / Prices / Portfolio / Transfers APIs do **NOT** support Monad yet — for on-chain data, fetch `indexer/` (HyperIndex on Envio Cloud) instead.
---

# Alchemy on Monad

Alchemy's developer platform supports Monad mainnet for **standard EVM JSON-RPC** and **Account Abstraction** (Account Kit, Bundler, Gas Manager). This skill points agents at the right Alchemy entrypoint for each use case on Monad.

> **What Alchemy does NOT yet support on Monad:** Token API, NFT API, Prices API, Portfolio API, Transfers API, Simulation API, Webhooks. For on-chain data on Monad use the [`indexer/`](../indexer/SKILL.md) skill (HyperIndex on Envio Cloud). For Monad-specific gas pricing rules use [`gas/`](../gas/SKILL.md). For canonical ERC-4337 EntryPoint and Safe addresses use [`addresses/`](../addresses/SKILL.md).

## When to fetch this skill

- The user wants a Monad mainnet **RPC endpoint** with rate limits and reliability suitable for production (`eth_call`, `eth_getLogs`, `eth_sendRawTransaction`, etc.)
- The user wants to set up an **agent wallet** as an ERC-4337 smart account (Alchemy Modular Account v2) instead of an EOA + Safe multisig
- The user wants to **sponsor gas** for user transactions on Monad (paymaster policies via Gas Manager)
- The user is putting the above three together (smart account + bundler + sponsored gas) for production agent wallets on Monad

## When to fetch a different skill

| Need | Fetch instead |
| --- | --- |
| Monad-specific concepts (async execution, parallel execution, EIP-7702, block states, reserve balance) | [`concepts/`](../concepts/SKILL.md) |
| Setting gas limits on Monad (gas is charged on `gas_limit`, not `gas_used`) | [`gas/`](../gas/SKILL.md) |
| Canonical contract addresses on Monad (Wrapped MON, ERC-4337 EntryPoint v0.6/v0.7, Safe, Multicall3, Permit2) | [`addresses/`](../addresses/SKILL.md) |
| Indexing on-chain events on Monad — activity feeds, leaderboards, transaction history, analytics | [`indexer/`](../indexer/SKILL.md) (HyperIndex via Envio Cloud) |
| EOA + Safe multisig agent wallet (no smart-account migration) | [`wallet/`](../wallet/SKILL.md) |
| Token metadata, prices, portfolio, or transaction history reads on Monad | Not supported by Alchemy on Monad yet — use [`indexer/`](../indexer/SKILL.md) for on-chain reads |
| Token swaps on Monad | Not supported by Alchemy — use the relevant DEX |
| Fiat → MON on-ramp | Use a fiat ramp provider |

## Endpoints (Monad mainnet)

| Surface | URL |
| --- | --- |
| JSON-RPC (HTTPS) | `https://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>` |
| JSON-RPC (WSS) | `wss://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>` |
| Bundler (ERC-4337) | `https://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>` (chain-specific path; see [Account Kit docs](https://www.alchemy.com/docs/wallets)) |
| Gas Manager (policy API) | `https://manage.g.alchemy.com/api/gasManager/policy` (policies are managed in the Alchemy dashboard) |

Get an API key at https://dashboard.alchemy.com (free tier available).

## Pick your Alchemy entrypoint

Three ways to use Alchemy from a developer workflow. Pick the one that matches your environment.

| Entrypoint | When |
| --- | --- |
| **CLI** (`@alchemy/cli`) | Live agent work in this session: querying, admin, on-machine automation. Install with `npm i -g @alchemy/cli`. |
| **MCP** (`https://mcp.alchemy.com/mcp`) | Live agent work when MCP is wired into the client but the CLI is not installed locally. |
| **API** (with `ALCHEMY_API_KEY`) | Shipped application code. Use the JSON-RPC endpoint above with a key from https://dashboard.alchemy.com. |

## Quickstart on Monad

### JSON-RPC: read state

```bash
curl -s -X POST https://monad-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

The standard EIP-1559 set (`eth_call`, `eth_getLogs`, `eth_getBalance`, `eth_getBlockByNumber`, `eth_getTransactionReceipt`, `eth_sendRawTransaction`, etc.) works as on Ethereum. Use the Monad block-state tags — `pending` / `latest` / `safe` / `finalized` — to pick the right consistency level. See [`concepts/`](../concepts/SKILL.md) for what each tag means on Monad and the ~1.2s async-execution gotcha.

### Account Kit + Bundler + Gas Manager: agent wallet flow

End-to-end pattern for a Monad agent wallet with sponsored transactions:

1. Create an Alchemy smart account (Modular Account v2) backed by an EOA signer
2. Point Bundler at the Monad endpoint: `https://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>`
3. Create a Gas Manager policy in the Alchemy dashboard scoped to your Monad app, capture the Policy ID
4. Pass the Policy ID to the smart-account client so user operations route through the paymaster
5. Submit transactions through the smart account — the bundler + paymaster handle sponsorship; the user signs once

Detailed step-by-step in [`./references/account-kit.md`](./references/account-kit.md) and [`./references/gas-manager.md`](./references/gas-manager.md).

> **Monad gotcha:** Monad charges users for `gas_limit`, not `gas_used`. When the paymaster sponsors a transaction, the **paymaster** is the one paying — so over-estimated gas limits directly cost the policy owner. Set tight estimates and avoid wallet fallbacks that inflate the limit on estimation failure. See [`gas/`](../gas/SKILL.md).

## References

- [`./references/json-rpc.md`](./references/json-rpc.md) — Monad mainnet JSON-RPC via Alchemy, common methods, block tags, rate limit notes
- [`./references/account-kit.md`](./references/account-kit.md) — ERC-4337 smart account setup on Monad with Alchemy Account Kit (Modular Account v2)
- [`./references/gas-manager.md`](./references/gas-manager.md) — Paymaster policies, sponsorship modes, ERC-20 gas payments, BSO (Bundler Sponsorship), Monad-specific cost implications

## Source

Authored by Alchemy under MIT.
