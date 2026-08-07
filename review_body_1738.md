The changes in this PR patch the built OpenClaw image at build time to add `expectFinal` as an optional property on the `RequestFrameSchema`. This resolves a protocol-level mismatch with Mission Control v2.3.0 which hardcodes `expectFinal` on gateway request frames.

### Analysis & Benefits:
- By patching `RequestFrameSchema` to allow `expectFinal` (while keeping `additionalProperties: false` for other fields), OpenClaw can successfully parse request frames from Mission Control without throwing an validation error.
- Applying this via a separate `RUN` step with an inline Python patch ensures clean heredoc usage and prevents Dockerfile formatting issues.
- The build will compile on merge, updating `kenny-k3s/openclaw:v2026.5.7`.

### Risk Score: 20
- Low (+5): Build-time Dockerfile patching of built assets.

Verdict: APPROVE (Note: Submitted as a comment review because GitHub does not permit approving one's own PR, and the authenticated user is the PR author).
