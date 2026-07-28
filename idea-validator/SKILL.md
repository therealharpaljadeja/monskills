---
name: idea-validator
description: Check a new project idea against past Monad Blitz hackathon showcase submissions to see whether it (or something close to it) has already been built, and surface similar projects with names, categories, and links. Fetch when the user has an idea and wants a prior-art check before or during building.
---

# Idea Validator

Checks a new project idea against the Monad Blitz hackathon showcase — a public dataset of 1,250+ projects submitted across ~49 events at `https://blitz.devnads.com/api/showcase`. The goal is to tell the user whether their idea overlaps with something already built, and if so, which project(s), with links.

**Caveat:** this dataset only covers projects submitted to Monad Blitz hackathon showcases. It is not a registry of every project ever built on Monad — a "no matches found" result means "nothing like this was submitted to a Monad Blitz," not "this has never been built."

## When to use

- The user describes a new idea and wants to know if it's already been built (fits before/during the `scaffold/` idea-to-production flow).
- The user is mid-build and wants to check their concept against prior hackathon projects.

## How it works

1. **Extract search terms.** Pull 2-4 distinct phrases from the idea — specific noun phrases and domain terms, not generic words like "app" or "platform". Example: idea "an onchain prediction market for esports" → terms `"prediction market"`, `"esports"`, `"betting"`.
2. **Run the helper script** from this skill's `utils/` folder (use its full path on disk — it ships with the plugin; it has no dependencies and needs no install step):
   ```bash
   node <skill-dir>/utils/search-showcase.mjs "term 1" "term 2" [--category=X] [--max=150]
   ```
   This queries `https://blitz.devnads.com/api/showcase?search=<term>` once per term, dedupes results by project id, and prints a JSON shortlist (title, description, category, `github_url`/`demo_url`/`tweet_url`, event, `submitted_at`, winner status).
3. **Read `per_query_total_matches`.** This is the server-side total matched per term *before* truncation to `--max`. A high total is itself a signal the space is crowded, even if you don't review every match.
4. **Judge similarity yourself.** Read the returned descriptions and decide which are genuinely similar in concept — not just ones that share a keyword. A "prediction market" hit that's actually a sports-betting app for a totally different mechanism is not a real match.

## Reporting results

For each project you judge as a real match, report:
- Title
- One line on what specifically overlaps with the user's idea
- Links: whichever of `github_url`, `demo_url`, `tweet_url` are non-null
- Event name and `submitted_at`, plus `is_winner`/`winner_placement` if set

If nothing meaningfully overlaps, say so plainly, and repeat the caveat that this only covers tracked Monad Blitz submissions.

Never fabricate matches or links — only report projects actually returned by the script.

## Script reference

```
node utils/search-showcase.mjs "<term>" ["<term 2>" ...] [--category=<name>] [--event=<slug>] [--limit=<n>] [--max=<n>]
```

| Flag | Default | Notes |
|------|---------|-------|
| `--category` | none | Filters to a showcase category. Categories are free-text and not normalized (e.g. `DeFi`, `Defi`, `defi` all exist) — prefer relying on search terms unless you've confirmed the exact category string. |
| `--event` | none | Filters to one event slug (e.g. `blitz-ankara-27-Jun`). |
| `--limit` | `50` | Results fetched per search term from the API in one page. |
| `--max` | `150` | Cap on total deduped results returned to you. Keep this reasonable — you have to read every description, so don't raise it past what you'll actually review. |

No API key required; the script only makes `GET` requests.
