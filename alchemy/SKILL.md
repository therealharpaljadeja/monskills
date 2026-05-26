---
name: alchemy
description: Use Alchemy on Monad mainnet for the agent-controlled wallet. An ERC-4337 smart account that the monskills agent operates to deploy contracts and run onchain actions, with Alchemy's Bundler executing UserOperations and Gas Manager (paymaster) sponsoring the gas. Fetch this skill whenever the agent needs to deploy a contract, send a transaction, or batch onchain actions on Monad. For end-user embedded wallets in a frontend (email, Google, X, passkey, social login), use `wallet-integration/` (Para) instead.
---

# Alchemy Agent Wallet on Monad

This skill provides an **ERC-4337 smart-account wallet** that the monskills agent operates on Monad mainnet. It is the path for deploying contracts and running onchain actions from inside an agent loop, with Alchemy's Bundler executing UserOperations and Gas Manager (paymaster) sponsoring the gas. The agent operator does not need to hold MON.

## When to fetch this skill

- The agent needs a wallet to **deploy a contract** on Monad mainnet
- The agent needs to **send a transaction** (call a contract method, transfer tokens, etc.) on Monad
- You want the agent's transactions to be **sponsored** so the wallet does not need to hold MON to operate
- You want **session keys**, **batch operations**, or **gasless onboarding** for the agent's flow

## When to fetch a different skill

| Need | Fetch instead |
| --- | --- |
| End-user embedded wallets in a frontend (email, Google, X, passkey, social login) | `wallet-integration/` (Para) |
| Monad-specific concepts (async execution, EIP-7702, block states, reserve balance) | `concepts/` |
| Gas pricing rules on Monad. `gas_limit` is what users (and paymaster policies) pay, not `gas_used` | `gas/` |
| Canonical contract addresses (ERC-4337 EntryPoint v0.6 / v0.7, Safe, Multicall3, Permit2) | `addresses/` |
| Indexing onchain events on Monad | `indexer/` |

## Stack

```
┌─────────────────────────────────────────────────┐
│  Agent / script                                 │
│    └─ @alchemy/aa-* SDK                         │  Signs UserOperations
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│  Alchemy Bundler (Monad)                        │  Submits UserOperations
│  https://monad-mainnet.g.alchemy.com/v2/<KEY>   │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│  ERC-4337 EntryPoint (Monad mainnet)            │  Canonical contract
│  v0.7: 0x0000000071727De22E5E9d8BAf0edAc6f37da032│  (see addresses/)
└─────────────────────────────────────────────────┘
```

## End-to-end agent wallet flow

1. **Get an API key** at https://dashboard.alchemy.com (free tier works for hackathons)
2. **Install the SDK**: `npm install @alchemy/aa-core @alchemy/aa-alchemy`
3. **Create a Gas Manager policy** in the Alchemy dashboard, scoped to Monad mainnet, and capture the Policy ID
4. **Configure the smart-account client** with the Monad endpoint, an EOA signer, and the Policy ID:

```typescript
import { createAlchemySmartAccountClient } from "@alchemy/aa-alchemy";
import { LocalAccountSigner } from "@alchemy/aa-core";
import { monad } from "viem/chains";

const client = createAlchemySmartAccountClient({
  chain: monad,
  rpcUrl: "https://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>",
  signer: LocalAccountSigner.privateKeyToAccountSigner("0x..."),
  gasManagerConfig: { policyId: "<POLICY_ID>" },
});
```

5. **Send a sponsored UserOperation.** The bundler and paymaster handle sponsorship. The signer does not need MON.

```typescript
const uoHash = await client.sendUserOperation({
  uo: { target: "0x<contract>", data: "0x<calldata>", value: 0n },
});
const txHash = await client.waitForUserOperationTransaction({ hash: uoHash });
```

The first UserOperation deploys the smart account (sponsored too if the policy allows). All subsequent operations run from the deployed account.

> **Monad gotcha:** Monad charges users for `gas_limit`, not `gas_used`. Since the paymaster pays for the agent wallet's transactions, **over-estimated gas limits drain the policy faster than on Ethereum**. Set tight estimates. See [`gas/`](../gas/SKILL.md).

## References

- [`./references/account-kit.md`](./references/account-kit.md). Smart account setup details, signer options, Modular Account v2 specifics, EIP-7702 alternative.
- [`./references/gas-manager.md`](./references/gas-manager.md). Paymaster policies, sponsorship modes, ERC-20 gas payments, BSO (Bundler Sponsorship), Monad-specific cost implications.

## Source

Authored by Alchemy under MIT.
