# Codex CLI port

`block-compound-bash-codex.py` reuses the canonical `evaluate()` from
`global/hooks/block-compound-bash.py` and adapts only the I/O to Codex.

## Install
1. Ensure Python 3 is available.
2. Register a PreToolUse hook in your Codex config (`~/.codex/` config, per Codex
   docs) that runs, on shell tool calls:
   ```
   python3 /path/to/claude-harness/portable/codex/block-compound-bash-codex.py
   ```
3. Codex reads `AGENTS.md` natively — no extra step for instructions.
4. Skills: symlink or copy `.claude/skills/` into `~/.codex/skills/` (see
   `../convert.sh`).

## Notes
- Codex's deny shape is `{"permissionDecision":"deny","reason":"..."}`; a hook
  is a guardrail, not a hard boundary — the model may reach an effect via another
  tool path, so keep the AGENTS.md command-rule as the primary discipline.
- If your Codex version names the shell tool something not in `SHELL_TOOLS` or
  nests the command differently, edit `_extract()`.
