# Phase 1 — wire tradingview-mcp into your AI client

Goal: ask for market analysis in plain language and get real data back.
No API keys, no accounts, no infrastructure. About five minutes.

## Why this runs on your machine

An MCP server over stdio is launched as a subprocess by the client that uses it.
It has to live on the same machine as that client. A cloud session cannot host
it for you — the process would end with the session.

So: this goes on the laptop where you run Claude Code or Claude Desktop.

## Install

One prerequisite — `uv`:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh      # macOS / Linux
```
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"   # Windows
```

### Option A — from PyPI (fastest, nothing to clone)

```bash
claude mcp add tradingview -- uvx --from tradingview-mcp-server tradingview-mcp
```

### Option B — from this repo (use this if you want to edit the tools)

```bash
git clone https://github.com/zigzag305/tradingview-mcp.git
cd tradingview-mcp
./scripts/verify-install.sh
claude mcp add tradingview -- uv --directory "$(pwd)" run tradingview-mcp
```

`verify-install.sh` checks three things: dependencies resolve, the server starts
and registers its 37 tools, and live market data is reachable from your network.
Run it before wiring anything up — it tells you which of the three broke.

### Claude Desktop instead of Claude Code

Add to `claude_desktop_config.json`, then **fully quit and reopen the app** —
saving the file is not enough, MCP servers connect at startup.

macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
Windows: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "tradingview": {
      "command": "uvx",
      "args": ["--from", "tradingview-mcp-server", "tradingview-mcp"]
    }
  }
}
```

## Confirm it worked

```bash
claude mcp list
```

`tradingview` should be listed and connected. Then ask for something only live
data can answer:

```
What's the multi-timeframe read on BTC right now?
```

If you get actual prices, you're done.

## First week — what to actually ask

Start with reads, not strategies. You are learning what the tools return
before you trust any of it.

```
Show today's top gainers on Binance
Run a full technical analysis of NVDA
What's the multi-timeframe read on gold?
Give me the Bitcoin market pulse
```

Then move to the part that has real value — testing whether an edge survives
contact with out-of-sample data:

```
Backtest an RSI strategy on BTC on the daily timeframe
Compare all 9 strategies on ETH daily
Run a walk-forward backtest of macd_cross on BTC daily
```

`walk_forward_backtest_strategy` is the one worth your attention. It splits
train and test and returns an overfitting verdict — ROBUST, MODERATE, WEAK or
OVERFITTED. A strategy that looks excellent in `backtest_strategy` and comes
back OVERFITTED here is a strategy that fits the past and will not repeat. That
distinction is the whole reason to run Phase 1 before building anything.

## What this is not

These tools compute indicators from third-party market data. They do not
execute trades, and nothing they return is financial advice. Treat the output
as an instrument reading, not a decision.

## Where the data comes from

Outbound HTTPS to these hosts must be reachable, or tools fail with connection
errors rather than bad data:

| Host | Used by |
|---|---|
| `scanner.tradingview.com` | screeners, TA, most tools |
| `query1.finance.yahoo.com` | `yahoo_price`, extended hours, options |
| `finance.yahoo.com`, `cnbc.com`, `marketwatch.com` | `financial_news` |
| `reddit.com` | `market_sentiment` |

Corporate VPNs and locked-down networks block the first one most often.
