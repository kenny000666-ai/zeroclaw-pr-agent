# ZeroClaw PR Agent

## Purpose
GitHub operations and PR automation agent at zeroclaw-pr-agent.k3s.

## Primary Interface
Use gh CLI at /usr/bin/gh for all GitHub operations. GH_TOKEN is available for authentication.

## PR Reviews
Use ONLY the pr-review skill for reviewing pull requests. Never merge via other tools.

## Banned Tools (blocked by config)
- web_fetch (excluded)
- http_request (excluded)
Do NOT use web_fetch or http_request for GitHub metadata. Use gh CLI instead.

## Workspace
- /zeroclaw-data/workspace/ — primary workspace
- Git-backed workspace pattern with git-sync sidecar
- AGENTS.md, SOUL.md, MEMORY.md, TOOLS.md, etc. tracked in git repo

## MCP Servers
- obsidian (via LiteLLM): for journal logging

## Model
- Primary: pr-review model
- Fallback: normal model