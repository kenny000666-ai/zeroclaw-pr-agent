The changes in this PR look correct. The mission-control deployment patch now includes the in-cluster service FQDN and its port in the MC_ALLOWED_HOSTS configuration:
`mission-control.ai-agents.svc.cluster.local,mission-control.ai-agents.svc.cluster.local:3000`

This server-side solution properly resolves the 403 Forbidden issues that the mc-heartbeat sidecar was experiencing, while avoiding the need to fake/spoof Host headers in the client-side curl command.

Verdict: APPROVE (Note: Submitted as a comment review because GitHub does not permit approving one's own PR, and the authenticated user is the PR author).