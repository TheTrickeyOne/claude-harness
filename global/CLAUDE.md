# Global work-style preferences (Mark)

Stack-agnostic operating rules that apply in every session, including repos that
have not been bootstrapped. Project-specific rules live in each repo's
`AGENTS.md`. Keep this file short; it loads into every session.

## Command discipline
- **One command per Bash call.** No `&&`, `||`, `;`, `$(...)`, backticks,
  redirects, or background `&`. A single pipe into a read-only filter
  (`grep`, `head`, `tail`, `wc`, `jq`, `sort`, ...) is fine. This is enforced by
  the `block-compound-bash` hook — but follow it by habit so the rule holds in
  other agents (Codex/Gemini/OpenCode) that lack the hook.
- Prefer the dedicated file tools (Read/Edit/Write/Grep/Glob) over shell
  equivalents (`cat`/`sed`/`echo >`).

## Change discipline
- Never commit or push unless asked. If on a default branch, branch first.
- Confirm before destructive or outward-facing actions (deletes, `kubectl
  delete`, `qm destroy`, VM power-offs, sending anything externally).
- Report outcomes faithfully: if a command failed, say so with the output.

## Communication
- Lead with the outcome. Full sentences, spelled-out technical terms — no
  arrow-chains or shorthand. Match depth to the question.

## Infra safety (applies whenever a live system is in reach)
- Read before you write: inspect current state before changing it.
- On an incident, gather state and form a hypothesis before acting; verify the
  evidence supports the specific action before a restart/delete/config edit.
