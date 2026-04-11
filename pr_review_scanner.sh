#!/usr/bin/env bash
# pr_review_scanner.sh
# Scans three GitHub orgs for open PRs that have no review from k3s-pr-merger[bot].
# Finds ONE unreviewed PR per cycle and triggers the pr-review skill via webhook.
# Loops internally every 10 seconds for ~50 seconds (cron fires every minute).
#
# Design:
#   - Uses state file only for dedup (reviewed{} and merged[]) — no pending queue.
#   - POSTs directly to http://localhost:3000/webhook to trigger the LLM pr-review skill.
#   - The skill handles review, scoring, posting, state update, and merge.
#
# Dependencies: curl (system), jq (workspace/bin/jq)
# Auth: GH_TOKEN environment variable (from openclaw-github secret)

set -eu

STATE_FILE="/zeroclaw-data/workspace/.pr_pipeline_state.json"
JQ="/zeroclaw-data/workspace/bin/jq"
GRAPHQL_URL="https://api.github.com/graphql"
WEBHOOK_URL="http://localhost:3000/webhook"
ORGS="kenny-k3s kenny-apps kenny000666"
LOOP_CYCLES=5
LOOP_SLEEP=10

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

die() {
  log "ERROR: $*"
  exit 1
}

# Verify dependencies
[ -z "${GH_TOKEN:-}" ] && die "GH_TOKEN not set"
[ -x "$JQ" ] || die "jq not found at $JQ — init container may not have run yet"
command -v curl >/dev/null || die "curl not found"

# Ensure state file exists with valid JSON
init_state() {
  if [ ! -f "$STATE_FILE" ]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '{"pending":[],"reviewed":{},"merged":[]}\n' > "$STATE_FILE"
  fi
  "$JQ" . "$STATE_FILE" >/dev/null 2>&1 || \
    printf '{"pending":[],"reviewed":{},"merged":[]}\n' > "$STATE_FILE"
}

# Return true if PR key is already in reviewed{} or merged[]
pr_already_handled() {
  local key="$1"
  local in_reviewed in_merged
  in_reviewed=$("$JQ" -r --arg k "$key" '.reviewed | has($k)' "$STATE_FILE")
  in_merged=$("$JQ" -r --arg k "$key" '.merged | map(. == $k) | any' "$STATE_FILE")
  [ "$in_reviewed" = "true" ] || [ "$in_merged" = "true" ]
}

# GraphQL: find ONE open PR across orgs with no review from k3s-pr-merger[bot]
# Returns "owner/repo#number" or empty string.
find_unreviewed_pr() {
  local QUERY
  QUERY='query($searchQuery: String!, $cursor: String) {
    search(query: $searchQuery, type: ISSUE, first: 50, after: $cursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        ... on PullRequest {
          number
          title
          repository { nameWithOwner }
          reviews(first: 20) {
            nodes { author { login } }
          }
        }
      }
    }
  }'

  for org in $ORGS; do
    local search_query="org:${org} is:pr is:open"
    local cursor="null"
    local has_next="true"

    while [ "$has_next" = "true" ]; do
      local vars
      if [ "$cursor" = "null" ]; then
        vars="$(printf '{"searchQuery":"%s"}' "$search_query")"
      else
        vars="$(printf '{"searchQuery":"%s","cursor":"%s"}' "$search_query" "$cursor")"
      fi

      local payload
      payload="$(printf '{"query":%s,"variables":%s}' \
        "$("$JQ" -Rs '.' <<< "$QUERY")" \
        "$vars")"

      local response
      response="$(curl -s -f \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: zeroclaw-pr-scanner/1.0" \
        --data "$payload" \
        "$GRAPHQL_URL")" || { log "curl failed for org ${org}"; break; }

      local errors
      errors="$("$JQ" -r '.errors // empty' <<< "$response" 2>/dev/null)"
      [ -n "$errors" ] && { log "GraphQL errors: $errors"; break; }

      has_next="$("$JQ" -r '.data.search.pageInfo.hasNextPage' <<< "$response" 2>/dev/null || echo "false")"
      local raw_cursor
      raw_cursor="$("$JQ" -r '.data.search.pageInfo.endCursor // "null"' <<< "$response" 2>/dev/null || echo "null")"
      cursor="$raw_cursor"

      local node_count i
      node_count="$("$JQ" '.data.search.nodes | length' <<< "$response" 2>/dev/null || echo 0)"
      i=0
      while [ "$i" -lt "$node_count" ]; do
        local number name_with_owner owner repo key
        local bot_reviewed
        number="$("$JQ" -r ".data.search.nodes[$i].number" <<< "$response")"
        name_with_owner="$("$JQ" -r ".data.search.nodes[$i].repository.nameWithOwner" <<< "$response")"

        if [ -z "$name_with_owner" ] || [ "$name_with_owner" = "null" ]; then
          i=$((i + 1)); continue
        fi

        owner="${name_with_owner%%/*}"
        repo="${name_with_owner#*/}"
        key="${owner}/${repo}#${number}"

        # Skip if already in state file
        if pr_already_handled "$key"; then
          i=$((i + 1)); continue
        fi

        # Skip if k3s-pr-merger[bot] already reviewed
        bot_reviewed="$("$JQ" -r \
          ".data.search.nodes[$i].reviews.nodes | map(select(.author.login == \"k3s-pr-merger[bot]\")) | length" \
          <<< "$response" 2>/dev/null || echo 0)"
        if [ "$bot_reviewed" -gt 0 ]; then
          i=$((i + 1)); continue
        fi

        # Found one — return it and stop
        echo "$key"
        return 0

        i=$((i + 1))
      done
    done
  done

  echo ""
}

# Trigger the pr-review skill via webhook
trigger_review() {
  local key="$1"
  local message="pr-review ${key}"
  local payload
  payload="$("$JQ" -n --arg m "$message" '{message: $m}')"

  local http_code
  http_code="$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    --max-time 10 \
    --data "$payload")" || true

  if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
    log "Triggered pr-review for ${key} (HTTP ${http_code})"
    return 0
  else
    log "WARN: webhook returned HTTP ${http_code} for ${key}"
    return 1
  fi
}

run_cycle() {
  local pr
  pr="$(find_unreviewed_pr)"
  if [ -z "$pr" ]; then
    log "No unreviewed PRs found"
    return 0
  fi
  log "Found unreviewed PR: $pr"
  trigger_review "$pr"
}

main() {
  log "PR scanner starting (${LOOP_CYCLES} cycles, ${LOOP_SLEEP}s apart)"
  init_state
  local cycle=0
  while [ "$cycle" -lt "$LOOP_CYCLES" ]; do
    run_cycle
    cycle=$((cycle + 1))
    if [ "$cycle" -lt "$LOOP_CYCLES" ]; then
      sleep "$LOOP_SLEEP"
    fi
  done
  log "PR scanner done"
}

main
