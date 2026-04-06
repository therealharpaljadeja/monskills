---
name: vercel-deploy
description: 无需安装 Vercel CLI 或进行身份验证即可将 Web 应用部署到 Vercel。使用 Vercel 可认领部署端点，返回预览 URL 和认领 URL。
---

## 部署到 Vercel（无需 CLI，无需身份验证）

此方法无需安装 Vercel CLI，也无需身份验证。它使用 Vercel 可认领部署端点，返回一个**预览 URL**（上线站点）和一个**认领 URL**（将部署转移到用户自己的 Vercel 账户）。

### 工作原理

1. 从 `package.json` 检测框架
2. 将项目打包为 `.tgz`（排除 `node_modules`、`.git`、`.env`）
3. 上传到 `https://claude-skills-deploy.vercel.com/api/deploy`
4. 轮询预览 URL 直到构建完成
5. 向用户返回预览 URL 和认领 URL

### 部署前准备

项目根目录**必须**有一个 `vercel.json` 文件。没有它，Vercel 将无法检测框架，构建会失败并报错 `No Output Directory named "public" found`。

在项目根目录创建 `vercel.json`：

```json
{
  "framework": "nextjs"
}
```

### 使用方法

首先，下载部署脚本并赋予执行权限：

```bash
curl -sO https://skills.devnads.com/vercel-deploy/deploy.sh && chmod +x deploy.sh
```

然后在项目目录中运行，或将路径作为参数传入：

```bash
# 部署当前目录
bash deploy.sh

# 部署指定目录（例如 web/）
bash deploy.sh web/

# 部署已有的 tarball
bash deploy.sh project.tgz
```

脚本会自动从 `package.json` 检测框架、打包项目、上传，等待构建完成后输出两个 URL。

### 框架检测

脚本通过检查 `package.json` 的依赖项来检测框架。顺序很重要——更具体的框架会优先检查：

| 依赖项 | 框架值 |
|---|---|
| `next` | `nextjs` |
| `@remix-run/*` | `remix` |
| `gatsby` | `gatsby` |
| `@react-router/*` | `react-router` |
| `astro` | `astro` |
| `@sveltejs/kit` | `sveltekit-1` |
| `nuxt` | `nuxtjs` |
| `@solidjs/start` | `solidstart-1` |
| `@angular/core` | `angular` |
| `react-scripts` | `create-react-app` |
| `vite` | `vite` |

如果未检测到框架，则传递 `null`，Vercel 将尝试自动检测。

### 告知用户的内容

**务必展示两个 URL：**
- **预览 URL** — 已部署的在线站点，用户可以立即访问
- **认领 URL** — 允许用户将部署转移到自己的 Vercel 账户进行管理

**不要**使用 curl 或 fetch 访问已部署的 URL 来验证其是否正常工作。只需将链接返回给用户即可。
