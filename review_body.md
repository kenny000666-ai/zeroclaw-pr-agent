If we change MC_ALLOWED_HOSTS to include `mission-control.ai-agents.svc.cluster.local` (Approach b), compared to adding `-H 'Host: localhost'` to the sidecar curls (Approach a):

**Tradeoffs:**
- **Security & Spoofing**: Host headers are easily spoofed by clients, so forcing it in curl offers no real security. Django/FastAPI use ALLOWED_HOSTS to prevent host header injection; MC validates the Host header against this list.
- **Centralized Config**: Approach (b) keeps configuration on the server (MC deployment), which is the standard, cleaner approach. Approach (a) scatters this infrastructure detail into client sidecar scripts.
- **Blast Radius**: Approach (b) allows the internal service FQDN, which has a negligible blast radius as it is only resolvable/accessible inside the cluster and still requires a valid `MC_API_KEY`.
- **Validation**: MC checks the Host header string directly. Using the actual FQDN is cleaner and matches standard routing compared to spoofing `localhost`.

**Verdict:** Request Changes. We should update `MC_ALLOWED_HOSTS` on the mission-control deployment to include `mission-control.ai-agents.svc.cluster.local` instead of faking the Host header in the sidecar.