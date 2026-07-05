@AGENTS.md

## Claude Code

The canonical instructions are in `AGENTS.md` (imported above). This block holds
only the Claude-Code-specific extras.

- **Skills:** enabled skills for this repo live in `.claude/skills/`. The full
  staged catalog is in `skills-catalog/` (`_vendored/` = public, `_custom/` =
  authored for this stack). `/bootstrap` copies the relevant subset in.
- **Compound-command hook:** `block-compound-bash` (registered globally in
  `~/.claude/settings.json`, mirrored in `.claude/settings.json`) enforces the
  command-discipline rule. If a Bash call is denied for chaining/pipes, split it
  into separate calls — do not try to work around the hook.
- **Bootstrap:** `/bootstrap` tailors this repo to its stack; `/adopt` merges the
  harness into an existing project without clobbering. `/bootstrap --reconfigure`
  re-runs idempotently using `.harness-manifest.json`.
