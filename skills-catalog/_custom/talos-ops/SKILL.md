---
name: talos-ops
description: Operate and troubleshoot Talos Linux Kubernetes nodes via talosctl — cluster/node health, machine config inspection and diffs, etcd health, and safe upgrades. Use when working with a Talos cluster (talosctl, machineconfig, talconfig, Sidero/Omni), diagnosing node problems, checking etcd/control-plane health, or planning a Talos or Kubernetes-version upgrade. Trigger on "talos", "talosctl", "machine config", "control plane down", "etcd", "upgrade the node/cluster", even when talosctl isn't named explicitly.
---

# talos-ops

Talos is an immutable, API-driven Linux for Kubernetes — there is no SSH and no
package manager. Everything goes through `talosctl` against the machine API.
This skill is **read-first**: diagnose from state before changing anything, and
never mutate a node without explicit confirmation.

## Golden rules
1. **Read before write.** Establish current state with `get`/`health`/`dmesg`
   before any `apply-config`, `upgrade`, `reset`, or `reboot`.
2. **Confirm every mutation.** `talosctl reset`, `upgrade`, `upgrade-k8s`,
   `reboot`, `shutdown`, and `apply-config` (non-`--dry-run`) change or destroy a
   node. State exactly which node and what will happen, and get a yes first.
3. **One node at a time** for control-plane changes; never touch a quorum's worth
   of control-plane nodes together.
4. `talosctl` calls obey the harness command rule — one command per call, a
   single pipe into a read-only filter only.

## Diagnose (safe, read-only)
- Cluster/members: `talosctl get members`
- Node/service health: `talosctl health --nodes <ip>` and
  `talosctl services --nodes <ip>`
- Kernel log: `talosctl dmesg --nodes <ip>`
- Resources (Talos COSI): `talosctl get <resource> --nodes <ip>` — useful ones:
  `nodestatus`, `machineconfig`, `staticpods`, `etcdmembers`, `certsans`,
  `addresses`, `routes`, `links`, `mounts`, `disks`.
- Version: `talosctl version --nodes <ip>`
- Support bundle (for deep triage): `talosctl support --nodes <ip>` (writes an
  archive — confirm the output path first).

## etcd / control-plane health
- `talosctl get etcdmembers --nodes <cp-ip>`
- `talosctl etcd status` (read-only)
- Before any control-plane upgrade/reset, verify etcd has quorum and all members
  are healthy. If quorum is at risk, STOP and surface it — do not proceed.
- etcd recovery (`talosctl etcd remove-member`, `bootstrap`) is destructive —
  treat as a break-glass action requiring explicit confirmation and a snapshot
  (`talosctl etcd snapshot <path>`) first.

## Machine config
- Inspect live config: `talosctl get machineconfig --nodes <ip> -o yaml`
- **Diff before apply:** generate/patch the config, then
  `talosctl apply-config --dry-run --nodes <ip> --file <cfg>` and show the diff.
  Only after the user approves the diff, apply without `--dry-run`.
- Prefer the declarative source (talhelper/`talconfig.yaml`, or the GitOps repo)
  over ad-hoc live patches, so the change survives an upgrade.
- Apply modes matter: `--mode=auto` may reboot; call out whether the change
  triggers a reboot before applying.

## Upgrades (destructive — confirm target + version)
- Talos: `talosctl upgrade --nodes <ip> --image <installer:version>`. Check the
  release notes for the version path; don't skip across unsupported jumps.
- Kubernetes: `talosctl upgrade-k8s --to <version>` (run from a control-plane
  node context). Verify workloads tolerate the new k8s version first.
- Always: drain/verify workload placement expectations, upgrade one node, watch
  it rejoin healthy (`get members`, `health`), then proceed.

## When something's down
Follow the `homelab-runbook` triage loop: gather Talos state + `kubectl` state,
form a hypothesis, confirm the evidence points to the specific fix, then act
with confirmation. A node showing `NotReady` in kubectl may be a kubelet, a CNI,
an etcd, or a hardware issue — distinguish before rebooting.

## Notes
- No official Talos MCP exists; this skill wraps `talosctl` deliberately. Pair
  with Sidero/Omni docs for Omni-managed clusters.
- If the cluster is Omni-managed, some lifecycle actions belong in Omni, not
  raw `talosctl` — check which is the source of truth before acting.
