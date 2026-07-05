---
name: longhorn-ops
description: Operate and triage Longhorn distributed block storage on Kubernetes — it is entirely CRD-driven, so everything runs through kubectl against the longhorn-system namespace. Use when working with Longhorn volumes/replicas/engines, diagnosing a degraded or faulted volume, checking node/disk capacity, or driving Longhorn backups/restores. Trigger on "longhorn", "volume degraded", "volume faulted", "replica rebuild", "PVC stuck", "detached volume", "robustness", "longhorn backup/restore", even when kubectl isn't named explicitly.
---

# longhorn-ops

Longhorn is a Kubernetes-native distributed block store. Its entire control
surface is CRDs in the `longhorn-system` namespace, so you operate it with
`kubectl` — there is no separate CLI. This skill is **read-first**: a volume in
trouble is usually mid-recovery, and the wrong `delete` turns a self-healing
problem into data loss.

## Golden rules
1. **Read before write.** Establish `robustness`, `state`, and replica placement
   with `kubectl get`/`describe` before touching anything.
2. **Degraded ≠ delete.** A `degraded` volume is actively rebuilding a replica —
   it is healthy-but-working, not broken. Never delete replicas or the volume to
   "fix" degraded; you remove the very copies it is rebuilding from. Wait for it
   to return to `healthy`, or add disk/node capacity so a replica can schedule.
3. **Confirm every mutation.** `kubectl delete` of a volume/replica/backup,
   detach, or a replica-count change destroys or moves data. State the exact
   object name and namespace and what happens, and get a yes first.
4. `kubectl` calls obey the harness command rule — one command per call, and a
   single pipe into a read-only filter only (no `&&`, `||`, `;`, `$()`,
   backticks, or redirects).

## Inspect (safe)
- Volumes: `kubectl get volumes.longhorn.io -n longhorn-system`
  (watch the `ROBUSTNESS` column: `healthy` / `degraded` / `faulted` / `unknown`,
  and `STATE`: `attached` / `detached`).
- One volume in detail: `kubectl describe volumes.longhorn.io <vol> -n longhorn-system`
- Replicas (the physical copies): `kubectl get replicas.longhorn.io -n longhorn-system -o wide`
- Engines (the per-volume controller): `kubectl get engines.longhorn.io -n longhorn-system`
- Nodes + disks (scheduling/capacity): `kubectl get nodes.longhorn.io -n longhorn-system`
  and `kubectl describe nodes.longhorn.io <node> -n longhorn-system` for disk
  pressure, schedulable state, and allowed replica counts.
- Backups/snapshots: `kubectl get backups.longhorn.io -n longhorn-system` ·
  `kubectl get backupvolumes.longhorn.io -n longhorn-system` ·
  `kubectl get snapshots.longhorn.io -n longhorn-system`
- Manager health: `kubectl get pods -n longhorn-system` (look for the
  `longhorn-manager`, `instance-manager`, and CSI pods).

## Triage a degraded / faulted volume
- `degraded`: fewer healthy replicas than requested; Longhorn is rebuilding.
  Check *why a replica won't schedule* — `describe` the volume and the
  `nodes.longhorn.io` for disk-full, node cordoned/unschedulable, or
  replica-count > available nodes. Fix the capacity/scheduling cause; the volume
  heals itself. Do **not** delete replicas.
- `faulted`: no usable replica — this is the dangerous one. Do not delete
  anything. Look for the most recent good replica/snapshot and prefer a
  restore-from-backup path over any in-place surgery. Surface it before acting.
- Stuck attach/detach: check the `engines.longhorn.io` state and the
  instance-manager pod on the owning node before forcing anything.

## Mutations (confirm first — name the exact object)
- **Delete a replica** (`kubectl delete replicas.longhorn.io <r> -n longhorn-system`):
  only ever to evict a *known-bad* copy from a full/failing disk, and only when
  other replicas are healthy. Never on a degraded/faulted volume to "reset" it.
- **Delete a volume** (`kubectl delete volumes.longhorn.io <vol> -n longhorn-system`):
  destroys the PV's data. Confirm the PVC is truly unused and a backup exists.
- **Detach**: patch the volume's `nodeID`/attachment — interrupts the workload;
  confirm the consuming pod is stopped.
- **Change replica count**: edit `spec.numberOfReplicas` on the volume. Raising
  it triggers rebuilds (load); lowering it deletes copies (less redundancy) —
  confirm which and why.
- **Delete a backup** (`kubectl delete backups.longhorn.io <b> -n longhorn-system`):
  removes a restore point permanently. Confirm it isn't the last good one.

## Backup / restore
- Backups and restores flow through Longhorn CRs against the configured backup
  target (S3/NFS). Verify the backup target is reachable
  (`kubectl get settings.longhorn.io -n longhorn-system`) before relying on it.
- Restore creates a new volume from a `Backup` — confirm the target volume name
  won't collide with a live one.

## Notes
- No official Longhorn MCP exists; this skill wraps `kubectl` against the CRDs
  deliberately. The UI shows the same objects — CRDs are the source of truth.
- Pair with `talos-ops` (node/disk health underneath) and `homelab-runbook`
  when a storage symptom might actually be a node or network problem.
