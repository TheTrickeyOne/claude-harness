# Secrets: layered model (env → Infisical → Agent Vault)

How this harness feeds credentials to MCP servers and the agent, from simplest to
most hardened. Pick the layer that matches the machine; they compose.

| Layer | What it is | When |
|---|---|---|
| **1. `.env` fallback** | plaintext values in a gitignored `.env`, exported by `mcp/secrets.sh` | quick start, or a host with no Infisical |
| **2. Infisical `run`** (baseline) | `infisical run -- <agent>` injects a project/env's secrets as env vars; `${VARS}` in `.mcp.json` resolve from them | the default once you self-host Infisical |
| **3. Agent Vault** (hardening) | a TLS-intercepting egress proxy injects API tokens on the wire; the agent only ever holds `__placeholder__` strings | high-value / prompt-injection-exposed runs |

The `${VAR}` references in `mcp/.mcp.json.template` are backend-agnostic — only
how those vars get populated changes between layers.

---

## Layer 2 — Infisical `run` (baseline)

Infisical (self-hosted, MIT core) is the credential store. Authenticate a
**machine identity** once, then launch any agent through `infisical run`, which
injects the project/environment's secrets as env vars into that process — no
`.env`, nothing on disk:

```
infisical login --method=universal-auth --client-id=<id> --client-secret=<secret> --silent --plain
infisical run --projectId <id> --env prod -- claude
```

Point the CLI at your instance with `INFISICAL_API_URL` / `--domain`. This works
for any agent (`infisical run -- codex`, `infisical run -- gemini`), so it fits
the harness's cross-agent goal. In-cluster, the **Infisical Kubernetes operator**
(`InfisicalSecret` CRD) syncs secrets into native k8s Secrets for MCP servers or
workloads running on the Talos cluster.

Keep `secrets.sh` + `.env` only as the no-Infisical fallback (Layer 1).

---

## Layer 3 — Agent Vault + internal PKI (hardening)

[Agent Vault](https://github.com/Infisical/agent-vault) (Infisical, open source,
**research preview as of 2026-04** — pilot it, don't make it the sole path yet)
is a **TLS-intercepting, credential-injecting forward proxy** built for agents.
The agent routes egress through it; the proxy swaps placeholder header values
(e.g. `__anthropic_api_key__`) for real credentials on the outbound request. The
agent **never sees, stores, or logs the real secret** — so a prompt-injected or
otherwise compromised agent has nothing to exfiltrate. It can use Infisical as
its backing credential store.

### Why this layer exists
Layers 1–2 still put raw tokens in the agent's environment. Layer 3 removes them
from the agent entirely. Given this harness guards infrastructure that holds
sensitive personal/financial/medical data — and is used to red-team that same
infrastructure — "the agent physically cannot read its own credentials" is a real
upgrade over "the agent has them and we trust it."

### Topology — shared, and on a SEPARATE host
Agent Vault is **one shared service**, and by design it must run **on a different
host than the agents**. If it ran beside the agent, a compromised agent could read
the vault's secrets locally and the guarantee collapses. The agent host holds only:
`HTTPS_PROXY` → the vault, a scoped `AGENT_VAULT_TOKEN`, and trust for the vault's
signing CA. Secrets live solely on the vault host.

- **Ports:** `14322` = MITM proxy (agent traffic); `14321` = management UI/API.
- **Per-agent isolation:** register each real agent (your laptop's Claude Code, a
  red-team sandbox, a cloud run) as an Agent Vault *agent* → unique token +
  *service rules* controlling which agent may reach which upstream API.
- **Placement for this stack:** run it in the Talos cluster (a pod) or a Proxmox
  LXC — anywhere that is **not** the machine running the agent. Reach it over LAN
  or the NetBird tailnet.

### The certificate reality (why ingress + Let's Encrypt is NOT the answer)
Agent Vault impersonates the **upstream** domains (`api.anthropic.com`,
`api.github.com`, …) to inject headers. No public CA will ever sign a cert for a
domain you don't own, so a cert-manager/Let's Encrypt cert **cannot** make the
interception path trusted. It only helps the **management UI (14321)**, which is a
normal reverse-proxy HTTPS endpoint on a domain you *do* own (`vault.homelab.tld`)
— give that one a real cert via cert-manager and be done.

### The trick that removes the per-host trust chore: internal PKI
Don't try to make the interception "publicly trusted" (impossible). Instead root
Agent Vault's signing CA in an **internal PKI your fleet already trusts**:

1. Stand up / reuse a private root CA — cert-manager private `ClusterIssuer`, or
   **step-ca (smallstep)**, or an existing homelab root.
2. Distribute that root to every host's trust store **once**, via Ansible (see the
   play below). New hosts inherit trust automatically.
