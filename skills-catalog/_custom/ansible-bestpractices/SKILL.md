---
name: ansible-bestpractices
description: Idiomatic Ansible authoring and review guidance — role/collection/execution-environment structure, variable precedence, idempotency, handlers, tags, check-mode/--diff, Galaxy modules over shell, Vault for secrets, and per-site/per-network inventory separation. Use when writing or refactoring roles/playbooks, deciding how to structure inventory or variables, replacing shell tasks with proper modules, or planning a safe playbook run. Complements ansible-auditor (which audits an existing repo). Trigger on "write an ansible role", "is this playbook idiomatic", "ansible best practice", "should this be a handler", "vault", "check mode", "make this idempotent", "structure my inventory", even when phrased loosely.
---

# ansible-bestpractices

Guidance for writing Ansible the way it's meant to be written, and for running it
safely. This skill is **preview-first**: Ansible touches real hosts, so prove a
change in `--check --diff` before you apply it. For auditing an existing repo end
to end, use the `ansible-auditor` skill; this one is for authoring and reviewing
individual roles/playbooks and for safe execution.

## Golden rules
1. **Read before write.** Understand current inventory, variable precedence, and
   what a play targets before changing it. `ansible-inventory --graph` and
   reading the role's `defaults`/`vars` come first.
2. **Preview real-host runs.** Any `ansible-playbook` against real hosts runs in
   `--check --diff` first. A run **without `--check`** mutates hosts — confirm
   the target hosts/limit and that check-mode output looked right before it.
3. **Confirm every real apply.** Name the inventory, the `--limit`, and the tags.
   No accidental all-hosts runs — prefer `--limit` and `--check` by default.
4. Commands obey the harness rule — one command per call, and a single pipe into
   a read-only filter only (no `&&`, `||`, `;`, `$()`, backticks, or redirects).

## Inspect / preview (safe)
- Lint: `ansible-lint` (and `yamllint` for formatting).
- Inventory shape: `ansible-inventory --graph` · `ansible-inventory --host <h>`
  to see resolved vars for a host.
- Dry run with diff: `ansible-playbook <play> --check --diff --limit <host>` —
  the primary "what would change" tool.
- Syntax only: `ansible-playbook <play> --syntax-check`.
- List targets/tasks/tags: `ansible-playbook <play> --list-hosts` ·
  `--list-tasks` · `--list-tags`.

## Authoring guidance
- **Structure**: standard role layout (`tasks/`, `handlers/`, `defaults/`,
  `vars/`, `templates/`, `files/`, `meta/`). Package reusable roles into a
  collection; use an execution environment / `requirements.yml` to pin role and
  collection versions so runs are reproducible.
- **Variable precedence**: put sane, overridable values in `defaults/` (lowest
  meaningful precedence); reserve `vars/` for constants you don't want
  overridden; use group_vars/host_vars for inventory-scoped values. Keep the
  precedence chain shallow and predictable — deep overrides are where surprises
  live.
- **Idempotency**: a second run should report no changes. Use modules that
  declare desired state, not commands that "do" things. When you must use
  `command`/`shell`, add `creates:`/`removes:`/`changed_when:`/`when:` guards so
  the task is idempotent and honest about `changed`.
- **Galaxy modules over shell**: prefer a purpose-built module
  (`ansible.builtin.*`, certified collections) over `shell`/`command`. Modules
  are idempotent, check-mode aware, and give real diffs; raw shell usually isn't.
- **Handlers**: use handlers for restart/reload triggered by `notify`, so a
  service bounces once at the end, not per-task. Name handlers by the effect.
- **Tags**: tag tasks/roles so operators can run slices (`--tags`) and skip
  slow/destructive ones. Keep a small, documented tag vocabulary.
- **Check-mode friendliness**: write tasks so `--check` produces a meaningful
  diff; mark genuinely non-check-safe tasks with `check_mode: false` knowingly.

## Secrets & inventory separation
- **Vault**: never commit plaintext secrets. Encrypt with `ansible-vault`
  (vaulted vars files or `!vault` inline), and keep the vault password out of
  the repo. Reference secrets by variable, not literal.
- **Per-site / per-network inventory**: keep each physical site / network in its
  own inventory tree so variables and secrets don't leak across boundaries. A
  play should target one site's inventory; cross-network reuse comes from shared
  *roles*, not shared *host data*. (This mirrors the separation `ansible-auditor`
  treats as first-class.)

## Mutations (confirm first)
- **`ansible-playbook` without `--check` against real hosts** — this is the
  mutation. Confirm inventory + `--limit` + tags, and that the `--check --diff`
  preview matched intent. Prefer the smallest `--limit` (one host / one group).
- **`--diff` on apply**: run the real apply with `--diff` so changes are visible
  and auditable.
- Avoid `-e` var overrides that silently change behavior on a real run — make
  them explicit and confirmed.

## Notes
- Guidance here is re-derived from general Ansible best practice — not copied
  from any licensed docs.
- Division of labor: `ansible-auditor` reviews a whole repo and emits
  recommendations; `ansible-bestpractices` helps you write/fix one role or play
  and run it safely.
