# Gemini CLI port

`block-compound-bash-gemini.py` reuses the canonical `evaluate()` and adapts the
I/O to a Gemini `BeforeTool` hook.

## Install
1. Register a `BeforeTool` hook (Gemini hooks are enabled by default in recent
   versions) that runs on shell tool calls:
   ```
   python3 /path/to/claude-harness/portable/gemini/block-compound-bash-gemini.py
   ```
2. Instructions: point Gemini at `AGENTS.md`. Either keep `GEMINI.md` (which
   imports `@AGENTS.md`) or set `contextFileName=AGENTS.md` in Gemini settings.
3. Skills: Gemini Agent Skills are supported (preview→stable through 2026). Use
   `../convert.sh` to lay skills out where Gemini expects, or convert to Gemini
   extensions with a tool like `jduncan-rva/skill-porter`.

## Notes
- Gemini's hook event names (`BeforeTool`) and block-output schema are
  version-sensitive. If blocking doesn't take effect, check whether your version
  expects `{"decision":"block"}` vs another shape and adjust the script.
- The shell tool is usually `run_shell_command`; edit `SHELL_TOOLS` if not.