3. Give **Agent Vault a name-constrained intermediate** signed by that root, to use
   as its interception CA. *(Verify Agent Vault exposes a bring-your-own-CA option
   in the current repo; it's standard for MITM proxies but the research-preview
   docs were thin. If it only self-generates a CA, distribute that single CA via
   the same Ansible play instead.)*

Now every forged upstream cert chains to a root your machines already trust — no
per-agent CA import, ever.

### Security hardening (do these — a fleet-trusted MITM CA is a loaded gun)
A CA in your hosts' trust stores that can forge **any** domain is exactly what an
attacker wants; if its key leaks, everything those hosts talk to (including your
bank) is interceptable. Contain it:

1. **Name Constraints (RFC 5280)** on the intermediate so it can *only* sign the
   specific API domains you intercept — a leaked key then can't forge `chase.com`.
2. **Keep the signing key only on the vault host**, never on agent hosts.
3. **Scope trust narrowly** — ideally only the agent-runner host/sandbox trusts the
   CA, not the whole fleet.
4. Prefer **short-lived** intermediates (step-ca makes rotation easy).

### Which secrets go proxy-side vs env-side
Agent Vault only covers secrets sent as **HTTP(S) headers**. Split accordingly:

| Secret | Layer | Why |
|---|---|---|
| Anthropic API key (the model key) | Agent Vault | bearer header → ideal, highest value to hide |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | Agent Vault | bearer header |
| `ARGOCD_API_TOKEN` | Agent Vault | bearer header (pilot after read-only ones) |
| `GRAFANA_SERVICE_ACCOUNT_TOKEN` | Agent Vault | bearer header (good first pilot) |
| `HA_TOKEN` | Agent Vault | bearer header |
| `CONTEXT7_API_KEY` | Agent Vault | header (low blast radius — pilot first) |
| `NORDIC_API_KEY` | Agent Vault | header |
| Proxmox `PVEAPIToken` | Agent Vault | `Authorization` header, if the client sends it as one |
| `KUBECONFIG` | Infisical / k8s operator | k8s-API auth (often client-cert) — not a plain header |
| SSH keys, client certs | Infisical / files | not HTTP headers |

**Pilot order:** start with the Anthropic key + read-only tokens (Grafana,
Context7, GitHub), where a mistake is low-blast-radius, before moving write-capable
ones (ArgoCD, Proxmox) behind the proxy.

### Availability caveat
Agent Vault is now in the agents' egress path — if it's down, agents can't reach
their APIs. Treat it as a service you keep up (HA pod / monitored LXC), not a
throwaway.

---

## Concrete setup for this stack (sketch)

1. **Store** the API tokens in Infisical (or as Agent Vault vault entries backed by
   Infisical).
2. **Deploy Agent Vault** as a Talos pod or Proxmox LXC — *not* on the agent host.
   Front the **14321** management UI with cert-manager + Let's Encrypt on
   `vault.homelab.tld`; keep it private (VPN/IP-allowlist).
3. **Internal PKI:** step-ca (or cert-manager private issuer) as root; issue a
   name-constrained intermediate to Agent Vault for the intercepted API domains.
4. **Distribute root trust** with Ansible (below).
5. **Per agent:** create an Agent Vault agent + token + service rules; on the agent
   host set `HTTPS_PROXY=https://<vault-host>:14322` and `AGENT_VAULT_TOKEN=…`.
6. **In `.mcp.json`,** put placeholders (`__anthropic_api_key__`, …) for the
   proxy-side secrets; keep `${KUBECONFIG}` etc. on the Infisical/operator path.

### Ansible: distribute the internal root once
```yaml
- name: Trust the homelab internal root CA (Agent Vault interception)
  hosts: agent_hosts
  become: true
  tasks:
    - name: Install root CA into the system trust store
      copy:
        src: files/homelab-root-ca.pem
        dest: /usr/local/share/ca-certificates/homelab-root-ca.crt   # Debian/Ubuntu
        mode: "0644"
      notify: update-ca
  handlers:
    - name: update-ca
      command: update-ca-certificates
```
(For macOS agent hosts, add the root to the System keychain / use
`NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`, `CURL_CA_BUNDLE`
env vars for runtimes that don't read the system store.)

---

## Cross-agent note
All three layers are agent-agnostic. Infisical `run` and `HTTPS_PROXY` + CA trust
work identically for Codex, Gemini CLI, and OpenCode — the same portability
property as `AGENTS.md` and the skills. No harness code is Claude-specific here.
