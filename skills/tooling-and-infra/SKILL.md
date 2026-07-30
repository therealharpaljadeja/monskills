---
name: tooling-and-infra
description: Monad tooling and infrastructure provider support directory. Use this skill whenever a developer asks which tools, services, or infrastructure providers support Monad (mainnet or testnet), or needs to find an RPC provider, block explorer, oracle, bridge, indexer, wallet, onramp, custody solution, analytics tool, toolkit, or wallet infrastructure provider for Monad. Also use when a developer asks "does X support Monad?" or "what providers are available for Y on Monad?". Covers all categories from the official Monad docs tooling page.
---

# Monad Tooling & Infrastructure

Routing guide for finding which tooling and infrastructure providers support Monad mainnet, testnet, or both.

## How to use this skill

1. If the developer asks about a **category** (e.g. "what oracles support Monad testnet?"), fetch the relevant official Monad docs Markdown page from the routing table below before answering.
2. If the developer asks about a **specific provider** (e.g. "does Alchemy support Monad?"), fetch the most relevant official category page(s) below and answer only from the current docs content. If the provider is not listed there, say that you could not confirm support from the official Monad docs.
3. Use the `.md` URLs directly so agents receive Markdown instead of rendered HTML.

## Categories

The official Monad docs are the source of truth for provider lists, network support, and provider documentation. Read only the category page(s) relevant to the developer's question.

| Category | Official Markdown page | What it covers |
|----------|------------------------|----------------|
| Analytics | `https://docs.monad.xyz/tooling-and-infra/analytics.md` | On-chain monitoring, portfolio tracking, DeFi analytics, dashboards |
| Block Explorers | `https://docs.monad.xyz/tooling-and-infra/block-explorers.md` | Transaction explorers, contract verification, UserOp explorers |
| Cross-Chain | `https://docs.monad.xyz/tooling-and-infra/cross-chain.md` | Bridges, bridge aggregators, liquidity layers, AMBs, chain abstraction |
| Custody | `https://docs.monad.xyz/tooling-and-infra/custody.md` | Institutional-grade custody solutions |
| Indexers | `https://docs.monad.xyz/tooling-and-infra/indexers.md` | Common data APIs and indexing frameworks (subgraphs, data pipelines) |
| Onramps | `https://docs.monad.xyz/tooling-and-infra/onramps.md` | Fiat-to-crypto conversion, payment gateways |
| Oracles | `https://docs.monad.xyz/tooling-and-infra/oracles.md` | Price feeds, VRF, data feeds |
| RPC Providers | `https://docs.monad.xyz/tooling-and-infra/rpc-providers.md` | RPC endpoints for interacting with Monad |
| Toolkits | `https://docs.monad.xyz/tooling-and-infra/toolkits.md` | Development frameworks and SDKs |
| Wallets | `https://docs.monad.xyz/tooling-and-infra/wallets.md` | Software wallets, hardware wallets, institutional wallets, multisig wallets |
| Wallet Infrastructure | `https://docs.monad.xyz/tooling-and-infra/wallet-infra.md` | Embedded wallets, account abstraction, smart accounts |

## Important notes

- Provider support can change. Treat the official Monad docs Markdown pages as the current baseline, then suggest the developer confirm final integration details in the provider's own docs.
- Some providers listed as mainnet-only may add testnet support later (and vice versa).
- "Pending" status (marked with a clock icon) means the provider has announced support but it's not yet live.
