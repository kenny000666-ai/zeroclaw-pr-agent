# zeroclaw-pr-agent

Autonomous GitHub PR review and merge pipeline running on [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) inside a Kubernetes cluster.

## What this agent does

`zeroclaw-pr-agent` scans three GitHub organisations (`kenny-k3s`, `kenny-apps`, `kenny000666`) every minute for open pull requests that have not yet been reviewed by the `k3s-pr-merger[bot]` GitHub App. For each unreviewed PR it:

1. **Scores the diff** against a risk rubric (Critical +35, Normal +15, Low +5, capped at 100).
2. **Posts a formal review** as the `k3s-pr-merger[bot]` GitHub App — APPROVE if score < 50, COMMENT only if score ≥ 50.
3. **Merges automatically** (squash) when the decision is APPROVED.
4. **Alerts via Telegram** when a PR scores ≥ 50 and needs human attention.
5. **Tracks state** in `.pr_pipeline_state.json` so no PR is reviewed or merged twice.

## Architecture

```
Every minute (cron):
  pr_review_scanner.sh — loops 5× with sleep 10
    └─ GraphQL: find ONE open PR with no k3s-pr-merger[bot] review
    └─ Skip if already in reviewed{} or merged[] (state file dedup)
    └─ POST http://localhost:3000/webhook {"message": "pr-review owner/repo#number"}

pr-review skill (LLM agent, triggered by webhook):
    1. Dedup check via state file + gh-app-review.sh
    2. Fetch PR diff via GitHub MCP (github__gh-pull_request_read)
    3. Score + compose review body
    4. bash gh-app-review.sh → posts review as GitHub App, updates state
    5. If APPROVED → github__gh-merge_pull_request (squash) + add to merged[]
```

## Risk scoring rubric

| Finding | Points |
|---|---|
| Critical (secrets, RCE, privilege escalation, destructive ops) | +35 |
| Normal (missing error handling, insecure config, breaking change, no tests) | +15 |
| Low (style, docs gap, minor warning) | +5 |
| **Cap** | 100 |

| Score | Risk band | Decision |
|---|---|---|
| 0–49 | Low / Moderate | APPROVE + squash merge |
| 50–100 | High / Critical | COMMENT only + Telegram alert |

## Runtime files

| File | Purpose |
|---|---|
| `AGENTS.md` | Operational playbook and PR review policy |
| `IDENTITY.md` | Agent identity definition |
| `SOUL.md` | Core behaviour and safety principles |
| `MEMORY.md` | Long-term memory (curated facts across sessions) |
| `HEARTBEAT.md` | Periodic maintenance task list |
| `pr_review_scanner.sh` | Cron script: scans orgs, triggers webhook per unreviewed PR |
| `gh-app-review.sh` | Posts GitHub App review (APPROVE/COMMENT), updates state file, sends Telegram alert |
| `pipeline_prompt.txt` | Legacy pipeline agent prompt (reference) |
| `skills/pr-review/SKILL.md` | On-demand `pr-review owner/repo#number` skill |
| `bin/gen_github_token.sh` | Generates a GitHub App installation token via RS256 JWT |
| `bin/auto_fix_merge.sh` | Auto-resolves merge conflicts and pushes the fixed branch |
| `bin/gh_authed.sh` | Wrapper: runs `gh` with the App token |
| `bin/list_prs.sh` | Lists open PRs across configured repos |
| `bin/run-pr-scanner` | Entrypoint called by ZeroClaw cron (`job_type = shell`) |

## Deployment

This agent runs as a Kubernetes Deployment (`zeroclaw-pr-agent`) in the `ai-agents` namespace. Manifests live in [`kenny-k3s/ai_agents`](https://github.com/kenny-k3s/ai_agents) under `kustomize/base/zeroclaw-pr-agent/`.

Model inference routes through LiteLLM (`litellm.ai.svc.cluster.local:4000`). The GitHub App private key is mounted from a Kubernetes secret at `/zeroclaw-data/.zeroclaw/github-app.pem`.

## Triggering a manual review

The agent has no external ingress. Trigger a review by exec-ing into the pod or via the ZeroClaw gateway:

```sh
# Via kubectl exec
kubectl exec -n ai-agents deploy/zeroclaw-pr-agent -- \
  curl -s -X POST http://localhost:3000/webhook \
  -H "Content-Type: application/json" \
  -d '{"message": "pr-review kenny-k3s/ai_agents#123"}'
```

## State file

`/zeroclaw-data/workspace/.pr_pipeline_state.json`

```json
{
  "pending": [],
  "reviewed": {
    "kenny-k3s/ai_agents#927": {"score": 0, "decision": "approved", "reviewed_at": "..."}
  },
  "merged": ["kenny-k3s/ai_agents#927"]
}
```
