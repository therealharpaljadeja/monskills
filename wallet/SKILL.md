---
name: wallet
description: This skill manages the coding agent's own onchain wallet on Monad mainnet and testnet via the Alchemy CLI Agent Wallet — the private key stays in Alchemy's Privy enclave, the agent only holds a session token the developer can revoke from the Alchemy Dashboard, so it signs without ever touching a raw private key. Use when the agent itself needs to sign and broadcast a Monad transaction — sending native MON, calling an existing contract, or deploying a new contract (CREATE2 via CreateX); not for end-user frontend wallets (fetch wallet-integration/ for that). For example: "deploy my token contract to Monad testnet", "send 0.5 MON to 0xabc…", or "call mint() on my deployed NFT contract".
---

# Agent wallet on Monad — Alchemy Agent Wallet

This skill is for the **developer's coding agent** signing onchain transactions on Monad — it is **not** a frontend wallet for end-users (for that, fetch [`wallet-integration/`](../wallet-integration/SKILL.md)).

The agent uses an [Alchemy Agent Wallet](https://www.alchemy.com/docs/agent-wallets) session: the private key lives inside a Privy embedded wallet on Alchemy's side, the agent only holds a session token, and the developer can revoke the session at any time from the Alchemy Dashboard.

## ⚠️ Critical rules — no exceptions

- **NEVER ask the user for a private key.** The agent never sees a private key in this flow.
- **NEVER use `--mode local`** for this skill. Local mode imports a raw private key file onto the developer's machine — that's exactly what Agent Wallet sessions are designed to avoid. If a workflow seems to require a raw key, stop and tell the user.
- **NEVER install the Alchemy CLI or run `alchemy auth` on the user's behalf.** Both require user-driven browser flows. Surface the prompt and wait.
- **NEVER hardcode an Agent Wallet session token or API key into a committed file.** The CLI keeps these in `~/.alchemy/`.

## Prereqs (hook-gated)

The monskills hook (`hooks/check-alchemy-auth.sh`) gates every `alchemy …` command until both prereqs are satisfied. If either is missing, surface the exact command and stop.

1. **CLI installed (v0.18.0 or newer)** — ask the user to run:
   ```bash
   npm install -g @alchemy/cli@latest
   ```
   monskills requires `@alchemy/cli` **v0.18.0+**; the hook blocks `alchemy` commands on older versions. Check with `alchemy --version`.

2. **Signed in** — ask the user to run:
   ```bash
   alchemy auth
   ```
   Browser OAuth flow. Only the user can complete it. After sign-in the CLI prompts to pick an Alchemy app; pick the app whose API key you want monskills to use for RPC.

   **Headless / remote environments (no reachable browser):** if the CLI is running somewhere a browser can't reach it — GitHub Codespaces, Gitpod, Replit, Google Cloud Shell, Coder workspaces, SSH sessions, or non-interactive/CI/piped sessions — do **not** ask the user to complete a browser login. Tell them to use the **device authorization flow** instead:
   ```bash
   alchemy auth login --device-code
   ```
   The CLI prints a short code and a verification link; the user opens the link in a browser on any device, checks the code matches their terminal, and approves. The `--device-code` flag works in every environment. Plain `alchemy auth` also switches to this flow automatically when it detects Codespaces, Gitpod, Replit, Google Cloud Shell, Coder, SSH, or a non-interactive session — so the flag isn't strictly required there. If auto-detection misses the environment, the browser login times out after two minutes and its error points to this same command. When in doubt in a remote/headless context, prefer `--device-code`.

Verify with:
```bash
alchemy auth status
alchemy doctor
```

## Create an Agent Wallet session

Sessions are created in the **Alchemy Dashboard**, not from the CLI. The agent cannot create one autonomously — only the developer can.

1. Ask the user to open https://dashboard.alchemy.com/products/agent-wallet/evm-wallet and create a new EVM Agent Wallet session.
2. Once the session is approved, the user runs:
   ```bash
   alchemy wallet connect --mode session
   alchemy wallet use session
   ```
3. Verify the session is the active EVM signer and confirm the address:
   ```bash
   alchemy wallet status --verify
   alchemy wallet address
   ```

`alchemy wallet status` is the source of truth. Never assume a session exists — always check.

## Default to Monad

Set the default network so subsequent commands don't need `-n` on every call:

```bash
alchemy config set network monad-mainnet   # or monad-testnet
```

Confirm with `alchemy evm network list --search monad`. Override per-command with `-n monad-mainnet` or `-n monad-testnet`.

Fund the session address with MON before any state-changing call.  

For Monad testnet here is how to get funds from faucet:

```bash
# Fund agent's wallet from faucet, since it is testnet, funds can be claimed from faucet.
FAUCET_RESPONSE=$(curl -s -X POST https://agents.devnads.com/v1/faucet \
  -H "Content-Type: application/json" \
  -d "{\"chainId\": 10143, \"address\": \"$AGENT_WALLET_ADDRESS\"}")

# Then check for balance
```

Monad mainnet: bridge / on-ramp via providers in [`tooling-and-infra/`](../tooling-and-infra/SKILL.md).

## Onchain actions (sends + contract calls)

These work natively through the session signer — no factory dance required.

### Send native MON

```bash
alchemy evm send <recipient> 0.01 -n monad-mainnet
```

Returns a smart wallet call ID. Once the user op confirms, the same `alchemy evm status <id-or-hash>` resolves to a transaction hash.

### Call an existing contract

```bash
alchemy evm contract call <address> "transfer(address,uint256)" \
  --args "0xRecipient,1000000000000000000" \
  -n monad-mainnet
```

For non-trivial ABIs, pass `--abi-file ./out/Foo.sol/Foo.json` (forge build output) instead of inline `--abi`.

Read-only calls don't need the session — use `alchemy evm contract read` (it's `eth_call` and consumes no gas).

