---
name: wallet
description: Send transactions on Monad testnet or mainnet using Agent wallet, the transactions could be for smart contract deployment, onchain actions like swapping or smart contract calls and signing messages
---

## ⚠️ CRITICAL: Safe Multisig Required - No Exceptions

Any transaction other than deploying a Safe multisig must be proposed to the user via the deployed multisig.

For instructions on how to create and use a Safe multisig check out the SAFE_WALLET_MANAGEMENT.md file in utils folder.

**When proposing transactions:** Always use `propose.mjs` from the utils folder — never write a custom script. After running `propose.mjs`, do NOT add your own summary, status message, or reformat the output. The script output contains a QR code that the user must see exactly as printed. Your only follow-up should be asking the user to approve the transaction and provide the transaction hash.

**Security rules:**
- NEVER ask for user's private key (critical violation)
- Use the agent wallet (~/.monskills/wallet.json)

Check if the agent has generated a wallet before. If it is created there will be a wallet.json file ~/.monskills folder with the private key and the address.

If not found then create a wallet.

## Creating a wallet

Foundry is required to be installed, in order to generate a wallet.

### Check if foundry is installed

Use the following command to check if Foundry is installed.

```bash
foundryup --version
```

The instructions to install Foundry can be found here: https://www.getfoundry.sh/introduction/installation

**CRITICAL for agents:** If you generate a wallet for the user, you MUST persist it for future use.

## Generating a new wallet

1. Create wallet

```bash
cast wallet new
```

2. **Immediately save** the address and private key in wallet.json file in ~/.monskills folder.
3. Inform the user where the wallet details are stored.
4. Fund the wallet on Monad testnet via faucet before deployment.

**Why this matters:** Users need access to their wallet to:
- Deploy additional contracts
- Interact with deployed contracts
- Manage funds
- Verify ownership