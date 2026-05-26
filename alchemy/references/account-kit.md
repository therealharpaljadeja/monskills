# Account Kit on Monad (ERC-4337 Smart Accounts)

Alchemy Account Kit creates ERC-4337 smart accounts on Monad. The primary use case in this skill is the **agent-controlled wallet** path: the agent (or your script) operates a smart account to deploy contracts and run onchain actions, with sponsored gas (Gas Manager), session keys for scoped delegation, and batch operations. This is an alternative or complement to the Safe multisig pattern in monskills' [`wallet/`](../../wallet/SKILL.md).

Account Kit also supports building end-user smart wallets in a frontend, but that is a different integration shape and is **not** the focus of this reference. monskills handles that path via [`wallet-integration/`](../../wallet-integration/SKILL.md) (Para), which gives users embedded MPC wallets with email / social / passkey login. Stick with `wallet-integration/` for end-user frontends and use this skill for the agent's own wallet.

Reach for Account Kit when you want:

- Sponsored gas: the policy (your app, or the agent) pays so the operator does not need to hold MON
- Session keys: scoped, time-bound delegation to an agent or signer
- Batch operations: multiple calls in one signed transaction
- Gasless onboarding: deploy the smart account on first action; the paymaster can cover the deployment gas

Safe multisig still makes sense for high-value treasury operations. Smart accounts make sense for agent-controlled execution. They coexist.

## Stack

```
┌─────────────────────────────────────────────────┐
│  Your app                                       │
│    └─ @alchemy/account-kit / @alchemy/aa-*      │  SDK (signs UserOperations)
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│  Alchemy Bundler (Monad)                        │  Submits UserOperations → EntryPoint
│  https://monad-mainnet.g.alchemy.com/v2/<KEY>   │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│  ERC-4337 EntryPoint (Monad mainnet)            │  Canonical contract
│  v0.7: 0x0000000071727De22E5E9d8BAf0edAc6f37da032│  (see monskills' addresses/)
│  v0.6: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789│
└─────────────────────────────────────────────────┘
```

Alchemy provides the Bundler endpoint. The EntryPoint contracts are deployed canonically on Monad — see [`addresses/`](../../addresses/SKILL.md) for verified addresses.

## Modular Account v2 (recommended)

Alchemy's default smart-account implementation is **Modular Account v2** — an ERC-6900-compatible modular account with:

- Native session keys
- Batch / multicall execution
- Permission modules (allow-lists, value caps, time bounds)
- Migration path from prior account templates

Address derivation: `keccak256(factory, signer, salt)` — deterministic, so you can compute the smart-account address before deploying it.

## End-to-end flow

### 1. Install the SDK

```bash
npm install @alchemy/aa-core @alchemy/aa-alchemy
# or your preferred AA SDK package — see https://www.alchemy.com/docs/wallets
```

### 2. Configure the Monad transport

```typescript
import { createAlchemySmartAccountClient } from "@alchemy/aa-alchemy";
import { LocalAccountSigner } from "@alchemy/aa-core";
import { monad } from "viem/chains"; // or define manually

const client = createAlchemySmartAccountClient({
  chain: monad,
  rpcUrl: "https://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>",
  signer: LocalAccountSigner.privateKeyToAccountSigner("0x..."),
  gasManagerConfig: { policyId: "<POLICY_ID>" }, // optional, for sponsored gas
});
```

The `rpcUrl` doubles as the bundler endpoint on Alchemy — the same URL serves JSON-RPC and Bundler routes.

### 3. Send a sponsored UserOperation

```typescript
const uoHash = await client.sendUserOperation({
  uo: { target: "0x<contract>", data: "0x<calldata>", value: 0n },
});
const txHash = await client.waitForUserOperationTransaction({ hash: uoHash });
```

If `gasManagerConfig.policyId` is set and the policy permits the call, the paymaster sponsors it. The signer doesn't need MON.

### 4. Verify on-chain

```bash
cast tx <txHash> --rpc-url https://monad-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY
```

Or `eth_getTransactionReceipt` via raw RPC.

## Migrating from monskills' `wallet/` (Safe multisig)

The Safe multisig pattern in [`wallet/`](../../wallet/SKILL.md) and the smart-account pattern here are complementary, not exclusive:

| Use case | Use |
| --- | --- |
| Treasury / high-value approvals requiring multiple humans | Safe multisig (`wallet/`) |
| Agent-controlled execution with sponsored gas, session keys, batch ops | Smart account (this skill) |
| Mixed (humans approve large moves, agent executes routine ops) | Both — Safe owns funds; agent operates a session-keyed smart account funded by the Safe |

If migrating an existing agent from Safe → Smart Account: the smart-account address is deterministic, so you can fund it before deployment. First UserOperation will deploy the account (paymaster can sponsor deployment too).

## EIP-7702 alternative (single-address smart wallet)

Monad supports EIP-7702 natively. EIP-7702 lets an **existing EOA** delegate to a smart-contract implementation — you keep the EOA address but gain smart-wallet features for the lifetime of the delegation. Trade-offs vs ERC-4337 smart accounts:

| | EIP-7702 (delegated EOA) | ERC-4337 (smart account) |
| --- | --- | --- |
| Address | Same as the EOA | New deterministic address |
| Replay safety | Per-chain nonce on the EOA | Per-account nonce on EntryPoint |
| Batch ops | Yes (via delegated impl) | Yes (native) |
| Gas sponsorship | Possible via BSO (see [`gas-manager.md`](./gas-manager.md)) | Native (Gas Manager) |
| Reserve balance | 10 MON floor still applies | 10 MON floor still applies |
| `CREATE`/`CREATE2` in delegated context | **Not available** — use canonical factories | Available |

If the user already has assets on an EOA and wants smart-wallet features without moving funds, EIP-7702 is the lighter path. See monskills' [`concepts/`](../../concepts/SKILL.md) → `eip-7702.md` for details.

## Where to go deeper

- Full Account Kit docs: https://www.alchemy.com/docs/wallets
- For Monad-specific gas cost implications when sponsoring, see [`./gas-manager.md`](./gas-manager.md)
