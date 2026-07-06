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

Pick the weight that matches the project. Most of the time you want one of the
first two — the full flow is only for stack-heavy work.

### Simple project — nothing to install
The compound-command hook and work-style prefs are already global (in
`~/.claude`), so a bare new directory is already covered:
```
mkdir foo && cd foo && git init && claude
```
Optionally run the built-in `/init` for a project `CLAUDE.md`. No harness copy,
no bootstrap.

### Simple project + good-habits skills — one command
Adds `AGENTS.md` + ~5 core dev skills (TDD, debugging, verification, git/secrets
hygiene). A few KB, no 158 MB catalog, no interview, no MCP. Two ways:

- **Before opening Claude** (from your canonical clone; target defaults to cwd):
  ```
  bash ~/src/claude-harness/bin/harness-init.sh ~/Projects/foo
  ```
- **Inside Claude**, in a project that has the harness copied in:
  ```
  > /bootstrap light
  ```

Both leave any existing `AGENTS.md`/`CLAUDE.md` untouched.

### Stack-heavy project — full bootstrap
```
npx degit TheTrickeyOne/claude-harness new-thing
cd new-thing && claude
> /bootstrap        # or: /bootstrap --profile k8s-infra
```
`/bootstrap` interviews you about the stack, rewrites `AGENTS.md`'s `## Project`
section, prunes `.claude/skills/` to the relevant skills, writes a permission
profile, wires MCP servers, and records choices in `.harness-manifest.json`.
Re-tune later with `/bootstrap --reconfigure`. Then trim the staging catalog:
`echo "skills-catalog/_vendored/" >> .gitignore` (the pruned skills you use live
in `.claude/skills/`).

**Existing project (already has files):** run `/adopt` instead — it merges the
harness in without clobbering existing `CLAUDE.md`/`.claude/` content.

## Other agents (Codex / Gemini / OpenCode)

`AGENTS.md` is read natively by all three. Skills (`SKILL.md`) are portable too —
see `portable/` for the hook ports and skill-mapping notes, and
`portable/convert.sh` for regenerating per-agent artifacts.

## Secrets

Three composable layers (full detail in **`docs/secrets.md`**):
1. **`.env`** (gitignored), referenced via `${VARS}` in `.mcp.json` — quick start.
2. **Infisical `run`** — self-hosted, injects secrets as env; nothing on disk.
3. **Agent Vault** — TLS-intercepting egress proxy so the agent never holds raw
   API tokens (only placeholders); trust via your own internal PKI, not a public
   cert. Pilot layer (research preview).

`${VAR}` references are backend-agnostic — only how they're populated changes.

## Licensing

This harness's own code (hook, `skills-catalog/_custom/`, commands, profiles, MCP
config, portability adapters, docs) is **MIT** — see `LICENSE`. Vendored public
skills under `skills-catalog/_vendored/` keep their upstream licenses; copyleft
ones (CC-BY-SA/GPL/MPL) are isolated in per-license subdirs. Full map:
`docs/LICENSES.md`.
