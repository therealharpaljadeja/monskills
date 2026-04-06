---
name: wallet-integration
description: 如何在 Monad 上使用 RainbowKit、Wagmi 和 viem 将钱包连接集成到 Next.js 应用中。
---

将钱包连接集成到 Next.js 前端，使用 [RainbowKit](https://rainbowkit.com/docs/installation)、Wagmi 和 viem。

Next.js 项目可能位于整个项目的 web 目录中，具体取决于用户在哪个目录下运行 claude，路径可能有所不同。

Monad 已被 Wagmi 原生支持 — 从 `wagmi/chains` 导入 `monad` 和 `monadTestnet` 即可。

## 可选前置条件

如果用户提供了项目 ID，则将其存储为 `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` 环境变量；如果没有提供，则在任务完成时警告用户 WalletConnect 将无法工作，并列出使其正常工作的步骤。

## 安装

```bash
npm install @rainbow-me/rainbowkit wagmi viem@2.x @tanstack/react-query
```

## 配置

### 1. 配置 RainbowKit

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

### 2. 创建 Providers

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

### 3. 更新布局

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

### 4. Next.js 脚本

在 `package.json` 中添加 `--webpack` 标志：

```json
{
  "scripts": {
    "dev": "next dev --webpack",
    "build": "next build --webpack"
  }
}
```

## 连接按钮

### 使用 RainbowKit 内置按钮

```tsx
import { ConnectButton } from '@rainbow-me/rainbowkit'

export default function Header() {
  return <ConnectButton />
}
```

## 智能合约交互

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

## 参考资料

完整 RainbowKit 文档：https://rainbowkit.com/docs/installation
