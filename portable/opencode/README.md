# OpenCode port

Two layers, because OpenCode's declarative permission globs can't express the
"single pipe into a read-only filter" rule on their own:

1. **Coarse (declarative):** merge `opencode.permissions.json`'s `permission`
   block into your `opencode.json`. Last-match-wins globs deny the obvious
   operators (`&&`, `||`, `;`, backticks, `$(`, redirects, background) and set
   pipes to `ask`.
2. **Precise (plugin):** drop `plugin/block-compound-bash.ts` into
   `.opencode/plugin/` (project) or `~/.config/opencode/plugin/` (global). It
   implements the exact same logic as the Python hook — including the pipe
   allowlist — in `tool.execute.before`, throwing to block.

Use the plugin if you want the precise behavior (recommended). The glob layer is
a useful backstop and works with zero code.

## Instructions & skills
- OpenCode reads `AGENTS.md` natively.
- Skills (`SKILL.md`) are supported; copy `.claude/skills/` where OpenCode looks,
  or expose them as commands (see `../convert.sh`).

## Keeping in sync
`plugin/block-compound-bash.ts` mirrors `global/hooks/block-compound-bash.py`.
If you change the allowlist or rules in one, update the other. The Python file's
test suite (`block-compound-bash.test.py`) is the behavioral reference.
