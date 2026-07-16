---
name: wallet
description: 通过 Alchemy CLI Agent Wallet 在 Monad 主网和测试网上管理 agent 钱包。发送原生 MON、调用已部署合约、部署新合约（通过 CreateX 的 CREATE2）— 全程 agent 永不接触私钥。会话由 Alchemy Dashboard 创建和撤销。
---

# Monad 上的 Agent 钱包 — Alchemy Agent Wallet

本技能适用于**开发者的编码 agent** 在 Monad 上签署链上交易 — 它**不是**给终端用户使用的前端钱包（前端用法请获取 [`wallet-integration/`](../wallet-integration/SKILL.md)）。

Agent 使用 [Alchemy Agent Wallet](https://www.alchemy.com/docs/agent-wallets) 会话：私钥保存在 Alchemy 侧的 Privy 内嵌钱包中，agent 仅持有会话令牌，开发者可随时通过 Alchemy Dashboard 撤销该会话。

## ⚠️ 关键规则 — 无例外

- **绝不向用户索取私钥。** 在本流程中 agent 永不接触私钥。
- **绝不使用 `--mode local`。** Local 模式会把原始私钥文件导入开发者机器，这正是 Agent Wallet 会话要避免的事。如果某流程似乎需要原始私钥，请停下并告知用户。
- **绝不替用户安装 Alchemy CLI 或运行 `alchemy auth`。** 两者都需要用户驱动的浏览器流程。提示用户并等待。
- **绝不把 Agent Wallet 会话令牌或 API key 硬编码到提交的文件里。** CLI 把它们保存在 `~/.alchemy/`。

## 前置条件（hook 拦截）

monskills 的 hook（`hooks/check-alchemy-auth.sh`）会拦截所有 `alchemy …` 命令，直到两个前置条件都满足。若有任一缺失，请告知用户准确的命令并停止操作。

1. **CLI 已安装（v0.18.0 或更高）** — 请用户运行：
   ```bash
   npm install -g @alchemy/cli@latest
   ```
   monskills 要求 `@alchemy/cli` **v0.18.0+**；版本过低时 hook 会拦截 `alchemy` 命令。用 `alchemy --version` 查看。

2. **已登录** — 请用户运行：
   ```bash
   alchemy auth
   ```
   浏览器 OAuth 流程。只有用户能完成。登录后 CLI 会提示选择一个 Alchemy app；选择你想让 monskills 用于 RPC 的 app。

   **无头 / 远程环境（无法打开浏览器）：** 如果 CLI 运行在浏览器无法访问的环境中 —— GitHub Codespaces、Gitpod、Replit、Google Cloud Shell、Coder 工作区、SSH 会话，或非交互 / CI / 管道会话 —— **不要**让用户去完成浏览器登录，而应让其使用**设备授权流程（device authorization flow）**：
   ```bash
   alchemy auth login --device-code
   ```
   CLI 会打印一个短验证码和一个验证链接；用户在任意设备的浏览器中打开该链接，核对验证码与终端中一致后批准即可。`--device-code` 标志在任何环境下都有效。当检测到 Codespaces、Gitpod、Replit、Google Cloud Shell、Coder、SSH 或非交互会话时，普通的 `alchemy auth` 也会自动切换到该流程 —— 因此在这些环境下不强制要求加该标志。如果自动检测未能识别环境，浏览器登录会在两分钟后超时，其错误信息会指向同一条命令。在远程 / 无头环境下如有疑问，请优先使用 `--device-code`。

验证：
```bash
alchemy auth status
alchemy doctor
```

## 创建 Agent Wallet 会话

会话只能在 **Alchemy Dashboard** 中创建，无法通过 CLI 自动创建 — 只有开发者能完成。

1. 让用户打开 https://dashboard.alchemy.com/products/agent-wallet/evm-wallet 并创建一个新的 EVM Agent Wallet 会话。
2. 会话获批后，用户运行：
   ```bash
   alchemy wallet connect --mode session
   alchemy wallet use session
   ```
3. 验证会话已成为 EVM 当前签名器，并确认地址：
   ```bash
   alchemy wallet status --verify
   alchemy wallet address
   ```

`alchemy wallet status` 是唯一的真相源 — 切勿臆测会话已存在，始终检查。

## 默认使用 Monad

设置默认网络，后续命令无需每次都带 `-n`：

```bash
alchemy config set network monad-mainnet   # 或 monad-testnet
```

可用 `alchemy evm network list --search monad` 确认。也可在单条命令上用 `-n monad-mainnet` 或 `-n monad-testnet` 覆盖。

执行任何状态变更调用前，先给会话地址充值 MON。Monad 测试网水龙头：https://testnet.monad.xyz。Monad 主网：通过 [`tooling-and-infra/`](../tooling-and-infra/SKILL.md) 列出的桥/法币入口。

## 链上操作（转账 + 合约调用）

这些通过会话签名器直接工作 — 无需走 factory。

### 发送原生 MON

```bash
alchemy evm send <recipient> 0.01 -n monad-mainnet
```

返回一个 smart wallet call ID。user op 确认后，同一个 `alchemy evm status <id-or-hash>` 会解析出交易哈希。

### 调用已部署合约

```bash
alchemy evm contract call <address> "transfer(address,uint256)" \
  --args "0xRecipient,1000000000000000000" \
  -n monad-mainnet
```

对于复杂 ABI，用 `--abi-file ./out/Foo.sol/Foo.json`（forge build 输出）替代内联 `--abi`。

只读调用不需要会话 — 用 `alchemy evm contract read`（它是 `eth_call`，不消耗 gas）。

## 智能合约部署 — 通过 CreateX 进行 CREATE2

Alchemy CLI 没有 `deploy` 子命令，且 Agent Wallet 会话无法签署原始部署交易（`tx.to == null`），因为会话模式是为合约调用 user operation 设计的。**本技能的部署路径是通过权威的 CreateX factory 进行 CREATE2 部署。**

CreateX 在 Monad 主网和测试网上部署在同一个地址（CREATE2 确定性部署）：

```
0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed
```

依赖前先用 `cast code` 检查它确实有代码 — 见 [`addresses/`](../addresses/SKILL.md)。其他权威部署器（Create2Deployer、Foundry Deterministic Deployer）也在 `addresses/` 中，但这里优先使用 CreateX，因为它暴露了一个 `alchemy evm contract call` 可以编码的有类型的 ABI。

### 部署流程

假定已安装 Foundry（构建产物来自 `forge build`）。

1. **编译** 合约：
   ```bash
   forge build
   ```

2. **获取部署 init code** — creation bytecode 加上 ABI 编码后的构造函数参数：
   ```bash
   CREATION=$(forge inspect src/Foo.sol:Foo bytecode)
   # 如果构造函数有参数，追加它们：
   ARGS=$(cast abi-encode "constructor(address,uint256)" 0xOwner 1000)
   INIT_CODE="${CREATION}${ARGS#0x}"
   ```
   若构造函数无参数，则 `INIT_CODE=$CREATION`。

3. **选定 salt** — `bytes32`。首次部署用 `0x0000000000000000000000000000000000000000000000000000000000000000` 即可。如需跨网络确定性重部署，跨网络保持同一个 salt。

4. **发送交易前先计算确定性地址**，便于前端/脚本/索引器硬编码：
   ```bash
   SALT=0x0000000000000000000000000000000000000000000000000000000000000000
   INIT_CODE_HASH=$(cast keccak "$INIT_CODE")
   PREDICTED=$(cast call 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed \
     "computeCreate2Address(bytes32,bytes32)(address)" \
     "$SALT" "$INIT_CODE_HASH" \
     --rpc-url https://rpc.monad.xyz)
   echo "Predicted address: $PREDICTED"
   ```

5. **通过会话签名器部署**：
   ```bash
   alchemy evm contract call 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed \
     "deployCreate2(bytes32,bytes)" \
     --args "$SALT,$INIT_CODE" \
     -n monad-mainnet
   ```

6. **等待最终确认**，并验证预测地址上已有代码：
   ```bash
   alchemy evm status <call-id>      # 解析为 tx hash
   cast code "$PREDICTED" --rpc-url https://rpc.monad.xyz
   ```

部署完成后，按 monskills 的验证流程进行合约源码验证（[`scaffold/`](../scaffold/SKILL.md)）。

> **Monad gas 坑：** Monad 按 `gas_limit` 收费，而非 `gas_used`。通过 CreateX 的 CREATE2 部署比 `forge create` 直接部署更重 — 估算时相应放宽。见 [`gas/`](../gas/SKILL.md)。

## 撤销 / 断开连接

Agent 任务完成后，撤销会话以防止泄露的令牌被复用：

```bash
alchemy wallet disconnect
```

该命令在后端撤销会话并清除本地配置。开发者也可以随时从 Agent Wallets dashboard 撤销。

## 诊断

| 现象 | 检查 |
| --- | --- |
| `alchemy: command not found` | CLI 未安装。请用户运行 `npm install -g @alchemy/cli@latest`。 |
| Hook 拒绝：`alchemy` 版本低于 v0.18.0 | 请用户升级：`npm install -g @alchemy/cli@latest`。monskills 要求 v0.18.0+。切勿代为升级。 |
| `Not authenticated` | 请用户运行 `alchemy auth`。切勿代为运行。在无头 / 远程环境（Codespaces、Gitpod、Replit、Cloud Shell、Coder、SSH、CI）中，请让其改用 `alchemy auth login --device-code`。 |
| 浏览器登录卡住 / 两分钟后超时 | 说明环境是无头的。请用户运行 `alchemy auth login --device-code`，并通过打印出的链接 + 验证码批准。 |
| `No active signer` / `Session expired` | `alchemy wallet status --verify`。如果过期，让用户在 dashboard 重新批准会话，然后 `alchemy wallet connect --mode session`。 |
| CREATE2 部署 user op 回滚 | 重新生成 `INIT_CODE`（forge 产物可能已过期）。检查预测地址上是否已有代码 — 相同 salt + initCode 重复部署时 CreateX 会回滚。 |
