# 钱包基础设施

Monad 上的嵌入式钱包、账户抽象和智能账户实现。

## 嵌入式钱包

| 提供商 | 主网 | 测试网 | 描述 | 文档 |
|--------|------|--------|------|------|
| Alchemy | Yes | Yes | 智能合约钱包，支持邮箱、Passkey 和社交登录认证 | [alchemy.com](https://www.alchemy.com/) |
| Coinbase Developer Platform | Yes | Yes | 无需助记词或扩展程序的嵌入式钱包 | [docs.cdp.coinbase.com](https://docs.cdp.coinbase.com/) |
| Dynamic | Yes | Yes | 面向加密用户的登录流程 + 新用户引导 | [dynamic.xyz](https://www.dynamic.xyz/) |
| Fordefi | Yes | Yes | 机构级 MPC 钱包，支持 DeFi 策略控制和模拟 | [fordefi.com](https://www.fordefi.com/) |
| MetaMask Embedded Wallet | Yes | Yes | 通过 Google 或 Apple 的一键 OAuth 引导 | [metamask.io](https://metamask.io/) |
| Openfort | Yes | Yes | 嵌入式、后端和生态系统钱包 | [openfort.xyz](https://www.openfort.xyz/) |
| Para | Yes | Yes | 跨多个生态系统的跨应用嵌入式钱包 | [para.io](https://www.para.io/) |
| Phantom | — | Yes | 无需助记词的引导，应用内非托管访问（仅测试网） | [phantom.app](https://phantom.app/) |
| Portal | Yes | Yes | 快速稳定币金融平台，提供简洁的 SDK/API | [portalhq.io](https://www.portalhq.io/) |
| Privy | Yes | Yes | 无论用户是否熟悉加密货币均可引导上手 | [privy.io](https://www.privy.io/) |
| Reown | Yes | Yes | AppKit SDK，用于钱包连接和 Web3 功能 | [reown.com](https://reown.com/) |
| Sequence | Yes | Yes | 开源非托管嵌入式和生态系统钱包 | [docs.sequence.xyz](https://docs.sequence.xyz/) |
| thirdweb | Yes | Yes | 客户端 SDK，用于引导、身份验证和交易 | [portal.thirdweb.com](https://portal.thirdweb.com/) |
| Turnkey | Yes | Yes | 可扩展基础设施，支持数百万个钱包 | [turnkey.com](https://www.turnkey.com/) |

## 账户抽象

| 提供商 | 主网 | 测试网 | 描述 | 文档 |
|--------|------|--------|------|------|
| Alchemy | Yes | Yes | 支持 ERC-4337、EIP-7702 和 ERC-6900——为用户免除 Gas 费 | [alchemy.com](https://www.alchemy.com/) |
| Biconomy | Yes | Yes | 全面的智能账户和执行基础设施 | [docs.biconomy.io](https://docs.biconomy.io/) |
| FastLane | ? | Yes | MEV 协议，集成 4337 Bundler 和任务调度器 | [fastlane.finance](https://fastlane.finance/) |
| Gelato | — | Yes | Paymaster 和 Bundler 服务，用于赞助交易 | [docs.gelato.network](https://docs.gelato.network/) |
| Openfort | Yes | Yes | SSS、Passkey 和赞助 Paymaster，用于钱包引导 | [openfort.xyz](https://www.openfort.xyz/) |
| Pimlico | Yes | Yes | 高级 ERC-4337 基础设施——Bundler、Paymaster、SDK | [docs.pimlico.io](https://docs.pimlico.io/) |
| Sequence | Yes | Yes | 统一中继器，支持 Gas 赞助、批处理和并行处理 | [docs.sequence.xyz](https://docs.sequence.xyz/) |
| thirdweb | Yes | Yes | 预审计账户工厂合约，支持赞助策略 | [portal.thirdweb.com](https://portal.thirdweb.com/) |
| ZeroDev | Yes | Yes | 无需 Gas、无需确认、无需助记词的智能账户 | [docs.zerodev.app](https://docs.zerodev.app/) |

## 智能账户

| 提供商 | 主网 | 测试网 | 描述 | 文档 |
|--------|------|--------|------|------|
| Biconomy | Yes | Yes | Nexus 智能账户，支持 Gas 抽象、会话密钥、Passkey、7702 | [docs.biconomy.io](https://docs.biconomy.io/) |
| MetaMask Smart Accounts Kit | Yes | Yes | 可编程账户行为，支持 WebAuthn、多签、ERC-7710 | [metamask.io](https://metamask.io/) |
| Pimlico | Yes | Yes | permissionless.js SDK——灵活支持多种智能账户 | [docs.pimlico.io](https://docs.pimlico.io/) |
| ZeroDev | Yes | Yes | 会话密钥、多种签名方案（ECDSA、Passkey、多签） | [docs.zerodev.app](https://docs.zerodev.app/) |
