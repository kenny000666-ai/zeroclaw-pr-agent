The changes in this PR switch hindsight's structured fact-extraction LLM from `antigravity/gemini-3.5-flash-low` to `antigravity/gemini-3.5-flash-extra-low`.

**Analysis & Benefits:**
- Swapping the model is beneficial because `gemini-3.5-flash-low` is reasoning-heavy, burning a large share of its output budget on `reasoning_content` before emitting content.
- This reasoning overhead occasionally leads to `finish: length` mid-JSON on large/schema-heavy prompts, causing `JSONDecodeError` and retries.
- The `gemini-3.5-flash-extra-low` model variant spends far fewer tokens on reasoning while still natively supporting `response_schema`.
- The LiteLLM key scope (DB) has been updated to include this model.
- CHANGELOG.md has been correctly updated.
- Kustomize dry-run validation has been completed successfully.

Risk Score: 20
Findings:
- Low (+0): Straightforward model configuration switch, already verified via dry-run and key scope update.

Verdict: APPROVE (Note: Submitted as a comment review because GitHub does not permit approving one's own PR, and the authenticated user is the PR author).
