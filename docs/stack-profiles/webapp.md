---
profile: webapp
projectType: webapp
stackComponents: [generic web frontend]
secretsBackend: env
securityToolingAuthorized: false
---

# Profile: webapp

Web application coding — frontend + backend. Design-quality and testing forward.

## Skills enabled
frontend-design, web-design-guidelines, web-quality, webapp-testing,
test-driven-development, systematic-debugging, verification-before-completion,
git-pr-workflow, secrets-hygiene, docs-diagrams, skill-creator.

## MCP servers
context7 (docs), github.

## permissions.allow (starting point — merge, don't replace)
```json
[
  "Read(//**)",
  "Bash(npm run *)",
  "Bash(npm test *)",
  "Bash(npm ci)",
  "Bash(npm install)",
  "Bash(pnpm *)",
  "Bash(node --version)",
  "Bash(npx playwright *)",
  "Bash(git status)",
  "Bash(git diff *)",
  "Bash(git log *)",
  "WebSearch"
]
```

## Safety notes to write into AGENTS.md ## Project
- Run the design-audit (`web-design-guidelines`) and a11y/CWV (`web-quality`)
  skills before calling a UI change done.
- No deploys or `npm publish` without explicit confirmation.
