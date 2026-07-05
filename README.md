# claude-harness

A portable, self-adapting agent harness for infra + dev work. One repo
that (1) enforces a consistent work style, (2) drops into a new project and
rewrites itself for that project's stack, (3) ships curated + custom skills, and
(4) stays portable across Claude Code, Codex, Gemini CLI, and OpenCode.

## What's in here

| Path | Purpose |
|---|---|
| `AGENTS.md` | **Canonical** agent instructions (all agents). Edit this. |
| `CLAUDE.md` / `GEMINI.md` | Thin `@AGENTS.md` pointers + agent-specific extras. |
| `global/` | Installs into `~/.claude` — the compound-command hook + global prefs. |
| `.claude/` | Project layer: skills, slash commands, subagents, permissions. |
| `skills-catalog/` | All staged skills (`_vendored/` public, `_custom/` authored). `/bootstrap` copies the relevant subset into `.claude/skills/`. |
| `mcp/` | MCP server template, `.env.example`, `secrets.sh` resolver, catalog. |
| `portable/` | Hook/skill ports for Codex, Gemini CLI, OpenCode. |
| `docs/` | License map + canned bootstrap stack-profiles. |

## Global install (once per machine)

Installs the compound-command hook and stack-agnostic prefs so they apply in
**every** session, including un-bootstrapped repos. This touches `~/.claude` —
review before running. Each command stands alone (per the harness's own rule):

```
cp global/hooks/block-compound-bash.py  ~/.claude/hooks/block-compound-bash.py
cp global/hooks/block-compound-bash.test.py  ~/.claude/hooks/block-compound-bash.test.py
python3 ~/.claude/hooks/block-compound-bash.test.py
```

Then MERGE `global/settings.json` into `~/.claude/settings.json` (add the
`hooks.PreToolUse` entry — do not overwrite your existing file) and append the
contents of `global/CLAUDE.md` to `~/.claude/CLAUDE.md`. Your existing
`settings.local.json` permission allowlist is preserved.

Verify live: in any session, `echo a && echo b` should be denied, `ls | grep x`
allowed.

## Use in a project

**New project:**
```
cp -R claude-harness/. ~/Projects/new-thing/
```
Then open the project in Claude Code and run `/bootstrap`. It interviews you
about the stack, rewrites `AGENTS.md`'s `## Project` section, prunes
`.claude/skills/` to the relevant skills, writes a permission profile, wires the
right MCP servers, and records everything in `.harness-manifest.json`.

Skip the interview with a canned profile: `/bootstrap --profile k8s-infra`
(see `docs/stack-profiles/`). Re-tune later with `/bootstrap --reconfigure`.

**Existing project (already has files):** run `/adopt` instead — it merges the
harness in without clobbering existing `CLAUDE.md`/`.claude/` content.

## Other agents (Codex / Gemini / OpenCode)

`AGENTS.md` is read natively by all three. Skills (`SKILL.md`) are portable too —
see `portable/` for the hook ports and skill-mapping notes, and
`portable/convert.sh` for regenerating per-agent artifacts.

## Secrets

`.env` today (gitignored), referenced via `${VARS}` in `.mcp.json`. To move to
1Password or Bitwarden later, only `mcp/secrets.sh` changes — no MCP config or
skill edits. See `mcp/catalog.md`.

## Licensing

Vendored public skills keep their upstream licenses; copyleft ones
(CC-BY-SA/GPL/MPL) are isolated in per-license subdirs. Full map:
`docs/LICENSES.md`.
