# Skill: pr-review

**Trigger**: `pr-review <owner/repo#number>` (e.g. `pr-review kenny-k3s/ai_agents#927`)

Review a specific PR on demand using the same pipeline as the automated cron reviewer.

## Workflow

1. Parse `owner`, `repo`, `number` from the argument (format: `owner/repo#number`).

2. Check if already reviewed:
   ```sh
   JQ=/zeroclaw-data/workspace/bin/jq
   STATE=/zeroclaw-data/workspace/.pr_pipeline_state.json
   $JQ -r --arg k "owner/repo#number" 'if .reviewed | has($k) then "already_reviewed" else "ok" end' $STATE
   ```
   If `already_reviewed`, report the existing entry and stop (do not re-post).

3. Fetch the PR diff via `github__gh-pull_request_read` (owner, repo, number).

4. Score using the rubric:
   - Critical issue: +35 (secrets, credentials, RCE, privilege escalation, destructive ops)
   - Normal issue: +15 (missing error handling, insecure config, breaking change, no tests)
   - Low issue: +5 (style, docs gap, minor warning)
   - Cap at 100

5. Compose the review body using EXACTLY this format:

```
## Verdict
<one-line overall assessment>

## Issue Counts
- Critical: <n>
- Normal: <n>
- Low: <n>

## Top Findings
- [<Critical|Normal|Low>] <short issue summary> — <concrete fix (one line)>

## Risk Score
<score 0-100> (<Low|Moderate|High|Critical>) - <one-line rationale>

## Decision
<APPROVED or COMMENT ONLY> — <one-line reason>

---
*zeroclaw-pr-agent*
```

   Risk bands: 0-20=Low, 21-50=Moderate, 51-75=High, 76-100=Critical.
   Use at most 3 bullets in Top Findings.
   If no issues found: Critical=0, Normal=0, Low=0, score=0 (Low).

6. Get the PR head SHA from the PR data returned in step 3.

7. Post the review via shell:
   ```sh
   bash /zeroclaw-data/workspace/gh-app-review.sh <owner> <repo> <number> <head_sha> <score> "<review_body>"
   ```
   - score < 50 → script posts APPROVE
   - score >= 50 → script posts COMMENT
   - The script also updates the state file and sends a Telegram alert if COMMENT.

8. Report result: `Reviewed <owner/repo#number>: <APPROVED|COMMENT ONLY> (score=<n>)`

## Notes

- The script (`gh-app-review.sh`) handles dedup automatically — if `k3s-pr-merger[bot]` already posted a review containing `zeroclaw-pr-agent`, it exits with SKIP. No double-reviews.
- The script also updates `.pr_pipeline_state.json` to move the PR from `pending[]` to `reviewed{}`.
- Do NOT use `github__gh-pull_request_review_write` directly — always use `gh-app-review.sh` to post as the GitHub App (`k3s-pr-merger[bot]`).
