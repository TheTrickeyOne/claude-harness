---
name: argocd-ops
description: Operate ArgoCD GitOps deployments via the argocd CLI — inspect app sync/health status, diff live-vs-desired, review history, and drive syncs/rollbacks with a git-is-source-of-truth discipline. Use when working with ArgoCD (argocd app ..., Applications, ApplicationSets), diagnosing OutOfSync/drift, a failed or degraded app, self-heal/prune behavior, or planning a sync/rollback. Trigger on "argocd", "app out of sync", "sync the app", "rollback", "gitops drift", "prune", "applicationset", "self-heal", even when the CLI isn't named explicitly.
---

# argocd-ops

ArgoCD reconciles Kubernetes state toward what's declared in git. The cluster is
an output; git is the input. This skill is **read-first** and **git-first**:
diagnose from app state, and prefer a commit that ArgoCD auto-syncs over poking
the live cluster imperatively.

## Golden rules
1. **Git is the source of truth.** To change what runs, change git and let
   ArgoCD sync. Imperative `argocd app set` / live `kubectl edit` create drift
   that self-heal or the next sync will revert — call that out before doing it.
2. **Read before write.** Always `argocd app get` and `argocd app diff` before a
   sync so you know exactly what will change.
3. **Confirm every mutation.** `sync` (especially `--prune`), `rollback`,
   `delete`, and manual `app set` change or destroy running resources. Name the
   app and what will change, and get a yes first.
4. **`--prune` deletes resources** that exist live but not in git. Treat any
   prune as destructive: enumerate what will be pruned (from the diff) and
   confirm before running.
5. `argocd` calls obey the harness command rule — one command per call, and a
   single pipe into a read-only filter only (no `&&`, `||`, `;`, `$()`,
   backticks, or redirects).

## Inspect (safe)
- List apps + status: `argocd app list` (watch `SYNC STATUS`: `Synced` /
  `OutOfSync`, and `HEALTH`: `Healthy` / `Degraded` / `Progressing` / `Missing`).
- One app: `argocd app get <app>` — sync state, health, target revision, and
  per-resource status.
- **What would change:** `argocd app diff <app>` — live vs desired manifests.
  Run this before any sync.
- History: `argocd app history <app>` — revisions you can roll back to.
- Resource tree / events: `argocd app resources <app>` and
  `kubectl describe application <app> -n argocd` for the controller's view.
- ApplicationSets: `kubectl get applicationsets -n argocd` and
  `argocd appset list` — remember an AppSet *generates* Applications; edit the
  generator/template, not the generated app.

## Diagnose OutOfSync / drift
- `OutOfSync` means live ≠ git. First `argocd app diff` to see whether git moved
  ahead (a pending deploy) or someone changed the cluster live (drift).
- If self-heal is enabled, live drift gets reverted automatically — so a manual
  live fix is temporary by design. Fix it in git instead.
- `Degraded` health with `Synced` sync usually points *below* ArgoCD (the
  workload itself, storage, node) — pivot to `homelab-runbook` rather than
  re-syncing blindly.

## Mutations (confirm first — name the app)
- **Sync** (`argocd app sync <app>`): applies git → cluster. Show the diff
  first. With `--prune`, resources absent from git are **deleted** — enumerate
  and confirm. Avoid `--force` unless you've explained the replace it triggers.
- **Rollback** (`argocd app rollback <app> <history-id>`): reverts to a prior
  synced revision but *diverges from git HEAD* — confirm, and follow up by
  reconciling git so the next sync doesn't undo it.
- **Delete** (`argocd app delete <app>`): with cascade this deletes the app's
  live resources. Confirm cascade behavior and that it's intended.
- **Manual `argocd app set`** (image, params, target revision): creates drift
  vs git. Prefer a git commit; if used for a hotfix, note it must be back-ported
  to git or it will be reverted.

## Self-heal & auto-sync considerations
- With auto-sync + self-heal on, the safe change path is: commit to git → watch
  `argocd app get` reconcile. Manual/live edits fight the controller.
- Before disabling auto-sync/self-heal to do surgery, note it and re-enable
  after — a silently-disabled sync policy is a latent drift source.

## Notes
- No official ArgoCD MCP exists; this skill wraps the `argocd` CLI (and
  `kubectl` against the `argocd` namespace) deliberately.
- Pair with `homelab-runbook` when a `Degraded` app is really a storage/node
  symptom, and with `longhorn-ops`/`talos-ops` for the layers underneath.
