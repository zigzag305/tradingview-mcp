#!/usr/bin/env bash
# Phase 1 setup: tradingview-mcp + OpenBB as MCP servers for Claude Code.
# Both are free and need no API keys to start.
set -euo pipefail

BASE="${1:-$HOME/trading}"
echo "==> Installing into: $BASE"
mkdir -p "$BASE"

if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# ---------- 1. tradingview-mcp (no API key needed) ----------
echo "==> Setting up tradingview-mcp"
if [ ! -d "$BASE/tradingview-mcp/.git" ]; then
  git clone --depth 1 https://github.com/atilaahmettaner/tradingview-mcp "$BASE/tradingview-mcp"
fi
cd "$BASE/tradingview-mcp"
uv venv .venv
uv pip install --python .venv/bin/python -e .
TV_BIN="$BASE/tradingview-mcp/.venv/bin/tradingview-mcp"

# ---------- 2. OpenBB + its MCP server ----------
echo "==> Setting up OpenBB (this one takes a few minutes)"
uv venv "$BASE/.obb-venv"
uv pip install --python "$BASE/.obb-venv/bin/python" openbb openbb-yfinance openbb-mcp-server
# First import builds the extension map; do it now so Claude doesn't time out later.
"$BASE/.obb-venv/bin/python" -c "from openbb import obb; print('OpenBB extensions built')"
OBB_BIN="$BASE/.obb-venv/bin/openbb-mcp"

# ---------- 3. Wire into Claude Code ----------
echo "==> Writing $BASE/.mcp.json"
cat > "$BASE/.mcp.json" <<JSON
{
  "mcpServers": {
    "tradingview": {
      "command": "$TV_BIN",
      "args": [],
      "env": {}
    },
    "openbb": {
      "command": "$OBB_BIN",
      "args": ["--transport", "stdio", "--tool-discovery"],
      "env": {}
    }
  }
}
JSON

echo
echo "==> Done. Next:"
echo "   cd $BASE && claude"
echo "   Approve both MCP servers when prompted, then try:"
echo "     \"Use tradingview top_gainers for crypto\""
echo "     \"Use openbb to pull SPY price history for the last 6 months\""
