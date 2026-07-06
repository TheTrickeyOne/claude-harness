# MCP server catalog

Which MCP servers to enable for this stack, rated from the 2026-07 research
sweep. `/bootstrap` pulls the entries for the chosen components from
`.mcp.json.template`.

## Must-have (official, mature)

| Server | Source | Notes |
|---|---|---|
| **kubernetes** | `containers/kubernetes-mcp-server` (Red Hat) | Go-native, `--read-only` mode, multi-cluster. Also reaches Longhorn (CRDs). |
| **argocd** | `akuity/argocd-mcp` (official Argo) | stdio + HTTP/SSE; API-token auth. |
| **grafana** | `grafana/mcp-grafana` (official) | Also queries Prometheus/Loki via datasources; service-account token. |
| **github** | `github/github-mcp-server` (official) | `gh` CLI often covers this at lower context cost — enable the MCP when you want structured tools. |
| **homeassistant** | HA built-in MCP Server integration (zero-install) + `homeassistant-ai/ha-mcp` (config/automation authoring) | Front door to Zigbee/Z-Wave/Thread/Matter *devices*. |
| **context7** | `upstash/context7` | Live library docs. Often already available in the environment. |

## Embedded (per firmware/esp32/nordic-zephyr profiles)

| Server | Source | Notes |
|---|---|---|
| **esp-idf** | built-in `idf.py mcp-server` (ESP-IDF v6+) | build/flash/target; needs an activated IDF env. |
| **esp-idf-monitor** | `jinw06k/esp-idf-monitor-mcp` | adds the serial `monitor` tool the built-in server lacks. |
| **platformio** | `jl-codes/platformio-mcp` | builds/flash/bounded serial capture. |
| **embedded-debugger** | `Adancurusul/embedded-debugger-mcp` | probe-rs debug/flash/RTT/memory; ST-Link/J-Link/DAPLink + Nordic RTT. |
| **nordic** | Nordic official MCP (remote, June 2026) | docs/API/config + nRF Cloud fleet data; account auth. |

## Optional / audit-before-use

| Server | Why the caution |
|---|---|
| **proxmox** | **DEFERRED (decision 2026-07).** No official server; community forks are unaudited and hold root-ish API tokens. Rather than wire a shaky fork, the plan is to **build a proper Proxmox MCP later**. Until then use the `proxmox-api` skill (read-first, confirm-on-destroy). The template entry is a non-wired placeholder. |
| prometheus-direct | `pab1it0/prometheus-mcp-server` — only if not already covered by grafana. |

## Live offensive tooling (authorized self-testing only)

- **red-run** (vendored at `skills-catalog/_vendored/GPL/red-run/`, GPL-3.0) is a
  full framework that *executes* live tools (nmap, sqlmap, hashcat, impacket)
  through its own MCP with operator-approval gates — for lab/CTF/self-testing,
  not a drop-in server. Activate it via its own `install.sh`/`preflight.sh` and
  the `.mcp.json` it ships; it needs the underlying tools installed. It carries
  its own operator/approval harness, so it is NOT auto-wired into the harness
  `.mcp.json.template`. Point it only at assets you own or are authorized to
  test. Pairs with the (advisory) `pentest-agents` set.

## Skip (no credible MCP → use skills/CLIs)

- **Talos** — no credible server; use the `talos-ops` skill wrapping `talosctl`.
- **Longhorn** — no dedicated server; managed through the kubernetes MCP (CRDs).
- **Meshtastic** — the one community MCP is immature; use the `meshtastic` skill
  wrapping the official Python CLI.
- **OPNsense** — nothing public; use the `opnsense-api` skill.

## Secrets

Every `env` value in `.mcp.json.template` is a backend-agnostic `${VAR}`
reference. Never put a literal secret in `.mcp.json` or a skill. Three layers,
detailed in **[`docs/secrets.md`](../docs/secrets.md)**:

1. **`.env` fallback** — plaintext values exported by `secrets.sh` (quick start /
   no-Infisical hosts).
2. **Infisical `run`** (baseline) — `infisical run -- <agent>` injects a project's
   secrets as env; nothing on disk. Self-hosted, MIT core. In-cluster: the
   Infisical k8s operator syncs into native Secrets.
3. **Agent Vault** (hardening, research preview) — a TLS-intercepting egress proxy
   injects header-based API tokens on the wire, so the agent only holds
   `__placeholder__` strings. Runs as ONE shared service on a host separate from
   the agents; trust is solved with a name-constrained intermediate off your own
   internal PKI (step-ca / cert-manager), distributed via Ansible — NOT a public
   Let's Encrypt cert (which can't sign for the upstream domains it impersonates).

Note (1Password/Bitwarden): 1Password has no free tier; Vaultwarden can't do
Secrets Manager (`bws`) — its `sdk-secrets` stayed proprietary. Since Infisical is
already self-hosted here, it supersedes both. See `docs/secrets.md`.
