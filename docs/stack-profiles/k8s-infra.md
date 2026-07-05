---
profile: k8s-infra
projectType: infra
stackComponents: [Talos, Longhorn, ArgoCD, Ansible, Proxmox, Kubernetes]
secretsBackend: env
securityToolingAuthorized: false
---

# Profile: k8s-infra

Core homelab profile: Talos/Longhorn/ArgoCD Kubernetes on Proxmox, managed with
Ansible. Read-first, GitOps-driven.

## Skills enabled
talos-ops, longhorn-ops, argocd-ops, ansible-bestpractices, ansible-auditor,
proxmox-api, homelab-runbook, secrets-hygiene, git-pr-workflow, docs-diagrams,
systematic-debugging, verification-before-completion, kubernetes-skill.

## MCP servers
kubernetes (read-only mode), argocd, grafana, github. Proxmox MCP left OFF by
default — use the `proxmox-api` skill; enable the MCP only after auditing it.

## permissions.allow (starting point — merge, don't replace)
```json
[
  "Read(//**)",
  "Bash(kubectl get *)",
  "Bash(kubectl describe *)",
  "Bash(kubectl logs *)",
  "Bash(kubectl top *)",
  "Bash(talosctl get *)",
  "Bash(talosctl health *)",
  "Bash(talosctl dmesg *)",
  "Bash(talosctl version *)",
  "Bash(argocd app get *)",
  "Bash(argocd app list *)",
  "Bash(argocd app diff *)",
  "Bash(ansible-inventory *)",
  "Bash(ansible-lint *)",
  "Bash(ansible-playbook * --check *)",
  "Bash(pvesh get *)",
  "Bash(helm list *)",
  "Bash(helm get *)",
  "Bash(git status)",
  "Bash(git diff *)",
  "Bash(git log *)"
]
```

## Safety notes to write into AGENTS.md ## Project
- Treat the cluster as production. Never `kubectl delete`, `talosctl reset`,
  `talosctl upgrade`, `argocd app delete`, `pvesh` writes, or `ansible-playbook`
  without `--check` unless the user explicitly confirms that specific action.
- Longhorn: never delete a volume/replica; degraded ≠ delete. Triage first.
- ArgoCD is the source of truth — prefer git changes over live `kubectl edit`.
