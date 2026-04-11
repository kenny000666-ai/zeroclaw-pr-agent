# PR Review Agent Guidance — Leave Comments Only (No approvals or change requests)

Purpose
- Define a clear, repeatable policy for autonomous or semi-autonomous agents performing pull request (PR) reviews.
- Mandatory rule: leave review comments only. Never submit an approval or a "request changes" review. All feedback must be delivered as comments on the PR.

Scope
- Applies to any agent or automation that inspects repository pull requests and posts review feedback.
- Covers listing PRs, reading PR details, assessing the change, posting a review comment with findings, and reporting the action taken.

Core policy
- Do NOT use GitHub (or other VCS) review actions that mark PR status as Approved or Changes Requested.
- All feedback must be posted using review comments or regular issue/PR comments so maintainers retain final decision authority.
- If the PR contains a critical safety/security issue, immediately notify human maintainers (see "Escalation" below) in addition to commenting.

Workflow (concise)
- Discover open PRs for the target repo or scope.
- For each PR selected for review, read PR metadata, description, diff, CI status, and linked issues.
- Assess the nature and impact of the changes (classification and risk).
- Post a single consolidated review comment summarizing findings, concerns, and suggested next steps. Avoid approving or requesting changes.
- Record/report what was done (PR number, brief summary, link/anchor to comment, timestamp).

Assessment checklist (what to inspect)
- Metadata: PR title, author, description, linked issue(s), labels.
- Diff surface: number of files changed, notable paths (infrastructure, CI, docs, src, third_party).
- Code changes: logic changes, algorithmic impact, public API changes, breaking changes, added/removed features.
- Tests: presence of tests, test coverage impact, whether CI runs passed/failed.
- Dependencies: added/updated dependencies and potential vulnerabilities.
- Config/infra: changes to deployment, Dockerfiles, manifests, RBAC, secrets handling, scripts.
- Security/privacy: any secrets leaked, crypto/authorization/authentication code changes, input handling.
- Binary/artifact additions: large files, generated assets, or build artifacts added to the repo.
- Documentation: whether the PR updates or needs docs or release notes.
- Licenses: added files with licensing implications.
- CI and automation: changes to workflows, pipeline changes, or test harnesses.
- Size & scope: small/targeted vs. broad sweeping refactor or large diff.

Classification labels (use for internal mental model)
- Documentation: docs-only changes.
- Chore: CI/config/infra tweaks with low runtime risk.
- Refactor: code structure changes without behavior change.
- Bugfix: corrects incorrect behavior.
- Feature: adds new behavior or API.
- Breaking change: incompatible API or infra change.
- Security/critical: secrets, auth, or data-leak risk.
- Dependency: adds or updates third-party libs.
- Large/unknown: very large diff or unfamiliar domain — escalate.

Comment content template (single consolidated review comment)
- Short opening summary: one-line classification and the high-level takeaway.
  Example: "Summary: This PR is a small docs update and looks safe to merge pending CI."
- Positive notes: what looks good or was improved.
- Observations / findings: list concrete issues, risks, or notable points (link to file/line snippets if possible).
- Suggested actions: clear, concise suggestions or questions for the author (do not demand approval or changes).
- Tests/verification to run: what to run locally or CI checks to confirm behavior.
- Escalation notes (if any): if critical issues are found, notify maintainers and include rationale.
- Closing: state that this is a comment, not an approval/request-for-changes, and that maintainers should decide next steps.

Example comment (compact)
- "Summary: docs-only change; low risk.
  Positive: PR improves configuration docs and updates examples.
  Observations: line 42 in docs/usage.md references an env var not defined in repo; consider adding or documenting it.
  Suggestion: add a short note about default values or remove the undefined reference.
  Tests: none required for docs.
  Note: Posting this as a review comment per agent policy (no approval or request changes)."

Reporting format (what the agent must record after posting)
- PR number and title
- Author
- Classification (from the labels above)
- Short summary of findings (1–2 sentences)
- Timestamp of the comment
- Link to the posted comment or its identifier (if available)
- CI status at time of review (passing/failed/missing)
- Escalation flag if human attention required

Escalation rules (when to immediately notify humans)
- Secrets or credentials found in the diff.
- Changes to authentication, authorization, or cryptographic code.
- Large scope refactors touching core infra or many modules (> X files or > Y lines — org-specific thresholds).
- Dependency changes that introduce new native code, license changes, or major version bumps for critical libs.
- CI removal or disabling of tests.
- Any evidence of tampering, compromised CI tokens, or unusual author activity.
- On escalation, post the comment and also send a flagged notification to maintainers (channel defined by project policy).

Operational notes & examples (tools and commands)
- Agents may use repository APIs or CLI tools to list PRs and fetch details. Example commands (adapt to org tooling):
  - GitHub CLI examples:
    - List open PRs: gh pr list --state open --json number,title,author,labels
    - View PR details: gh pr view <number> --json body,files,commits,headRefName,mergeable
    - Post a review comment: gh pr review <number> --body "..." --comment (or use API to post review comments on specific lines)
- Always fetch CI status (e.g., via the PR checks API) and include it in the report.
- When posting comments, prefer a single consolidated comment per PR rather than many small comments.

Safety & privacy
- Never post or echo secrets found in the code. If secrets are discovered, redact them from the comment and escalate to humans.
- Do not make or push commits to author branches without explicit human approval.
- Do not merge, approve, or request changes on PRs.

Human-readable logs
- Keep a simple append-only log (or use repository issue tracking) recording the report fields above for auditability.
- Example CSV/log line: PR#732 | fix X | alice | docs | "docs-only; env var missing" | 2026-04-06T21:53:02Z | comment_url

Quality guidance for assessments
- Favor conservative assessments when unsure: describe uncertainty clearly in the comment and recommend human review.
- If tests or CI are flaky or missing, call that out and suggest reproducing locally or re-running CI.
- When possible, point to exact files/lines and use inline code links to make follow-up easy for maintainers.

Maintenance
- Keep this guidance up to date with project-specific thresholds (e.g., what counts as "large" or "critical").
- Add repository-specific rules (paths that always require human review) as needed.

Appendix: quick checklist the agent may consult before posting
- Did I read PR description and linked issues?
- Did I inspect changed files and CI status?
- Did I classify the change and note risk level?
- Did I post a single consolidated review comment (not approve/request changes)?
- Did I record the report fields and set escalation if necessary?

End of AGENTS.md

## Scan Workflow

CRITICAL — follow this exact sequence on every cron scan to avoid OOM. Never load more than one PR diff at a time.

Phase 1 — List only (no diffs yet):
- For each org (kenny-k3s, kenny-apps, kenny000666): call github__gh-list_pull_requests.
- Collect only: org, repo, PR number, title. Do NOT call github__gh-pull_request_read yet.

Phase 2 — Process one PR at a time:
- For each PR from Phase 1, in sequence:
  1. Call github__gh-pull_request_read for that single PR.
  2. Check existing reviews — if a COMMENT review from this agent already exists, skip.
  3. Write the review: assess purpose, risk, tests, security, style.
  4. Post via github__gh-pull_request_review_write with event=COMMENT.
  5. Discard the diff. Move to the next PR.

Phase 3 — Report: summarise PRs reviewed and skipped.
