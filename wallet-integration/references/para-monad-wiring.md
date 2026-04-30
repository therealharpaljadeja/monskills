# Para — wiring Monad into the wagmi config

`para init` sets up Para's React SDK in your existing frontend, but the EVM chain set the SDK templates ship is generic (Ethereum mainnet, Sepolia, etc.). Monad isn't included — neither mainnet (chain id 143) nor testnet (chain id 10143). This file is the post-integration patch you apply to make Monad the default chain.

Apply this **after** the manual provider wiring in `references/para-workflows.md` → "Integrate Para into the existing frontend."

## Prereq: bump tsconfig target to ES2020

`create-next-app` generates `"target": "ES2017"`. viem and wagmi use BigInt literals (`0n`, `1n`) for chain ids, gas, amounts — without ES2020 you hit `TS2737: BigInt literals are not available when targeting lower than ES2020` the moment you touch a chain id or `useReadContract`.

```bash
cd web
jq '.compilerOptions.target = "ES2020"' tsconfig.json > tsconfig.tmp && mv tsconfig.tmp tsconfig.json
```

If `jq` isn't installed, open `tsconfig.json` and change `"target": "ES2017"` to `"target": "ES2020"` by hand.

## Add Monad to the wagmi config

Find the wagmi config that Para's provider consumes — it's typically at one of:

- `web/config/wagmi.ts` (most common in Next.js setups)
- `web/lib/wagmi.ts`
- `web/app/wagmi.ts`

Whichever file imports `createConfig` from `wagmi` (or `getDefaultConfig` from a Para-shipped helper) and exports a config object — that's the one to edit.

Add `monad` and `monadTestnet` to the `chains` array and register HTTP transports:

```ts
import { createConfig, http } from 'wagmi'
import { monad, monadTestnet } from 'wagmi/chains'
// ... other chain imports

export const wagmiConfig = createConfig({
  chains: [monad, monadTestnet /* , ...other chains the scaffolded config already had */],
  transports: {
    [monad.id]: http('https://rpc.monad.xyz'),
    [monadTestnet.id]: http('https://testnet-rpc.monad.xyz'),
    // ... other transports
  },
  ssr: true, // keep if it was already there for Next.js
})
```

Notes:
- `monad` and `monadTestnet` are exported from `wagmi/chains` directly — no need to define them by hand. If the import errors, bump `wagmi` to a version that includes them (`wagmi@2.x` recent minors).
- Don't strip the other chains the scaffold added unless the user explicitly asks for Monad-only. Removing Ethereum mainnet, for example, may break wallet-side balance lookups that some external wallets do at connect time.
- Use the public RPC URLs above unless the user has a paid RPC (Alchemy / QuickNode / Ankr) — in that case wire the env-var-driven URL instead.
- If the scaffold uses a Para helper (`getParaWagmiConfig`, etc.) instead of bare `createConfig`, pass `chains` and `transports` to that helper the same way — the parameter names match.

## Set Monad as the default chain in `ParaProvider`

If the user wants Monad to be the chain users land on by default (most cases), set the `defaultChain` prop on `ParaProvider`:

```tsx
import { ParaProvider } from '@getpara/react-sdk'
import { monadTestnet } from 'wagmi/chains'

<ParaProvider
  apiKey={process.env.NEXT_PUBLIC_PARA_API_KEY!}
  defaultChain={monadTestnet}
>
  {children}
</ParaProvider>
```

Pick `monad` (mainnet) or `monadTestnet` based on which network the contracts are deployed to. If both are deployed and the user wants the user-facing chain switcher to default to mainnet, use `monad`.

## Verify

After the edits:

```bash
cd web
para doctor                    # should still pass
npm run dev                    # start dev server
```

Open the app, click connect, complete a Para auth flow, then open the chain switcher — Monad mainnet and Monad testnet should both appear. If they don't, the most common cause is editing the wrong wagmi config file (one that the provider isn't actually consuming). Grep for `ParaProvider` to confirm which config is wired in.

## Don't do these things

- **Don't define Monad chain objects by hand** (`{ id: 143, name: 'Monad', ... }`). `wagmi/chains` exports them — using the export keeps the chain id, RPC defaults, explorer URLs, and native currency in sync if anything ever changes upstream.
- **Don't set the chain id as a string.** `[monad.id]: http(...)` works because `monad.id` is already a number; `["143"]: http(...)` will silently mismatch.
- **Don't skip `ssr: true`** in a Next.js App Router project. Without it, hydration mismatches show up as flickering connect buttons or "wallet not connected" flashes on every page load.
