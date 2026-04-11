#!/usr/bin/env bash
# gh-app-review.sh
# Post a formal GitHub App APPROVE or COMMENT review on a PR.
# Uses RS256 JWT to obtain a GitHub App installation token.
#
# Usage: gh-app-review.sh <owner> <repo> <pr_number> <head_sha> <risk_score> <review_body>
#
# Required env / files:
#   GITHUB_APP_ID           — from zeropragent-github-app secret (app-id key)
#   GITHUB_INSTALLATION_ID  — from zeropragent-github-app secret (installation-id key)
#   /zeroclaw-data/.zeroclaw/github-app.pem — RSA private key (mounted by deployment)
#
# Dependencies: openssl, curl, jq (workspace/bin/jq)

set -eu

OWNER="${1:?owner required}"
REPO="${2:?repo required}"
PR_NUMBER="${3:?pr_number required}"
HEAD_SHA="${4:?head_sha required}"
SCORE="${5:?risk_score required}"
REVIEW_BODY="${6:?review_body required}"

JQ="/zeroclaw-data/workspace/bin/jq"
PEM="/zeroclaw-data/.zeroclaw/github-app.pem"
APP_ID="${GITHUB_APP_ID:?GITHUB_APP_ID not set}"
INSTALL_ID="${GITHUB_INSTALLATION_ID:?GITHUB_INSTALLATION_ID not set}"

# ── Dedup check: skip if any existing review contains zeroclaw-pr-agent ──
# Note: concatenate ALL review bodies (not just head -1) to avoid missing prior reviews.
EXISTING_BODIES=$(curl -s \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews?per_page=100" | \
  "$JQ" -r '.[] | select(.user.login == "k3s-pr-merger[bot]") | .body' 2>/dev/null)
if echo "$EXISTING_BODIES" | grep -q "zeroclaw-pr-agent"; then
  echo "SKIP: already reviewed by zeroclaw-pr-agent (dedup)"
  exit 0
fi

[ -f "$PEM" ] || { echo "ERROR: PEM not found at $PEM"; exit 1; }
[ -x "$JQ" ]  || { echo "ERROR: jq not found at $JQ"; exit 1; }

# ── Generate JWT (RS256) ──────────────────────────────────────────────────
NOW=$(date +%s)
IAT=$((NOW - 60))   # issued 60s in the past to allow clock skew
EXP=$((NOW + 540))  # 9-minute expiry (max 10 min per GitHub docs)

b64url() {
  openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | b64url)
SIG=$(printf '%s.%s' "$HEADER" "$PAYLOAD" \
  | openssl dgst -sha256 -sign "$PEM" \
  | b64url)
JWT="${HEADER}.${PAYLOAD}.${SIG}"

# ── Exchange JWT for installation token ───────────────────────────────────
TOKEN_RESP=$(curl -s -f \
  -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${INSTALL_ID}/access_tokens")

INSTALL_TOKEN=$("$JQ" -r '.token' <<< "$TOKEN_RESP")
[ -n "$INSTALL_TOKEN" ] && [ "$INSTALL_TOKEN" != "null" ] \
  || { echo "ERROR: failed to get installation token: $TOKEN_RESP"; exit 1; }

# ── Decide event ─────────────────────────────────────────────────────────
if [ "$SCORE" -lt 50 ]; then
  EVENT="APPROVE"
else
  EVENT="COMMENT"
fi
BODY="$REVIEW_BODY"

# ── Clear any existing PENDING review from this app ──────────────────────
# GitHub only allows one pending review per user/app per PR.
# List existing reviews, find PENDING ones, delete them before posting.
EXISTING_REVIEWS=$(curl -s \
  -H "Authorization: Bearer $INSTALL_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews?per_page=100")

PENDING_IDS=$("$JQ" -r '[.[] | select(.state == "PENDING") | .id] | .[]' <<< "$EXISTING_REVIEWS" 2>/dev/null || true)

for PENDING_ID in $PENDING_IDS; do
  echo "Deleting existing PENDING review id=$PENDING_ID on ${OWNER}/${REPO}#${PR_NUMBER}"
  curl -s -f \
    -X DELETE \
    -H "Authorization: Bearer $INSTALL_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews/${PENDING_ID}" \
    >/dev/null || echo "WARN: failed to delete pending review $PENDING_ID (continuing)"
done

# ── Post formal review ────────────────────────────────────────────────────
REVIEW_RESP=$(curl -s -f \
  -X POST \
  -H "Authorization: Bearer $INSTALL_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
  -d "$("$JQ" -n \
    --arg sha   "$HEAD_SHA" \
    --arg event "$EVENT" \
    --arg body  "$BODY" \
    '{commit_id: $sha, event: $event, body: $body}')")

REVIEW_ID=$("$JQ" -r '.id // "unknown"' <<< "$REVIEW_RESP")
echo "Posted $EVENT review (id=$REVIEW_ID) on ${OWNER}/${REPO}#${PR_NUMBER} (score=$SCORE)"

# ── Update state file: move from pending[] to reviewed{} ─────────────────
STATE_FILE="/zeroclaw-data/workspace/.pr_pipeline_state.json"
if [ -f "$STATE_FILE" ]; then
  KEY="${OWNER}/${REPO}#${PR_NUMBER}"
  DECISION="$([ "$EVENT" = "APPROVE" ] && echo "approved" || echo "commented")"
  TMP="${STATE_FILE}.tmp"
  "$JQ" \
    --arg k "$KEY" \
    --arg decision "$DECISION" \
    --argjson score "$SCORE" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.pending = [.pending[] | select(.owner + "/" + .repo + "#" + (.number | tostring) != $k)]
     | .reviewed[$k] = {score: $score, decision: $decision, recommendations: [], reviewed_at: $ts}' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  echo "State updated: $KEY → $DECISION (score=$SCORE)"
fi

# ── Telegram alert (COMMENT only — PR needs human review) ────────────────
if [ "$EVENT" = "COMMENT" ]; then
  TG_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  TG_CHAT="${TELEGRAM_ALERT_CHAT_ID:-}"
  if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT" ]; then
    ALERT_TEXT="PR needs human review: ${OWNER}/${REPO}#${PR_NUMBER} — Risk score ${SCORE}/100. Auto-merge skipped. https://github.com/${OWNER}/${REPO}/pull/${PR_NUMBER}"
    ALERT_RESP=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      --max-time 15 \
      -d "$("$JQ" -n --arg chat "$TG_CHAT" --arg text "$ALERT_TEXT" \
        '{chat_id: ($chat | tonumber), text: $text, disable_notification: false}')") || true
    if [ "$ALERT_RESP" = "200" ]; then
      echo "Telegram alert sent (HTTP 200)"
    else
      echo "WARN: Telegram alert returned HTTP $ALERT_RESP (non-fatal)"
    fi
  else
    echo "WARN: TELEGRAM_BOT_TOKEN or TELEGRAM_ALERT_CHAT_ID not set — skipping alert"
  fi
fi
