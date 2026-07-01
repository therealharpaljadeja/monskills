#!/usr/bin/env node
// Query the Monad Blitz showcase API for prior-art projects matching a new idea.
//
// Usage:
//   node search-showcase.mjs "<term 1>" ["<term 2>" ...] [--category=X] [--event=slug] [--limit=50] [--max=150]

const API = 'https://blitz.devnads.com/api/showcase';

function parseArgs(argv) {
  const terms = [];
  const opts = { category: undefined, event: undefined, limit: 50, max: 150 };
  for (const arg of argv) {
    if (arg.startsWith('--category=')) opts.category = arg.slice('--category='.length);
    else if (arg.startsWith('--event=')) opts.event = arg.slice('--event='.length);
    else if (arg.startsWith('--limit=')) opts.limit = Number(arg.slice('--limit='.length));
    else if (arg.startsWith('--max=')) opts.max = Number(arg.slice('--max='.length));
    else terms.push(arg);
  }
  return { terms, opts };
}

async function fetchQuery(term, opts) {
  const url = new URL(API);
  if (term) url.searchParams.set('search', term);
  if (opts.category) url.searchParams.set('category', opts.category);
  if (opts.event) url.searchParams.set('event', opts.event);
  url.searchParams.set('limit', String(opts.limit));
  const res = await fetch(url);
  if (!res.ok) throw new Error(`showcase API returned ${res.status} for query "${term}"`);
  return res.json();
}

function summarize(project) {
  return {
    id: project.id,
    title: project.title,
    description: project.description,
    category: project.category,
    github_url: project.github_url,
    demo_url: project.demo_url,
    tweet_url: project.tweet_url,
    event: project.event ? { name: project.event.name, slug: project.event.slug } : null,
    submitted_at: project.submitted_at,
    is_winner: project.is_winner,
    winner_placement: project.winner_placement,
  };
}

async function main() {
  const { terms, opts } = parseArgs(process.argv.slice(2));
  if (terms.length === 0) {
    console.error(
      'Usage: node search-showcase.mjs "<term 1>" ["<term 2>" ...] [--category=X] [--event=slug] [--limit=50] [--max=150]'
    );
    process.exit(1);
  }

  const seen = new Map();
  const perQueryTotals = {};

  for (const term of terms) {
    const data = await fetchQuery(term, opts);
    perQueryTotals[term] = data.total;
    for (const project of data.projects) {
      if (!seen.has(project.id)) seen.set(project.id, summarize(project));
    }
  }

  let results = Array.from(seen.values());
  const truncated = results.length > opts.max;
  results = results.slice(0, opts.max);

  console.log(
    JSON.stringify(
      {
        queries: terms,
        per_query_total_matches: perQueryTotals,
        returned: results.length,
        truncated,
        results,
      },
      null,
      2
    )
  );
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
