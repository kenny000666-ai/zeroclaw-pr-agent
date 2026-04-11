#!/bin/sh
# gen_github_token.sh — Generate a GitHub App installation token on demand.
# Usage: gen_github_token.sh [pem-path] [app-id] [installation-id]
# Falls back to env vars GITHUB_APP_ID, GITHUB_INSTALLATION_ID if args not supplied.
# Outputs the installation token to stdout.

set -e

PEM="${1:-/zeroclaw-data/.zeroclaw/github-app.pem}"
APP_ID="${2:-$GITHUB_APP_ID}"
INSTALLATION_ID="${3:-$GITHUB_INSTALLATION_ID}"

if [ -z "$APP_ID" ] || [ -z "$INSTALLATION_ID" ]; then
  echo "ERROR: APP_ID and INSTALLATION_ID are required (args or env vars)" >&2
  exit 1
fi

if [ ! -r "$PEM" ]; then
  echo "ERROR: Cannot read private key at $PEM" >&2
  exit 1
fi

# Generate a JWT valid for 9 minutes (iat-60 to exp+540)
JWT=$(python3 - <<EOF
import time, base64, json, subprocess, sys

app_id = "$APP_ID"
pem = "$PEM"
now = int(time.time())

header  = base64.urlsafe_b64encode(json.dumps({"alg":"RS256","typ":"JWT"}).encode()).rstrip(b"=").decode()
payload = base64.urlsafe_b64encode(json.dumps({"iat": now-60, "exp": now+540, "iss": app_id}).encode()).rstrip(b"=").decode()
msg = f"{header}.{payload}"

sig_raw = subprocess.check_output(
    ["openssl", "dgst", "-sha256", "-sign", pem],
    input=msg.encode()
)
sig = base64.urlsafe_b64encode(sig_raw).rstrip(b"=").decode()
print(f"{msg}.{sig}")
EOF
)

# Exchange JWT for an installation access token (~1 hour TTL)
curl -sf \
  -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)[\"token\"])"
