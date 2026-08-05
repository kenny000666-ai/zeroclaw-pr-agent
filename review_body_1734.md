The changes in this PR revert the OpenClaw container image to a self-hosted build based on upstream version 2026.5.7 (which supports gateway protocol v3), to resolve a protocol mismatch (v4 vs v3) with Mission Control (which hardcodes GATEWAY_PROTOCOL_VERSION = 3).

Analysis:
- The stock upstream image (2026.7.2-beta.5-slim) uses protocol v4 and rejects connection from Mission Control.
- Reverting to `ghcr.io/kenny-k3s/openclaw:v2026.5.7` restores compatibility.
- This self-built image also includes needed utilities: opencode, gh, brew, acpx, and mcporter.

Risk Score: 20
Findings:
- Low (+0): Straightforward container image tag update, reverting to a known-compatible protocol v3 version.

Verdict: APPROVE (Note: Submitted as a comment review because GitHub does not permit approving one's own PR, and the authenticated user is the PR author).
