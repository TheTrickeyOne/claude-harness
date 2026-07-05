# Vendored skill attribution

Every skill copied into `_vendored/<LICENSE>/` is listed here with its upstream
source, license, and the commit it was pinned at. Keep each skill's own
`LICENSE` file alongside it. Fetch with `skills-catalog/vendor.sh`; copy only the
specific skill directory, not the whole repo.

Copyleft skills (CC-BY-SA, GPL, MPL) live in their own per-license subdirs so
their obligations don't attach to the permissive majority. For personal use this
is informational; if this repo is ever redistributed, honor each license.

## Pinned sources

| Skill(s) to take | Repo | License | Pin (fill on fetch) |
|---|---|---|---|
| test-driven-development, systematic-debugging, brainstorming, writing-plans, executing-plans, verification-before-completion, requesting-code-review, receiving-code-review, writing-skills | obra/superpowers | MIT | `_______` |
| skill-creator, mcp-builder, webapp-testing, frontend-design | anthropics/skills | Apache-2.0 | `_______` |
| security-review (`/security-review`) | anthropics/claude-code-security-review | MIT | `_______` |
| static-analysis, semgrep-rule-creator, variant-analysis, supply-chain-risk-auditor, agentic-actions-auditor, insecure-defaults | trailofbits/skills | CC-BY-SA-4.0 | `_______` |
| pentest agents (scope-guard PRESERVED) | 0xSteph/pentest-ai-agents | MIT | `_______` |
| DFIR/SOC/Sigma reference subset (rename dir to avoid implying Anthropic affiliation) | mukul975/Anthropic-Cybersecurity-Skills | Apache-2.0 | `_______` |
| web-design-guidelines, react-best-practices | vercel-labs/agent-skills | MIT | `_______` |
| accessibility, core-web-vitals | addyosmani/web-quality-skills | MIT | `_______` |
| terraform style/tests/modules | hashicorp/agent-skills | MPL-2.0 | `_______` |
| terraform-skill | antonbabenko/terraform-skill | Apache-2.0 | `_______` |
| kubernetes-skill | LukasNiessen/kubernetes-skill | MIT | `_______` |
| devops generator/validator pairs | akin-ozer/cc-devops-skills | Apache-2.0 | `_______` |
| home-assistant ops | komal-SkyNET/claude-skill-homeassistant | MIT | `_______` |
| esphome | tonylofgren/aurora-smart-home | MIT | `_______` |
| ansible skills | leogallego/claude-ansible-skills | GPL-3.0 | `_______` |
| esp32 workbench | agodianel/esp32-claude-workbench | MIT | `_______` |
| zephyr-agent-skills (incl. power-performance, hardware-io, iot-protocols) | beriberikix/zephyr-agent-skills | Apache-2.0 | `_______` |
| embeddedskills toolchain pack | zhinkgit/embeddedskills | MIT | `_______` |

## Excluded (reference only — do NOT vendor)
- anthropics/skills Office skills (`docx`/`pdf`/`pptx`/`xlsx`) — proprietary,
  no redistribution.
- Unlicensed repos (horw/esp-mcp, chshzh/claude, EricSun787/robominds STM32,
  Claude-BugHunter) — all-rights-reserved; re-derive ideas instead of copying.
