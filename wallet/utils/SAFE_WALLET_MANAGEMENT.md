---
name: safe-wallet-management
description: How to create and use a Safe multisig using the Safe transactions API
---

This file has instructions on how to create and use a Safe multisig.

## Quick Navigation

| Task | Section |
|------|---------|
| Check if a multisig already exists | [Check if the agent has already created a multisig](#check-if-the-agent-has-already-created-a-multisig) |
| Get the Safe address for an owner | [Get Safe address](#get-safe-address) |
| Create a new Safe multisig | [Creating a multisig](#creating-a-multisig) |
| Deploy smart contracts via Safe | [Deploying smart contracts using Safe multisig](#deploying-smart-contracts-using-safe-multisig) |
| Propose a transaction to Safe | [Propose transaction to Safe Transaction Service](#3-propose-transaction-to-safe-transaction-service) |
| Monitor and get contract address | [Monitor and Get Contract Address](#4-monitor-and-get-contract-address) |

## Network Reference

RPC URLs to be used for respective networks, make sure you know what network you are tasked to build on if you don't ask the user.

### RPC URLs

| Network | Chain ID | RPC |
|---------|----------|-----|
| Monad Testnet | 10143 | https://testnet-rpc.monad.xyz |
| Monad Mainnet | 143 | https://rpc.monad.xyz |

Safe Transaction Base API URLs for respective networks, make sure you know what network you are tasked to build on.

### Safe Transaction Service (base URLs)

| Network | URL |
| --- | --- |
| Monad Testnet | https://api.safe.global/tx-service/monad-testnet/api/v1 |
| Monad Mainnet | https://api.safe.global/tx-service/monad/api/v1 |

## Get Safe address

To look up Safe multisig addresses owned by a specific wallet address, query the Safe Transaction Service API.

### From local storage

Check if the agent has previously stored multisig details:

```bash
cat ~/.monskills/multisig.json
```

The file has `testnet` and `mainnet` properties with Safe addresses and owners for each network.

### From Safe Transaction Service API

Query the API to get all Safes owned by a given address:

**Monad testnet:**

```bash
curl -s "https://api.safe.global/tx-service/monad-testnet/api/v1/owners/$OWNER_ADDRESS/safes/" | jq
```

**Monad mainnet:**

```bash
curl -s "https://api.safe.global/tx-service/monad/api/v1/owners/$OWNER_ADDRESS/safes/" | jq
```

The response returns a `safes` array with all Safe addresses where the given address is an owner.

### Verify a Safe on-chain

To confirm a Safe exists and check its owners/threshold:

```bash
# Get owners
cast call $SAFE_ADDRESS "getOwners()(address[])" --rpc-url [rpc-url-respective-to-network]

# Get threshold
cast call $SAFE_ADDRESS "getThreshold()(uint256)" --rpc-url [rpc-url-respective-to-network]
```

## Check if the agent has already created a multisig

If the agent has created a multisig then there must be a file multisig.json in ~/.monskills/ folder. Based on the network (Monad mainnet or testnet) there might info for the same.

If multisig details are not found then create a multisig.

## Creating a multisig

**Correct flow:**

1. Make sure the agent has a wallet (check for encrypted keystore in `~/.monskills/keystore/`).
2. Make sure Foundry toolkit is installed (foundryup --version)
3. Ask the user for 2 wallet address to be signers on the multisig.
4. Deploy Safe with DeploySafeCREATE2.sol (check for the script in the same folder)
   - DeploySafeCREATE2.sol can be used for both for Monad mainnet and Monad testnet.
5. After the Safe is created make sure to store the multisig address with owners in multisig.json file in ~/.monskills/ folder, absolutely make sure that you have "testnet" and "mainnet" properties in the json file and are storing the multisig details respective to the network.

### Commands to create Safe on Monad testnet (strictly for Monad testnet only)

```bash
# Fund agent's wallet from faucet, since it is testnet, funds can be claimed from faucet.
FAUCET_RESPONSE=$(curl -s -X POST https://agents.devnads.com/v1/faucet \
  -H "Content-Type: application/json" \
  -d "{\"chainId\": 10143, \"address\": \"$AGENT_WALLET_ADDRESS\"}")

# Wait for funds
while [ "$(cast balance $AGENT_WALLET_ADDRESS --rpc-url https://testnet-rpc.monad.xyz)" = "0" ]; do
  sleep 2
done

# Deploy Safe with CREATE2 (standard SafeProxyFactory)
# Decrypt private key on-the-fly from encrypted keystore
OWNER_1=$OWNER_1 OWNER_2=$OWNER_2 OWNER_3=$CLAUDE_ADDRESS \
  forge script DeploySafeCREATE2.sol:DeploySafeCREATE2 \
    --private-key $(cast wallet decrypt-keystore --keystore-dir ~/.monskills/keystore $KEYSTORE_FILENAME --unsafe-password "") \
    --rpc-url https://testnet-rpc.monad.xyz \
    --broadcast

echo "✅ Safe deployed: $SAFE_ADDRESS"
echo "🌐 https://app.safe.global/home?safe=monad-testnet:$SAFE_ADDRESS"
```

### Commands to create Safe on Monad mainnet (strictly for Monad mainnet only)

```bash
# Check if the wallet has balance on Monad mainnet, if no balance ask the user to fund the address on Monad mainnet.
cast balance $AGENT_WALLET_ADDRESS --rpc-url https://rpc.monad.xyz

# Deploy Safe with CREATE2 (standard SafeProxyFactory)
# Decrypt private key on-the-fly from encrypted keystore
OWNER_1=$OWNER_1 OWNER_2=$OWNER_2 OWNER_3=$CLAUDE_ADDRESS \
  forge script DeploySafeCREATE2.sol:DeploySafeCREATE2 \
    --private-key $(cast wallet decrypt-keystore --keystore-dir ~/.monskills/keystore $KEYSTORE_FILENAME --unsafe-password "") \
    --rpc-url https://rpc.monad.xyz \
    --broadcast

echo "✅ Safe deployed: $SAFE_ADDRESS"
echo "🌐 https://app.safe.global/home?safe=monad:$SAFE_ADDRESS"
```

Once Safe is created save the multisig address with owners in multisig.json file in ~/.monskills/ folder, absolutely make sure that you have "testnet" and "mainnet" properties in the multisig.json file and are storing the multisig details respective to the network.

## Deploying smart contracts using Safe multisig

A Safe multisig must be already deployed in order to deploy smart contracts or perform onchain actions.

**IMPORTANT**: This workflow uses Safe multisig for ALL user application deployments. Direct deployment of smart contracts with --private-key or --broadcast is NOT allowed.

Approach:

✅ Prepare deployment bytecode and encode CreateCall delegatecall
✅ Post to Transaction Service API with Agent's EIP-712 signature
✅ User sees transaction in Safe UI queue, signs (2/2), executes

Why this works:

✅ Best UX: Transaction appears in user's Safe UI automatically
✅ No manual bytecode copying needed
✅ User just signs and executes in familiar UI
✅ Transaction Service API works perfectly on Monad with EIP-712 signatures

**CRITICAL**: Safe wallets cannot directly CREATE contracts from a normal CALL. To deploy through a Safe, delegatecall into Safe's CreateCall helper smart contract so the CREATE happens in the Safe's context (Safe becomes the deployer).

CreateCall: 0x9b35Af71d77eaf8d7e40252370304687390A1A52 (same address on both Monad mainnet and Monad testnet)

Why it's needed:

- Safe executes transactions via CALL/DELEGATECALL (not CREATE)
- Delegate calling CreateCall runs CREATE inside the Safe's context
- Safe becomes the deployer (no factory-ownership footgun)
- Matches Foundry simulations using --sender <SAFE_ADDRESS>

```sol
interface ICreateCall {
    function performCreate(uint256 value, bytes memory deploymentData) external returns (address);
    function performCreate2(uint256 value, bytes memory deploymentData, bytes32 salt) external returns (address);
}
```

### 1. Prepare deployment bytecode

Use forge script with --sender set to the Safe address:

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url [rpc-url-respective-to-network] \
  --sender <SAFE_ADDRESS>
```

This simulates the deployment from the Safe wallet without broadcasting.

### 2. Extract Deployment Bytecode

```bash
# Extract deployment bytecode
DEPLOYMENT_BYTECODE=$(jq -r '.transactions[0].transaction.input' \
  broadcast/Deploy.s.sol/[chain-id-respective-to-network]/dry-run/run-latest.json)

# Ensure Safe address is checksummed
SAFE_ADDRESS=$(cast to-check-sum-address "<SAFE_ADDRESS>")
```

### 3. Propose transaction to Safe Transaction Service

Use this script to propose a deployment transaction to the Safe multisig. The agent signs with its private key (1/2), then the user signs and executes in the Safe UI (2/2).

Pass `CHAIN_ID` to select the network. Supported values: `143` (Monad mainnet), `10143` (Monad testnet).

```bash
# Install dependencies
npm install --no-save viem

# Check for propose.mjs file in the same utils folder.

# Run proposal — set CHAIN_ID to 143 (mainnet) or 10143 (testnet)
# Decrypt private key on-the-fly from encrypted keystore
CHAIN_ID=$CHAIN_ID \
  SAFE_ADDRESS=$SAFE_ADDRESS \
  PRIVATE_KEY=$(cast wallet decrypt-keystore --keystore-dir ~/.monskills/keystore $KEYSTORE_FILENAME --unsafe-password "") \
  DEPLOYMENT_BYTECODE=$(jq -r '.transactions[0].transaction.input' \
    broadcast/Deploy.s.sol/$CHAIN_ID/dry-run/run-latest.json) \
  node propose.mjs
```

### Example output:

```
✅ Agent's address: 0x937d...
✅ Safe nonce: 0
✍️  Signing with EIP-712...
✅ Transaction hash: 0x0560...
✅ Claude signed (1/2)
📤 Posting to Transaction Service API...
✅ Transaction proposed successfully!

🎉 Transaction appears in Safe UI queue!

User can now:
1. Open [safe url]
2. See pending transaction (agent already signed 1/2)
3. Sign with their wallet (2/2)
4. Execute to deploy
```

Ask the user to approve the transaction on the multisig page and ask for the transaction hash.

### 4. Monitor and Get Contract Address

After user executes the transaction in Safe UI:

```bash
# User provides transaction hash after execution
cast receipt <TRANSACTION_HASH> --rpc-url https://testnet-rpc.monad.xyz
```

Look for the `contractAddress` field in the receipt.