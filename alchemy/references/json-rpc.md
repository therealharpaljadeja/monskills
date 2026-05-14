# JSON-RPC on Monad via Alchemy

Standard Ethereum JSON-RPC against Monad mainnet through Alchemy's node infrastructure. All requests are `POST` with JSON-RPC 2.0 bodies. WebSocket is also available for subscriptions.

## Endpoints

| Protocol | URL |
| --- | --- |
| HTTPS | `https://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>` |
| WSS | `wss://monad-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>` |

Get an API key at https://dashboard.alchemy.com (free tier available).

## Block-state tags (Monad specifics)

Pick the tag that matches your consistency requirement. See monskills' [`concepts/`](../../concepts/SKILL.md) for the full mapping.

| Tag | Monad state | Use when |
| --- | --- | --- |
| `pending` | Proposed (not yet voted) | Optimistic UI |
| `latest` | Proposed → executed (~1.2s lag) | Default for most reads |
| `safe` | Voted by validators | Defensive UI for high-value displays |
| `finalized` | Finalized by consensus | Settlement, bridges, irrevocable actions |

## Async execution

Newly funded EOAs cannot send a transaction right away on Monad. For the full explanation and recommended handling, see monskills' [`concepts/references/async-execution.md`](../../concepts/references/async-execution.md).

## Common methods

### `eth_blockNumber`

```bash
curl -s -X POST https://monad-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Response (hex block number):

```json
{ "jsonrpc": "2.0", "id": 1, "result": "0x1234" }
```

### `eth_getBalance`

```bash
curl -s -X POST https://monad-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0","id":1,"method":"eth_getBalance",
    "params":["0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045","latest"]
  }'
```

Returns native MON balance as a hex wei string.

### `eth_call`

Read-only contract calls. Pass the call object + a block tag:

```bash
curl -s -X POST https://monad-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0","id":1,"method":"eth_call",
    "params":[{"to":"<contract>","data":"<calldata>"},"latest"]
  }'
```

### `eth_getLogs`

Filter by address and topics. Keep ranges narrow — large ranges 429.

```json
{
  "jsonrpc":"2.0","id":1,"method":"eth_getLogs",
  "params":[{
    "fromBlock":"0x100","toBlock":"latest",
    "address":"0x...",
    "topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
  }]
}
```

### `eth_sendRawTransaction`

Submit a signed transaction. Returns the transaction hash.

```json
{
  "jsonrpc":"2.0","id":1,"method":"eth_sendRawTransaction",
  "params":["0x<signed-raw-tx-hex>"]
}
```

### `eth_getTransactionReceipt`

Poll for inclusion. On Monad's ~400ms block time, expect a receipt within 1-2 seconds.

```json
{ "jsonrpc":"2.0","id":1,"method":"eth_getTransactionReceipt",
  "params":["0x<txhash>"] }
```

> **Gas pricing reminder:** Monad charges users for `gas_limit`, not `gas_used`. The `gasUsed` field in the receipt is informational only — the cost is `gasLimit × effectiveGasPrice`. See [`gas/`](../../gas/SKILL.md).

## WebSocket subscriptions

`wss://monad-mainnet.g.alchemy.com/v2/<API_KEY>` supports the standard Geth subscription set:

- `eth_subscribe("newHeads")` — new block headers
- `eth_subscribe("logs", { address, topics })` — log filter
- `eth_subscribe("newPendingTransactions", true)` — pending tx hashes (set the second arg `true` for full tx objects)

For Monad's extended WS endpoint (richer event payloads, Execution Events SDK), see monskills' [`concepts/`](../../concepts/SKILL.md) → real-time data sources.

## Rate limits

Free tier handles development workloads. For production, use a paid plan and increase compute-unit caps from the dashboard. The standard 429 response includes a `Retry-After` header — back off and retry.

For the three ways to use Alchemy from a developer workflow (CLI, MCP, API key), see [`../SKILL.md`](../SKILL.md).
