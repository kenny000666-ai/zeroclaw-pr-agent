The changes in this PR look correct. Updating the `ai_agents` submodule pointer to `8d95116` is appropriate. This includes:
- Switch structured fact-extraction LLM to `antigravity/gemini-3.5-flash-extra-low` to optimize token usage and prevent JSON truncation errors (PR #1732).
- Pin the `opencode-obscura` deployment and the `opencode-scrape` cronjob to the healthy `ubuntu-proxmox` node due to `ubuntu-proxmox2` being down, which also maintains local hostPath storage consistency (PR #1733).

Risk Score: 20
Findings:
- Low (+20): Standard submodule pointer bump to incorporate upstream changes, already validated.

Verdict: APPROVE (Note: Submitted as a comment review because GitHub does not permit approving one's own PR, and the authenticated user is the PR author).
