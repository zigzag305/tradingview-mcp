#!/usr/bin/env bash
# Verify a local tradingview-mcp install end to end.
#   1. dependencies resolve
#   2. the MCP server starts over stdio and registers its tools
#   3. live market data is actually reachable from this machine
#
# Usage: ./scripts/verify-install.sh
set -euo pipefail

cd "$(dirname "$0")/.."

command -v uv >/dev/null || {
  echo "uv not found. Install it:  curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
}

echo "==> 1/3  Installing dependencies"
uv sync --quiet
echo "    ok"

echo "==> 2/3  Starting server over stdio and listing tools"
uv run python - <<'PY'
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    params = StdioServerParameters(command=".venv/bin/tradingview-mcp", args=[])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print(f"    ok - {len(tools.tools)} tools registered")

asyncio.run(main())
PY

echo "==> 3/3  Checking live market data reachability"
uv run python - <<'PY'
import sys
from tradingview_ta import TA_Handler, Interval

try:
    analysis = TA_Handler(
        symbol="BTCUSDT", screener="crypto",
        exchange="BINANCE", interval=Interval.INTERVAL_1_DAY,
    ).get_analysis()
except Exception as exc:
    print(f"    FAILED - no market data: {exc}")
    print("    scanner.tradingview.com must be reachable from this machine.")
    sys.exit(1)

close = analysis.indicators.get("close")
rsi = analysis.indicators.get("RSI")
print(f"    ok - BTCUSDT 1d close={close} RSI={rsi:.2f} {analysis.summary['RECOMMENDATION']}")
PY

echo
echo "All checks passed. Wire it into your client:"
echo "  claude mcp add tradingview -- uv --directory \"$(pwd)\" run tradingview-mcp"
