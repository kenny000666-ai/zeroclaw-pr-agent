The changes in this PR replace the Chrome-based `zeroclaw-browser` OpenCode usage scraper with `Obscura` (a lightweight Rust-based headless browser). The implementation includes:
- Multi-arch Dockerfile for `opencode-obscura:0.1.11` supporting both amd64 and arm64.
- `scrape-opencode.js` scraper script supporting percentage and balance parsing, state persistence, and session expiry detection.
- Configured K8s resources: ConfigMap for the script, Deployment for the persistent CDP server (mounting hostPath storage), Service, and a CronJob to run the scraper every 5 minutes.

Everything looks correct and well-implemented. The dry-run validation and image verification pass.

Risk Score: 20
Findings:
- Normal (+15): No unit tests / test coverage for the scraper script.
- Low (+5): Relies on hardcoded default URLs for Telegraf and the target workspace, although these are configurable via environment variables.

Verdict: APPROVE (Note: Submitted as a comment review because GitHub does not permit approving one's own PR, and the authenticated user is the PR author).
