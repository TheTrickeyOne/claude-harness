# Portability

`AGENTS.md` and `SKILL.md` are read natively by Codex, Gemini CLI, and OpenCode,
so the instructions and skills port for free. The one Claude-Code-specific piece
is the **compound-command hook** — this dir ports it to each agent.

All three ports reuse the SAME decision logic (`evaluate()` in
`global/hooks/block-compound-bash.py`) so there is one source of truth; only the
per-agent I/O wrapper differs. Keep the core in sync — if you change the
allowlist, the ports pick it up automatically because they import it.

| Agent | Mechanism | File |
|---|---|---|
| Codex CLI | PreToolUse hook (near-clone of Claude's) | `codex/` |
| Gemini CLI | BeforeTool hook (renamed event/payload) | `gemini/` |
| OpenCode | `opencode.json` permission globs (coarse) + TS plugin (precise) | `opencode/` |

`convert.sh` regenerates per-agent skill layouts (symlink/copy `.claude/skills`
into `~/.codex/skills`, build Gemini extension manifests, etc.).

> Verify event names and payload shapes against your installed agent version —
> these ecosystems move; the ports note where a field is version-sensitive.
