---
name: homelab-runbook
description: The incident-triage glue skill that orchestrates the per-component ops skills (talos-ops, longhorn-ops, argocd-ops, proxmox-api, opnsense-api) into one disciplined SCOPE→GATHER→HYPOTHESIZE→VERIFY→ACT→VERIFY-RECOVERY loop across the Proxmox → Talos → Kubernetes → Longhorn → ArgoCD → OPNsense stack. Use when something is broken or degraded and the layer isn't obvious, when a symptom spans components, or when you're tempted to restart/delete something. Trigger on "something's down", "cluster is broken", "node NotReady", "app is degraded", "where do I even look", "triage", "incident", "outage", "what changed", even when no single component is named.
---

# homelab-runbook

The glue skill for cross-layer incidents. When a symptom doesn't clearly belong
to one component, run this structured loop instead of pattern-matching to a fix.
It coordinates the per-component skills — it doesn't replace them; hand off to
`talos-ops`, `longhorn-ops`, `argocd-ops`, `proxmox-api`, `opnsense-api` for the
actual commands.

## Golden rules
1. **Read before write, everywhere.** The whole GATHER phase is read-only. You
   act only after evidence points at a specific cause.
2. **Don't restart/delete on a pattern-match.** A signal that looks like a known
   failure may have a different cause. A `NotReady` node could be kubelet, CNI,
   etcd, disk, or hardware — a reboot "because it worked last time" can destroy
   the evidence and the data. Distinguish first.
3. **Confirm every mutation, name the exact target.** Every fix goes through the
   owning component skill's confirm-on-destructive-action rule — state the exact
   node/volume/app/rule and what happens, and get a yes.
4. **Smallest reversible fix, one at a time.** One node/service/rule per change;
   verify recovery before the next. Never batch changes across layers at once.
5. Commands obey the harness rule — one command per call, and a single pipe into
   a read-only filter only (no `&&`, `||`, `;`, `$()`, backticks, or redirects).

## The loop

### 1. SCOPE
- What is the exact symptom, and who/what observes it (user, alert, dashboard)?
- Blast radius: one workload, one node, one VLAN, or everything?
- **What changed recently** — a deploy (ArgoCD sync), a config apply (Talos,
  Ansible, OPNsense), an upgrade, a reboot, a full disk? Recent change is the
  single highest-value clue.

### 2. GATHER (read-only, top-down through the stack)
Pull state at the layers plausibly involved, from the physical up:
- **Proxmox host** (`proxmox-api`): is the VM/host up, out of RAM/disk, throttled?
- **Talos node** (`talos-ops`): `health`, `services`, `dmesg`, etcd quorum.
- **Kubernetes**: `kubectl get nodes`, events, the affected pods.
- **Longhorn** (`longhorn-ops`): volume `robustness`, replica scheduling, disk
  capacity — but remember `degraded` = rebuilding, not broken.
- **ArgoCD** (`argocd-ops`): sync/health, `app diff` — did git move, or did the
  cluster drift?
- **OPNsense** (`opnsense-api`): gateway status, relevant firewall/NAT, DHCP —
  is it reachability rather than the service?

### 3. HYPOTHESIZE
- Form one *specific* root-cause hypothesis (not "storage is weird" but "volume X
  is degraded because node Y's disk is full so a replica can't schedule").
- Write down what evidence would **confirm** it and what would **refute** it.

### 4. VERIFY (before acting)
- Go get that specific evidence. Does it actually support *this* cause, or just
  correlate? Rule out the look-alikes:
  - `NotReady` node → kubelet vs CNI vs etcd vs disk vs host/hardware.
  - App `Degraded` → the workload vs its storage vs the node vs the network.
  - PVC/volume stuck → Longhorn rebuild vs node down vs disk full.
- If the evidence doesn't fit, return to HYPOTHESIZE. Do not proceed on a hunch.

### 5. ACT (smallest reversible fix, confirmed)
- Choose the least-destructive fix that the evidence justifies, and route it
  through the owning skill so its confirm/rollback discipline applies.
- Prefer reversible and GitOps-native: a git commit ArgoCD syncs beats a live
  edit; add-then-remove beats edit-in-place on a firewall rule; snapshot before
  a risky VM change.
- One target at a time. Announce exactly what you're changing.

### 6. VERIFY RECOVERY
- Re-run the relevant GATHER checks and confirm the symptom is gone and nothing
  new broke. Only then move to the next item. Note what fixed it.

## Cross-layer "where to look" table
| Symptom | Look first (layer / skill) | Then rule out |
|---|---|---|
| Node `NotReady` | Talos `health`/`services`, kubelet (`talos-ops`) | CNI, etcd quorum, disk full, Proxmox host/hardware |
| Pod stuck `ContainerCreating` / volume won't mount | Longhorn volume + replica scheduling (`longhorn-ops`) | node down, disk pressure, CSI pods |
| App `OutOfSync` / `Degraded` in ArgoCD | `argocd app diff`/`get` (`argocd-ops`) | git moved vs live drift; then the workload/storage below |
| Volume `degraded`/`faulted` | Longhorn robustness + node disks (`longhorn-ops`) | **degraded=rebuilding, don't delete**; capacity/scheduling |
| Service unreachable but pod healthy | OPNsense firewall/NAT/gateway (`opnsense-api`) | VLAN/routing, DNS, load balancer |
| Whole node/VM gone | Proxmox host + VM status (`proxmox-api`) | host resources, storage backing the VM |
| etcd / control-plane wobble | Talos etcd health & quorum (`talos-ops`) | never touch multiple control-plane nodes at once |
| Config-driven regression | what changed: Ansible/Talos apply, ArgoCD sync, OPNsense apply | correlate to the recent-change timeline |

## Notes
- No single MCP spans this stack; that's *why* these skills wrap the component
  CLIs/APIs. This runbook is the coordinator over them.
- The discipline is the point: gather wide, hypothesize narrow, verify before
  acting, fix small and reversible, confirm recovery. Skipping VERIFY to "just
  restart it" is how a one-layer incident becomes a data-loss incident.
