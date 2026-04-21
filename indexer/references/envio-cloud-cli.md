# envio-cloud CLI reference

Source of truth: https://docs.envio.dev/docs/HyperIndex/envio-cloud-cli

## Install

```bash
npm install -g envio-cloud
# or run without installing:
npx envio-cloud <command>
```

Do not install this for the user. Tell them the command.

## Companion requirement: GitHub CLI (`gh`)

`envio-cloud` requires `gh` to be installed and authenticated so the indexer repo can be pushed to GitHub (Envio Cloud deploys from GitHub).

```bash
# macOS
brew install gh
gh auth login
```

Do not install `gh` or run `gh auth login` for the user. Both require browser interaction.

## Authentication

```bash
envio-cloud login
```

Opens a browser tab on envio.dev. 30-day session duration. Only the user can complete this — never try to run it on their behalf.

### Session status

```bash
envio-cloud token    # Exit 0 = session valid. Prints session info to stdout.
envio-cloud logout   # Remove stored credentials.
```

`envio-cloud token` is the canonical way to check whether the current user is authenticated. The monskills hook uses this.

## Context defaults

Set org and indexer defaults so you don't have to repeat them on every command.

```bash
envio-cloud config set-org <org>
envio-cloud config set-indexer <name>
envio-cloud config get-context
envio-cloud config clear
```

When both are set, `envio-cloud indexer get` (no args) refers to the active indexer in the active org.

## Indexer lifecycle

| Command | Purpose |
|---|---|
| `envio-cloud indexer list [--org <org>]` | List indexers in an org. |
| `envio-cloud indexer get <name> [<org>]` | Show details for one indexer. |
| `envio-cloud indexer add --name <name> --repo <repo>` | Register a new indexer from a GitHub repo. |
| `envio-cloud indexer delete <name> [<org>]` | Remove an indexer. Irreversible — confirm with the user. |
| `envio-cloud indexer settings get` | Read current indexer settings. |
| `envio-cloud indexer settings set <key> <value>` | Update an indexer setting. |

## Deployments

A deployment is a specific commit of an indexer. Commands take `<indexer>` and `<commit>` as positional args.

| Command | Purpose |
|---|---|
| `envio-cloud deployment status <indexer> <commit> [<org>]` | Build/sync status of a deployment. Pass `--watch-till-synced` to stream status until all chains hit 100%. |
| `envio-cloud deployment metrics <indexer> <commit> [<org>]` | Runtime metrics (events/sec, lag, memory). |
| `envio-cloud deployment logs <indexer> <commit> [<org>]` | Runtime logs. First place to look when something misbehaves. |
| `envio-cloud deployment promote <indexer> <commit> [<org>]` | Promote a deployment to serve production traffic. |
| `envio-cloud deployment restart <indexer> <commit> [<org>]` | Restart the running deployment. |
| `envio-cloud deployment delete <indexer> <commit> [<org>]` | Delete a deployment. |
| `envio-cloud deployment endpoint <indexer> <commit> <org>` | Print the GraphQL URL the frontend queries (see below). |

### GraphQL endpoint URL — what the frontend talks to

```bash
envio-cloud deployment endpoint <indexer-name> <commit-hash> <organisation-id> [flags]
```

Alias: `envio-cloud deployment ep`.

**This is the URL the frontend queries.** After a deployment is healthy, this command prints the GraphQL endpoint that any GraphQL client — Apollo, urql, graphql-request, `fetch`, or a raw `curl` — uses to read the indexed data and render it in the UI. The indexer is useless to the frontend until this URL is wired in.

If the project has a frontend, Claude wires this up automatically (see the "Get the GraphQL endpoint URL" recipe in `envio-cloud-workflows.md`) — resolve the URL, write it to `web/.env.local` as `NEXT_PUBLIC_INDEXER_URL`, and point the GraphQL client at `process.env.NEXT_PUBLIC_INDEXER_URL`. Don't hand the raw URL to the user to paste themselves.

Usage examples:

```bash
# Bare URL — ideal for copying into a .env file
envio-cloud deployment endpoint myindexer abc1234 myorg

# Pipe directly into a smoke-test query
curl "$(envio-cloud deployment endpoint myindexer abc1234 myorg)" \
  -H 'Content-Type: application/json' \
  -d '{"query": "{ _meta { block { number } } }"}'

# Machine-readable (for scripts that need more than the URL)
envio-cloud deployment endpoint myindexer abc1234 myorg -o json
```

Frontend wiring example (Next.js + fetch):

```ts
// .env.local
// NEXT_PUBLIC_INDEXER_URL=<paste the URL printed by `envio-cloud deployment endpoint`>

const res = await fetch(process.env.NEXT_PUBLIC_INDEXER_URL!, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: `{ transfers(first: 10) { id from to value } }` }),
});
const { data } = await res.json();
```

Flags:

| Flag | Purpose |
|---|---|
| `--cluster <name>` | Override the resolved cluster. Valid values: `hyper`, `hypertierchicago`, `ip-projects`, `prodaws`, `staging`. Only set this if the user explicitly asked for a non-default cluster. |
| `-o json` | Structured output instead of the bare URL. |
| `-q` | Suppress informational messages (global flag). Use this when piping the URL into another command. |

Notes:
- The URL is **computed locally** from deployment parameters; only the cluster is resolved via the API. Fast, but still requires authentication to resolve cluster.
- `<commit-hash>` is the same short SHA returned by `indexer add` / shown in `deployment status`. Use the promoted/healthy commit — that's what serves traffic.
- You can only view endpoints for orgs you are a member of (exit 1 otherwise).
- Use the URL exactly as printed when writing it into env files or client configs. Don't rewrite it, add a trailing slash, or strip query parts.

## Environment variables

```bash
envio-cloud indexer env list
envio-cloud indexer env set <KEY> <value>
envio-cloud indexer env delete <KEY>
```

Env vars are per-indexer, shared across all its deployments. Setting an env var does not restart running deployments automatically — follow up with `deployment restart` if the change needs to take effect on an active deployment.

Never echo secret values back to the user when reading them.

## Security (IP allowlist)

```bash
envio-cloud indexer security get
envio-cloud indexer security add-ip <ip-or-cidr>
envio-cloud indexer security enable
```

Enabling the allowlist without adding the user's current IP first will lock them out of their own indexer's API. Add their IP first, then enable.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | User error (bad args, not logged in, unknown indexer) |
| `2` | API/server error |

Don't rely on stdout content alone — check the exit code.
