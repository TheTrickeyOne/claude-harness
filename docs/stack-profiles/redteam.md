---
profile: redteam
projectType: red-team engagement
stackComponents: [OPNsense]
secretsBackend: env
securityToolingAuthorized: true
---

# Profile: redteam

Authorized security testing of your OWN infrastructure (or systems you are
contracted to test) — adversarially stress-testing the homelab, network, and
devices (incl. the Pico-based network HSM) that hold sensitive personal /
financial / medical data, so real attackers can't get in. Red-team and blue-team
are two halves of the same defensive job here; the full offensive toolset is
enabled.

## Authorization gate (the one guardrail — and it works for you)
The `_scope-guard` that ships with pentest-agents stays active: it keeps every
execution-capable agent pointed at assets you own or are authorized to test, and
hard-refuses DoS, mass-scanning, and targeting third-party systems. That's not a
capability limit on your own lab — it's what stops an agent from wandering off
your network. Record the in-scope hosts/networks in `.harness-manifest.json` and
`AGENTS.md` before running live tools.

## Skills enabled
security-review, trailofbits-static-analysis, trailofbits-semgrep-rule-creator,
trailofbits-supply-chain-risk-auditor, trailofbits-agentic-actions-auditor,
trailofbits-variant-analysis, trailofbits-insecure-defaults,
**pentest-agents (FULL 50-agent set + _scope-guard)**, opnsense-api,
secrets-hygiene, systematic-debugging, docs-diagrams, git-pr-workflow.
Blue-team (cyberref, 47 skills): detection-engineering, threat-hunting,
container/k8s defense (falco, k8s-audit, rbac-hardening), network monitoring
(suricata, zeek, C2-over-DNS), IoT/OT/BLE detection, LLM prompt-injection
detection, CI/CD supply-chain detection, and ransomware incident response +
backup-integrity validation.
Stack-relevant offensive agents: iot-pentester, wireless-pentester, llm-redteam,
cicd-redteam, container-breakout, credential-tester, crypto-analyzer,
network-attacker, web-hunter, api-security.

**Live tooling:** `red-run` (GPL, `_vendored/GPL/red-run/`) executes real tools
(nmap/sqlmap/hashcat/impacket) with operator-approval gates for end-to-end
self-testing — activate via its own installer (see `mcp/catalog.md`). The
advisory pentest-agents tell you what to run; red-run closes the loop.

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
- State the authorized scope explicitly (your networks/hosts/devices). The
  scope-guard refuses anything outside it — that's the point.
- Full offensive tooling is available for self-testing; use it to find and fix
  weaknesses before an attacker does. Pair each finding with the fix (blue-team
  side) so the exercise hardens the lab, not just proves it's breakable.
