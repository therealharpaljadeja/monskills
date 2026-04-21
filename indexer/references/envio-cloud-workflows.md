# Envio Cloud — workflow recipes

Opinionated sequences for common indexer tasks. Each recipe assumes the user is already logged in (`envio-cloud token` exit 0).

## First deploy

Use when: the user wants to take a local HyperIndex project and put it on Envio Cloud for the first time.

1. **Confirm the repo is pushed to GitHub.** Envio Cloud deploys from GitHub, not from local files. If the project is local-only, stop and ask the user to push it first.
2. **Set the org context (once):**
   ```bash
   envio-cloud config set-org <org>
   ```
   Ask the user for their org slug if you don't know it. Don't guess.
3. **Register the indexer:**
   ```bash
   envio-cloud indexer add --name <name> --repo <owner/repo>
   ```
   The `--repo` argument is `owner/repo`, not a full URL.
4. **Wait for the deployment to build.** The add command returns a commit SHA. Poll with:
   ```bash
   envio-cloud deployment status <name> <commit>
   ```
   Don't busy-loop — wait at least 5s between polls. If it stays pending for >5 minutes, check logs.
5. **Promote to production when ready:**
   ```bash
   envio-cloud deployment promote <name> <commit>
   ```
   Only promote after confirming the indexer is syncing and returning data as expected.
6. **Report both the indexer name and the promoted commit** to the user so they can reference it later.

## Debug a failing deploy

Use when: `deployment status` shows `failed`, `errored`, or the indexer is stuck syncing.

1. **Read the logs first:**
   ```bash
   envio-cloud deployment logs <indexer> <commit>
   ```
   Quote the relevant error back to the user — don't summarize away the details.
2. **Check metrics for sync lag:**
   ```bash
   envio-cloud deployment metrics <indexer> <commit>
   ```
   Persistent lag with no errors usually means underpowered resources or an RPC-side bottleneck, not a code bug.
3. **Common causes, in order of likelihood:**
   - Missing or wrong env var — check with `envio-cloud indexer env list`.
   - Schema/handler mismatch that the CI build did not catch.
   - RPC endpoint rate-limited or wrong chain.
4. **If you fix code**, the user pushes a new commit to GitHub, then re-deploy by running `indexer add` is **not** needed — the cloud should pick up the new commit automatically. Check with `deployment status <indexer> <new-commit>`.
5. **If you only changed env vars**, restart the current deployment:
   ```bash
   envio-cloud deployment restart <indexer> <commit>
   ```

## Rotate env vars

Use when: the user rotated an API key, RPC URL, or database credential and needs the indexer to pick up the new value.

1. **Set the new value:**
   ```bash
   envio-cloud indexer env set <KEY> <new-value>
   ```
   Ask the user to paste the value directly into their terminal — do not ask them to send it to you.
2. **Restart the deployment** so the new value is loaded:
   ```bash
   envio-cloud deployment restart <indexer> <commit>
   ```
3. **Verify it's running** by tailing logs for a few seconds.
4. **Never print the new value back** to the user. A generic "updated" confirmation is fine.

## Allowlist an IP

Use when: the user wants to restrict the indexer's API to specific IPs (e.g. their backend servers).

1. **Add the user's current IP first** so enabling the allowlist doesn't lock them out:
   ```bash
   envio-cloud indexer security add-ip <user-ip>
   ```
   Ask the user for their IP — don't assume.
2. **Add any additional IPs or CIDRs** they want allowlisted.
3. **Enable the allowlist:**
   ```bash
   envio-cloud indexer security enable
   ```
4. **Confirm the current state:**
   ```bash
   envio-cloud indexer security get
   ```

## Delete an indexer

Use when: the user explicitly says they want to remove an indexer.

1. **Confirm with the user by name** before running delete. Say the indexer name and org back to them and wait for explicit yes.
2. **Run delete:**
   ```bash
   envio-cloud indexer delete <name> <org>
   ```
3. This is irreversible. Don't add retry logic around it.