## Smart contract deployment — CREATE2 via CreateX

The Alchemy CLI has no `deploy` subcommand, and Agent Wallet sessions cannot sign raw deploy transactions (`tx.to == null`) because session mode is built for contract-call user operations. **The deploy path for this skill is CREATE2 via the canonical CreateX factory.**

CreateX is deployed at the same address on Monad mainnet and Monad testnet (canonical CREATE2-deterministic deployment):

```
0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed
```

Verify it has code before relying on it — see [`addresses/`](../addresses/SKILL.md) for the `cast code` check. Other canonical deployers (Create2Deployer, Foundry Deterministic Deployer) are also in `addresses/` but CreateX is preferred here because it exposes a typed ABI that `alchemy evm contract call` can encode.

### Deploy flow

Assume Foundry is installed (build artifacts come from `forge build`).

1. **Compile** the contract:
   ```bash
   forge build
   ```

2. **Get the deploy init code** — creation bytecode plus ABI-encoded constructor args:
   ```bash
   CREATION=$(forge inspect src/Foo.sol:Foo bytecode)
   # If the constructor takes args, append them:
   ARGS=$(cast abi-encode "constructor(address,uint256)" 0xOwner 1000)
   INIT_CODE="${CREATION}${ARGS#0x}"
   ```
   If the constructor takes no args, `INIT_CODE=$CREATION`.

3. **Pick a salt** — `bytes32`. For a first deploy, `0x0000000000000000000000000000000000000000000000000000000000000000` is fine. For deterministic redeploys, use the same salt across networks.

4. **Compute the deterministic address** before sending the tx so the frontend / scripts / indexers can hardcode it:
   ```bash
   # cast doesn't read `alchemy` config — point RPC_URL at the SAME network you'll
   # deploy to with `-n`, or step 6 will check the wrong chain and report no code.
   RPC_URL=https://rpc.monad.xyz            # monad-mainnet
   # RPC_URL=https://testnet-rpc.monad.xyz  # monad-testnet
   SALT=0x0000000000000000000000000000000000000000000000000000000000000000
   INIT_CODE_HASH=$(cast keccak "$INIT_CODE")
   PREDICTED=$(cast call 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed \
     "computeCreate2Address(bytes32,bytes32)(address)" \
     "$SALT" "$INIT_CODE_HASH" \
     --rpc-url "$RPC_URL")
   echo "Predicted address: $PREDICTED"
   ```

5. **Deploy through the session signer**:
   ```bash
   alchemy evm contract call 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed \
     "deployCreate2(bytes32,bytes)" \
     --args "$SALT,$INIT_CODE" \
     -n monad-mainnet
   ```

6. **Wait for finality** and confirm the predicted address has code:
   ```bash
   alchemy evm status <call-id>      # resolves to a tx hash
   cast code "$PREDICTED" --rpc-url "$RPC_URL"   # same network you deployed to
   ```

After deployment, verify the contract using monskills' verification flow ([`scaffold/`](../scaffold/SKILL.md)).

> **Monad gas gotcha:** Monad charges `gas_limit`, not `gas_used`. CREATE2 deploys via CreateX are heavier than direct `forge create` deploys — pad estimates accordingly. See [`gas/`](../gas/SKILL.md).

## Revoke / disconnect

When the agent's job is done, revoke the session so a leaked token can't be reused:

```bash
alchemy wallet disconnect
```

This revokes the session backend-side and clears the local config. The developer can also revoke from the Agent Wallets dashboard at any time.

## Diagnostics

| Symptom | Check |
| --- | --- |
| `alchemy: command not found` | CLI not installed. Ask user to `npm install -g @alchemy/cli@latest`. |
| Hook denies: `alchemy` version below v0.18.0 | Ask user to upgrade: `npm install -g @alchemy/cli@latest`. monskills requires v0.18.0+. Do not upgrade it for them. |
| `Not authenticated` | Ask user to `alchemy auth`. Do not run it for them. In a headless/remote env (Codespaces, Gitpod, Replit, Cloud Shell, Coder, SSH, CI), ask them to use `alchemy auth login --device-code` instead. |
| Browser login hangs / times out after 2 min | The environment is headless. Ask user to run `alchemy auth login --device-code` and approve via the printed link + code. |
| `No active signer` / `Session expired` | `alchemy wallet status --verify`. If expired, ask user to re-approve the session in the dashboard, then `alchemy wallet connect --mode session`. |
| User op reverts on a CREATE2 deploy | Re-derive `INIT_CODE` (forge artifacts may be stale). Check the predicted address doesn't already have code — CreateX reverts on a re-deploy with the same salt + initCode. |