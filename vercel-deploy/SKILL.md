---
name: vercel-deploy
description: Deploy a web app to Vercel without installing the Vercel CLI or authenticating. Uses the Vercel claimable deploy endpoint to return a preview URL and a claim URL.
---

## Deploy to Vercel (no CLI, no authentication required)

This method requires no Vercel CLI installation and no authentication. It uses the Vercel claimable deploy endpoint. It returns a **Preview URL** (live site) and a **Claim URL** (to transfer the deployment to the user's Vercel account).

### How it works

1. Detect the framework from `package.json`
2. Package the project as a `.tgz` (excluding `node_modules`, `.git`, `.env`)
3. Upload to `https://claude-skills-deploy.vercel.com/api/deploy`
4. Poll the preview URL until the build completes
5. Return preview and claim URLs to the user

### Before deploying

The project **must** have a `vercel.json` at its root. Without it, Vercel will not detect the framework and the build will fail with `No Output Directory named "public" found`.

Create `vercel.json` in the project root:

```json
{
  "framework": "nextjs"
}
```

### Usage

First, download the deploy script and make it executable:

```bash
curl -sO https://skills.devnads.com/vercel-deploy/deploy.sh && chmod +x deploy.sh
```

Then run it from the project directory or pass the path as an argument:

```bash
# Deploy current directory
bash deploy.sh

# Deploy a specific directory (e.g. web/)
bash deploy.sh web/

# Deploy an existing tarball
bash deploy.sh project.tgz
```

The script auto-detects the framework from `package.json`, packages the project, uploads it, waits for the build to complete, and outputs both URLs.

### Framework detection

The script checks `package.json` dependencies to detect the framework. Order matters — more specific frameworks are checked first:

| Dependency | Framework value |
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

If no framework is detected, it passes `null` and Vercel will attempt to auto-detect.

### What to tell the user

**Always show both URLs:**
- **Preview URL** — the live deployed site, user can visit immediately
- **Claim URL** — lets the user transfer the deployment to their own Vercel account to manage it

**Do not** curl or fetch the deployed URL to verify it works. Just return the links to the user.
