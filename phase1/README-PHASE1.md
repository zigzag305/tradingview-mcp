# Phase 1 — Free research stack (tradingview-mcp + OpenBB)

Two MCP servers, no API keys, no paid subscriptions.

## Install

```bash
bash setup-phase1.sh ~/trading      # takes ~5-10 min (OpenBB is large)
cd ~/trading && claude              # approve both servers when prompted
```

## What you get

| Server | Tools | Keys needed |
|---|---|---|
| `tradingview` | 37 — screeners, technical ratings, multi-timeframe, backtests | none |
| `openbb` | 197, exposed via discovery (10 visible) | none to start |

OpenBB runs in **tool-discovery mode**: Claude sees 10 admin tools and calls
`available_categories` / `activate_category` to pull in only what a question
needs. Without this it registers all 197 at once and floods the context.

## First things to try

- "Use tradingview `top_gainers` for crypto, then `combined_analysis` on the top 2"
- "Activate the openbb equity category, then pull SPY price history for 6 months"
- "Use openbb `economy` tools to chart CPI and unemployment for the last 3 years"

## Optional free keys (later, not needed now)

- **FRED** (`fredaccount.stlouisfed.org`) — macro series. Free.
- **Marketaux** — news sentiment for tradingview-mcp's `financial_news`. Free tier.

Set via `obb.account` or env vars; neither is required for Phase 1.

## Known limits

- tradingview-mcp reads `scanner.tradingview.com`, an internal undocumented
  endpoint. It works, but it can change without notice and rate-limits under
  parallel bursts. Don't build anything load-bearing on it.
- OpenBB's free providers (yfinance, SEC, FRED) are fine for research but are
  delayed and occasionally gappy. Verify anything before it informs a real trade.
- Corporate/VPN networks sometimes block these finance endpoints outright.

## Phase 1 exit criteria

You can ask one question in plain English and get a coherent multi-source read
on a ticker — price action, technicals, and one fundamental or macro input —
without hand-editing any code. When that works, move to Phase 2 (Unusual Whales).
