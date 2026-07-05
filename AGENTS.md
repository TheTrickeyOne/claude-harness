# AGENTS.md — canonical agent instructions

This is the single source of truth for how coding agents work in this repo. It
is read natively by Codex, Gemini CLI, OpenCode, and others; Claude Code reads
it via the `@AGENTS.md` import in `CLAUDE.md`. Edit **this** file — the others
are thin pointers.

`/bootstrap` fills in the `## Project` section at the bottom for the specific
stack this repo targets. Everything above it is the stack-agnostic contract.

---

## Command discipline
- **One command per shell call.** No chaining (`&&`, `||`, `;`), no command or
  process substitution (`$(...)`, backticks, `<(...)`), no redirects
  (`>`, `>>`), no background `&`. A **single** pipe into a read-only filter
  (`grep egrep rg head tail wc jq yq sort uniq cut tr column less cat nl awk
  sed`) is allowed; `awk`/`sed` must not carry write/in-place flags.
  - In Claude Code this is hard-enforced by the `block-compound-bash` hook.
    Other agents self-comply by following this rule.
  - Need two things done? Issue two separate calls.
- Prefer dedicated file tools over shell (`cat`/`sed -i`/`echo >`).

## Change discipline
- Do not commit or push unless explicitly asked. Branch before committing on a
  default branch. End commit messages with the project's trailer convention.
- Confirm before destructive or outward-facing actions. Approval in one context
  does not extend to the next.
- Read a target before deleting/overwriting it; if what you find contradicts how
  it was described, surface that instead of proceeding.

## Infra & operational safety
- **Read before write** on any live system. Inspect current state first.
- **Hypothesis before action** on incidents: gather state, form a hypothesis,
  confirm the evidence supports the specific fix before a restart/delete/config
  change. A signal that pattern-matches a known failure may have another cause.
- Never run state-mutating cluster/host commands (`kubectl delete`,
  `qm destroy`/`pct destroy`, `pvesh` writes, firewall-rule changes, node
  reboots) without explicit confirmation. Default to read-only verbs.
- Secrets never land in git, logs, or command output. Reference them via env
  vars resolved at launch (see `mcp/secrets.sh`).

## Communication
- Lead with the outcome — the first sentence answers "what happened / what did
  you find." Supporting detail after. Full sentences, spelled-out terms.
- If tests fail or a step was skipped, say so plainly with the evidence.

## Working style
- When you have enough to act, act — don't re-litigate settled decisions or
  narrate options you won't take. For reversible actions that follow from the
  request, proceed; stop only for destructive actions or genuine scope changes.
- When the user is thinking out loud or asking a question, the deliverable is
  your assessment — report findings and stop; don't apply a fix until asked.

---

## Project
<!-- BOOTSTRAP:PROJECT -->
_Not yet bootstrapped. Run `/bootstrap` (Claude Code) to fill this in for this
repo's stack, or edit this section by hand. It should name: the stack
components in play, key endpoints/hosts, repo conventions, and any
stack-specific safety notes._
<!-- /BOOTSTRAP:PROJECT -->
