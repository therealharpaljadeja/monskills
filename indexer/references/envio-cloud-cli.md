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
| `envio-cloud deployment status <indexer> <commit> [<org>]` | Build/sync status of a deployment. |
| `envio-cloud deployment metrics <indexer> <commit> [<org>]` | Runtime metrics (events/sec, lag, memory). |
| `envio-cloud deployment logs <indexer> <commit> [<org>]` | Runtime logs. First place to look when something misbehaves. |
| `envio-cloud deployment promote <indexer> <commit> [<org>]` | Promote a deployment to serve production traffic. |
| `envio-cloud deployment restart <indexer> <commit> [<org>]` | Restart the running deployment. |
| `envio-cloud deployment delete <indexer> <commit> [<org>]` | Delete a deployment. |

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
