# Vendored skill attribution

Every skill copied into `_vendored/<LICENSE>/` is listed here with its upstream
source, license, and the commit it was pinned at. Each vendored skill keeps its
own `LICENSE`/`LICENSE.txt`. Re-fetch with `skills-catalog/vendor.sh` (clones to
the gitignored `_vendored/.cache/`).

Copyleft skills (CC-BY-SA, GPL, MPL) live in their own per-license subdirs so
their obligations don't attach to the permissive majority. For personal use this
is informational; if this repo is ever redistributed, honor each license.

Vendored 2026-07-05. 98 SKILL.md files across the buckets.

## Pinned sources (as vendored)

| Target dir | Upstream | License | Pinned commit |
|---|---|---|---|
| `MIT/superpowers-*` (9: test-driven-development, systematic-debugging, brainstorming, writing-plans, executing-plans, verification-before-completion, requesting-code-review, receiving-code-review, writing-skills) | obra/superpowers | MIT | `d884ae0` |
| `APACHE/{frontend-design,mcp-builder,skill-creator,webapp-testing}` | anthropics/skills | Apache-2.0 | `9d2f1ae` |
| `MIT/vercel-{web-design-guidelines,react-best-practices}` | vercel-labs/agent-skills | MIT (see caveat) | `f8a72b9` |
| `MIT/webquality-{accessibility,core-web-vitals}` | addyosmani/web-quality-skills | MIT | `95d6e25` |
| `MIT/kubernetes-skill` | LukasNiessen/kubernetes-skill | MIT | `a34b06a` |
| `APACHE/terraform-skill` | antonbabenko/terraform-skill | Apache-2.0 | `0a3a4a6` |
| `CC-BY-SA/tob-*` (6: static-analysis[+codeql/sarif], semgrep-rule-creator, variant-analysis, supply-chain-risk-auditor, agentic-actions-auditor, insecure-defaults) | trailofbits/skills | CC-BY-SA-4.0 | `cfe5d7b` |
| `MIT/pentest-agents` (FULL set: all 50 agents + **_scope-guard**, commands/, docs/, examples/, db/) | 0xSteph/pentest-ai-agents | MIT | `1ef99f2` |
| `APACHE/cyberref/*` (47 blue-team: DFIR/SOC/Sigma + detection-engineering, threat-hunting, container/k8s defense, network monitoring, IoT/OT/BLE, LLM defense, CI/CD supply-chain, ransomware IR) | mukul975/Anthropic-Cybersecurity-Skills | Apache-2.0 | `673da1f` |
| `GPL/red-run` (FULL framework: live-tool orchestrator — nmap/sqlmap/hashcat/impacket via MCP, operator-approval gates; skills/agents/operator/tools/install) | blacklanternsecurity/red-run | GPL-3.0 | `050ac1f` |
| `MIT/security-review` (`/security-review` command) | anthropics/claude-code-security-review | MIT | `0c6a49f` |
| `MPL/hashicorp-terraform` (4: style-guide, test, refactor-module, terraform-stacks) | hashicorp/agent-skills | MPL-2.0 | `339a113` |
| `APACHE/cc-devops/skills` (10: terraform/ansible/k8s-yaml/helm/dockerfile gen+validator pairs) | akin-ozer/cc-devops-skills | Apache-2.0 | `feaf2b2` |
| `GPL/ansible-skills` (2: ansible-good-practices, ansible-zen) | leogallego/claude-ansible-skills | GPL-3.0 | `1bcc720` |
| `MIT/home-assistant-manager` | komal-SkyNET/claude-skill-homeassistant | MIT | `2112679` |
| `MIT/esphome` + `MIT/aurora-{home-assistant,ha-integration-dev}` | tonylofgren/aurora-smart-home | MIT | `5323aef` |
| `MIT/esp32-workbench` (9 skills, from `.claude/skills/`) | agodianel/esp32-claude-workbench | MIT | `9089ed8` |
| `APACHE/zephyr-agent-skills` (22 skills + index) | beriberikix/zephyr-agent-skills | Apache-2.0 | `ed63cdf` |
| `MIT/embeddedskills` (12 toolchain skills) | zhinkgit/embeddedskills | MIT | `60dfb5d` |

## Selection notes
- **pentest-agents**: the FULL agent set (all 50 + `_scope-guard.md`) is
  vendored for authorized adversarial self-testing of the owner's own homelab
  and devices (incl. the Pico-based network HSM). The `_scope-guard.md`
  authorization gate + hard-refusal list is retained and applies to every
  execution-capable agent — it keeps the tooling pointed at assets the operator
  owns or is contracted to test. Relevant to this stack: iot-pentester,
  wireless-pentester, llm-redteam, cicd-redteam, container-breakout,
  credential-tester, crypto-analyzer, network-attacker, and more.
- **cyberref**: 8 *defensive* DFIR/SOC/Sigma skills only (no offensive skills);
  each keeps its own per-skill LICENSE.
- **cc-devops**: 5 infra generator/validator pairs (10 skills) of the ~31.
- **ansible-skills (GPL)**: only the two review/authoring plugins; scaffolding
  generators left out.
- **security-review**: the `/security-review` slash command only (the GitHub
  Action harness was not vendored).

## Caveats
- **vercel-labs/agent-skills has no `LICENSE` file** at pin `f8a72b9`. MIT is
  affirmatively declared in the repo README and in `package.json` (`"license":
  "MIT"`), so a standard MIT LICENSE (© Vercel, Inc.) was synthesized into each
  vendored skill dir. If you'd rather wait for an upstream LICENSE file, delete
  `MIT/vercel-*`.

## Excluded (reference only — not vendored)
- anthropics/skills Office skills (`docx`/`pdf`/`pptx`/`xlsx`) — proprietary.
- Unlicensed repos (horw/esp-mcp, chshzh/claude, STM32 leaders, Claude-BugHunter)
  — all-rights-reserved; ideas re-derived instead of copied.
