#!/usr/bin/env python3
"""Gemini CLI port of the compound-command hook.

Gemini CLI exposes lifecycle hooks (BeforeTool/AfterTool/BeforeModel/...). This
wraps the canonical evaluate() and maps Gemini's BeforeTool payload to a
block/allow decision. Gemini's shell tool is typically `run_shell_command`.

Gemini's hook I/O schema is version-sensitive — verify the payload keys and the
expected "block" output against your installed `gemini` version and adjust
_extract()/the output block below if needed.
"""

import importlib.util
import json
import os
import sys

_CORE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "global", "hooks", "block-compound-bash.py",
)
_spec = importlib.util.spec_from_file_location("bcb_core", _CORE)
_core = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_core)

SHELL_TOOLS = {"run_shell_command", "shell", "bash", "Bash"}


def _extract(data):
    # Gemini BeforeTool payloads have varied by version; probe common shapes.
    name = (
        data.get("toolName")
        or data.get("tool_name")
        or data.get("name")
        or (data.get("tool") or {}).get("name")
    )
    if name not in SHELL_TOOLS:
        return False, None
    args = (
        data.get("args")
        or data.get("toolArgs")
        or data.get("parameters")
        or (data.get("tool") or {}).get("args")
        or {}
    )
    cmd = args.get("command") or args.get("cmd")
    if isinstance(cmd, list):
        cmd = " ".join(cmd)
    return True, cmd


def main():
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        return 0
    is_shell, command = _extract(data)
    if not is_shell:
        return 0
    try:
        allowed, reason = _core.evaluate(command)
    except Exception:
        return 0
    if allowed:
        return 0
    # Gemini "block" convention: emit a decision object. Field names may need
    # adjusting per version (some use {"decision":"block","reason":...}).
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
