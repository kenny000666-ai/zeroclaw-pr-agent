#!/bin/sh
set -euo pipefail
# List open PRs for the ai_agents repo using gh if available, else fallback to curl+python
REPO="kenny-k3s/ai_agents"
# Generate token
TOKEN=$(/zeroclaw-data/workspace/bin/gen_github_token.sh)
export GH_TOKEN="$TOKEN"
# Prefer workspace gh
if [ -x "/zeroclaw-data/workspace/bin/gh" ]; then
  GH_BIN="/zeroclaw-data/workspace/bin/gh"
elif command -v gh >/dev/null 2>&1; then
  GH_BIN="gh"
else
  GH_BIN=""
fi
if [ -n "$GH_BIN" ]; then
  # Use gh to list PRs in JSON
  "$GH_BIN" pr list --state open --repo "$REPO" --limit 50 --json number,title,url
else
  # Fallback to GitHub API via curl + python
  curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO/pulls?state=open&per_page=100" | python3 - <<PY
import sys, json
prs = json.load(sys.stdin)
out = []
for p in prs:
    out.append({"number": p.get(number), "title": p.get(title), "url": p.get(html_url)})
print(json.dumps(out))
PY
fi
