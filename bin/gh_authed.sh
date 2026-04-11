#!/bin/sh
# gh_authed.sh — run any gh command with a fresh GitHub App token
# Usage: gh_authed.sh pr list -R kenny-k3s/ai_agents --state open --limit 5
set -e
GH_TOKEN=$(/zeroclaw-data/workspace/bin/gen_github_token.sh)
export GH_TOKEN
exec gh "$@"
