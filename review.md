Here is a review of the changes in this PR. Overall, the implementation is clean, lightweight, and uses only the standard library as intended.

### Suggestions for Improvement:

1. **Use `time.monotonic()` for debouncing:**
   Using `time.time()` can be susceptible to system clock updates or drift (e.g., NTP adjustments). For measuring elapsed time/intervals, `time.monotonic()` is safer and guaranteed to be non-decreasing.
   * **Location:** `kustomize/base/metube-plex-bridge/configmap-metube-plex-bridge.yaml` (inside `bridge.py`).
   * **Fix:** Update `do_POST` to set `_last_event = time.monotonic()` and `debounce_loop` to use `idle = time.monotonic() - _last_event`.

2. **Suppress kubernetes health probe logs:**
   Since Kubernetes readiness and liveness probes query the GET `/` endpoint every 10 and 20 seconds, the Python `http.server.BaseHTTPRequestHandler` will log every probe request. This can clutter the container logs.
   * **Fix:** You can override `log_message` in the handler to ignore GET requests or paths. For example:
     ```python
     def log_message(self, fmt, *args):
         if self.command == "GET":
             return
         print(f"bridge: {self.address_string()} {fmt % args}", flush=True)
     ```

Other than these minor improvements, the Kustomize manifests, resource requests/limits, security contexts, and container configuration look solid.
