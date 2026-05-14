# Gas Manager on Monad (Paymaster Policies)

Alchemy Gas Manager is the **paymaster** layer on top of the Alchemy Bundler. You create a policy in the dashboard, scope it (chain, contract, method, address allowlist, value cap, time bound, etc.), and pass the Policy ID to the smart-account client. Matching UserOperations are sponsored — the policy owner pays, the user signs without holding MON.

## Primary use cases on Monad

- **Gasless onboarding** — new user mints their first NFT or sets up an agent wallet without holding MON
- **Sponsor specific methods or contracts** — only your app's calls get sponsored, not arbitrary ones
- **Pay gas with any token** — accept USDC, USDT, etc. as gas payment via post-operation or pre-operation modes (see "ERC-20 token gas payments" below)
- **BSO (Bundler Sponsored Operations)** for EIP-7702 undelegation — covers the gas to revoke a 7702 delegation

## Setup

### 1. Create a policy in the Alchemy dashboard

https://dashboard.alchemy.com → Gas Manager → New Policy

Configure:

- **Chain:** Monad mainnet
- **Sponsorship rules:** address allowlist, contract/method allowlist, max gas per UserOperation, max spend per user/day, time bounds
- **Funding source:** the policy is funded with MON (or USDC if the policy uses ERC-20 mode)

Capture the **Policy ID** — you'll pass it to the smart-account client.

### 2. Pass the Policy ID to the SDK

```typescript
import { createAlchemySmartAccountClient } from "@alchemy/aa-alchemy";

const client = createAlchemySmartAccountClient({
  chain: monad,
  rpcUrl: "https://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>",
  signer,
  gasManagerConfig: { policyId: "<POLICY_ID>" },
});
```

That's it. UserOperations submitted through this client will route through the paymaster. If the policy denies (out of allowance, address not in allowlist, etc.), the Bundler rejects with a clear `AA*` error.

### 3. Verify the policy is sponsoring

```typescript
const uoHash = await client.sendUserOperation({ uo: { target, data, value: 0n } });
const tx = await client.waitForUserOperationTransaction({ hash: uoHash });
// Inspect the receipt — the `paymaster` field will be Alchemy's paymaster address
```

## ERC-20 token gas payments

Two modes — choose based on whether your operations may revert:

| Mode | When the token is collected | Revert behavior | Use when |
| --- | --- | --- | --- |
| **Post-operation** | After the user op executes | If the batch reverts AND the approval was batched, the approval is also reverted. The paymaster can't collect — **you pay the gas cost without compensation.** | Operations are unlikely to revert. Works with all ERC-20 tokens. |
| **Pre-operation** | Before the user op executes | Tokens are transferred up-front, paymaster always compensated | Operations may revert. Use this for risky calls. |

If a sufficient ERC-20 allowance already exists (e.g. from earlier threshold-mode setup), the paymaster collects payment even if the batch reverts — this is the safest mode for production.

## BSO (Bundler Sponsored Operations)

BSO sponsors the **bundler-level** UserOperation directly, without a separate Gas Manager policy. The main current use case is **EIP-7702 undelegation** — covering gas to revoke a 7702 delegation when the user can't be expected to hold MON for it.

BSO chain support is "every chain that has both bundler and gas sponsorship". Confirm Monad inclusion in the live [supported-chains matrix](https://www.alchemy.com/docs/wallets/supported-chains) before depending on it.

## Monad-specific cost implications

> **Read this before launching a sponsored flow on Monad.**

Monad charges users for `gas_limit`, not `gas_used`. When the paymaster sponsors a transaction, **the paymaster is the user from a billing perspective**. That means:

1. **Over-estimated gas limits drain the policy faster than on Ethereum.** If your SDK estimates 500k gas and the call only uses 200k, on Ethereum you'd pay for 200k. On Monad you pay for 500k.

2. **Wallet fallback behavior matters.** Some wallets fall back to a very high default gas limit (10M+) when `eth_estimateGas` reverts (e.g., because the call would fail). On Monad that's a real charge. Always set `gasLimit` explicitly in the UserOperation for known-cost calls.

3. **Cold state access is 3-4× and precompiles 2-5× more expensive on Monad.** ZK-verification-heavy sponsored ops (`ecMul`, `ecPairing`) cost 5× the gas you'd expect from Ethereum benchmarks. Re-estimate against Monad before setting policy spend caps. See [`gas/`](../../gas/SKILL.md) for the full opcode/precompile repricing table.

### Operational guidelines

- **Tight `callGasLimit`** — match it to actual usage; rely on simulation rather than fallback estimation.
- **Pre-validation guards** in the policy — allowlist methods/contracts so only sane calls reach the paymaster.
- **Daily caps per user** — limits the blast radius of misconfigured estimation.
- **Monitor for abuse** — Gas Manager dashboard surfaces per-policy sponsorship. Set alerts on anomalous spend.

## Reference

- [Gas Manager Admin API](https://www.alchemy.com/docs/wallets/low-level-infra/gas-manager/policy-management/api-endpoints) — programmatic policy CRUD
- [Pay Gas With Any Token](https://www.alchemy.com/docs/wallets/transactions/pay-gas-with-any-token) — ERC-20 mode setup
- [Wallet APIs supported chains](https://www.alchemy.com/docs/wallets/supported-chains) — live matrix of which AA features work where
