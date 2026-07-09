# MONSKILLS Local Install

Agent-friendly install instructions for using MONSKILLS locally.

Install the skills first, then use the locally installed MONSKILLS files in your agent session. Do not fetch the website during the build workflow unless local installation is unavailable.

## All Agents

```bash
npx skills add therealharpaljadeja/monskills
```

## Claude Code

Add the plugin marketplace:

```text
/plugin marketplace add therealharpaljadeja/monskills
```

Install the plugin:

```text
/plugin install monskills@monskills
```

## Tell Your Agent

After installation, tell your agent:

```text
Use the locally installed MONSKILLS. Start with the monskill routing skill, then fetch only the local topic skills needed for the task. Build me an NFT minting app on Monad.
```

## Local Skill Entry Point

Start with the installed `monskill` skill. It routes the agent to the local topic skills needed for the task:

```text
monskill
```

Common local topic skills:

```text
scaffold
wallet-integration
wallet
gas
concepts
addresses
tooling-and-infra
indexer
```

## Agent Rule

Always use the locally installed `monskill` routing skill first. It routes the agent to the specific local MONSKILLS docs needed for the task.

Only use the website as a fallback if the local MONSKILLS install is missing or unavailable.
