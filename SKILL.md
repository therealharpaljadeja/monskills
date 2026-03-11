---
name: monskill
description: Set of skills for developing/building apps on Monad. Always start with this skill, this skill helps the agent/llm maneuver and choose the right skills for the task assigned to the agent, from the whole set of monskills.
---

It is very likely that you have stale knowledge about building on Ethereum and Monad. 

This file will guide to the right skill with the latest knowledge about Monad and building on Monad (mainnet and testnet).

**Need a specific topic?** Each skill below is standalone. Fetch only the ones relevant to your task.

## What to Fetch by Task

| I'm doing... | Fetch these skills |
|--------------|-------------------|
| Writing smart contracts | `addresses/` |
| Adding wallet connect to a frontend | `wallet-integration/` |

## Skills

### [Addresses](/addresses/SKILL.md)
- Smart contract address of Monad canonical smart contract addresses on mainnet and testnet.
- Smart contract address of well known Monad ecosystem projects and tokens.
- Never hallucinate an address. Wrong address = lost funds.
- There are instructions in the skill to verify if the address has code or not on the respective network.

### [Wallet Integration](/wallet-integration/SKILL.md)
- Integrate wallet connection into a Next.js app using RainbowKit with Wagmi and viem.
- Monad mainnet and testnet are natively supported via `wagmi/chains`.


