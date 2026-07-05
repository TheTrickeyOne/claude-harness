#!/usr/bin/env python3
"""Codex CLI port of the compound-command hook.

Codex's PreToolUse hook I/O is a near-clone of Claude Code's, so this is a thin
wrapper that reuses the SAME evaluate() from the canonical hook. Codex names its
shell tool differently across versions (`shell`, `local_shell`, `bash`) and may
nest the command under different keys — we probe the likely shapes.

Install: reference this from your Codex hooks config as a PreToolUse command
hook. Deny output shape ({"permissionDecision":"deny",...}) matches Codex.

Verify the tool name + payload keys against your Codex version; adjust
_extract_command() if they differ.
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

SHELL_TOOLS = {"bash", "shell", "local_shell", "Bash"}


def _extract(data):
    """Return (is_shell, command) probing Codex payload shapes."""
    name = data.get("tool_name") or data.get("tool") or data.get("name")
    if name not in SHELL_TOOLS:
        return False, None
    ti = data.get("tool_input") or data.get("input") or data.get("arguments") or {}
    cmd = ti.get("command") or ti.get("cmd")
    if isinstance(cmd, list):  # some shells pass argv
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
    print(json.dumps({"permissionDecision": "deny", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
