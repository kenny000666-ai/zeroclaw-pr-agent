#!/bin/bash
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <pr-number>" >&2
  exit 2
fi
PR_NUM="$1"
REPO="kenny-k3s/ai_agents"
WORK="/zeroclaw-data/workspace/repos/ai_agents"
mkdir -p "$(dirname "$WORK")"

echo "Generating installation token..."
TOKEN=$(/zeroclaw-data/workspace/bin/gen_github_token.sh)
if [ -z "$TOKEN" ]; then
  echo "Failed to get token" >&2
  exit 3
fi

API="https://api.github.com/repos/${REPO}/pulls/${PR_NUM}"
echo "Fetching PR metadata $API"
curl -s -H "Authorization: token $TOKEN" "$API" -o /zeroclaw-data/workspace/pr_${PR_NUM}.json
if [ ! -s /zeroclaw-data/workspace/pr_${PR_NUM}.json ]; then
  echo "Failed to fetch PR metadata" >&2
  exit 4
fi

HEAD_REF=$(python3 -c 'import json,sys; print(json.load(open("/zeroclaw-data/workspace/pr_'${PR_NUM}'.json"))["head"]["ref"])')
if [ -z "$HEAD_REF" ]; then
  echo "Could not determine head.ref" >&2
  exit 5
fi

echo "PR $PR_NUM head ref: $HEAD_REF"

CLONE_URL="https://x-access-token:${TOKEN}@github.com/${REPO}.git"

if [ ! -d "$WORK/.git" ]; then
  echo "Cloning repo into workspace..."
  git clone "$CLONE_URL" "$WORK"
fi

cd "$WORK"

# Set git identity for all commits in this repo
git config user.email "zeropragent[bot]@users.noreply.github.com"
git config user.name "zeropragent[bot]"

# Update remote URL with fresh token (tokens expire)
git remote set-url origin "$CLONE_URL"

echo "Fetching origin..."
git fetch origin --prune

# Checkout PR branch
if git rev-parse --verify "$HEAD_REF" >/dev/null 2>&1; then
  git checkout "$HEAD_REF"
  git reset --hard "origin/$HEAD_REF" || true
else
  if git ls-remote --exit-code --heads origin "$HEAD_REF" >/dev/null 2>&1; then
    git checkout -B "$HEAD_REF" "origin/$HEAD_REF"
  else
    git fetch origin "refs/pull/${PR_NUM}/head:${HEAD_REF}" && git checkout "$HEAD_REF"
  fi
fi

# Fetch main and attempt merge
git fetch origin main
set +e
git merge --no-edit origin/main
MERGE_EXIT=$?
set -e

if [ "$MERGE_EXIT" -eq 0 ]; then
  echo "Merge successful with no conflicts"
  echo "Pushing merged branch back to origin/$HEAD_REF"
  git push "$CLONE_URL" "HEAD:$HEAD_REF"
  echo "Pushed successfully"
  exit 0
fi

# Detect conflicts
CONFLICTS=$(git diff --name-only --diff-filter=U || true)
if [ -z "$CONFLICTS" ]; then
  echo "Merge failed but no conflicted files found. Exiting." >&2
  exit 6
fi

echo "Conflicted files:"
echo "$CONFLICTS"

# Auto-resolve: prefer PR changes (ours)
for f in $CONFLICTS; do
  echo "Resolving $f by keeping PR (ours)"
  git checkout --ours -- "$f"
  git add -- "$f"
done

# Commit resolution
git commit -m "Auto-resolve merge conflicts with main: prefer PR changes"

# Push fixed branch
git push "$CLONE_URL" "HEAD:$HEAD_REF"

echo "Auto-fix and push complete for PR $PR_NUM"
