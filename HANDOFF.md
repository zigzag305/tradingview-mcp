# Where this work stands

Context for picking this up in a new session (Cowork, a fresh Claude Code
session, or any other surface). Everything described here is on the branch
`claude/trading-repos-review-dgj6dz`.

## The plan

Three phases, agreed after reviewing eight trading repos:

1. **Phase 1 (current)** — wire this MCP server into an AI client and learn what
   the tools actually return. Free, no infrastructure.
2. **Phase 2** — TradingAgents on a server, one ticker a day, decisions logged,
   paper only, for 60 days before trusting anything.
3. **Phase 3** — only if Phase 2 earns it: nautilus_trader for execution.

FinRL was deliberately deprioritized (its own README now points new work at
FinRL-X). agency-agents and digital-marketing-pro are not trading tools; they
are the business layer if any of this becomes a product.

## What is already built here

| File | What it does |
|---|---|
| `QUICKSTART-PHASE1.md` | Local stdio wiring for Claude Code and Claude Desktop |
| `scripts/verify-install.sh` | 3-way diagnostic: deps / server start / data reachable |
| `deploy/` | Hosted option — Caddy with TLS + bearer auth, compose, smoke test |
| `Dockerfile` | Healthcheck fixed (it probed `/health`, which 404s) |

## Two findings worth not rediscovering

1. **The server has no authentication.** In `streamable-http` mode an
   unauthenticated POST to `/mcp` completes `initialize` and exposes all 37
   tools. Verified, not theoretical. It must never be exposed directly — that
   is what `deploy/` exists for, and why `deploy/smoke-test.sh` asserts
   no-token and wrong-token both return 401.

2. **The Dockerfile healthcheck was broken.** It probed `/health`; FastMCP
   serves `/mcp` only, so every container was marked unhealthy forever. Now a
   TCP connect check, verified against both a live and a dead port.

## Current state

Phase 1, local install. Not yet hosted.

## Hosting, when it is wanted

Decided against for now, deliberately — local first, decide later. Two paths
are ready:

- **VPS** — built and documented in `deploy/README.md`. ~$6/mo. Needs a domain,
  a DNS record, SSH. Always on, no cold starts.
- **Cloudflare Containers** — not built yet. ~$5/mo Workers Paid. No domain, no
  DNS, no SSH, no Caddy; free HTTPS on `*.workers.dev`. Needs a ~40-line
  TypeScript Worker wrapper. One detail to get right: MCP sessions must route
  to a single fixed container instance ID, or session state breaks between
  requests. Trade-off is a 10-20s cold start after idle.

The Dockerfile is identical for both, so neither choice wastes the other's work.

**This becomes load-bearing on a cloud surface.** A local stdio server is a
subprocess on one machine; anything running in the cloud (browser Cowork, a
cloud session) cannot reach it and needs one of the hosted paths above.

## Note on the data sources

No API keys anywhere — that is a real advantage of this server. But the upstream
hosts must be reachable, and they rate-limit by IP:

`scanner.tradingview.com` (most tools), `query1.finance.yahoo.com` (prices,
options), news RSS hosts, `reddit.com` (sentiment).

Cloud containers with a restrictive network policy will block these. That is a
network-policy question, not a bug in the server.
