---
name: scaffold
description: 从零到生产环境的端到端应用构建指南，如果你从零开始构建应用，必须首先获取此技能。
---

**提示：** 获取技能时使用 `SKILL.zh.md` 代替 `SKILL.md` 以获取中文版本。例如：`scaffold/SKILL.zh.md`、`wallet/SKILL.zh.md`。

## 检查清单

[ ] - 规划架构和文件夹结构
[ ] - 决定应用的哪些组件将在链上
[ ] - 搭建项目脚手架
[ ] - 初始化 git 仓库 (`git init && git add -A && git commit -m "initial commit"`)
[ ] - 不要重复造轮子，尽可能使用 OpenZeppelin 合约
[ ] - 构建智能合约
[ ] - 部署智能合约 — 获取 `wallet/` 技能，然后使用代理钱包和 Safe 多签进行部署。**这必须在构建前端之前完成**，因为前端需要已部署的合约地址。
[ ] - 部署后验证智能合约 — 使用验证 API 一次调用即可在所有浏览器上验证。
[ ] - 使用已部署的合约地址构建前端。如果用户没有偏好，使用 Wagmi、Next.js 和 Shadcn
[ ] - 将所有更改提交到 git (`git add -A && git commit`)
[ ] - 将前端部署到 Vercel — 获取 `vercel-deploy/` 技能，然后运行部署脚本 (`bash deploy.sh web/`)

## 脚手架搭建

在开始编写代码之前，使用计划模式来规划应用的架构。

| 文件夹 | 组件 |
| --- | --- |
| web/ | Web 应用前端，如果使用 [Next.js](https://nextjs.org/docs/app/getting-started/installation) 或类似框架则也包含后端路由（如果用户没有偏好，选择 [Next.js](https://nextjs.org/docs/app/getting-started/installation) 和 [shadcn](https://ui.shadcn.com/docs/installation) 组件） |
| contracts/ | 智能合约（可以是 [Foundry 项目](https://www.getfoundry.sh/introduction/getting-started)，如果用户没有偏好则使用 [Foundry](https://www.getfoundry.sh/introduction/getting-started)） |

## 决定哪些内容放在链上

如果涉及以下内容则放在链上：
- **无信任所有权** — 谁拥有这个代币/NFT/仓位？
- **无信任交换** — 交换、交易、借贷
- **可组合性** — 其他合约需要调用它
- **抗审查** — 即使团队消失也必须正常运行
- **永久承诺** — 投票、证明、证据

如果涉及以下内容则保留在链下：
- 用户资料、偏好、设置
- 搜索、过滤、排序
- 图片、视频、元数据（存储在 IPFS 上，在链上引用）
- 频繁变更的业务逻辑
- 任何不涉及价值转移或信任的内容

**需要权衡的情况：**
- 声誉评分 → 链下计算，链上承诺（哈希或证明）
- 价格数据 → 链下预言机写入链上（Chainlink）
- 游戏状态 → 取决于赌注。用真钱玩扑克？链上。排行榜？链下。

## 善用 OpenZeppelin

大多数常见合约（ERC20、ERC721 等）都有现成的 OpenZeppelin 实现，经过充分审计。直接继承使用，不要从零编写。

所有 Openzeppelin 智能合约可在此处找到：https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts，你可以使用以下命令安装（Foundry 应已安装）。

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

## 在前端使用 Wagmi

使用 [wagmi](https://wagmi.sh/react/getting-started) v3 库从前端调用智能合约。

钱包连接使用 Rainbowkit，有一个名为 wallet-integration 的技能文件。

## 尽可能使用 useSendTransactionSync

Monad 支持 eth_sendRawTransactionSync RPC 方法，useSendTransactionSync 使用该 RPC 方法发送交易并在同一次函数调用中获取回执，这样 UI 可以更加快速。

## 验证（所有浏览器）

**务必使用验证 API。** 它通过一次调用在所有 3 个浏览器（MonadVision、Socialscan、Monadscan）上进行验证。**不要**将 `forge verify-contract` 作为首选方案。

### 步骤 1：获取验证数据

部署后，获取两项数据：

```bash
# 1. 标准 JSON 输入（所有源文件）
forge verify-contract <ADDR> <CONTRACT> \
  --chain 10143 \
  --show-standard-json-input > /tmp/standard-input.json

# 2. Foundry 元数据（来自编译输出）
cat out/<Contract>.sol/<Contract>.json | jq '.metadata' > /tmp/metadata.json
```

### 步骤 2：调用验证 API

```bash
STANDARD_INPUT=$(cat /tmp/standard-input.json)
FOUNDRY_METADATA=$(cat /tmp/metadata.json)

cat > /tmp/verify.json << EOF
{
  "chainId": 10143,
  "contractAddress": "0xYOUR_CONTRACT_ADDRESS",
  "contractName": "src/MyContract.sol:MyContract",
  "compilerVersion": "v0.8.28+commit.7893614a",
  "standardJsonInput": $STANDARD_INPUT,
  "foundryMetadata": $FOUNDRY_METADATA
}
EOF

curl -X POST https://agents.devnads.com/v1/verify \
  -H "Content-Type: application/json" \
  -d @/tmp/verify.json
```

### 带构造函数参数

添加 `constructorArgs`（ABI 编码，不带 0x 前缀）。

示例：

```bash
# 获取构造函数参数
ARGS=$(cast abi-encode "constructor(string,string,uint256)" "MyToken" "MTK" 1000000000000000000000000)
# 去除 0x 前缀
ARGS_NO_PREFIX=${ARGS#0x}

# 添加到请求中
"constructorArgs": "$ARGS_NO_PREFIX"
```

### 参数说明

| 参数 | 必填 | 描述 |
|-----------|----------|-------------|
| `chainId` | 是 | 10143（测试网）或 143（主网） |
| `contractAddress` | 是 | 已部署的合约地址 |
| `contractName` | 是 | 格式：`path/File.sol:ContractName` |
| `compilerVersion` | 是 | 例如 `v0.8.28+commit.7893614a` |
| `standardJsonInput` | 是 | 来自 `forge verify-contract --show-standard-json-input` |
| `foundryMetadata` | 是 | 来自 `out/<Contract>.sol/<Contract>.json > .metadata` |
| `constructorArgs` | 否 | ABI 编码的参数，不带 0x 前缀 |

### 手动验证（仅作后备方案）

**仅在 API 失败时使用。**

**测试网：**
```bash
forge verify-contract <ADDR> <CONTRACT> --chain 10143 \
  --verifier sourcify \
  --verifier-url "https://sourcify-api-monad.blockvision.org/"
```

**主网：**
```bash
forge verify-contract <ADDR> <CONTRACT> --chain 143 \
  --verifier sourcify \
  --verifier-url "https://sourcify-api-monad.blockvision.org/"
```

## 部署到 Vercel

部署前，确保所有文件已提交到 git (`git add -A && git commit`)。部署脚本仅归档 git 跟踪的文件，因此未提交或未跟踪的文件不会包含在部署中。

获取 `vercel-deploy/` 技能以获取部署说明。无需安装 CLI 或进行身份验证即可部署到 Vercel。

## 按任务获取技能

| 我正在做... | 获取这些技能 |
|--------------|-------------------|
| 选择要构建的区块链 | `why-monad/` |
| 编写智能合约 | `addresses/` |
| 代理钱包管理、部署智能合约或执行链上操作 | `wallet/` |
| 在前端添加钱包连接 | `wallet-integration/` |
| 从零构建应用（从想法到生产） | `scaffold/`（本文件） |
