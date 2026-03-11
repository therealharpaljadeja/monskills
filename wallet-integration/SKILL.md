---
name: wallet-integration
description: How to integrate wallet connection into a Next.js app on Monad using RainbowKit with Wagmi and viem.
---

Integrate wallet connection into a Next.js frontend using [RainbowKit](https://rainbowkit.com/docs/installation) with Wagmi and viem. 

The Next.js project might be in the web directory of the entire project, depending on which directory the user is running claude on it might vary.

Monad is natively supported by Wagmi — import `monad` and `monadTestnet` from `wagmi/chains`.

## Optional prerequisite

If the user has provided the project ID then store it as `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` environment variable, if not then when the task is complete warn the user that WalletConnect will not work and lay out the steps on how to make it work.

## Installation

```bash
npm install @rainbow-me/rainbowkit wagmi viem@2.x @tanstack/react-query
```

## Setup

### 1. Configure RainbowKit

`config/index.ts`:

```tsx
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { monad, monadTestnet } from 'wagmi/chains'
import { http } from 'wagmi'

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID

export const config = getDefaultConfig({
  appName: 'My App',
  projectId,
  chains: [monad, monadTestnet],
  transports: {
    [monad.id]: http('https://rpc.monad.xyz'),
    [monadTestnet.id]: http('https://testnet-rpc.monad.xyz'),
  },
  ssr: true,
})
```

### 2. Create providers

`providers.tsx`:

```tsx
'use client'

import '@rainbow-me/rainbowkit/styles.css'

import { RainbowKitProvider } from '@rainbow-me/rainbowkit'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from '@/config'
import type { ReactNode } from 'react'

const queryClient = new QueryClient()

export default function Providers({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

### 3. Update layout

`app/layout.tsx`:

```tsx
import Providers from '@/providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

### 4. Next.js scripts

Add `--webpack` flag in `package.json`:

```json
{
  "scripts": {
    "dev": "next dev --webpack",
    "build": "next build --webpack"
  }
}
```

## Connect Button

### Using RainbowKit's built-in button

```tsx
import { ConnectButton } from '@rainbow-me/rainbowkit'

export default function Header() {
  return <ConnectButton />
}
```

## Smart Contract Interaction

```tsx
import { useReadContract } from 'wagmi'

const contractAddress = '0x...'
const abi = [/* contract ABI */]

function App() {
  const { data } = useReadContract({
    abi,
    address: contractAddress,
    functionName: 'totalSupply',
  })

  return <div>Total Supply: {data?.toString()}</div>
}
```

## Reference

Full RainbowKit docs: https://rainbowkit.com/docs/installation
