---
name: tooling-and-infra
description: Monad 工具和基础设施提供商支持目录。当开发者询问哪些工具、服务或基础设施提供商支持 Monad（主网或测试网），或需要查找 Monad 的 RPC 提供商、区块浏览器、预言机、跨链桥、索引器、钱包、法币入金通道、托管方案、分析工具、开发工具包或钱包基础设施提供商时，使用此技能。也适用于开发者询问"X 是否支持 Monad？"或"Monad 上有哪些 Y 类提供商？"的场景。涵盖 Monad 官方文档工具页面的所有类别。
---

# Monad 工具与基础设施

用于查询哪些工具和基础设施提供商支持 Monad 主网、测试网或两者兼有的路由指南。

## 如何使用此技能

1. 如果开发者询问**某个类别**（例如"哪些预言机支持 Monad 测试网？"），回答前必须先获取下方路由表中对应的 Monad 官方文档 Markdown 页面。
2. 如果开发者询问**特定提供商**（例如"Alchemy 支持 Monad 吗？"），请获取最相关的官方类别页面，并且只根据当前文档内容回答。如果该提供商未出现在官方 Monad 文档中，请说明无法从官方 Monad 文档确认其支持状态。
3. 直接使用 `.md` URL，让代理收到 Markdown，而不是渲染后的 HTML。

## 类别

Monad 官方文档是提供商列表、网络支持状态和提供商文档的事实来源。只需读取与开发者问题相关的类别页面。

| 类别 | 官方 Markdown 页面 | 涵盖内容 |
|------|--------------------|---------|
| 分析工具 | `https://docs.monad.xyz/tooling-and-infra/analytics.md` | 链上监控、投资组合追踪、DeFi 分析、仪表盘 |
| 区块浏览器 | `https://docs.monad.xyz/tooling-and-infra/block-explorers.md` | 交易浏览器、合约验证、UserOp 浏览器 |
| 跨链 | `https://docs.monad.xyz/tooling-and-infra/cross-chain.md` | 跨链桥、跨链桥聚合器、流动性层、AMB、链抽象 |
| 托管 | `https://docs.monad.xyz/tooling-and-infra/custody.md` | 机构级托管方案 |
| 索引器 | `https://docs.monad.xyz/tooling-and-infra/indexers.md` | 通用数据 API 和索引框架（子图、数据管道） |
| 法币入金 | `https://docs.monad.xyz/tooling-and-infra/onramps.md` | 法币转加密货币、支付网关 |
| 预言机 | `https://docs.monad.xyz/tooling-and-infra/oracles.md` | 价格数据源、VRF、数据馈送 |
| RPC 提供商 | `https://docs.monad.xyz/tooling-and-infra/rpc-providers.md` | 与 Monad 交互的 RPC 端点 |
| 开发工具包 | `https://docs.monad.xyz/tooling-and-infra/toolkits.md` | 开发框架和 SDK |
| 钱包 | `https://docs.monad.xyz/tooling-and-infra/wallets.md` | 软件钱包、硬件钱包、机构钱包、多签钱包 |
| 钱包基础设施 | `https://docs.monad.xyz/tooling-and-infra/wallet-infra.md` | 嵌入式钱包、账户抽象、智能账户 |

## 重要说明

- 提供商的支持状态可能会变化。请将 Monad 官方文档 Markdown 页面作为当前基准，然后建议开发者在提供商自己的文档中确认最终集成细节。
- 某些仅标注为主网支持的提供商可能稍后会添加测试网支持（反之亦然）。
- "待定"状态（以时钟图标标记）表示提供商已宣布支持但尚未上线。
