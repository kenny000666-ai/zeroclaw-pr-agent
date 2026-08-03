The changes in this PR look correct. Updating the `ai_agents` submodule pointer to `2cfa872` (which configures the `zeroclaw-pr-agent` deployment with 2-replica HA, RollingUpdate strategy, and podAntiAffinity scheduling) is appropriate and ensures the PR agent remains resilient against single-node outages.

Verdict: APPROVE (Note: Submitted as a comment review because GitHub does not permit approving one's own PR, and the authenticated user is the PR author).
