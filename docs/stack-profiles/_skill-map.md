# Component → skill/MCP map

`/bootstrap` uses this to decide which skills and MCP servers to enable for each
selected stack component. Skill names are directory names under
`skills-catalog/` (`_custom/` unless marked `[v]` = vendored under
`_vendored/<LICENSE>/`). MCP names match keys in `mcp/.mcp.json.template`.

| Stack component | Skills | MCP servers |
|---|---|---|
| Talos | `talos-ops`, `homelab-runbook` | kubernetes |
| Longhorn | `longhorn-ops`, `homelab-runbook` | kubernetes |
| Kubernetes (generic) | `kubernetes-skill [v]`, `homelab-runbook` | kubernetes |
| ArgoCD | `argocd-ops`, `secrets-hygiene` | argocd |
| Ansible | `ansible-bestpractices`, `ansible-auditor [v]` | — |
| Proxmox | `proxmox-api`, `homelab-runbook` | proxmox (audit first) |
| OPNsense | `opnsense-api` | — |
| Home Assistant | `homeassistant [v]` | homeassistant |
| ESPHome | `esphome [v]`, `esptool-flash` | esphome |
| Meshtastic | `meshtastic` | — |
| ESP-IDF / ESP32 | `esp32-workbench [v]`, `esptool-flash`, `firmware-size`, `mcu-debug [v]` | esp-idf, esp-idf-monitor, platformio |
| Nordic / Zephyr | `zephyr [v]`, `nrfutil`, `firmware-size`, `mcu-debug [v]` | nordic, embedded-debugger |
| Matter | `matter-device`, `zcl-codegen`, `matter-zigbee-ota` | esp-idf / nordic (per target) |
| Thread | `thread-device` | — |
| Zigbee | `zigbee-device`, `zigbee-z2m-converter`, `zcl-codegen` | — |
| generic web frontend | `frontend-design [v]`, `web-design-guidelines [v]`, `web-quality [v]`, `webapp-testing [v]` | context7, github |
| generic embedded | `embeddedskills [v]`, `mcu-debug [v]`, `firmware-size`, `i2c-bringup`, `sensor-fusion`, `pico-sdk` | platformio, embedded-debugger |
| sensors / IMU | `sensor-fusion`, `i2c-bringup` | — |
| power/memory tuning | `power-profiling`, `firmware-size` | — |
| red-team engagement | `pentest-agents [v]` (scope-guarded), `security-review [v]`, `trailofbits-* [v]` | — |
| any (always) | `git-pr-workflow`, `secrets-hygiene`, `docs-diagrams`, `skill-creator [v]`, `systematic-debugging [v]`, `test-driven-development [v]`, `verification-before-completion [v]` | context7, github |

Notes:
- `homelab-runbook` is added whenever any infra component is present; it
  orchestrates the per-component ops skills.
- Security skills are enabled only when the user confirms this repo is
  authorized for security tooling (bootstrap Phase 1).
- Proxmox MCP is community-only — prefer the `proxmox-api` skill; enable the MCP
  only after auditing its code (see `mcp/catalog.md`).
