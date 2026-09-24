# Hosted deployment — tradingview-mcp over streamable-http

Runs the server on a VPS behind Caddy, reachable from claude.ai, ChatGPT,
Cursor or any MCP client, from any device, whether or not your laptop is on.

## Read this first

**The MCP server has no authentication.** In `streamable-http` mode an
unauthenticated POST to `/mcp` opens a session and exposes all 37 tools. This
is verified behavior, not a theory. Two consequences:

1. Never publish the server's port directly. Caddy in front of it is not
   optional, it is the entire access control story.
2. Whoever holds your token uses *your* server and *your* IP against the
   upstream data sources. If it leaks, rotate it (below).

`smoke-test.sh` exists to prove the auth actually works before you trust it.
Run it every time you deploy.

## What you need

| | |
|---|---|
| A VPS | 1 vCPU / 2 GB is plenty. Hetzner CX22 (~€4/mo), DigitalOcean or Vultr ($6/mo). |
| A domain | Any subdomain you control, e.g. `mcp.yourdomain.com`. Required — Let's Encrypt will not issue for a bare IP. |
| Ports | 80 and 443 open inbound. |
| Docker | Engine + Compose plugin on the box. |

Pick a region near you; every tool call pays the round trip twice.

## Deploy

**1. Point DNS at the box.** An `A` record for your subdomain → the VPS IP.
Do this first and let it propagate. Let's Encrypt validates over HTTP, so if
DNS is not live yet, certificate issuance fails and Caddy retries with backoff.

Confirm before continuing:
```bash
dig +short mcp.yourdomain.com     # must print your VPS IP
```

**2. On the box:**
```bash
git clone https://github.com/zigzag305/tradingview-mcp.git
cd tradingview-mcp/deploy
cp .env.example .env
```

**3. Edit `.env`** — set `DOMAIN`, and generate a real token:
```bash
openssl rand -hex 32
```

**4. Start it:**
```bash
docker compose up -d
docker compose logs -f caddy     # watch the certificate get issued, then Ctrl-C
```

**5. Verify — do not skip this:**
```bash
./smoke-test.sh
```

Five checks: TLS valid, no-token rejected, wrong-token rejected, right-token
accepted, and raw port 8000 unreachable. Check 2 failing means the server is
open to the internet; take it down with `docker compose down` before anything
else.

## Connect it

**claude.ai** — Settings → Connectors → Add custom connector:
- URL: `https://mcp.yourdomain.com/mcp`
- Header: `Authorization: Bearer <your token>`

**Claude Code:**
```bash
claude mcp add --transport http tradingview \
  https://mcp.yourdomain.com/mcp \
  --header "Authorization: Bearer <your token>"
```

Then ask for something only live data answers: *"What's the multi-timeframe
read on BTC right now?"*

## Operating it

**Update:**
```bash
git pull && docker compose up -d --build && ./smoke-test.sh
```

**Rotate the token** — do this if it ever appears in a screenshot, a shared
config, or a chat log:
```bash
openssl rand -hex 32          # put the new value in .env
docker compose up -d caddy    # Caddy reloads; the old token stops working
```
Then update every client that used the old one.

**Logs:**
```bash
docker compose logs -f mcp                              # tool calls and errors
docker exec -it deploy-caddy-1 tail -f /var/log/caddy/access.log   # requests
```

Watch the access log for 401s you did not cause. A steady stream means someone
is probing; that is expected on a public IP and is exactly what the 401 is for.

## Hardening worth doing

The stack is safe by default but minimal. In rough order of value:

- **Firewall.** Allow only 22, 80, 443 inbound (`ufw allow 22,80,443/tcp`).
  Nothing else needs to be reachable.
- **Rate limiting.** Caddy's rate limiter is a plugin and needs a custom image.
  Worth adding if your token is shared with anyone.
- **Unattended upgrades** for OS security patches.
- **Fail2ban** on SSH if you keep password auth (better: keys only).

## When this is the wrong choice

If only you use it, on one laptop, stdio is simpler and free — see
`QUICKSTART-PHASE1.md`. The hosted setup earns its keep when you want the tools
from your phone, from claude.ai in a browser, from a cloud session, or shared
with someone else. Otherwise you are paying €4/mo and maintaining a box to
reach parity with a local subprocess.
