---
profile: redteam
projectType: red-team engagement
stackComponents: [OPNsense]
secretsBackend: env
securityToolingAuthorized: true
---

# Profile: redteam

Authorized security testing / auditing of your OWN infrastructure (or systems
he is contracted to test). Defensive-first; offensive tooling is scope-gated.

## Authorization gate (required)
Enable this profile ONLY after confirming, in `.harness-manifest.json` and
`AGENTS.md`, the explicit scope: which hosts/networks are in scope and that the
user owns them or holds written authorization. Skills that can execute against
live targets stay disabled until scope is recorded. No DoS, no mass-scanning, no
targeting of third-party systems.

## Skills enabled
security-review, trailofbits-static-analysis, trailofbits-semgrep-rule-creator,
trailofbits-supply-chain-risk-auditor, trailofbits-agentic-actions-auditor,
pentest-agents (scope-guarded), opnsense-api, secrets-hygiene,
systematic-debugging, docs-diagrams, git-pr-workflow.
Blue-team/DFIR reference skills (Sigma/SOC) added on request.

## MCP servers
github, context7. No target-facing MCP by default.

## permissions.allow (starting point — merge, don't replace)
```json
[
  "Read(//**)",
  "Bash(semgrep *)",
  "Bash(nmap -sn *)",
  "Bash(git status)",
  "Bash(git diff *)",
  "WebSearch"
]
```
Deliberately minimal — add scanning/exec permissions per engagement, scoped to
the authorized targets only.

## Safety notes to write into AGENTS.md ## Project
- State the authorized scope explicitly. Refuse anything outside it.
- Prefer defensive analysis (static analysis, config audit, log review) over
  live exploitation unless the engagement requires it and scope permits.
