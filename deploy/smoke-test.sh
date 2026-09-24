#!/usr/bin/env bash
# Post-deploy verification. Run this after `docker compose up -d`.
#
# Checks, in order:
#   1. TLS is valid and the domain resolves here
#   2. A request with NO token is rejected      <- the one that matters
#   3. A request with a WRONG token is rejected
#   4. A request with the right token works
#   5. The MCP port is not reachable directly, bypassing auth
#
# Exits non-zero on the first failure. Check 2 failing means your server is
# open to the internet: take it down before doing anything else.
set -uo pipefail

cd "$(dirname "$0")"

[ -f .env ] || { echo "No .env here. cp .env.example .env and fill it in."; exit 1; }
set -a; . ./.env; set +a
: "${DOMAIN:?DOMAIN not set in .env}"
: "${MCP_TOKEN:?MCP_TOKEN not set in .env}"

URL="https://${DOMAIN}/mcp"
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1"}}}'
ACCEPT='Accept: application/json, text/event-stream'
fail=0

probe() { # $1 = auth header value ("" for none) -> prints status code
  if [ -z "$1" ]; then
    curl -s -o /dev/null -w '%{http_code}' -m 20 -X POST "$URL" \
      -H 'Content-Type: application/json' -H "$ACCEPT" -d "$INIT"
  else
    curl -s -o /dev/null -w '%{http_code}' -m 20 -X POST "$URL" \
      -H 'Content-Type: application/json' -H "$ACCEPT" \
      -H "Authorization: $1" -d "$INIT"
  fi
}

echo "==> 1/5  TLS certificate for ${DOMAIN}"
if curl -sS -o /dev/null -m 20 "https://${DOMAIN}/" 2>/tmp/tls.err; then
  echo "    ok"
else
  # A 401 from Caddy still proves TLS worked.
  if grep -qi 'certificate\|SSL\|TLS' /tmp/tls.err; then
    echo "    FAILED - TLS problem:"; sed 's/^/      /' /tmp/tls.err
    echo "    Check the A record points here and ports 80/443 are open."
    echo "    Watch issuance with: docker compose logs -f caddy"
    exit 1
  fi
  echo "    ok"
fi

echo "==> 2/5  Request with no token must be rejected"
code=$(probe "")
if [ "$code" = "401" ]; then
  echo "    ok - 401"
else
  echo "    *** FAILED - got HTTP $code, expected 401 ***"
  echo "    *** YOUR SERVER IS OPEN TO THE INTERNET. Run: docker compose down ***"
  fail=1
fi

echo "==> 3/5  Request with a wrong token must be rejected"
code=$(probe "Bearer definitely-not-the-token")
if [ "$code" = "401" ]; then echo "    ok - 401"; else
  echo "    *** FAILED - got HTTP $code, expected 401 ***"; fail=1
fi

echo "==> 4/5  Request with the correct token must succeed"
code=$(probe "Bearer ${MCP_TOKEN}")
if [ "$code" = "200" ]; then echo "    ok - 200"; else
  echo "    FAILED - got HTTP $code, expected 200"
  echo "    Inspect with: docker compose logs mcp"
  fail=1
fi

echo "==> 5/5  Raw MCP port must not be reachable from outside"
code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${DOMAIN}:8000/mcp" 2>/dev/null || echo "000")
if [ "$code" = "000" ]; then echo "    ok - port 8000 refused"; else
  echo "    *** FAILED - port 8000 answered with HTTP $code, bypassing auth ***"
  echo "    *** Remove any ports: block from the mcp service and redeploy ***"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed. Connect with:"
  echo "  URL:    ${URL}"
  echo "  Header: Authorization: Bearer <your MCP_TOKEN>"
else
  echo "One or more checks FAILED - see above. Do not use this deployment yet."
  exit 1
fi
