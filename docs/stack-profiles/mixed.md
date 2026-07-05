---
profile: mixed
projectType: mixed
stackComponents: []
secretsBackend: env
securityToolingAuthorized: false
---

# Profile: mixed

Fallback for a repo that spans several domains. Enables the always-on core plus
whatever the interview selects — do NOT load every skill blindly; pick per the
components the user actually confirms.

## Skills enabled (always-on core)
git-pr-workflow, secrets-hygiene, docs-diagrams, skill-creator,
systematic-debugging, test-driven-development, verification-before-completion.
Then add per-component skills from `_skill-map.md` for each confirmed component.

## MCP servers
context7, github. Add per component.

## permissions.allow (starting point — merge, don't replace)
```json
[
  "Read(//**)",
  "Bash(git status)",
  "Bash(git diff *)",
  "Bash(git log *)",
  "WebSearch"
]
```

## Safety notes
Write component-specific safety notes into AGENTS.md for each confirmed stack
element, drawing from the matching dedicated profile.
