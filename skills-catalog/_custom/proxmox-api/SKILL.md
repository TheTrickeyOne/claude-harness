---
name: proxmox-api
description: Manage Proxmox VE via pvesh/the API and qm/pct — inspect and operate VMs, LXC containers, storage, backups, and cluster status with a read-first, confirm-on-destroy safety model. Use when working with Proxmox (pvesh, qm, pct, PVE cluster, VM/CT lifecycle, snapshots, backups, ZFS/Ceph storage on PVE). Trigger on "proxmox", "pvesh", "qm", "pct", "VM 100", "LXC container", "PVE node", even when the tool name isn't explicit.
---

# proxmox-api

Operate Proxmox VE safely. Reads and inspection are free; anything that starts,
stops, deletes, or rewrites a VM/CT/storage requires explicit confirmation. This
skill adopts the unprivileged-user + confirm-on-destroy model from the community
proxmox-manager skill.

## Golden rules
1. **Read before write.** Know the current state of a VMID/node before changing
   it. `pvesh get` and `qm/pct` status verbs are safe.
2. **Confirm every destructive or state-changing op.** Name the exact node and
   VMID and what happens. This covers: `qm/pct destroy`, `stop`, `shutdown`,
   `reset`, `rollback`, `qm set` that changes hardware, disk resize/delete,
   `pvesm` removal, and any `pvesh create/set/delete`.
3. **Guard VMID reuse.** Confirm the VMID maps to the machine you think it does
   (`qm config <vmid>` / `pct config <vmid>`) before acting — IDs get recycled.
4. **Prefer the API token path** with least privilege; never require root SSH.
   Run destructive verbs only against nodes/pools the token is scoped to.
5. One command per call (harness rule); a single read-only-filter pipe is fine.

## Inspect (safe)
- Cluster + nodes: `pvesh get /cluster/status` · `pvesh get /nodes`
- Node resources: `pvesh get /nodes/<node>/status`
- VM list/config/status:
  `qm list` · `qm config <vmid>` · `qm status <vmid>`
- Container list/config/status:
  `pct list` · `pct config <vmid>` · `pct status <vmid>`
- Storage: `pvesm status` · `pvesh get /nodes/<node>/storage`
- Backups/tasks: `pvesh get /nodes/<node>/tasks` ·
  `pvesh get /cluster/backup`
- Snapshots: `qm listsnapshot <vmid>` · `pct listsnapshot <vmid>`

## Lifecycle (confirm first)
- Start is low-risk but still announce it: `qm start <vmid>` / `pct start <vmid>`.
- Stop/shutdown/reset interrupt running workloads — confirm:
  `qm shutdown <vmid>` (graceful) vs `qm stop <vmid>` (hard). Prefer graceful.
- Snapshot before risky changes: `qm snapshot <vmid> <name>` — cheap insurance.
- Rollback is destructive of intervening state: `qm rollback <vmid> <name>` —
  confirm the snapshot and that the user accepts losing changes since.

## Destructive (explicit confirmation, name the target)
- `qm destroy <vmid>` / `pct destroy <vmid>` — irreversible. Confirm VMID,
  node, and that backups exist. Never batch-destroy.
- Disk/hardware edits via `qm set` (e.g. `--delete`, resize down) — can lose
  data. Show the current `qm config` diff first.
- Storage removal (`pvesm remove`, deleting a datastore) — confirm nothing
  depends on it.

## Backups
- Trigger: `vzdump <vmid> --storage <store> --mode snapshot` (announce target
  store + mode). Verify space first (`pvesm status`).
- Restore is destructive to the target VMID — confirm you won't overwrite a live
  machine.

## Safety model to record in AGENTS.md
- The API token in use and its privilege scope.
- Which nodes/pools are in scope.
- That destructive verbs require confirmation naming node + VMID.
- Keep an audit trail: state each mutating command run and its outcome.

## Notes
- No official Proxmox MCP exists; a community MCP can be wired (see
  `mcp/catalog.md`) but audit its code first and prefer this skill for safety.
- `pvesh` mirrors the REST API 1:1 — anything in the API is reachable, so the
  confirm-on-write discipline is what keeps it safe.
