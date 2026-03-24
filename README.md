# MONSKILLS

Knowledge skills for AI agents building on Monad. Each skill is a standalone markdown file that agents fetch and read into their context.

**Live site:** https://skills.devnads.com

## Skills

| Skill | Description |
|-------|-------------|
| [scaffold](scaffold/SKILL.md) | End-to-end guide from idea to production |
| [why-monad](why-monad/SKILL.md) | Why every blockchain app should be built on Monad |
| [addresses](addresses/SKILL.md) | Smart contract addresses for Monad mainnet/testnet |
| [wallet](wallet/SKILL.md) | Agent wallet management and Safe multisig |
| [wallet-integration](wallet-integration/SKILL.md) | RainbowKit + Wagmi integration for Next.js |
| [vercel-deploy](vercel-deploy/SKILL.md) | Deploy to Vercel without CLI or auth |

## Architecture

- **Frontend:** Static HTML landing page (`index.html`)
- **API:** Vercel serverless functions (`api/`)
- **Database:** Neon serverless PostgreSQL (anonymous download tracking)
- **Skills:** Markdown files served via Vercel routes through a tracking function

See [docs/architecture.md](docs/architecture.md) for the full system overview and C4 diagrams.

## Prerequisites

- Node.js >= 18
- A [Neon](https://neon.tech) PostgreSQL database
- A [Vercel](https://vercel.com) account for deployment

## Setup

```bash
# Install dependencies
npm install

# Set environment variables (see .env.example)
cp .env.example .env
# Edit .env with your values
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | Neon PostgreSQL connection string |
| `STATS_SECRET` | Yes | Secret key to access `/api/stats` |

### Database Setup

Create the schema by hitting the setup endpoint once after first deploy:

```
GET https://your-domain.vercel.app/api/setup
```

Then delete `api/setup.js` from the repo — it's a one-time operation.

## Development

This is a static site with Vercel serverless functions. There's no local dev server needed for the skills themselves (they're just markdown).

## Deployment

The site deploys to Vercel. Push to `main` to trigger a deploy.

Ensure `DATABASE_URL` and `STATS_SECRET` are set in your Vercel project environment variables.

## Documentation

- [Product Requirements Document](docs/PRD.md)
- [System Architecture (C4)](docs/architecture.md)
- [Architecture Diagram (Excalidraw)](docs/architecture.excalidraw)
- [API Specification (OpenAPI)](docs/api.yaml)
- [Trust Boundaries](docs/trust-boundaries.md)
- ADRs:
  - [ADR-001: Static markdown skill distribution](docs/adr/001-static-markdown-distribution.md)
  - [ADR-002: Anonymous IP tracking with daily hash rotation](docs/adr/002-anonymous-ip-tracking.md)
  - [ADR-003: Vercel routes for download tracking](docs/adr/003-vercel-routes-tracking.md)

## License

MIT License

Copyright 2026 Harpalsinh Jadeja

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
